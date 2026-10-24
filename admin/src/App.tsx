import { BrowserRouter, Navigate, NavLink, Outlet, Route, Routes } from 'react-router'
import { AuthProvider, useAuth } from './auth/AuthContext'
import { Button, Spinner } from './components/ui'
import { ChangePasswordPage } from './pages/ChangePasswordPage'
import { ClientDetailPage } from './pages/ClientDetailPage'
import { ClientsPage } from './pages/ClientsPage'
import { DashboardPage } from './pages/DashboardPage'
import { LoginPage } from './pages/LoginPage'
import { MembershipsPage } from './pages/MembershipsPage'
import { PlansPage } from './pages/PlansPage'
import { ReportsPage } from './pages/ReportsPage'
import { RequestsPage } from './pages/RequestsPage'
import { TrainersPage } from './pages/TrainersPage'
import { VisitsPage } from './pages/VisitsPage'
import { fullName } from './lib/format'

const nav = [
  { to: '/', label: 'Обзор', end: true },
  { to: '/clients', label: 'Клиенты' },
  { to: '/memberships', label: 'Абонементы' },
  { to: '/plans', label: 'Планы' },
  { to: '/trainers', label: 'Тренеры' },
  { to: '/requests', label: 'Заявки' },
  { to: '/visits', label: 'Посещения' },
  { to: '/reports', label: 'Отчёты' },
]

function Layout() {
  const { user, loading, logout } = useAuth()
  if (loading) return <div className="center"><Spinner /></div>
  if (!user) return <Navigate to="/login" replace />
  if (user.mustChangePassword) return <ChangePasswordPage forced />
  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">Fitness <b>Formulasi</b></div>
        <nav>{nav.map(n => <NavLink key={n.to} to={n.to} end={n.end}>{n.label}</NavLink>)}</nav>
        <div className="sidebar-footer">
          <div className="muted small">{fullName(user)}</div>
          <NavLink to="/password" className="sidebar-link">Сменить пароль</NavLink>
          <Button variant="ghost" onClick={logout}>Выйти</Button>
        </div>
      </aside>
      <main className="content"><Outlet /></main>
    </div>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route element={<Layout />}>
            <Route index element={<DashboardPage />} />
            <Route path="clients" element={<ClientsPage />} />
            <Route path="clients/:id" element={<ClientDetailPage />} />
            <Route path="memberships" element={<MembershipsPage />} />
            <Route path="plans" element={<PlansPage />} />
            <Route path="trainers" element={<TrainersPage />} />
            <Route path="requests" element={<RequestsPage />} />
            <Route path="visits" element={<VisitsPage />} />
            <Route path="reports" element={<ReportsPage />} />
            <Route path="password" element={<ChangePasswordPage />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  )
}
