import { NavLink, Outlet } from 'react-router'
import { useAuth } from '../auth/AuthContext'
import { Badge, Card, PageHeader } from '../components/ui'
import { fullName } from '../lib/format'

export function SettingsPage() {
  return (
    <>
      <PageHeader title="Настройки" />
      <div className="tabs" role="tablist">
        <NavLink to="/settings/general" className={({ isActive }) => `tab ${isActive ? 'active' : ''}`}>Общие настройки</NavLink>
        <NavLink to="/settings/integrations" className={({ isActive }) => `tab ${isActive ? 'active' : ''}`}>Интеграции</NavLink>
      </div>
      <Outlet />
    </>
  )
}

/** Read-only for now: club-wide parameters (time zone etc.) are set in the server configuration. */
export function GeneralSettings() {
  const { user } = useAuth()
  if (!user) return null
  return (
    <Card title="Учётная запись">
      <table className="table compact">
        <tbody>
          <tr><td className="muted">Администратор</td><td>{fullName(user)}</td></tr>
          <tr><td className="muted">Телефон</td><td>{user.phone}</td></tr>
          <tr>
            <td className="muted">Управление интеграциями</td>
            <td>{user.canManageIntegrations ? <Badge tone="green">Разрешено</Badge> : <Badge tone="gray">Нет доступа</Badge>}</td>
          </tr>
        </tbody>
      </table>
      <p className="muted small">Параметры клуба (часовой пояс, адреса) задаются в конфигурации сервера.</p>
    </Card>
  )
}
