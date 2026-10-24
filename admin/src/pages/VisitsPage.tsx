import { useState } from 'react'
import { Link } from 'react-router'
import { api, qs } from '../api/client'
import type { Paged, Visit } from '../api/types'
import { DataState, PageHeader, Pagination } from '../components/ui'
import { fmtDateTime } from '../lib/format'
import { useAsync } from '../lib/useAsync'

export function VisitsPage() {
  const [page, setPage] = useState(1)
  const { data, error, loading, reload } = useAsync(() => api<Paged<Visit>>(`/api/admin/visits${qs({ page, pageSize: 30 })}`), [page])
  return (
    <>
      <PageHeader title="Посещения" />
      <p className="muted small">Посещения отмечаются вручную на карточке клиента. Автоматический учёт через турникет — этап 2.</p>
      <DataState loading={loading} error={error} empty={!!data && data.items.length === 0} onRetry={reload}>
        {data && (
          <>
            <table className="table">
              <thead><tr><th>Время</th><th>Клиент</th><th>Источник</th></tr></thead>
              <tbody>
                {data.items.map(v => (
                  <tr key={v.id}>
                    <td>{fmtDateTime(v.visitedAt)}</td>
                    <td><Link to={`/clients/${v.clientId}`}>{v.clientName}</Link></td>
                    <td>{v.source === 'Manual' ? 'Вручную' : v.source}</td>
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
