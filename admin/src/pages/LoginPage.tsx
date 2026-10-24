import { useState, type FormEvent } from 'react'
import { Navigate } from 'react-router'
import { useAuth } from '../auth/AuthContext'
import { Button, ErrorBanner, Field } from '../components/ui'
import { errorMessage } from '../lib/useAsync'

export function LoginPage() {
  const { user, login } = useAuth()
  const [phone, setPhone] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  if (user) return <Navigate to="/" replace />

  async function submit(e: FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError(null)
    try { await login(phone, password) } catch (err) { setError(errorMessage(err)) } finally { setBusy(false) }
  }

  return (
    <div className="login">
      <form className="login-card" onSubmit={submit}>
        <div className="brand brand-lg">Fitness <b>Formulasi</b></div>
        <p className="muted">Вход для администраторов клуба</p>
        <ErrorBanner message={error} />
        <Field label="Номер телефона">
          <input value={phone} onChange={e => setPhone(e.target.value)} placeholder="+998 90 123 45 67" autoComplete="username" required />
        </Field>
        <Field label="Пароль">
          <input type="password" value={password} onChange={e => setPassword(e.target.value)} autoComplete="current-password" required />
        </Field>
        <Button type="submit" disabled={busy}>{busy ? 'Вход…' : 'Войти'}</Button>
      </form>
    </div>
  )
}
