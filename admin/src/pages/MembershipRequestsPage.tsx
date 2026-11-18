import { useState, type FormEvent } from 'react'
import { Link, NavLink } from 'react-router'
import { api, qs } from '../api/client'
import type { MembershipRequestAdmin, MembershipRequestStatus, Paged } from '../api/types'
import { Badge, Button, DataState, Field, Modal, PageHeader, Pagination } from '../components/ui'
import {
  fmtDate, fmtDateTime, fmtMoney, fullName, membershipRequestKindLabel, membershipRequestStatusLabel,
  membershipRequestStatusTone, membershipStatusLabel, planTypeLabel, todayInClub,
} from '../lib/format'
import { errorMessage, useAsync } from '../lib/useAsync'

/** Switches between trainer requests and membership requests (both live under «Заявки»). */
export function RequestsTabs() {
  return (
    <div className="tabs">
      <NavLink to="/requests" end className={({ isActive }) => `tab ${isActive ? 'active' : ''}`}>На тренера</NavLink>
      <NavLink to="/requests/memberships" className={({ isActive }) => `tab ${isActive ? 'active' : ''}`}>На абонемент</NavLink>
    </div>
  )
}

const tabs: (MembershipRequestStatus | '')[] = ['Pending', 'Completed', 'Rejected', 'Cancelled', '']

/** Renewals and plan changes requested in the app; staff take the payment at the desk and complete them here. */
export function MembershipRequestsPage() {
  const [status, setStatus] = useState<MembershipRequestStatus | ''>('Pending')
  const [page, setPage] = useState(1)
  const [completing, setCompleting] = useState<MembershipRequestAdmin | null>(null)
  const { data, error, loading, reload } = useAsync(
    () => api<Paged<MembershipRequestAdmin>>(`/api/admin/membership-requests${qs({ status, page, pageSize: 20 })}`), [status, page])

  async function reject(item: MembershipRequestAdmin) {
    const comment = window.prompt('Причина отказа (клиент увидит уведомление)')
    if (comment === null) return
    try {
      await api(`/api/admin/membership-requests/${item.request.id}/reject`, { method: 'POST', body: { comment: comment || null } })
      reload()
    } catch (e) { window.alert(errorMessage(e)) }
  }

  return (
    <>
      <PageHeader title="Заявки" />
      <RequestsTabs />
      <p className="muted small">
        Клиент выбирает план в приложении. Примите оплату на ресепшене и нажмите «Оформить» — абонемент будет назначен,
        клиенту придёт уведомление. Онлайн-оплата (Click, Payme) — этап 2.
      </p>
      <div className="tabs">
        {tabs.map(t => (
          <button key={t} className={`tab ${status === t ? 'active' : ''}`} onClick={() => { setPage(1); setStatus(t) }}>
            {t ? membershipRequestStatusLabel[t] : 'Все'}
          </button>
        ))}
      </div>
      <DataState loading={loading} error={error} empty={!!data && data.items.length === 0} onRetry={reload}>
        {data && (
          <>
            <table className="table">
              <thead><tr><th>Создана</th><th>Клиент</th><th>Заявка</th><th>План</th><th>Цена</th><th>Текущий абонемент</th><th>Статус</th><th /></tr></thead>
              <tbody>
                {data.items.map(item => {
                  const r = item.request
                  return (
                    <tr key={r.id}>
                      <td>{fmtDateTime(r.createdAt)}</td>
                      <td><Link to={`/clients/${r.client.id}`}>{fullName(r.client)}</Link><div className="muted small">{r.clientPhone}</div></td>
                      <td>{membershipRequestKindLabel[r.kind]}</td>
                      <td>{r.plan.name}<div className="muted small">{planTypeLabel[r.plan.type]} · {r.plan.durationDays} дн.</div></td>
                      <td>{fmtMoney(r.plan.price)}</td>
                      <td>{item.currentMembership
                        ? <>{item.currentMembership.planName}<div className="muted small">
                            {membershipStatusLabel[item.currentMembership.effectiveStatus]} до {fmtDate(item.currentMembership.endDate)}</div></>
                        : r.status === 'Pending' ? <span className="muted">нет</span> : '—'}</td>
                      <td>
                        <Badge tone={membershipRequestStatusTone[r.status]}>{membershipRequestStatusLabel[r.status]}</Badge>
                        {r.responseComment && <div className="muted small">Ответ: {r.responseComment}</div>}
                      </td>
                      <td className="row-actions">{r.status === 'Pending' && <>
                        <Button onClick={() => setCompleting(item)}>Оформить</Button>
                        <Button variant="ghost" onClick={() => reject(item)}>Отклонить</Button>
                      </>}</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
            <Pagination page={data.page} totalPages={data.totalPages} totalCount={data.totalCount} onChange={setPage} />
          </>
        )}
      </DataState>
      {completing && <CompleteModal item={completing} onClose={() => setCompleting(null)}
        onDone={() => { setCompleting(null); reload() }} />}
    </>
  )
}

function CompleteModal({ item, onClose, onDone }: { item: MembershipRequestAdmin; onClose(): void; onDone(): void }) {
  const r = item.request
  const today = todayInClub()
  const current = item.currentMembership
  const afterCurrent = item.suggestedStartDate ?? today
  // A plan change may start right away (the current membership then ends yesterday) or after the current one.
  const canStartNow = r.kind === 'Change' && !!current && afterCurrent > today
  const [startNow, setStartNow] = useState(false)
  const [start, setStart] = useState(afterCurrent)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      await api(`/api/admin/membership-requests/${r.id}/complete`, {
        method: 'POST', body: startNow ? { startDate: today, closeCurrent: true } : { startDate: start },
      })
      onDone()
    } catch (err) { setError(errorMessage(err)) } finally { setBusy(false) }
  }

  return (
    <Modal title={`${membershipRequestKindLabel[r.kind]}: ${fullName(r.client)}`} onClose={onClose}>
      <form className="form" onSubmit={submit}>
        <div className="kv">
          <div><span>План</span><b>{r.plan.name}</b></div>
          <div><span>К оплате</span><b>{fmtMoney(r.plan.price)}</b></div>
          <div><span>Текущий абонемент</span><b>{current ? `${current.planName} до ${fmtDate(current.endDate)}` : 'нет'}</b></div>
        </div>
        {canStartNow && (
          <div className="stack">
            <label className="check"><input type="radio" checked={!startNow} onChange={() => setStartNow(false)} />
              После окончания текущего ({fmtDate(afterCurrent)})</label>
            <label className="check"><input type="radio" checked={startNow} onChange={() => setStartNow(true)} />
              Сегодня — текущий абонемент закончится вчерашним днём</label>
          </div>
        )}
        {!startNow && (
          <Field label="Начало абонемента" hint="Окончание рассчитается по длительности плана.">
            <input type="date" value={start} min={today} onChange={e => setStart(e.target.value)} required />
          </Field>
        )}
        <p className="muted small">Нажимайте «Оформить» только после оплаты.</p>
        {error && <div className="field-error" role="alert">{error}</div>}
        <div className="form-actions">
          <Button type="button" variant="secondary" onClick={onClose}>Отмена</Button>
          <Button type="submit" disabled={busy}>Оплачено — оформить</Button>
        </div>
      </form>
    </Modal>
  )
}
