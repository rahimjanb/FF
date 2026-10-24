import { useState } from 'react'
import { Link } from 'react-router'
import { api, qs } from '../api/client'
import type { Paged, TrainerRequest, TrainerRequestStatus } from '../api/types'
import { Badge, Button, DataState, PageHeader, Pagination } from '../components/ui'
import { fmtDateTime, fullName, requestStatusLabel, requestStatusTone } from '../lib/format'
import { errorMessage, useAsync } from '../lib/useAsync'

const tabs: (TrainerRequestStatus | '')[] = ['Pending', 'Accepted', 'Rejected', 'Cancelled', '']

export function RequestsPage() {
  const [status, setStatus] = useState<TrainerRequestStatus | ''>('Pending')
  const [page, setPage] = useState(1)
  const { data, error, loading, reload } = useAsync(
    () => api<Paged<TrainerRequest>>(`/api/admin/trainer-requests${qs({ status, page, pageSize: 20 })}`), [status, page])

  async function respond(r: TrainerRequest, action: 'accept' | 'reject') {
    const comment = window.prompt(action === 'accept' ? 'Комментарий клиенту (необязательно)' : 'Причина отказа (необязательно)')
    if (comment === null) return
    try {
      await api(`/api/admin/trainer-requests/${r.id}/${action}`, { method: 'POST', body: { comment: comment || null } })
      reload()
    } catch (e) { window.alert(errorMessage(e)) }
  }

  return (
    <>
      <PageHeader title="Заявки на тренера" />
      <div className="tabs">
        {tabs.map(t => (
          <button key={t} className={`tab ${status === t ? 'active' : ''}`} onClick={() => { setPage(1); setStatus(t) }}>
            {t ? requestStatusLabel[t] : 'Все'}
          </button>
        ))}
      </div>
      <DataState loading={loading} error={error} empty={!!data && data.items.length === 0} onRetry={reload}>
        {data && (
          <>
            <table className="table">
              <thead><tr><th>Создана</th><th>Клиент</th><th>Тренер</th><th>Сообщение</th><th>Статус</th><th /></tr></thead>
              <tbody>
                {data.items.map(r => (
                  <tr key={r.id}>
                    <td>{fmtDateTime(r.createdAt)}</td>
                    <td><Link to={`/clients/${r.client.id}`}>{fullName(r.client)}</Link></td>
                    <td>{fullName(r.trainer)}</td>
                    <td>{r.message ?? '—'}{r.responseComment && <div className="muted small">Ответ: {r.responseComment}</div>}</td>
                    <td><Badge tone={requestStatusTone[r.status]}>{requestStatusLabel[r.status]}</Badge></td>
                    <td className="row-actions">{r.status === 'Pending' && <>
                      <Button variant="ghost" onClick={() => respond(r, 'accept')}>Принять</Button>
                      <Button variant="ghost" onClick={() => respond(r, 'reject')}>Отклонить</Button>
                    </>}</td>
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
