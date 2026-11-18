import { useState, type FormEvent } from 'react'
import { api, apiUrl } from '../api/client'
import type { Banner, BannerMedia } from '../api/types'
import { Badge, Button, DataState, ErrorBanner, Field, Modal, PageHeader } from '../components/ui'
import { errorMessage, fieldErrors, useAsync } from '../lib/useAsync'

const MAX_IMAGE_BYTES = 10 * 1024 * 1024
const MAX_VIDEO_BYTES = 100 * 1024 * 1024
const ACCEPT = 'image/jpeg,image/png,image/webp,video/mp4,video/quicktime'

/** Moves item `index` by `delta` positions and returns the ids in the new order. */
function moved<T extends { id: string }>(items: T[], index: number, delta: number): string[] {
  const ids = items.map(i => i.id)
  const target = index + delta
  if (target < 0 || target >= ids.length) return ids
  ;[ids[index], ids[target]] = [ids[target], ids[index]]
  return ids
}

/**
 * Banners at the top of the client app home screen, under the greeting. A tap in the app opens the title,
 * the text and the gallery of photos and videos. The first photo is the cover.
 */
export function BannersPage() {
  const { data, error, loading, reload } = useAsync(() => api<Banner[]>('/api/admin/banners'), [])
  const [editing, setEditing] = useState<Banner | 'new' | null>(null)
  const [busy, setBusy] = useState(false)
  const [actionError, setActionError] = useState<string | null>(null)

  async function run(call: () => Promise<unknown>) {
    setBusy(true); setActionError(null)
    try { await call(); reload() } catch (e) { setActionError(errorMessage(e)) } finally { setBusy(false) }
  }

  const reorder = (ids: string[]) => run(() => api('/api/admin/banners/order', { method: 'PUT', body: { ids } }))
  const remove = (b: Banner) => {
    if (!window.confirm(`Удалить баннер «${b.title}» вместе с фото и видео?`)) return
    void run(() => api(`/api/admin/banners/${b.id}`, { method: 'DELETE' }))
  }

  return (
    <>
      <PageHeader title="Баннеры" actions={<Button onClick={() => setEditing('new')}>+ Новый баннер</Button>} />
      <p className="muted page-hint">
        Показываются в приложении клиента на главном экране под приветствием, в этом порядке. Нажатие открывает
        описание, фото и видео. Обложка баннера — первое фото.
      </p>
      <ErrorBanner message={actionError} />
      <DataState loading={loading} error={error} empty={!!data && data.length === 0} onRetry={reload}>
        {data && (
          <table className="table">
            <thead><tr><th>Обложка</th><th>Баннер</th><th>Медиа</th><th>Статус</th><th>Порядок</th><th /></tr></thead>
            <tbody>
              {data.map((b, i) => (
                <tr key={b.id}>
                  <td><BannerCover banner={b} /></td>
                  <td>
                    <b>{b.title}</b>
                    {b.description && <div className="muted small promo-text">{b.description}</div>}
                  </td>
                  <td className="muted">{mediaSummary(b.media)}</td>
                  <td>{b.isActive ? <Badge tone="green">Показывается</Badge> : <Badge tone="gray">Скрыт</Badge>}</td>
                  <td>
                    <div className="row-actions">
                      <Button variant="ghost" aria-label="Выше" disabled={busy || i === 0} onClick={() => reorder(moved(data, i, -1))}>↑</Button>
                      <Button variant="ghost" aria-label="Ниже" disabled={busy || i === data.length - 1} onClick={() => reorder(moved(data, i, 1))}>↓</Button>
                    </div>
                  </td>
                  <td className="row-actions">
                    <Button variant="ghost" onClick={() => setEditing(b)}>Изменить</Button>
                    <Button variant="ghost" disabled={busy} onClick={() => remove(b)}>Удалить</Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </DataState>
      {editing && <BannerModal banner={editing === 'new' ? null : editing} onClose={() => setEditing(null)} onChanged={reload} />}
    </>
  )
}

function fileSize(bytes: number): string {
  return bytes < 1024 * 1024 ? `${Math.max(1, Math.round(bytes / 1024))} КБ` : `${(bytes / 1024 / 1024).toFixed(1)} МБ`
}

function mediaSummary(media: BannerMedia[]): string {
  const photos = media.filter(m => m.kind === 'Image').length
  const videos = media.length - photos
  if (media.length === 0) return 'Нет'
  return [photos && `${photos} фото`, videos && `${videos} видео`].filter(Boolean).join(', ')
}

/** Small preview of the app card: the cover with the title over it. */
function BannerCover({ banner }: { banner: Banner }) {
  return (
    <div className="promo-cover" style={banner.coverUrl ? { backgroundImage: `url(${apiUrl(banner.coverUrl)})` } : undefined}>
      <span>{banner.title}</span>
    </div>
  )
}

/** Text fields are saved with the button; photos and videos are saved as soon as they are uploaded. */
function BannerModal({ banner, onClose, onChanged }: { banner: Banner | null; onClose(): void; onChanged(): void }) {
  const [current, setCurrent] = useState<Banner | null>(banner)
  const [form, setForm] = useState({
    title: banner?.title ?? '', description: banner?.description ?? '', isActive: banner?.isActive ?? true,
  })
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [error, setError] = useState<string | null>(null)
  const [saved, setSaved] = useState(false)
  const [busy, setBusy] = useState(false)

  async function submit(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setError(null); setErrors({}); setSaved(false)
    const body = { title: form.title, description: form.description || null, isActive: form.isActive }
    try {
      const result = current
        ? await api<Banner>(`/api/admin/banners/${current.id}`, { method: 'PUT', body })
        : await api<Banner>('/api/admin/banners', { method: 'POST', body })
      setCurrent(result)
      setSaved(true)
      onChanged()
    } catch (err) { setError(errorMessage(err)); setErrors(fieldErrors(err)) } finally { setBusy(false) }
  }

  return (
    <Modal title={current ? 'Баннер' : 'Новый баннер'} onClose={onClose}>
      <form className="form" onSubmit={submit}>
        <ErrorBanner message={error} />
        <Field label="Название" error={errors.title} hint="Видно на баннере и в начале описания.">
          <input value={form.title} onChange={e => setForm({ ...form, title: e.target.value })} required maxLength={120} />
        </Field>
        <Field label="Описание" error={errors.description} hint="Открывается при нажатии на баннер.">
          <textarea value={form.description} onChange={e => setForm({ ...form, description: e.target.value })} rows={5} maxLength={4000} />
        </Field>
        <label className="check">
          <input type="checkbox" checked={form.isActive} onChange={e => setForm({ ...form, isActive: e.target.checked })} /> Показывать в приложении
        </label>
        <div className="form-actions">
          {saved && <span className="ok">Сохранено</span>}
          <Button type="button" variant="secondary" onClick={onClose}>{current ? 'Закрыть' : 'Отмена'}</Button>
          <Button type="submit" disabled={busy}>{current ? 'Сохранить' : 'Создать и добавить фото'}</Button>
        </div>
      </form>
      {current && <MediaManager banner={current} onChange={b => { setCurrent(b); onChanged() }} />}
    </Modal>
  )
}

function MediaManager({ banner, onChange }: { banner: Banner; onChange(b: Banner): void }) {
  const [progress, setProgress] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const media = banner.media

  async function run(call: () => Promise<Banner>) {
    setError(null)
    try { onChange(await call()) } catch (err) { setError(errorMessage(err)) }
  }

  async function upload(e: React.ChangeEvent<HTMLInputElement>) {
    const files = Array.from(e.target.files ?? [])
    e.target.value = ''
    setError(null)
    const tooLarge = files.find(f => f.size > (f.type.startsWith('video/') ? MAX_VIDEO_BYTES : MAX_IMAGE_BYTES))
    if (tooLarge) { setError(`«${tooLarge.name}» слишком большой: фото — до 10 МБ, видео — до 100 МБ.`); return }
    try {
      for (const [i, file] of files.entries()) {
        setProgress(files.length > 1 ? `Загрузка ${i + 1} из ${files.length}…` : 'Загрузка…')
        const body = new FormData()
        body.append('file', file)
        onChange(await api<Banner>(`/api/admin/banners/${banner.id}/media`, { method: 'POST', body }))
      }
    } catch (err) { setError(errorMessage(err)) } finally { setProgress(null) }
  }

  const reorder = (ids: string[]) => run(() => api<Banner>(`/api/admin/banners/${banner.id}/media/order`, { method: 'PUT', body: { ids } }))
  const makeCover = (m: BannerMedia) => reorder([m.id, ...media.filter(x => x.id !== m.id).map(x => x.id)])
  const remove = (m: BannerMedia) => {
    if (!window.confirm(m.kind === 'Video' ? 'Удалить это видео?' : 'Удалить это фото?')) return
    void run(() => api<Banner>(`/api/admin/banners/${banner.id}/media/${m.id}`, { method: 'DELETE' }))
  }

  return (
    <div className="promo-media">
      <div className="card-header">
        <h2>Фото и видео</h2>
        <label className={`btn btn-secondary${progress ? ' disabled' : ''}`}>
          {progress ?? '+ Добавить'}
          <input type="file" accept={ACCEPT} multiple onChange={upload} disabled={!!progress} hidden />
        </label>
      </div>
      {error ? <div className="field-error" role="alert">{error}</div>
        : <p className="field-hint">Фото JPEG, PNG, WebP до 10 МБ; видео MP4 или MOV до 100 МБ. До 20 файлов. Сохраняется сразу.</p>}
      {media.length === 0 ? <div className="empty small">Добавьте хотя бы одно фото — оно станет обложкой баннера.</div> : (
        <div className="promo-grid">
          {media.map((m, i) => (
            <figure key={m.id} className="promo-tile">
              {m.kind === 'Video'
                ? <video src={apiUrl(m.url)} muted controls preload="metadata" />
                : <img src={apiUrl(m.url)} alt="" />}
              <figcaption>
                {m.url === banner.coverUrl ? <Badge tone="blue">Обложка</Badge> : m.kind === 'Video' ? <Badge tone="gray">Видео</Badge> : <Badge tone="gray">Фото</Badge>}
                <span className="muted small">{fileSize(m.sizeBytes)}</span>
              </figcaption>
              <div className="row-actions">
                <Button type="button" variant="ghost" aria-label="Левее" disabled={i === 0} onClick={() => reorder(moved(media, i, -1))}>←</Button>
                <Button type="button" variant="ghost" aria-label="Правее" disabled={i === media.length - 1} onClick={() => reorder(moved(media, i, 1))}>→</Button>
                {m.kind === 'Image' && m.url !== banner.coverUrl && <Button type="button" variant="ghost" onClick={() => makeCover(m)}>Обложка</Button>}
                <Button type="button" variant="ghost" onClick={() => remove(m)}>Удалить</Button>
              </div>
            </figure>
          ))}
        </div>
      )}
    </div>
  )
}
