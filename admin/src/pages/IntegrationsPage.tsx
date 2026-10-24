import { useState, type FormEvent } from 'react'
import { api } from '../api/client'
import type { AuditEntry, Integration, IntegrationMode, IntegrationProvider, IntegrationStatus } from '../api/types'
import { useAuth } from '../auth/AuthContext'
import { Badge, Button, Card, DataState, ErrorBanner, Field, Modal } from '../components/ui'
import { fmtDateTime } from '../lib/format'
import { errorMessage, useAsync } from '../lib/useAsync'

const providerInfo: Record<IntegrationProvider, { title: string; description: string }> = {
  Click: {
    title: 'Click',
    description: 'Оплата через Click (SHOP API): Click присылает серверу запросы Prepare и Complete, подписанные секретным ключом.',
  },
  Payme: {
    title: 'Payme',
    description: 'Оплата через Payme Business (Merchant API): Payme вызывает методы биллинга клуба с авторизацией ключом кассы.',
  },
}

function fieldLabel(provider: IntegrationProvider, name: string, mode: IntegrationMode): string {
  if (provider === 'Payme' && name === 'key') return mode === 'Test' ? 'Ключ песочницы (TEST_KEY)' : 'Ключ кассы (key)'
  if (provider === 'Payme' && name === 'merchantId') return 'ID кассы (Merchant ID)'
  return ({ serviceId: 'Service ID', merchantId: 'Merchant ID', merchantUserId: 'Merchant User ID', secretKey: 'Secret key' } as Record<string, string>)[name] ?? name
}

const statusView: Record<IntegrationStatus, { label: string; tone: 'gray' | 'blue' | 'orange' | 'green'; hint: string }> = {
  NotConfigured: { label: 'Не настроено', tone: 'gray', hint: 'Заполнены не все реквизиты выбранного режима.' },
  Configured: { label: 'Настроено', tone: 'blue', hint: 'Реквизиты заполнены, интеграция выключена.' },
  NeedsVerification: {
    label: 'Требует проверки', tone: 'orange',
    hint: 'Интеграция включена, но подлинный запрос от платёжной системы ещё не поступал. Подключение не подтверждено.',
  },
  Active: { label: 'Активно', tone: 'green', hint: 'Платёжная система прислала запрос, прошедший проверку подписи.' },
}

const modeLabel: Record<IntegrationMode, string> = { Test: 'Тестовый', Production: 'Боевой' }

export function IntegrationsPage() {
  const { user } = useAuth()
  const allowed = !!user?.canManageIntegrations
  const { data, error, loading, reload } = useAsync(
    () => (allowed ? api<Integration[]>('/api/admin/integrations') : Promise.resolve([])), [allowed])

  if (!allowed) {
    return <Card><p className="muted">Настройки интеграций доступны только администраторам с правом управления интеграциями.</p></Card>
  }
  return (
    <>
      <div className="banner banner-info">
        Онлайн-оплата — второй этап. Здесь хранятся реквизиты; платежи сейчас не принимаются, абонементы по ним не выдаются.
      </div>
      <DataState loading={loading} error={error} empty={false} onRetry={reload}>
        {data && !data[0]?.encryptionConfigured && (
          <ErrorBanner message="На сервере не задан ключ шифрования Integrations__EncryptionKey: секретные ключи сохранить нельзя." />
        )}
        {data?.map(i => <IntegrationCard key={i.provider} integration={i} />)}
      </DataState>
    </>
  )
}

