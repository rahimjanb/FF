import { useState, type FormEvent } from 'react'
import { api, apiUrl, qs } from '../api/client'
import type { Paged, Trainer, UserStatus } from '../api/types'
import { Badge, Button, DataState, ErrorBanner, Field, Modal, PageHeader, Pagination } from '../components/ui'
import { fullName } from '../lib/format'
import { errorMessage, fieldErrors, useAsync } from '../lib/useAsync'
import { ResetPasswordModal } from './ClientDetailPage'

export function TrainersPage() {
  const [page, setPage] = useState(1)
  const [search, setSearch] = useState('')
  const [query, setQuery] = useState('')
  const { data, error, loading, reload } = useAsync(
    () => api<Paged<Trainer>>(`/api/admin/trainers${qs({ page, pageSize: 20, search: query })}`), [page, query])
  const [editing, setEditing] = useState<Trainer | 'new' | null>(null)
  const [resetting, setResetting] = useState<Trainer | null>(null)

  return (
    <>
      <PageHeader title="Тренеры" actions={<Button onClick={() => setEditing('new')}>+ Новый тренер</Button>} />
      <form className="filters" onSubmit={e => { e.preventDefault(); setPage(1); setQuery(search.trim()) }}>
        <input placeholder="Имя или телефон" value={search} onChange={e => setSearch(e.target.value)} />
        <Button type="submit" variant="secondary">Найти</Button>
      </form>
      <DataState loading={loading} error={error} empty={!!data && data.items.length === 0} onRetry={reload}>
        {data && (
          <>
            <table className="table">
              <thead><tr><th>Тренер</th><th>Телефон</th><th>Специализация</th><th>Клиентов</th><th>Набор</th><th>Статус</th><th /></tr></thead>
              <tbody>
                {data.items.map(t => (
                  <tr key={t.id}>
                    <td><span className="person"><TrainerPhoto trainer={t} />{fullName(t)}</span></td>
                    <td>{t.phone}</td>
                    <td>{t.specialization ?? '—'}</td>
                    <td>{t.clientsCount}</td>
                    <td>{t.isAcceptingClients ? <Badge tone="green">Открыт</Badge> : <Badge tone="gray">Закрыт</Badge>}</td>
                    <td>{!t.isActive ? <Badge tone="gray">Неактивен</Badge> : t.userStatus === 'Blocked' ? <Badge tone="red">Заблокирован</Badge> : <Badge tone="green">Работает</Badge>}</td>
                    <td className="row-actions">
                      <Button variant="ghost" onClick={() => setEditing(t)}>Изменить</Button>
                      <Button variant="ghost" onClick={() => setResetting(t)}>Пароль</Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            <Pagination page={data.page} totalPages={data.totalPages} totalCount={data.totalCount} onChange={setPage} />
          </>
        )}
      </DataState>
      {editing && <TrainerModal trainer={editing === 'new' ? null : editing} onClose={() => setEditing(null)} onSaved={() => { setEditing(null); reload() }} onPhotoChanged={reload} />}
      {resetting && <ResetPasswordModal url={`/api/admin/trainers/${resetting.id}/reset-password`} onClose={() => setResetting(null)} />}
    </>
  )
}

function TrainerModal({ trainer, onClose, onSaved, onPhotoChanged }: {
  trainer: Trainer | null; onClose(): void; onSaved(): void; onPhotoChanged(): void
}) {
  const [form, setForm] = useState({
    phone: trainer?.phone ?? '', password: '', firstName: trainer?.firstName ?? '', lastName: trainer?.lastName ?? '',
    specialization: trainer?.specialization ?? '', bio: trainer?.bio ?? '', experienceYears: String(trainer?.experienceYears ?? ''),
    isAcceptingClients: trainer?.isAcceptingClients ?? true, isActive: trainer?.isActive ?? true,
    status: trainer?.userStatus ?? ('Active' as UserStatus),
  })
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const set = (k: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) =>
    setForm({ ...form, [k]: e.target.value })

  async function submit(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setError(null); setErrors({})
    const common = {
      phone: form.phone, firstName: form.firstName, lastName: form.lastName, specialization: form.specialization || null,
      bio: form.bio || null, experienceYears: form.experienceYears === '' ? null : Number(form.experienceYears),
    }
    try {
      if (trainer) {
        await api(`/api/admin/trainers/${trainer.id}`, { method: 'PUT', body: {
          ...common, isAcceptingClients: form.isAcceptingClients, isActive: form.isActive, status: form.status } })
      } else {
        await api('/api/admin/trainers', { method: 'POST', body: { ...common, password: form.password } })
      }
      onSaved()
    } catch (err) { setError(errorMessage(err)); setErrors(fieldErrors(err)) } finally { setBusy(false) }
  }

  return (
    <Modal title={trainer ? 'Изменить тренера' : 'Новый тренер'} onClose={onClose}>
      <form className="form" onSubmit={submit}>
        <ErrorBanner message={error} />
        <div className="grid-2">
          <Field label="Имя" error={errors.firstName}><input value={form.firstName} onChange={set('firstName')} required maxLength={64} /></Field>
          <Field label="Фамилия" error={errors.lastName}><input value={form.lastName} onChange={set('lastName')} required maxLength={64} /></Field>
        </div>
        {trainer && <PhotoField trainer={trainer} onChanged={onPhotoChanged} />}
        <Field label="Телефон (логин)" error={errors.phone}><input value={form.phone} onChange={set('phone')} required /></Field>
        {!trainer && (
          <Field label="Временный пароль" error={errors.password} hint="Не менее 8 символов, буквы и цифры. При первом входе тренер задаст свой пароль.">
            <input value={form.password} onChange={set('password')} required minLength={8} autoComplete="new-password" />
          </Field>
        )}
        <div className="grid-2">
          <Field label="Специализация" error={errors.specialization}><input value={form.specialization} onChange={set('specialization')} maxLength={128} /></Field>
          <Field label="Опыт, лет" error={errors.experienceYears}><input type="number" min={0} max={80} value={form.experienceYears} onChange={set('experienceYears')} /></Field>
        </div>
        <Field label="О тренере" error={errors.bio}><textarea value={form.bio} onChange={set('bio')} rows={3} maxLength={2000} /></Field>
        {trainer && (
          <>
            <label className="check"><input type="checkbox" checked={form.isAcceptingClients} onChange={e => setForm({ ...form, isAcceptingClients: e.target.checked })} /> Принимает новых клиентов</label>
            <label className="check"><input type="checkbox" checked={form.isActive} onChange={e => setForm({ ...form, isActive: e.target.checked })} /> Показывать в списке тренеров</label>
            <Field label="Статус аккаунта"><select value={form.status} onChange={set('status')}>
              <option value="Active">Активен</option><option value="Blocked">Заблокирован</option>
            </select></Field>
          </>
        )}
        <div className="form-actions">
          <Button type="button" variant="secondary" onClick={onClose}>Отмена</Button>
          <Button type="submit" disabled={busy}>Сохранить</Button>
        </div>
      </form>
    </Modal>
  )
}

function TrainerPhoto({ trainer, size = 32 }: { trainer: Trainer; size?: number }) {
  return trainer.photoUrl
    ? <img className="avatar" src={apiUrl(trainer.photoUrl)} alt="" width={size} height={size} />
    : <span className="avatar avatar-empty" style={{ width: size, height: size }}>{trainer.firstName.charAt(0)}</span>
}

/** Photo is saved immediately on upload or removal, separately from the form fields. */
function PhotoField({ trainer, onChanged }: { trainer: Trainer; onChanged(): void }) {
  const [current, setCurrent] = useState(trainer)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function run(call: () => Promise<Trainer>) {
    setBusy(true); setError(null)
    try { setCurrent(await call()); onChanged() } catch (err) { setError(errorMessage(err)) } finally { setBusy(false) }
  }

  function upload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    e.target.value = ''
    if (!file) return
    if (file.size > 2 * 1024 * 1024) { setError('Фото должно быть не больше 2 МБ.'); return }
    const body = new FormData()
    body.append('file', file)
    void run(() => api<Trainer>(`/api/admin/trainers/${trainer.id}/photo`, { method: 'PUT', body }))
  }

  return (
    // A div, not <Field>: Field is a <label>, which would forward every click inside it to the file input.
    <div className="field">
      <span className="field-label">Фото</span>
      <div className="photo-field">
        <TrainerPhoto trainer={current} size={64} />
        <label className="btn btn-secondary">
          {current.photoUrl ? 'Заменить' : 'Загрузить'}
          <input type="file" accept="image/jpeg,image/png,image/webp" onChange={upload} disabled={busy} hidden />
        </label>
        {current.photoUrl && (
          <Button type="button" variant="ghost" disabled={busy}
            onClick={() => run(() => api<Trainer>(`/api/admin/trainers/${trainer.id}/photo`, { method: 'DELETE' }))}>
            Удалить
          </Button>
        )}
      </div>
      {error ? <span className="field-error">{error}</span> : <span className="field-hint">JPEG, PNG или WebP до 2 МБ. Сохраняется сразу.</span>}
    </div>
  )
}
