import { BrowserRouter, Navigate, NavLink, Outlet, Route, Routes } from 'react-router'
import { AuthProvider, useAuth } from './auth/AuthContext'
import { Button, Spinner } from './components/ui'
import { ChangePasswordPage } from './pages/ChangePasswordPage'
import { CheckInPage } from './pages/CheckInPage'
import { ClientDetailPage } from './pages/ClientDetailPage'
import { ClientsPage } from './pages/ClientsPage'
import { AccessPage } from './pages/AccessPage'
import { BannersPage } from './pages/BannersPage'
import { DashboardPage } from './pages/DashboardPage'
import { LoginPage } from './pages/LoginPage'
import { MembershipRequestsPage } from './pages/MembershipRequestsPage'
import { MembershipsPage } from './pages/MembershipsPage'
import { PlansPage } from './pages/PlansPage'
import { ReportsPage } from './pages/ReportsPage'
import { IntegrationsPage } from './pages/IntegrationsPage'
import { GeneralSettings, SettingsPage } from './pages/SettingsPage'
import { RequestsPage } from './pages/RequestsPage'
import { TrainersPage } from './pages/TrainersPage'
import { VisitsPage } from './pages/VisitsPage'
import { fullName } from './lib/format'

const nav = [
  { to: '/', label: 'Обзор', end: true },
  { to: '/check-in', label: 'Пропуск' },
  { to: '/clients', label: 'Клиенты' },
  { to: '/memberships', label: 'Абонементы' },
  { to: '/plans', label: 'Планы' },
  { to: '/trainers', label: 'Тренеры' },
  { to: '/requests', label: 'Заявки' },
  { to: '/visits', label: 'Посещения' },
  { to: '/access', label: 'Турникеты' },
  { to: '/banners', label: 'Баннеры' },
  { to: '/reports', label: 'Отчёты' },
  { to: '/settings', label: 'Настройки' },
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
            <Route path="check-in" element={<CheckInPage />} />
            <Route path="clients" element={<ClientsPage />} />
            <Route path="clients/:id" element={<ClientDetailPage />} />
            <Route path="memberships" element={<MembershipsPage />} />
            <Route path="plans" element={<PlansPage />} />
            <Route path="trainers" element={<TrainersPage />} />
            <Route path="requests" element={<RequestsPage />} />
            <Route path="requests/memberships" element={<MembershipRequestsPage />} />
            <Route path="visits" element={<VisitsPage />} />
            <Route path="access" element={<AccessPage />} />
            <Route path="banners" element={<BannersPage />} />
            <Route path="reports" element={<ReportsPage />} />
            <Route path="settings" element={<SettingsPage />}>
              <Route index element={<Navigate to="general" replace />} />
              <Route path="general" element={<GeneralSettings />} />
              <Route path="integrations" element={<IntegrationsPage />} />
            </Route>
            <Route path="password" element={<ChangePasswordPage />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  )
}
