import { Link } from 'react-router'
import { api } from '../api/client'
import type { AdminDashboard } from '../api/types'
import { ErrorBanner, PageHeader, Spinner } from '../components/ui'
import { fmtDate } from '../lib/format'
import { useAsync } from '../lib/useAsync'

export function DashboardPage() {
  const { data, error, loading, reload } = useAsync(() => api<AdminDashboard>('/api/admin/dashboard'), [])

  return (
    <>
      <PageHeader title="Обзор" actions={data && <span className="muted">Сегодня: {fmtDate(data.today)}</span>} />
      <ErrorBanner message={error} onRetry={reload} />
      {loading && !data ? <Spinner /> : data && (
        <div className="stats">
          <Stat label="Клиентов всего" value={data.totalClients} to="/clients" />
          <Stat label="Новых за месяц" value={data.newClientsThisMonth} to="/clients" />
          <Stat label="Активных абонементов" value={data.activeMemberships} to="/memberships?status=Active" />
          <Stat label="Истекают в течение 7 дней" value={data.expiringSoon} to="/memberships?status=ExpiringSoon" accent={data.expiringSoon > 0} />
          <Stat label="Заявок на тренера ждут ответа" value={data.pendingTrainerRequests} to="/requests" accent={data.pendingTrainerRequests > 0} />
          <Stat label="Активных тренеров" value={data.activeTrainers} to="/trainers" />
          <Stat label="Посещений сегодня" value={data.visitsToday} to="/visits" />
          <Stat label="Тренировок сегодня" value={data.sessionsToday} />
        </div>
      )}
      {data && data.totalClients === 0 && (
        <p className="muted">Данных пока нет. Начните с создания планов абонементов и добавления клиентов.</p>
      )}
    </>
  )
}

function Stat({ label, value, to, accent }: { label: string; value: number; to?: string; accent?: boolean }) {
  const body = <><div className={`stat-value ${accent ? 'accent' : ''}`}>{value}</div><div className="stat-label">{label}</div></>
  return to ? <Link className="stat" to={to}>{body}</Link> : <div className="stat">{body}</div>
}
