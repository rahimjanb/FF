import { useState } from 'react'
import { Link, useSearchParams } from 'react-router'
import { api, qs } from '../api/client'
import type { Membership, MembershipFilter, MembershipStatus, Paged } from '../api/types'
import { Badge, Button, DataState, PageHeader, Pagination } from '../components/ui'
import { fmtDate, membershipStatusLabel, membershipStatusTone } from '../lib/format'
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
                    <td><Badge tone={membershipStatusTone[m.effectiveStatus]}>{membershipStatusLabel[m.effectiveStatus]}</Badge></td>
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

/** Freeze / unfreeze / cancel. Expired and cancelled memberships have no actions. */
export function MembershipActions({ membership: m, onChanged }: { membership: Membership; onChanged(): void }) {
  const [busy, setBusy] = useState(false)
  if (m.effectiveStatus === 'Expired' || m.effectiveStatus === 'Cancelled') return null

  async function set(status: MembershipStatus, confirmText?: string) {
    if (confirmText && !window.confirm(confirmText)) return
    setBusy(true)
    try {
      await api(`/api/admin/memberships/${m.id}`, { method: 'PUT', body: { status, startDate: m.startDate, endDate: m.endDate } })
      onChanged()
    } catch (e) { window.alert(errorMessage(e)) } finally { setBusy(false) }
  }

  return (
    <div className="row-actions">
      {m.status === 'Frozen'
        ? <Button variant="ghost" disabled={busy} onClick={() => set('Active')}>Разморозить</Button>
        : <Button variant="ghost" disabled={busy} onClick={() => set('Frozen')}>Заморозить</Button>}
      <Button variant="ghost" disabled={busy} onClick={() => set('Cancelled', 'Отменить абонемент? Действие нельзя отменить из списка.')}>Отменить</Button>
    </div>
  )
}
