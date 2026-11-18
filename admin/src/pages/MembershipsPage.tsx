import { useState, type FormEvent } from 'react'
import { Link, useSearchParams } from 'react-router'
import { api, qs } from '../api/client'
import type { Membership, MembershipFilter, MembershipStatus, Paged } from '../api/types'
import { Badge, Button, DataState, Field, Modal, PageHeader, Pagination } from '../components/ui'
import { fmtDate, membershipStatusLabel, membershipStatusTone, todayInClub } from '../lib/format'
import { errorMessage, useAsync } from '../lib/useAsync'

const filters: { value: MembershipFilter | ''; label: string }[] = [
  { value: '', label: 'Все' },
  { value: 'Active', label: 'Активные' },
  { value: 'ExpiringSoon', label: 'Истекают за 7 дней' },
  { value: 'Upcoming', label: 'Ещё не начались' },
  { value: 'Exhausted', label: 'Посещения исчерпаны' },
  { value: 'Frozen', label: 'Замороженные' },
  { value: 'Expired', label: 'Истёкшие' },
  { value: 'Cancelled', label: 'Отменённые' },
]

export function MembershipsPage() {
  const [params, setParams] = useSearchParams()
  const status = (params.get('status') ?? '') as MembershipFilter | ''
  const [page, setPage] = useState(1)
  const { data, error, loading, reload } = useAsync(
    () => api<Paged<Membership>>(`/api/admin/memberships${qs({ status, page, pageSize: 20 })}`), [status, page])

  return (
    <>
      <PageHeader title="Абонементы" />
      <div className="tabs">
        {filters.map(f => (
          <button key={f.value} className={`tab ${status === f.value ? 'active' : ''}`}
            onClick={() => { setPage(1); setParams(f.value ? { status: f.value } : {}) }}>{f.label}</button>
        ))}
      </div>
      <DataState loading={loading} error={error} empty={!!data && data.items.length === 0} onRetry={reload}>
        {data && (
          <>
            <table className="table">
              <thead><tr><th>Клиент</th><th>План</th><th>Начало</th><th>Окончание</th><th>Осталось</th><th>Посещения</th><th>Статус</th><th /></tr></thead>
              <tbody>
                {data.items.map(m => (
                  <tr key={m.id}>
                    <td><Link to={`/clients/${m.clientId}`}>{m.clientName}</Link></td>
                    <td>{m.planName}</td>
                    <td>{fmtDate(m.startDate)}</td>
                    <td>{fmtDate(m.endDate)}</td>
                    <td>{m.daysLeft > 0 ? `${m.daysLeft} дн.` : '—'}</td>
                    <td>{m.visitLimit !== null ? `${m.visitsUsed} / ${m.visitLimit}` : m.visitsUsed}</td>
                    <td><MembershipStatusCell membership={m} /></td>
                    <td><MembershipActions membership={m} onChanged={reload} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
            <Pagination page={data.page} totalPages={data.totalPages} totalCount={data.totalCount} onChange={setPage} />
          </>
        )}
      </DataState>
    </>
  )
}

/** Status badge plus the current or planned freeze period. */
export function MembershipStatusCell({ membership: m }: { membership: Membership }) {
  return (
    <>
      <Badge tone={membershipStatusTone[m.effectiveStatus]}>{membershipStatusLabel[m.effectiveStatus]}</Badge>
      {m.freezeStartDate && m.freezeEndDate && (
        <div className="muted small">
          {m.effectiveStatus === 'Frozen' ? 'Заморозка' : 'Запланирована заморозка'} {fmtDate(m.freezeStartDate)} – {fmtDate(m.freezeEndDate)}
        </div>
      )}
    </>
  )
}

/** Freeze / unfreeze / cancel. Expired and cancelled memberships have no actions. */
export function MembershipActions({ membership: m, onChanged }: { membership: Membership; onChanged(): void }) {
  const [busy, setBusy] = useState(false)
  const [freezing, setFreezing] = useState(false)
  if (m.effectiveStatus === 'Expired' || m.effectiveStatus === 'Cancelled') return null

  async function run(call: () => Promise<unknown>, confirmText?: string) {
    if (confirmText && !window.confirm(confirmText)) return
    setBusy(true)
    try {
      await call()
      onChanged()
    } catch (e) { window.alert(errorMessage(e)) } finally { setBusy(false) }
  }

  const set = (status: MembershipStatus, confirmText?: string) => run(
    () => api(`/api/admin/memberships/${m.id}`, { method: 'PUT', body: { status, startDate: m.startDate, endDate: m.endDate } }),
    confirmText)

  return (
    <div className="row-actions">
      {m.status === 'Frozen'
        // Frozen by status (before freeze periods existed): only reactivation, the end date was not moved.
        ? <Button variant="ghost" disabled={busy} onClick={() => set('Active')}>Разморозить</Button>
        : m.freezeEndDate
          ? <Button variant="ghost" disabled={busy} onClick={() => run(
              () => api(`/api/admin/memberships/${m.id}/unfreeze`, { method: 'POST' }),
              'Завершить заморозку сегодня? Неиспользованные дни заморозки будут вычтены из срока абонемента.')}>Разморозить</Button>
          : <Button variant="ghost" disabled={busy || freezeBlocked(m) !== null} title={freezeBlocked(m) ?? undefined}
              onClick={() => setFreezing(true)}>Заморозить</Button>}
      <Button variant="ghost" disabled={busy} onClick={() => set('Cancelled', 'Отменить абонемент? Действие нельзя отменить из списка.')}>Отменить</Button>
      {freezing && <FreezeModal membership={m} onClose={() => setFreezing(false)} onDone={() => { setFreezing(false); onChanged() }} />}
    </div>
  )
}

/** Longest single freeze, as enforced by the API (MembershipService.MaxFreezeDays). */
const MAX_FREEZE_DAYS = 30

/** Why the membership cannot be frozen now, or null if it can. */
function freezeBlocked(m: Membership): string | null {
  if (m.freezesAllowed === 0) return 'Заморозка доступна только для абонементов от 6 месяцев'
  if (m.freezesUsed >= m.freezesAllowed) return `Все ${m.freezesAllowed} заморозки уже использованы`
  return null
}

function addDays(date: string, days: number): string {
  const d = new Date(`${date}T00:00:00Z`)
  d.setUTCDate(d.getUTCDate() + days)
  return d.toISOString().slice(0, 10)
}

function daysBetween(from: string, to: string): number {
  return Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000) + 1
}

function FreezeModal({ membership: m, onClose, onDone }: { membership: Membership; onClose(): void; onDone(): void }) {
  const today = todayInClub()
  const firstDay = m.startDate > today ? m.startDate : today
  const [from, setFrom] = useState(firstDay)
  const [to, setTo] = useState(addDays(firstDay, 13))
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const days = from && to && to >= from ? daysBetween(from, to) : 0
  const tooLong = days > MAX_FREEZE_DAYS

  async function submit(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try {
      await api(`/api/admin/memberships/${m.id}/freeze`, { method: 'POST', body: { startDate: from, endDate: to } })
      onDone()
    } catch (err) { setError(errorMessage(err)) } finally { setBusy(false) }
  }

  return (
    <Modal title={`Заморозка: ${m.clientName}`} onClose={onClose}>
      <form className="form" onSubmit={submit}>
        <p className="muted small">
          Пока абонемент заморожен, вход по нему запрещён. Срок абонемента продлевается на дни заморозки,
          следующий абонемент клиента (если есть) сдвигается вместе с ним. Клиент получит уведомление.
          Одна заморозка — до {MAX_FREEZE_DAYS} дней; клиент может заморозить абонемент и сам в приложении.
        </p>
        <div className="grid-2">
          <Field label="С (включительно)">
            <input type="date" value={from} min={firstDay} max={m.endDate} onChange={e => setFrom(e.target.value)} required />
          </Field>
          <Field label="По (включительно)">
            <input type="date" value={to} min={from} max={from ? addDays(from, MAX_FREEZE_DAYS - 1) : undefined} onChange={e => setTo(e.target.value)} required />
          </Field>
        </div>
        <div className="kv">
          <div><span>Дней заморозки</span><b className={tooLong ? 'field-error' : undefined}>{days || '—'}{tooLong && ` (максимум ${MAX_FREEZE_DAYS})`}</b></div>
          <div><span>Заморозок использовано</span><b>{m.freezesUsed} из {m.freezesAllowed}</b></div>
          <div><span>Окончание сейчас</span><b>{fmtDate(m.endDate)}</b></div>
          <div><span>Окончание после заморозки</span><b>{days ? fmtDate(addDays(m.endDate, days)) : '—'}</b></div>
        </div>
        {error && <div className="field-error" role="alert">{error}</div>}
        <div className="form-actions">
          <Button type="button" variant="secondary" onClick={onClose}>Отмена</Button>
          <Button type="submit" disabled={busy || !days || tooLong}>Заморозить на {days || 0} дн.</Button>
        </div>
      </form>
    </Modal>
  )
}
