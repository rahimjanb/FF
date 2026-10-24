import { useState } from 'react'
import { api, qs } from '../api/client'
import type { CountByKey, Report } from '../api/types'
import { Card, ErrorBanner, Field, PageHeader, Spinner } from '../components/ui'
import { fmtDate, requestStatusLabel, sessionStatusLabel, todayInClub } from '../lib/format'
import { useAsync } from '../lib/useAsync'

export function ReportsPage() {
  const today = todayInClub()
  const [from, setFrom] = useState(today.slice(0, 8) + '01')
  const [to, setTo] = useState(today)
  const { data, error, loading, reload } = useAsync(() => api<Report>(`/api/admin/reports/summary${qs({ from, to })}`), [from, to])
  const maxDay = Math.max(1, ...(data?.visitsByDay.map(d => d.count) ?? [1]))

  return (
    <>
      <PageHeader title="Отчёты" />
      <div className="filters">
        <Field label="С"><input type="date" value={from} max={to} onChange={e => setFrom(e.target.value)} /></Field>
        <Field label="По"><input type="date" value={to} min={from} onChange={e => setTo(e.target.value)} /></Field>
      </div>
      <p className="muted small">Показатели рассчитываются только по данным, внесённым в систему. Платежи не учитываются (этап 2).</p>
      <ErrorBanner message={error} onRetry={reload} />
      {loading && !data ? <Spinner /> : data && (
        <>
          <div className="stats">
            <div className="stat"><div className="stat-value">{data.newClients}</div><div className="stat-label">Новых клиентов</div></div>
            <div className="stat"><div className="stat-value">{data.membershipsAssigned}</div><div className="stat-label">Выдано абонементов</div></div>
            <div className="stat"><div className="stat-value">{data.visits}</div><div className="stat-label">Посещений</div></div>
          </div>
          <div className="detail-grid">
            <Card title="Абонементы по планам"><CountTable rows={data.membershipsByPlan} /></Card>
            <Card title="Заявки на тренера">
              <CountTable rows={data.trainerRequestsByStatus.map(r => ({ ...r, key: requestStatusLabel[r.key as keyof typeof requestStatusLabel] ?? r.key }))} />
            </Card>
            <Card title="Тренировки">
              <CountTable rows={data.sessionsByStatus.map(r => ({ ...r, key: sessionStatusLabel[r.key as keyof typeof sessionStatusLabel] ?? r.key }))} />
            </Card>
            <Card title="Посещения по дням">
              {data.visitsByDay.length === 0 ? <p className="muted">Нет посещений за период</p> : (
                <div className="bars">
                  {data.visitsByDay.map(d => (
                    <div className="bar-row" key={d.date}>
                      <span>{fmtDate(d.date)}</span>
                      <div className="bar"><div style={{ width: `${(d.count / maxDay) * 100}%` }} /></div>
                      <b>{d.count}</b>
                    </div>
                  ))}
                </div>
              )}
            </Card>
          </div>
          <Card title="Нагрузка тренеров">
            {data.trainers.length === 0 ? <p className="muted">Нет активных тренеров</p> : (
              <table className="table">
                <thead><tr><th>Тренер</th><th>Клиентов сейчас</th><th>Проведено тренировок</th><th>Получено заявок</th></tr></thead>
                <tbody>{data.trainers.map(t => <tr key={t.trainerId}><td>{t.name}</td><td>{t.clients}</td><td>{t.sessionsCompleted}</td><td>{t.requestsReceived}</td></tr>)}</tbody>
              </table>
            )}
          </Card>
        </>
      )}
    </>
  )
}

function CountTable({ rows }: { rows: CountByKey[] }) {
  if (rows.length === 0) return <p className="muted">Нет данных за период</p>
  return <table className="table compact"><tbody>{rows.map(r => <tr key={r.key}><td>{r.key}</td><td className="num">{r.count}</td></tr>)}</tbody></table>
}
