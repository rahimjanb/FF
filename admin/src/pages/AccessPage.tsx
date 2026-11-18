import { useEffect, useState, type FormEvent } from 'react'
import { Link } from 'react-router'
import { absoluteApiUrl, api, qs } from '../api/client'
import type { AccessDevice, AccessDeviceCheck, AccessEvent, AccessIssue, AccessSyncResult, Paged } from '../api/types'
import { useAuth } from '../auth/AuthContext'
import { Badge, Button, Card, DataState, Empty, ErrorBanner, Field, Modal, PageHeader, Pagination } from '../components/ui'
import { fmtDateTime, fullName, type Tone } from '../lib/format'
import { errorMessage, fieldErrors, useAsync } from '../lib/useAsync'

/** A device that answered or sent an event this recently is shown as online. */
const ONLINE_MS = 10 * 60 * 1000

/** ISAPI minor event codes the server records (major type 5, access events). */
const minorLabel: Record<number, string> = {
  75: 'по лицу', 1: 'по карте', 38: 'по отпечатку', 76: 'лицо не прошло проверку', 9: 'вне срока действия',
}

/** Why a pass did not become a visit. */
const noteLabel: Record<string, string> = {
  no_membership: 'нет действующего абонемента',
  membership_frozen: 'абонемент заморожен',
  visit_limit_reached: 'посещения закончились',
  client_blocked: 'клиент заблокирован',
  unknown_person: 'номер на терминале не найден среди клиентов',
  invalid_code: 'клиент не найден',
}

function deviceStatus(d: AccessDevice): { label: string; tone: Tone } {
  if (!d.isActive) return { label: 'Выключен', tone: 'gray' }
  const last = Math.max(d.lastContactAt ? Date.parse(d.lastContactAt) : 0, d.lastEventAt ? Date.parse(d.lastEventAt) : 0)
  if (d.lastError) return { label: 'Ошибка связи', tone: 'red' }
  if (last > 0 && Date.now() - last < ONLINE_MS) return { label: 'На связи', tone: 'green' }
  return { label: last > 0 ? 'Давно не на связи' : 'Ещё не проверен', tone: 'orange' }
}

/**
 * Face recognition terminals (Hikvision). The server writes clients with a face photo and membership days to the
 * terminal; the terminal lets them in by itself and reports passes back, which become visits.
 */
export function AccessPage() {
  const { user } = useAuth()
  const allowed = !!user?.canManageIntegrations
  const [editing, setEditing] = useState<AccessDevice | 'new' | null>(null)
  const devices = useAsync(() => (allowed ? api<AccessDevice[]>('/api/admin/access/devices') : Promise.resolve([])), [allowed])

  // Synchronisation runs in the background on the server; keep the counters fresh.
  const { reload } = devices
  useEffect(() => {
    if (!allowed) return
    const timer = window.setInterval(reload, 30_000)
    return () => window.clearInterval(timer)
  }, [allowed, reload])

  return (
    <>
      <PageHeader title="Турникеты" actions={allowed && <Button onClick={() => setEditing('new')}>+ Терминал</Button>} />
      <p className="muted page-hint">
        Терминалы распознавания лиц Hikvision (DS-K1T343MFWX и похожие) пускают клиента по фото, пока действует абонемент.
        Сервер сам записывает на терминал клиентов с фото и датами абонемента и убирает тех, у кого он закончился. Проходы
        терминал присылает обратно — они отмечаются как посещения.
      </p>
      {allowed ? (
        <DataState loading={devices.loading && !devices.data} error={devices.error} empty={false} onRetry={devices.reload}>
          {devices.data && devices.data.length > 0 && !devices.data[0].encryptionConfigured && (
            <ErrorBanner message="На сервере не задан ключ шифрования Integrations__EncryptionKey: пароль терминала сохранить нельзя." />
          )}
          {devices.data?.length === 0 && (
            <Empty>Терминалы не подключены. Добавьте терминал: его IP-адрес в сети клуба, логин и пароль администратора терминала.</Empty>
          )}
          {devices.data?.map(d => <DeviceCard key={d.id} device={d} onEdit={() => setEditing(d)} onChanged={devices.reload} />)}
        </DataState>
      ) : (
        <Card><p className="muted">Настройки терминалов доступны администраторам с правом управления интеграциями. Журнал проходов — ниже.</p></Card>
      )}
      <Journal />
      {editing && (
        <DeviceModal device={editing === 'new' ? null : editing} onClose={() => setEditing(null)}
          onSaved={() => { setEditing(null); devices.reload() }} />
      )}
    </>
  )
}

