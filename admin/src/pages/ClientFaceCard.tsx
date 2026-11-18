import { useEffect, useState } from 'react'
import { ApiError, api, apiBlob } from '../api/client'
import type { AccessSyncState, FaceAccessAdmin, FaceAccessStatus } from '../api/types'
import { Badge, Button, Card, ErrorBanner, Spinner } from '../components/ui'
import { fmtDate, fmtDateTime, type Tone } from '../lib/format'
import { prepareFacePhoto } from '../lib/facePhoto'
import { errorMessage, useAsync } from '../lib/useAsync'

const statusView: Record<FaceAccessStatus, { label: string; tone: Tone }> = {
  None: { label: 'Фото нет', tone: 'gray' },
  Waiting: { label: 'Ожидает абонемента', tone: 'blue' },
  Pending: { label: 'Отправляется на терминал', tone: 'orange' },
  Ready: { label: 'Вход по лицу работает', tone: 'green' },
  Rejected: { label: 'Фото не подошло', tone: 'red' },
}

const deviceStateView: Record<AccessSyncState, { label: string; tone: Tone }> = {
  Synced: { label: 'На терминале', tone: 'green' },
  Pending: { label: 'Ожидает', tone: 'orange' },
  Failed: { label: 'Ошибка', tone: 'red' },
  PhotoRejected: { label: 'Фото не подошло', tone: 'red' },
}

function statusHint(f: FaceAccessAdmin): string {
  switch (f.status) {
    case 'None': return 'Клиент может сам сделать селфи в приложении, или сфотографируйте его здесь с его согласия.'
    case 'Waiting': return f.hasAccess
      ? 'Фото сохранено, но терминалы не подключены. Пока клиент проходит по QR-пропуску.'
      : 'Фото сохранено. На терминал попадёт, когда у клиента будет действующий абонемент.'
    case 'Pending': return 'Фото отправляется на терминалы — обычно это занимает до минуты.'
    case 'Ready': return 'Клиент проходит через турникет по лицу в указанный период.'
    case 'Rejected': return 'Терминал не нашёл лицо на фото. Сделайте новое: лицо анфас и целиком в кадре, без очков, маски и головного убора, ровный свет.'
  }
}

