import { useState, type FormEvent } from 'react'
import { useAuth } from '../auth/AuthContext'
import { Button, Card, ErrorBanner, Field, PageHeader } from '../components/ui'
import { errorMessage, fieldErrors } from '../lib/useAsync'

/**
 * Password change. With `forced` it replaces the whole panel after signing in with a temporary password
 * (account created or reset by staff, or the bootstrap administrator); the API rejects other calls until done.
 */
export function ChangePasswordPage({ forced = false }: { forced?: boolean }) {
  const { changePassword, logout } = useAuth()
  const [form, setForm] = useState({ current: '', next: '', confirm: '' })
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [error, setError] = useState<string | null>(null)
  const [done, setDone] = useState(false)
  const [busy, setBusy] = useState(false)
  const set = (k: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement>) => setForm({ ...form, [k]: e.target.value })

  async function submit(e: FormEvent) {
    e.preventDefault()
    setError(null); setErrors({}); setDone(false)
    if (form.next !== form.confirm) { setErrors({ confirm: 'Пароли не совпадают' }); return }
    if (form.next === form.current) { setErrors({ newPassword: 'Новый пароль должен отличаться от текущего' }); return }
    setBusy(true)
    try {
      await changePassword(form.current, form.next)
      setForm({ current: '', next: '', confirm: '' })
      setDone(true)
    } catch (err) { setError(errorMessage(err)); setErrors(fieldErrors(err)) } finally { setBusy(false) }
  }

  const body = (
    <form className="form" onSubmit={submit}>
      <ErrorBanner message={error} />
      {done && <p className="ok">Пароль изменён. Другие сессии завершены.</p>}
      <Field label="Текущий пароль" error={errors.currentPassword}>
        <input type="password" value={form.current} onChange={set('current')} required autoComplete="current-password" />
      </Field>
      <Field label="Новый пароль" error={errors.newPassword} hint="Не менее 8 символов, буквы и цифры">
        <input type="password" value={form.next} onChange={set('next')} required minLength={8} autoComplete="new-password" />
      </Field>
      <Field label="Повторите новый пароль" error={errors.confirm}>
        <input type="password" value={form.confirm} onChange={set('confirm')} required autoComplete="new-password" />
      </Field>
      <div className="form-actions">
        {forced && <Button type="button" variant="secondary" onClick={logout}>Выйти</Button>}
        <Button type="submit" disabled={busy}>Сохранить пароль</Button>
      </div>
    </form>
  )

  if (forced) {
    return (
      <div className="login">
        <div className="login-card">
          <div className="brand brand-lg">Fitness <b>Formulasi</b></div>
          <h1>Задайте свой пароль</h1>
          <p className="muted">Вы вошли с временным паролем. Чтобы продолжить, задайте новый пароль, который знаете только вы.</p>
          {body}
        </div>
      </div>
    )
  }
  return (
    <>
      <PageHeader title="Сменить пароль" />
      <div style={{ maxWidth: 480 }}><Card>{body}</Card></div>
    </>
  )
}
