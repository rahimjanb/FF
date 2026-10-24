import type { AuthResponse } from './types'

const BASE = (import.meta.env.VITE_API_URL as string | undefined) ?? ''
const REFRESH_KEY = 'ff.admin.refresh'

/** Error in the backend's ProblemDetails format. `fields` holds per-field validation messages. */
export class ApiError extends Error {
  status: number
  code: string
  fields: Record<string, string[]>
  constructor(status: number, code: string, message: string, fields: Record<string, string[]> = {}) {
    super(message)
    this.status = status
    this.code = code
    this.fields = fields
  }
}

// Access token lives only in memory. The refresh token is kept in sessionStorage, so it is gone when the tab closes.
let accessToken: string | null = null
let refreshing: Promise<boolean> | null = null
let onSessionEnd: () => void = () => {}

export const session = {
  set(auth: AuthResponse) {
    accessToken = auth.accessToken
    sessionStorage.setItem(REFRESH_KEY, auth.refreshToken)
  },
  clear() {
    accessToken = null
    sessionStorage.removeItem(REFRESH_KEY)
  },
  refreshToken: () => sessionStorage.getItem(REFRESH_KEY),
  onEnd(cb: () => void) { onSessionEnd = cb },
}

async function parseError(res: Response): Promise<ApiError> {
  let body: { title?: string; code?: string; errors?: Record<string, string[]> } = {}
  try { body = await res.json() } catch { /* empty body */ }
  return new ApiError(res.status, body.code ?? 'error', body.title ?? `Ошибка ${res.status}`, body.errors ?? {})
}

export async function refreshSession(): Promise<boolean> {
  const token = session.refreshToken()
  if (!token) return false
  refreshing ??= (async () => {
    try {
      const res = await fetch(`${BASE}/api/auth/refresh`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ refreshToken: token }),
      })
      if (!res.ok) { session.clear(); return false }
      session.set(await res.json())
      return true
    } catch {
      return false
    } finally {
      refreshing = null
    }
  })()
  return refreshing
}

export async function api<T>(path: string, init: { method?: string; body?: unknown } = {}): Promise<T> {
  const send = () => fetch(`${BASE}${path}`, {
    method: init.method ?? 'GET',
    headers: {
      ...(init.body !== undefined ? { 'Content-Type': 'application/json' } : {}),
      ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
    },
    body: init.body !== undefined ? JSON.stringify(init.body) : undefined,
  })

  let res: Response
  try {
    res = await send()
  } catch {
    throw new ApiError(0, 'network', 'Сервер недоступен. Проверьте подключение.')
  }
  if (res.status === 401 && !path.startsWith('/api/auth/')) {
    if (await refreshSession()) res = await send()
    else { session.clear(); onSessionEnd() }
  }
  if (!res.ok) throw await parseError(res)
  if (res.status === 204) return undefined as T
  return res.json() as Promise<T>
}

export function qs(params: Record<string, string | number | boolean | null | undefined>): string {
  const p = new URLSearchParams()
  for (const [k, v] of Object.entries(params)) if (v !== undefined && v !== null && v !== '') p.set(k, String(v))
  const s = p.toString()
  return s ? `?${s}` : ''
}