function DeviceCard({ device: d, onEdit, onChanged }: { device: AccessDevice; onEdit(): void; onChanged(): void }) {
  const [busy, setBusy] = useState<'check' | 'sync' | 'delete' | null>(null)
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null)
  const status = deviceStatus(d)
  const s = d.stats
  const problems = s.failed + s.photoRejected

  async function check() {
    setBusy('check'); setMessage(null)
    try {
      const r = await api<AccessDeviceCheck>(`/api/admin/access/devices/${d.id}/check`, { method: 'POST' })
      if (!r.ok) setMessage({ ok: false, text: `Нет связи: ${r.error}` })
      else {
        const warnings = [
          r.timeZoneMatches === false && 'часовой пояс терминала не совпадает с клубом (UTC+5)',
          r.clockSkewSeconds !== null && Math.abs(r.clockSkewSeconds) > 120 &&
            `часы терминала расходятся с сервером на ${Math.round(Math.abs(r.clockSkewSeconds) / 60)} мин`,
        ].filter(Boolean)
        setMessage({
          ok: warnings.length === 0,
          text: `Связь есть: ${r.device.model ?? 'модель не указана'}, прошивка ${r.device.firmware ?? '—'}.`
            + (warnings.length ? ` Внимание: ${warnings.join('; ')} — включите NTP и UTC+5 на терминале.` : ''),
        })
      }
      onChanged()
    } catch (e) { setMessage({ ok: false, text: errorMessage(e) }) } finally { setBusy(null) }
  }

  async function sync() {
    setBusy('sync'); setMessage(null)
    try {
      const { report: r } = await api<AccessSyncResult>(`/api/admin/access/devices/${d.id}/sync`, { method: 'POST' })
      if (r.deviceError) setMessage({ ok: false, text: `Синхронизация прервана: ${r.deviceError}` })
      else {
        const parts = [
          r.written && `записано клиентов: ${r.written}`, r.facesUploaded && `фото: ${r.facesUploaded}`,
          r.removed && `удалено: ${r.removed}`, r.failed && `ошибок: ${r.failed}`, r.remaining && `осталось: ${r.remaining}`,
        ].filter(Boolean)
        setMessage({ ok: r.failed === 0, text: parts.length ? `Готово — ${parts.join(', ')}.` : 'Готово — терминал уже в актуальном состоянии.' })
      }
      onChanged()
    } catch (e) { setMessage({ ok: false, text: errorMessage(e) }) } finally { setBusy(null) }
  }

  async function remove() {
    if (!window.confirm(`Удалить терминал «${d.name}»? Клиенты, уже записанные на него, останутся на самом терминале — удалите их там при необходимости.`)) return
    setBusy('delete')
    try { await api(`/api/admin/access/devices/${d.id}`, { method: 'DELETE' }); onChanged() }
    catch (e) { setMessage({ ok: false, text: errorMessage(e) }); setBusy(null) }
  }

  return (
    <section className="card access-device">
      <div className="card-header">
        <div className="row-actions">
          <h2>{d.name}</h2>
          <Badge tone={status.tone}>{status.label}</Badge>
          <Badge tone="gray">{d.recordsVisits ? 'Вход — отмечает посещения' : 'Выход'}</Badge>
        </div>
        <div className="row-actions">
          <Button variant="secondary" disabled={!!busy} onClick={check}>{busy === 'check' ? 'Проверка…' : 'Проверить связь'}</Button>
          <Button variant="secondary" disabled={!!busy || !d.isActive} onClick={sync}>{busy === 'sync' ? 'Синхронизация…' : 'Синхронизировать'}</Button>
          <Button variant="ghost" disabled={!!busy} onClick={onEdit}>Изменить</Button>
          <Button variant="ghost" disabled={!!busy} onClick={remove}>Удалить</Button>
        </div>
      </div>
      {d.lastError && <ErrorBanner message={`${d.lastError}${d.lastErrorAt ? ` (${fmtDateTime(d.lastErrorAt)})` : ''}`} />}
      {message && <div className={`banner ${message.ok ? 'banner-success' : 'banner-error'}`} role="status">{message.text}</div>}

      <div className="access-stats">
        <div><b>{s.synced}<span className="muted"> / {s.planned}</span></b><span>на терминале</span></div>
        <div><b>{s.pending}</b><span>ожидают отправки</span></div>
        <div className={s.failed ? 'bad' : ''}><b>{s.failed}</b><span>ошибок</span></div>
        <div className={s.photoRejected ? 'bad' : ''}><b>{s.photoRejected}</b><span>фото не подошло</span></div>
      </div>

      <div className="access-columns">
        <div className="kv">
          <div><span>Адрес</span><b>{d.baseUrl}</b></div>
          <div><span>Логин</span><b>{d.username}</b></div>
          <div><span>Модель</span><b>{d.model ?? '—'}</b></div>
          <div><span>Серийный номер</span><b className="access-mono">{d.serialNumber ?? '—'}</b></div>
          <div><span>Прошивка</span><b>{d.firmware ?? '—'}</b></div>
          <div><span>Дверь</span><b>№ {d.doorNo}</b></div>
          <div><span>Последний ответ</span><b>{fmtDateTime(d.lastContactAt)}</b></div>
          <div><span>Последнее событие</span><b>{fmtDateTime(d.lastEventAt)}</b></div>
        </div>
        <EventUrl path={d.eventPath} />
      </div>
      {problems > 0 && <Issues deviceId={d.id} version={`${s.failed}/${s.photoRejected}`} />}
    </section>
  )
}

