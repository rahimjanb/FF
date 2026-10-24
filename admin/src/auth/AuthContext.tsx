import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react'
import { api, ApiError, refreshSession, session } from '../api/client'
import type { AuthResponse, AuthUser } from '../api/types'

interface AuthState {
  user: AuthUser | null
  loading: boolean
  login(phone: string, password: string): Promise<void>
  changePassword(currentPassword: string, newPassword: string): Promise<void>
  logout(): Promise<void>
}

const AuthContext = createContext<AuthState | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    session.onEnd(() => setUser(null))
    // Restore the session after a page reload using the refresh token.
    refreshSession()
      .then(async ok => { if (ok) setUser(await api<AuthUser>('/api/auth/me')) })
      .catch(() => session.clear())
      .finally(() => setLoading(false))
  }, [])

  const login = useCallback(async (phone: string, password: string) => {
    const auth = await api<AuthResponse>('/api/auth/login', { method: 'POST', body: { phone, password } })
    session.set(auth)
    if (auth.user.role !== 'Admin') {
      // The backend enforces roles anyway; this only avoids a confusing empty panel.
      await api('/api/auth/logout', { method: 'POST', body: { refreshToken: auth.refreshToken } }).catch(() => {})
      session.clear()
      throw new ApiError(403, 'forbidden', 'Доступ только для администраторов.')
    }
    setUser(auth.user)
  }, [])

  const changePassword = useCallback(async (currentPassword: string, newPassword: string) => {
    // The server signs out other sessions and returns a fresh token pair for this one.
    const auth = await api<AuthResponse>('/api/auth/change-password', { method: 'POST', body: { currentPassword, newPassword } })
    session.set(auth)
    setUser(auth.user)
  }, [])

  const logout = useCallback(async () => {
    const token = session.refreshToken()
    if (token) await api('/api/auth/logout', { method: 'POST', body: { refreshToken: token } }).catch(() => {})
    session.clear()
    setUser(null)
  }, [])

  return <AuthContext.Provider value={{ user, loading, login, changePassword, logout }}>{children}</AuthContext.Provider>
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth outside AuthProvider')
  return ctx
}
