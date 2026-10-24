import { useEffect, useState, type FormEvent } from 'react'
import { Link, useParams } from 'react-router'
import { api } from '../api/client'
import type { Client, Gender, Membership, MembershipPlan, Paged, Trainer, UserStatus, Visit } from '../api/types'
import { Badge, Button, Card, DataState, ErrorBanner, Field, Modal, PageHeader, Spinner } from '../components/ui'
import {
  fmtDate, fmtDateTime, fullName, membershipStatusLabel, membershipStatusTone, planTypeLabel, todayInClub,
} from '../lib/format'
import { errorMessage, fieldErrors, useAsync } from '../lib/useAsync'
import { MembershipActions } from './MembershipsPage'

export function ClientDetailPage() {
  const { id } = useParams<{ id: string }>()
  const client = useAsync(() => api<Client>(`/api/admin/clients/${id}`), [id])
  const memberships = useAsync(() => api<Membership[]>(`/api/admin/clients/${id}/memberships`), [id])
  const visits = useAsync(() => api<Paged<Visit>>(`/api/admin/visits?clientId=${id}&pageSize=10`), [id])
  const [assigning, setAssigning] = useState(false)
  const [resetting, setResetting] = useState(false)
  const [visitMsg, setVisitMsg] = useState<{ ok: boolean; text: string } | null>(null)

  const reloadAll = () => { client.reload(); memberships.reload(); visits.reload() }

  async function recordVisit() {
    setVisitMsg(null)
    try {
      await api('/api/admin/visits', { method: 'POST', body: { clientId: id } })
      setVisitMsg({ ok: true, text: 'Посещение отмечено.' })
      reloadAll()
    } catch (e) { setVisitMsg({ ok: false, text: errorMessage(e) }) }
  }

  if (client.error) return <ErrorBanner message={client.error} onRetry={client.reload} />
  if (!client.data) return <Spinner />
  const c = client.data

  return (
    <>
      <PageHeader title={fullName(c)} actions={<>
        <Link to="/clients" className="btn btn-ghost">← К списку</Link>
        <Button variant="secondary" onClick={() => setResetting(true)}>Сменить пароль</Button>
      </>} />
      <div className="detail-grid">
        <Card title="Профиль"><ClientForm client={c} onSaved={client.reload} /></Card>
        <div className="stack">
          <Card title="Текущий абонемент" actions={<Button onClick={() => setAssigning(true)}>+ Назначить</Button>}>
            {c.currentMembership ? (
              <div className="kv">
                <div><span>План</span><b>{c.currentMembership.planName}</b></div>
                <div><span>Статус</span><Badge tone={membershipStatusTone[c.currentMembership.effectiveStatus]}>{membershipStatusLabel[c.currentMembership.effectiveStatus]}</Badge></div>
                <div><span>Срок</span><b>{fmtDate(c.currentMembership.startDate)} — {fmtDate(c.currentMembership.endDate)}</b></div>
                <div><span>Осталось дней</span><b>{c.currentMembership.daysLeft}</b></div>
                {c.currentMembership.visitLimit !== null &&
                  <div><span>Посещения</span><b>{c.currentMembership.visitsUsed} из {c.currentMembership.visitLimit}</b></div>}
              </div>
            ) : <p className="muted">Нет действующего абонемента.</p>}
            <div className="row">
              <Button variant="secondary" onClick={recordVisit}>Отметить посещение</Button>
              {visitMsg && <span className={visitMsg.ok ? 'ok' : 'field-error'}>{visitMsg.text}</span>}
            </div>
          </Card>
          <Card title="Последние посещения">
            <DataState loading={visits.loading} error={visits.error} empty={!!visits.data && visits.data.items.length === 0}>
              <ul className="list">{visits.data?.items.map(v => <li key={v.id}>{fmtDateTime(v.visitedAt)}</li>)}</ul>
            </DataState>
          </Card>
        </div>
      </div>
      <Card title="История абонементов">
        <DataState loading={memberships.loading} error={memberships.error} empty={!!memberships.data && memberships.data.length === 0} onRetry={memberships.reload}>
          <table className="table">
            <thead><tr><th>План</th><th>Начало</th><th>Окончание</th><th>Посещения</th><th>Статус</th><th /></tr></thead>
            <tbody>
              {memberships.data?.map(m => (
                <tr key={m.id}>
                  <td>{m.planName} <span className="muted">· {planTypeLabel[m.planType]}</span></td>
                  <td>{fmtDate(m.startDate)}</td>
                  <td>{fmtDate(m.endDate)}</td>
                  <td>{m.visitLimit !== null ? `${m.visitsUsed} / ${m.visitLimit}` : m.visitsUsed}</td>
                  <td><Badge tone={membershipStatusTone[m.effectiveStatus]}>{membershipStatusLabel[m.effectiveStatus]}</Badge></td>
                  <td><MembershipActions membership={m} onChanged={reloadAll} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </DataState>
      </Card>
      {assigning && <AssignMembershipModal clientId={c.id} onClose={() => setAssigning(false)} onDone={() => { setAssigning(false); reloadAll() }} />}
      {resetting && <ResetPasswordModal url={`/api/admin/clients/${c.id}/reset-password`} onClose={() => setResetting(false)} />}
    </>
  )
}

function ClientForm({ client, onSaved }: { client: Client; onSaved(): void }) {
  const init = () => ({
    phone: client.phone, firstName: client.firstName, lastName: client.lastName, email: client.email ?? '',
    birthDate: client.birthDate ?? '', gender: (client.gender ?? '') as Gender | '', notes: client.notes ?? '',
    status: client.status, assignedTrainerId: client.assignedTrainer?.id ?? '',
  })
  const [form, setForm] = useState(init)
  const [trainers, setTrainers] = useState<Trainer[]>([])
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null)
  const [busy, setBusy] = useState(false)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => setForm(init()), [client])
  useEffect(() => { api<Paged<Trainer>>('/api/admin/trainers?pageSize=100&isActive=true').then(p => setTrainers(p.items)).catch(() => {}) }, [])
  const set = (k: keyof ReturnType<typeof init>) =>
    (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => setForm({ ...form, [k]: e.target.value })

  async function submit(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setMsg(null); setErrors({})
    try {
      await api(`/api/admin/clients/${client.id}`, {
        method: 'PUT',
        body: {
          ...form, email: form.email || null, birthDate: form.birthDate || null, gender: form.gender || null,
          notes: form.notes || null, assignedTrainerId: form.assignedTrainerId || null,
        },
      })
      setMsg({ ok: true, text: 'Сохранено' })
      onSaved()
    } catch (err) { setMsg({ ok: false, text: errorMessage(err) }); setErrors(fieldErrors(err)) } finally { setBusy(false) }
  }

  return (
    <form className="form" onSubmit={submit}>
      <div className="grid-2">
        <Field label="Имя" error={errors.firstName}><input value={form.firstName} onChange={set('firstName')} required maxLength={64} /></Field>
        <Field label="Фамилия" error={errors.lastName}><input value={form.lastName} onChange={set('lastName')} required maxLength={64} /></Field>
      </div>
      <Field label="Телефон (логин)" error={errors.phone} hint={client.phoneConfirmed ? 'Подтверждён' : 'Не подтверждён по SMS (этап 2)'}>
        <input value={form.phone} onChange={set('phone')} required />
      </Field>
      <div className="grid-2">
        <Field label="Email" error={errors.email}><input type="email" value={form.email} onChange={set('email')} /></Field>
        <Field label="Дата рождения" error={errors.birthDate}><input type="date" value={form.birthDate} onChange={set('birthDate')} max={todayInClub()} /></Field>
      </div>
      <div className="grid-2">
        <Field label="Пол"><select value={form.gender} onChange={set('gender')}>
          <option value="">Не указан</option><option value="Male">Мужской</option><option value="Female">Женский</option>
        </select></Field>
        <Field label="Статус аккаунта"><select value={form.status} onChange={e => setForm({ ...form, status: e.target.value as UserStatus })}>
          <option value="Active">Активен</option><option value="Blocked">Заблокирован</option>
        </select></Field>
      </div>
      <Field label="Тренер"><select value={form.assignedTrainerId} onChange={set('assignedTrainerId')}>
        <option value="">Не назначен</option>
        {client.assignedTrainer && !trainers.some(t => t.id === client.assignedTrainer!.id) &&
          <option value={client.assignedTrainer.id}>{fullName(client.assignedTrainer)}</option>}
        {trainers.map(t => <option key={t.id} value={t.id}>{fullName(t)}</option>)}
      </select></Field>
      <Field label="Заметки персонала" hint="Видны только администраторам" error={errors.notes}>
        <textarea value={form.notes} onChange={set('notes')} rows={3} maxLength={2000} />
      </Field>
      <div className="form-actions">
        {msg && <span className={msg.ok ? 'ok' : 'field-error'}>{msg.text}</span>}
        <Button type="submit" disabled={busy}>Сохранить</Button>
      </div>
    </form>
  )
}

function AssignMembershipModal({ clientId, onClose, onDone }: { clientId: string; onClose(): void; onDone(): void }) {
  const plans = useAsync(() => api<MembershipPlan[]>('/api/admin/membership-plans?includeInactive=false'), [])
  const [planId, setPlanId] = useState('')
  const [startDate, setStartDate] = useState(todayInClub())
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const plan = plans.data?.find(p => p.id === planId)

  async function submit(e: FormEvent) {
    e.preventDefault()
    setBusy(true); setError(null)
    try {
      await api('/api/admin/memberships', { method: 'POST', body: { clientId, planId, startDate } })
      onDone()
    } catch (err) { setError(errorMessage(err)) } finally { setBusy(false) }
  }

  return (
    <Modal title="Назначить абонемент" onClose={onClose}>
      <form className="form" onSubmit={submit}>
        <ErrorBanner message={error ?? plans.error} />
        {plans.data && plans.data.length === 0 && <p className="muted">Нет активных планов. <Link to="/plans">Создайте план</Link>.</p>}
        <Field label="План">
          <select value={planId} onChange={e => setPlanId(e.target.value)} required>
            <option value="" disabled>Выберите план</option>
            {plans.data?.map(p => <option key={p.id} value={p.id}>{p.name} — {p.durationDays} дн.</option>)}
          </select>
        </Field>
        <Field label="Дата начала" hint={plan ? `Действует ${plan.durationDays} дн., окончание рассчитывается автоматически` : undefined}>
          <input type="date" value={startDate} onChange={e => setStartDate(e.target.value)} required />
        </Field>
        <div className="form-actions">
          <Button type="button" variant="secondary" onClick={onClose}>Отмена</Button>
          <Button type="submit" disabled={busy || !planId}>Назначить</Button>
        </div>
      </form>
    </Modal>
  )
}

export function ResetPasswordModal({ url, onClose }: { url: string; onClose(): void }) {
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [done, setDone] = useState(false)

  async function submit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    try { await api(url, { method: 'POST', body: { newPassword: password } }); setDone(true) } catch (err) { setError(errorMessage(err)) }
  }

  return (
    <Modal title="Новый пароль" onClose={onClose}>
      {done ? (
        <div className="form"><p>Временный пароль установлен. Все сессии пользователя завершены; при входе он задаст свой пароль.</p>
          <div className="form-actions"><Button onClick={onClose}>Готово</Button></div></div>
      ) : (
        <form className="form" onSubmit={submit}>
          <ErrorBanner message={error} />
          <Field label="Временный пароль" hint="Не менее 8 символов, буквы и цифры. При следующем входе пользователь задаст свой пароль.">
            <input value={password} onChange={e => setPassword(e.target.value)} minLength={8} required autoComplete="new-password" />
          </Field>
          <div className="form-actions">
            <Button type="button" variant="secondary" onClick={onClose}>Отмена</Button>
            <Button type="submit">Сохранить</Button>
          </div>
        </form>
      )}
    </Modal>
  )
}