/** Where the terminal sends passes. The device cannot sign requests, so the address contains a secret token. */
function EventUrl({ path }: { path: string }) {
  const url = absoluteApiUrl(path)
  const [copied, setCopied] = useState(false)
  async function copy() {
    try { await navigator.clipboard.writeText(url); setCopied(true); window.setTimeout(() => setCopied(false), 2000) }
    catch { window.prompt('Скопируйте адрес', url) }
  }
  const parsed = new URL(url)
  return (
    <div className="access-events-url">
      <div className="field-label">Адрес для событий</div>
      <div className="row-actions">
        <code className="access-mono">{url}</code>
        <Button variant="ghost" onClick={copy}>{copied ? 'Скопировано' : 'Копировать'}</Button>
      </div>
      <ol className="muted small">
        <li>Откройте веб-интерфейс терминала: Конфигурация → Сеть → Расширенные → HTTP Listening (HTTP-прослушивание).</li>
        <li>
          IP/домен сервера — <b>{parsed.hostname}</b>, порт — <b>{parsed.port || (parsed.protocol === 'https:' ? '443' : '80')}</b>,
          URL — путь из адреса выше, начиная с <span className="access-mono">/api/</span>; протокол HTTP{parsed.protocol === 'https:' ? 'S' : ''}, формат JSON.
        </li>
        <li>Адрес должен быть доступен с терминала (сеть клуба или VPN). Не публикуйте его: в нём секретный ключ.</li>
        <li>Часовой пояс терминала — как у клуба (UTC+5), время по NTP: сроки абонемента терминал проверяет по своим часам.</li>
      </ol>
    </div>
  )
}

