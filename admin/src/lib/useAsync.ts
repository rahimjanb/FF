import { useCallback, useEffect, useState } from 'react'
import { ApiError } from '../api/client'

/** Loads data and re-runs when `deps` change. `reload` re-fetches after a mutation. */
export function useAsync<T>(load: () => Promise<T>, deps: unknown[]) {
  const [data, setData] = useState<T | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [nonce, setNonce] = useState(0)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    setError(null)
    load()
      .then(d => { if (!cancelled) setData(d) })
      .catch(e => { if (!cancelled) setError(errorMessage(e)) })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, nonce])

  const reload = useCallback(() => setNonce(n => n + 1), [])
  return { data, error, loading, reload }
}

const codeMessages: Record<string, string> = {
  phone_taken: 'Пользователь с таким номером уже существует.',
  membership_overlap: 'У клиента уже есть абонемент на эти даты.',
  plan_inactive: 'Этот план абонемента отключён.',
  plan_name_taken: 'План с таким названием уже существует.',
  no_active_membership: 'У клиента нет действующего абонемента на эту дату.',
  request_not_pending: 'Заявка уже обработана.',
  invalid_credentials: 'Неверный номер телефона или пароль.',
  account_locked: 'Слишком много попыток входа. Попробуйте позже.',
  account_blocked: 'Аккаунт заблокирован.',
  trainer_not_found: 'Тренер не найден или неактивен.',
  validation_failed: 'Проверьте правильность заполнения полей.',
  too_many_requests: 'Слишком много запросов. Подождите минуту.',
  invalid_password: 'Текущий пароль указан неверно.',
  password_unchanged: 'Новый пароль должен отличаться от текущего.',
  password_change_required: 'Сначала смените временный пароль.',
}

export function errorMessage(e: unknown): string {
  if (e instanceof ApiError) return codeMessages[e.code] ?? e.message
  return 'Непредвиденная ошибка.'
}

export function fieldErrors(e: unknown): Record<string, string> {
  if (!(e instanceof ApiError)) return {}
  const out: Record<string, string> = {}
  for (const [k, v] of Object.entries(e.fields)) out[k.charAt(0).toLowerCase() + k.slice(1)] = v[0]
  return out
}
