import { useState, type FormEvent } from 'react'
import { Link, useNavigate } from 'react-router'
import { api, qs } from '../api/client'
import type { Client, Paged, UserStatus } from '../api/types'
import { Badge, Button, DataState, Field, Modal, PageHeader, Pagination, ErrorBanner } from '../components/ui'
import { fmtDate, fullName, membershipStatusLabel, membershipStatusTone, userStatusLabel } from '../lib/format'
import { errorMessage, fieldErrors, useAsync } from '../lib/useAsync'

export function ClientsPage() {
  const [search, setSearch] = useState('')
  const [query, setQuery] = useState('')
  const [status, setStatus] = useState<UserStatus | ''>('')
  const [hasActive, setHasActive] = useState<'' | 'true' | 'false'>('')
  const [page, setPage] = useState(1)
  const [creating, setCreating] = useState(false)
  const { data, error, loading, reload } = useAsync(
    () => api<Paged<Client>>(`/api/admin/clients${qs({ search: query, status, hasActiveMembership: hasActive, page, pageSize: 20 })}`),
    [query, status, hasActive, page])

  return (
    <>
      <PageHeader title="Клиенты" actions={<Button onClick={() => setCreating(true)}>+ Новый клиент</Button>} />
      <form className="filters" onSubmit={e => { e.preventDefault(); setPage(1); setQuery(search.trim()) }}>
        <input placeholder="Имя, фамилия или телефон" value={search} onChange={e => setSearch(e.target.value)} />
        <select value={status} onChange={e => { setPage(1); setStatus(e.target.value as UserStatus | '') }}>
          <option value="">Любой статус</option>
          <option value="Active">Активные</option>
          <option value="Blocked">Заблокированные</option>
        </select>
        <select value={hasActive} onChange={e => { setPage(1); setHasActive(e.target.value as '' | 'true' | 'false') }}>
          <option value="">Все абонементы</option>
          <option value="true">С действующим абонементом</option>
          <option value="false">Без действующего абонемента</option>
        </select>
        <Button type="submit" variant="secondary">Найти</Button>
      </form>
      <DataState loading={loading} error={error} empty={!!data && data.items.length === 0} onRetry={reload}>
        {data && (
          <>
            <table className="table">
              <thead><tr><th>Клиент</th><th>Телефон</th><th>Абонемент</th><th>Тренер</th><th>Статус</th><th>Создан</th></tr></thead>
              <tbody>
                {data.items.map(c => (
                  <tr key={c.id}>
                    <td><Link to={`/clients/${c.id}`}>{fullName(c)}</Link></td>
                    <td>{c.phone}</td>
                    <td>{c.currentMembership
                      ? <><Badge tone={membershipStatusTone[c.currentMembership.effectiveStatus]}>{membershipStatusLabel[c.currentMembership.effectiveStatus]}</Badge> <span className="muted">до {fmtDate(c.currentMembership.endDate)}</span></>
                      : <span className="muted">нет</span>}</td>
                    <td>{c.assignedTrainer ? fullName(c.assignedTrainer) : <span className="muted">—</span>}</td>
                    <td><Badge tone={c.status === 'Active' ? 'green' : 'red'}>{userStatusLabel[c.status]}</Badge></td>
                    <td>{fmtDate(c.createdAt)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            <Pagination page={data.page} totalPages={data.totalPages} totalCount={data.totalCount} onChange={setPage} />
          </>
        )}
      </DataState>
      {creating && <CreateClientModal onClose={() => setCreating(false)} />}
    </>
  )
}

function CreateClientModal({ onClose }: { onClose(): void }) {
  const navigate = useNavigate()
  const [form, setForm] = useState({ phone: '', password: '', firstName: '', lastName: '', email: '' })
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const set = (k: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement>) => setForm({ ...form, [k]: e.target.value })

  async function submit(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setError(null); setErrors({})
    try {
      const created = await api<Client>('/api/admin/clients', { method: 'POST', body: { ...form, email: form.email || null } })
      navigate(`/clients/${created.id}`)
    } catch (err) {
      setError(errorMessage(err)); setErrors(fieldErrors(err))
    } finally { setBusy(false) }
  }

  return (
    <Modal title="Новый клиент" onClose={onClose}>
      <form className="form" onSubmit={submit}>
        <ErrorBanner message={error} />
        <div className="grid-2">
          <Field label="Имя" error={errors.firstName}><input value={form.firstName} onChange={set('firstName')} required maxLength={64} /></Field>
          <Field label="Фамилия" error={errors.lastName}><input value={form.lastName} onChange={set('lastName')} required maxLength={64} /></Field>
        </div>
        <Field label="Телефон" error={errors.phone}><input value={form.phone} onChange={set('phone')} placeholder="+998 90 123 45 67" required /></Field>
        <Field label="Временный пароль" error={errors.password} hint="Не менее 8 символов, буквы и цифры. Передайте клиенту лично — при первом входе он задаст свой пароль.">
          <input value={form.password} onChange={set('password')} required minLength={8} autoComplete="new-password" />
        </Field>
        <Field label="Email (необязательно)" error={errors.email}><input type="email" value={form.email} onChange={set('email')} /></Field>
        <div className="form-actions">
          <Button type="button" variant="secondary" onClick={onClose}>Отмена</Button>
          <Button type="submit" disabled={busy}>Создать</Button>
        </div>
      </form>
    </Modal>
  )
}