function Issues({ deviceId, version }: { deviceId: string; version: string }) {
  const { data, error, loading } = useAsync(() => api<AccessIssue[]>(`/api/admin/access/devices/${deviceId}/issues`), [deviceId, version])
  return (
    <div className="access-issues">
      <div className="field-label">Клиенты с проблемами</div>
      <DataState loading={loading} error={error} empty={!!data && data.length === 0}>
        <table className="table">
          <thead><tr><th>Клиент</th><th>№ на терминале</th><th>Проблема</th><th>Ответ терминала</th><th>Попыток</th></tr></thead>
          <tbody>
            {data?.map(i => (
              <tr key={i.clientId}>
                <td><Link to={`/clients/${i.clientId}`}>{i.clientName}</Link></td>
                <td>{i.employeeNo}</td>
                <td>{i.state === 'PhotoRejected'
                  ? <Badge tone="red">Фото не подошло</Badge>
                  : <><Badge tone="orange">Ошибка</Badge>{i.retryAt && <div className="muted small">повтор {fmtDateTime(i.retryAt)}</div>}</>}</td>
                <td className="muted small">{i.lastError ?? '—'}</td>
                <td>{i.failedAttempts || '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </DataState>
    </div>
  )
}

function DeviceModal({ device, onClose, onSaved }: { device: AccessDevice | null; onClose(): void; onSaved(): void }) {
  const [form, setForm] = useState({
    name: device?.name ?? 'Вход', address: device?.baseUrl ?? '', username: device?.username ?? 'admin', password: '',
    doorNo: device?.doorNo ?? 1, recordsVisits: device?.recordsVisits ?? true, isActive: device?.isActive ?? true,
  })
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function submit(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setError(null); setErrors({})
    const body = { ...form, password: form.password || null }
    try {
      if (device) await api(`/api/admin/access/devices/${device.id}`, { method: 'PUT', body })
      else await api('/api/admin/access/devices', { method: 'POST', body })
      onSaved()
    } catch (err) { setError(errorMessage(err)); setErrors(fieldErrors(err)) } finally { setBusy(false) }
  }

  return (
    <Modal title={device ? 'Терминал' : 'Новый терминал'} onClose={onClose}>
      <form className="form" onSubmit={submit}>
        <ErrorBanner message={error} />
        <Field label="Название" error={errors.name} hint="Например, «Вход» или «Турникет 2». Видно в журнале проходов.">
          <input value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} required maxLength={64} />
        </Field>
        <Field label="Адрес терминала" error={errors.address}
          hint="IP-адрес в сети клуба, например 192.168.1.64 (можно с портом: 192.168.1.64:8080). Сервер должен его видеть.">
          <input value={form.address} onChange={e => setForm({ ...form, address: e.target.value })} required maxLength={200} placeholder="192.168.1.64" />
        </Field>
        <div className="grid-2">
          <Field label="Логин" error={errors.username}>
            <input value={form.username} onChange={e => setForm({ ...form, username: e.target.value })} required maxLength={32} autoComplete="off" />
          </Field>
          <Field label="Пароль" error={errors.password}
            hint={device ? 'Оставьте пустым, чтобы не менять сохранённый.' : 'Пароль администратора терминала. Хранится зашифрованным.'}>
            <input type="password" value={form.password} onChange={e => setForm({ ...form, password: e.target.value })}
              required={!device} maxLength={64} autoComplete="new-password" placeholder={device?.hasPassword ? '••••••••' : ''} />
          </Field>
        </div>
        <Field label="Номер двери" error={errors.doorNo} hint="1 — для терминала с одним турникетом.">
          <input type="number" min={1} max={8} value={form.doorNo} onChange={e => setForm({ ...form, doorNo: Number(e.target.value) })} required />
        </Field>
        <label className="check">
          <input type="checkbox" checked={form.recordsVisits} onChange={e => setForm({ ...form, recordsVisits: e.target.checked })} />
          Терминал на вход — отмечать посещения
        </label>
        <label className="check">
          <input type="checkbox" checked={form.isActive} onChange={e => setForm({ ...form, isActive: e.target.checked })} />
          Включён: синхронизировать клиентов и принимать события
        </label>
        {device && <p className="muted small">При смене адреса или двери все клиенты будут записаны на терминал заново.</p>}
        <div className="form-actions">
          <Button type="button" variant="secondary" onClick={onClose}>Отмена</Button>
          <Button type="submit" disabled={busy}>{device ? 'Сохранить' : 'Добавить'}</Button>
        </div>
      </form>
    </Modal>
  )
}

/** Passes and refusals from all terminals; open to every administrator. */
function Journal() {
  const [page, setPage] = useState(1)
  const { data, error, loading, reload } = useAsync(
    () => api<Paged<AccessEvent>>(`/api/admin/access/events${qs({ page, pageSize: 20 })}`), [page])
  return (
    <Card title="Журнал проходов" actions={<Button variant="ghost" onClick={reload}>Обновить</Button>}>
      <DataState loading={loading} error={error} empty={!!data && data.items.length === 0} onRetry={reload}>
        {data && (
          <>
            <table className="table">
              <thead><tr><th>Время</th><th>Терминал</th><th>Клиент</th><th>Событие</th><th>Посещение</th></tr></thead>
              <tbody>
                {data.items.map(e => (
                  <tr key={e.id}>
                    <td>{fmtDateTime(e.occurredAt)}</td>
                    <td>{e.deviceName}</td>
                    <td>{e.client
                      ? <Link to={`/clients/${e.client.id}`}>{fullName(e.client)}</Link>
                      : <span className="muted">неизвестный{e.employeeNo ? ` (№ ${e.employeeNo})` : ''}</span>}</td>
                    <td>
                      <Badge tone={e.granted ? 'green' : 'red'}>{e.granted ? 'Проход' : 'Отказ'}</Badge>{' '}
                      <span className="muted small">{minorLabel[e.minor] ?? `код ${e.minor}`}</span>
                    </td>
                    <td>{e.visitId ? <span className="ok">Отмечено</span>
                      : e.note ? <span className="field-error">{noteLabel[e.note] ?? e.note}</span>
                      : <span className="muted">—</span>}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            <Pagination page={data.page} totalPages={data.totalPages} totalCount={data.totalCount} onChange={setPage} />
          </>
        )}
      </DataState>
    </Card>
  )
}