function IntegrationCard({ integration }: { integration: Integration }) {
  const [current, setCurrent] = useState(integration)
  const [form, setForm] = useState(() => toForm(integration))
  const [error, setError] = useState<string | null>(null)
  const [saved, setSaved] = useState(false)
  const [busy, setBusy] = useState(false)
  const [secretAction, setSecretAction] = useState<{ name: string; kind: 'set' | 'delete' } | null>(null)
  const [showAudit, setShowAudit] = useState(false)

  const provider = current.provider
  const info = providerInfo[provider]
  const status = statusView[current.status]
  const mode = form.mode
  const modeState = mode === 'Test' ? current.test : current.production
  const plainFields = current.fields.filter(f => !f.isSecret)
  const secretFields = current.fields.filter(f => f.isSecret)
  const key = mode === 'Test' ? 'test' : 'production'

  function apply(next: Integration) {
    setCurrent(next)
    setForm(toForm(next))
  }

  async function save(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setError(null); setSaved(false)
    try {
      apply(await api<Integration>(`/api/admin/integrations/${provider}`, {
        method: 'PUT',
        body: { isEnabled: form.isEnabled, mode: form.mode, test: form.test, production: form.production, version: current.version },
      }))
      setSaved(true)
    } catch (err) { setError(errorMessage(err)) } finally { setBusy(false) }
  }

  const setValue = (name: string) => (e: React.ChangeEvent<HTMLInputElement>) =>
    setForm({ ...form, [key]: { ...form[key], [name]: e.target.value } })

  return (
    <section className="card" aria-label={info.title} data-testid={`integration-${provider}`}>
      <div className="card-header">
        <div>
          <h2>{info.title}</h2>
          <div className="muted small">{info.description}</div>
        </div>
        <Badge tone={status.tone}>{status.label}</Badge>
      </div>
      <p className="muted small">{status.hint}</p>
      {modeState.missingFields.length > 0 && (
        <p className="small">Не хватает: {modeState.missingFields.map(n => fieldLabel(provider, n, mode)).join(', ')}</p>
      )}

      <form className="form" onSubmit={save}>
        <ErrorBanner message={error} />
        {saved && <div className="banner banner-success">Сохранено</div>}
        <div className="grid-2">
          <label className="check">
            <input type="checkbox" checked={form.isEnabled} onChange={e => setForm({ ...form, isEnabled: e.target.checked })} />
            Интеграция включена
          </label>
          <Field label="Режим">
            <select value={form.mode} onChange={e => setForm({ ...form, mode: e.target.value as IntegrationMode })}>
              <option value="Test">{modeLabel.Test} (Test)</option>
              <option value="Production">{modeLabel.Production} (Production)</option>
            </select>
          </Field>
        </div>
        <div className="grid-2">
          {plainFields.map(f => (
            <Field key={f.name} label={`${fieldLabel(provider, f.name, mode)} · ${modeLabel[mode].toLowerCase()}`}>
              <input value={form[key][f.name] ?? ''} onChange={setValue(f.name)} autoComplete="off" spellCheck={false}
                name={`${provider}-${mode}-${f.name}`} />
            </Field>
          ))}
        </div>

        {secretFields.map(f => {
          const s = modeState.secrets[f.name]
          return (
            <div key={f.name} className="secret-row">
              <div>
                <div className="field-label">{fieldLabel(provider, f.name, mode)} · {modeLabel[mode].toLowerCase()}</div>
                {s?.isSet
                  ? <div><code>{s.mask}</code> <span className="muted small">задан {fmtDateTime(s.updatedAt)}</span>
                      {!s.isReadable && <div className="field-error">Не расшифровывается (сменён ключ сервера) — задайте заново.</div>}</div>
                  : <div className="muted">Не задан</div>}
              </div>
              <div className="row-actions">
                <Button type="button" variant="secondary" disabled={!current.encryptionConfigured}
                  onClick={() => setSecretAction({ name: f.name, kind: 'set' })}>{s?.isSet ? 'Заменить' : 'Задать'}</Button>
                {s?.isSet && (
                  <Button type="button" variant="ghost" onClick={() => setSecretAction({ name: f.name, kind: 'delete' })}>Удалить</Button>
                )}
              </div>
            </div>
          )
        })}

        <div className="form-actions">
          <span className="muted small">
            {current.updatedAt ? `Изменено ${fmtDateTime(current.updatedAt)}${current.updatedBy ? `, ${current.updatedBy}` : ''}` : 'Ещё не настраивалось'}
          </span>
          <Button type="button" variant="ghost" onClick={() => setShowAudit(v => !v)}>Журнал</Button>
          <Button type="submit" disabled={busy}>Сохранить</Button>
        </div>
      </form>

      {showAudit && <AuditList provider={provider} version={current.version} />}
      {secretAction && (
        <SecretModal provider={provider} mode={mode} name={secretAction.name} kind={secretAction.kind}
          label={fieldLabel(provider, secretAction.name, mode)}
          onClose={() => setSecretAction(null)} onDone={next => { apply(next); setSecretAction(null) }} />
      )}
    </section>
  )
}

function toForm(i: Integration) {
  const clean = (v: Record<string, string | null>) => Object.fromEntries(Object.entries(v).map(([k, x]) => [k, x ?? '']))
  return { isEnabled: i.isEnabled, mode: i.mode, test: clean(i.test.values), production: clean(i.production.values) }
}

/** Setting, replacing and removing a secret are explicit actions with confirmation. The value lives only in this input. */
function SecretModal({ provider, mode, name, kind, label, onClose, onDone }: {
  provider: IntegrationProvider; mode: IntegrationMode; name: string; kind: 'set' | 'delete'; label: string
  onClose(): void; onDone(next: Integration): void
}) {
  const [value, setValue] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const url = `/api/admin/integrations/${provider}/${mode}/secrets/${name}`

  async function submit(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setError(null)
    try {
      onDone(await api<Integration>(url, kind === 'set' ? { method: 'PUT', body: { value } } : { method: 'DELETE' }))
    } catch (err) { setError(errorMessage(err)) } finally { setBusy(false) }
  }

  return (
    <Modal title={kind === 'set' ? `${label}: новое значение` : `Удалить ${label}?`} onClose={onClose}>
      <form className="form" onSubmit={submit}>
        <ErrorBanner message={error} />
        {kind === 'set' ? (
          <Field label={`${label} (${modeLabel[mode].toLowerCase()} режим)`} hint="Значение сохраняется зашифрованным и больше не показывается.">
            <input type="password" value={value} onChange={e => setValue(e.target.value)} required minLength={8} maxLength={256}
              autoComplete="new-password" autoFocus />
          </Field>
        ) : (
          <p>Ключ будет удалён без возможности восстановления. Его придётся ввести заново.</p>
        )}
        <div className="form-actions">
          <Button type="button" variant="secondary" onClick={onClose}>Отмена</Button>
          <Button type="submit" variant={kind === 'set' ? 'primary' : 'danger'} disabled={busy}>
            {kind === 'set' ? 'Сохранить ключ' : 'Удалить'}
          </Button>
        </div>
      </form>
    </Modal>
  )
}

const auditAction: Record<string, string> = {
  integration_updated: 'Изменены настройки', secret_set: 'Задан ключ', secret_replaced: 'Заменён ключ', secret_removed: 'Удалён ключ',
}

function AuditList({ provider, version }: { provider: IntegrationProvider; version: number }) {
  const { data, error, loading, reload } = useAsync(() => api<AuditEntry[]>(`/api/admin/integrations/${provider}/audit`), [provider, version])
  return (
    <DataState loading={loading} error={error} empty={!!data && data.length === 0} onRetry={reload}>
      <table className="table compact">
        <tbody>
          {data?.map((a, i) => (
            <tr key={i}>
              <td className="muted small">{fmtDateTime(a.createdAt)}</td>
              <td>{auditAction[a.action] ?? a.action}</td>
              <td className="small">{a.details}</td>
              <td className="muted small">{a.userName}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </DataState>
  )
}