/** Face photo for entry through the turnstile, managed at the desk. */
export function ClientFaceCard({ clientId }: { clientId: string }) {
  const face = useAsync(() => api<FaceAccessAdmin>(`/api/admin/clients/${clientId}/face`), [clientId])
  const [photo, setPhoto] = useState<{ key: string; url: string } | null>(null)
  const [consent, setConsent] = useState(false)
  const [busy, setBusy] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const f = face.data
  // Identifies the stored photo: the version grows with every upload, the upload time tells a re-upload apart.
  const photoKey = f && f.status !== 'None' ? `${f.version}/${f.uploadedAt}` : ''

  // The photo needs the bearer token, so it is fetched as a blob and shown through an object URL.
  useEffect(() => {
    if (!photoKey) return
    let url: string | null = null
    let cancelled = false
    apiBlob(`/api/admin/clients/${clientId}/face/photo`)
      .then(blob => { if (!cancelled) { url = URL.createObjectURL(blob); setPhoto({ key: photoKey, url }) } })
      .catch(() => { /* the card shows "no photo" */ })
    return () => { cancelled = true; if (url) URL.revokeObjectURL(url) }
  }, [clientId, photoKey])
  const photoUrl = photoKey && photo?.key === photoKey ? photo.url : null

  // While the photo is on its way to the terminals, check again every few seconds (up to a minute).
  const { reload } = face
  const pending = f?.status === 'Pending'
  useEffect(() => {
    if (!pending) return
    let left = 20
    const timer = window.setInterval(() => { if (--left <= 0) window.clearInterval(timer); reload() }, 3000)
    return () => window.clearInterval(timer)
  }, [pending, reload])

  async function upload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    e.target.value = ''
    if (!file) return
    setError(null)
    setBusy('Подготовка фото…')
    try {
      const jpeg = await prepareFacePhoto(file)
      setBusy('Загрузка…')
      const body = new FormData()
      body.append('file', jpeg, 'face.jpg')
      body.append('consent', 'true')
      await api(`/api/admin/clients/${clientId}/face`, { method: 'PUT', body })
      setConsent(false)
      face.reload()
    } catch (err) {
      setError(err instanceof ApiError || !(err instanceof Error) ? errorMessage(err) : err.message)
    } finally { setBusy(null) }
  }

  async function remove() {
    if (!window.confirm('Удалить фото клиента? Он будет удалён с терминалов и сможет проходить только по QR-пропуску.')) return
    setError(null)
    setBusy('Удаление…')
    try { await api(`/api/admin/clients/${clientId}/face`, { method: 'DELETE' }); face.reload() }
    catch (err) { setError(errorMessage(err)) } finally { setBusy(null) }
  }

  return (
    <Card title="Вход по лицу" actions={f && <Badge tone={statusView[f.status].tone}>{statusView[f.status].label}</Badge>}>
      {face.error && <ErrorBanner message={face.error} onRetry={face.reload} />}
      {!f && !face.error && <Spinner />}
      {f && (
        <div className="face-card">
          <div className="face-photo">
            {photoUrl ? <img src={photoUrl} alt="Фото клиента для турникета" /> : <span className="muted small">Нет фото</span>}
          </div>
          <div className="face-info">
            <p className="muted small">{statusHint(f)}</p>
            {f.status !== 'None' && (
              <div className="kv">
                <div><span>Период прохода</span><b>{f.accessFrom && f.accessTo ? `${fmtDate(f.accessFrom)} — ${fmtDate(f.accessTo)}` : 'нет действующего абонемента'}</b></div>
                <div><span>Номер на терминале</span><b>{f.accessNo ?? '—'}</b></div>
                <div><span>Загружено</span><b>{fmtDateTime(f.uploadedAt)}{f.uploadedBy ? `, ${f.uploadedBy}` : ''}</b></div>
                <div><span>Согласие получено</span><b>{fmtDateTime(f.consentAt)}</b></div>
              </div>
            )}
            {f.status !== 'None' && f.devices.length > 0 && (
              <ul className="list face-devices">
                {f.devices.map(d => (
                  <li key={d.deviceId}>
                    {d.deviceName} <Badge tone={deviceStateView[d.state].tone}>{deviceStateView[d.state].label}</Badge>
                    {d.lastError && <div className="muted small">{d.lastError}</div>}
                  </li>
                ))}
              </ul>
            )}
            {f.status !== 'None' && f.terminals === 0 && <p className="muted small">Терминалы ещё не подключены (раздел «Турникеты»).</p>}
          </div>
        </div>
      )}
      {f && (
        <div className="face-upload">
          <label className="check">
            <input type="checkbox" checked={consent} onChange={e => setConsent(e.target.checked)} />
            Клиент согласен на обработку фото лица для прохода через турникет
          </label>
          <div className="row-actions">
            <label className={`btn btn-secondary${!consent || busy ? ' disabled' : ''}`}>
              {busy ?? (f.status === 'None' ? 'Загрузить фото' : 'Заменить фото')}
              <input type="file" accept="image/*" capture="user" onChange={upload} disabled={!consent || !!busy} hidden />
            </label>
            {f.status !== 'None' && <Button variant="ghost" disabled={!!busy} onClick={remove}>Удалить фото</Button>}
          </div>
          {error ? <div className="field-error" role="alert">{error}</div>
            : <p className="field-hint">Лицо анфас и целиком в кадре, без очков, маски и головного убора, ровный свет. Фото уменьшается до 200 КБ автоматически.</p>}
        </div>
      )}
    </Card>
  )
}
