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
  photo_invalid_format: 'Загрузите изображение JPEG, PNG или WebP.',
  photo_too_large: 'Фото должно быть не больше 2 МБ.',
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
  ai_key_missing: 'Сначала задайте API-ключ выбранного провайдера.',
  invalid_ai_key: 'Ключ выглядит неполным: скопируйте его целиком (без пробелов).',
  ai_key_wrong_provider: 'Это ключ другого провайдера: ключи OpenAI начинаются с «sk-», ключи Claude — с «sk-ant-».',
  ai_key_in_use: 'Этот ключ сейчас используется. Выключите ИИ или выберите другого провайдера, затем удаляйте.',
  invalid_ai_model: 'Название модели указано неверно.',
  unknown_ai_provider: 'Неизвестный провайдер ИИ.',
  integration_incomplete: 'Заполните все поля выбранного режима, затем включайте интеграцию.',
  integration_enabled: 'Сначала выключите интеграцию, потом удаляйте ключ активного режима.',
  encryption_not_configured: 'На сервере не задан ключ шифрования (Integrations__EncryptionKey). Секреты и пароли терминалов сохранить нельзя.',
  invalid_field: 'Значение поля в неверном формате.',
  invalid_secret: 'Ключ в неверном формате: 8–256 символов без пробелов.',
  unknown_field: 'Это поле нельзя изменить таким способом.',
  freeze_in_past: 'Заморозка не может начинаться в прошлом.',
  freeze_too_long: 'Одна заморозка — не дольше 30 дней.',
  freeze_not_available: 'Заморозка доступна только для абонементов от 6 месяцев.',
  freeze_limit_reached: 'Все заморозки этого абонемента уже использованы.',
  media_invalid_format: 'Загрузите фото JPEG, PNG, WebP или видео MP4, MOV.',
  media_too_large: 'Фото — до 10 МБ, видео — до 100 МБ.',
  banner_media_limit: 'В баннере может быть не больше 20 фото и видео.',
  invalid_telegram: 'Telegram: 5–32 латинские буквы, цифры или «_», например @coach_aziz.',
  invalid_instagram: 'Instagram: до 30 латинских букв, цифр, точек или «_», например @coach.aziz.',
  freeze_outside_membership: 'Заморозка должна начинаться в период действия абонемента.',
  freeze_exists: 'У абонемента уже есть текущая или запланированная заморозка.',
  not_frozen: 'Абонемент не заморожен.',
  membership_not_active: 'Заморозить можно только действующий абонемент.',
  membership_expired: 'Абонемент уже закончился.',
  invalid_dates: 'Дата окончания раньше даты начала.',
  invalid_start_date: 'Дата начала должна быть не раньше сегодняшней и не дальше года.',
  membership_request_not_pending: 'Заявка уже обработана.',
  visit_undo_expired: 'Отменить можно только вход, отмеченный не более 15 минут назад.',
  concurrency_conflict: 'Настройки изменил кто-то другой. Обновите страницу и повторите.',
  face_consent_required: 'Отметьте согласие клиента на обработку фото лица.',
  face_invalid_format: 'Нужно фото в формате JPEG.',
  face_too_large: 'Фото должно быть не больше 200 КБ.',
  face_bad_size: 'Фото должно быть от 240 до 4096 пикселей по каждой стороне.',
  device_password_required: 'Укажите пароль учётной записи терминала.',
  invalid_device_address: 'Укажите IP-адрес или имя терминала, например 192.168.1.64.',
  device_inactive: 'Терминал выключен. Включите его в настройках, чтобы синхронизировать.',
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
