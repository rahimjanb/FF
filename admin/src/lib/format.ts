import type {
  Gender, MembershipEffectiveStatus, MembershipPlanType, TrainerRequestStatus, TrainingSessionStatus, UserStatus,
} from '../api/types'

const CLUB_TZ = 'Asia/Tashkent'

/** Date-only values (yyyy-mm-dd) are club-local dates and are shown as-is, without time zone shifts. */
export function fmtDate(value: string | null | undefined): string {
  if (!value) return '—'
  const [y, m, d] = value.slice(0, 10).split('-')
  return `${d}.${m}.${y}`
}

/** Instants are shown in the club time zone regardless of the admin's browser settings. */
export function fmtDateTime(value: string | null | undefined): string {
  if (!value) return '—'
  return new Intl.DateTimeFormat('ru-RU', {
    timeZone: CLUB_TZ, day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit',
  }).format(new Date(value))
}

export function fmtMoney(value: number): string {
  return new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 0 }).format(value) + ' сум'
}

export function fullName(p: { firstName: string; lastName: string }): string {
  return `${p.firstName} ${p.lastName}`.trim()
}

export function todayInClub(): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: CLUB_TZ }).format(new Date())
}

export const membershipStatusLabel: Record<MembershipEffectiveStatus, string> = {
  Active: 'Активен', Upcoming: 'Ещё не начался', Expired: 'Истёк', Exhausted: 'Посещения исчерпаны',
  Frozen: 'Заморожен', Cancelled: 'Отменён',
}

export const membershipStatusTone: Record<MembershipEffectiveStatus, Tone> = {
  Active: 'green', Upcoming: 'blue', Expired: 'gray', Exhausted: 'orange', Frozen: 'blue', Cancelled: 'red',
}

export const planTypeLabel: Record<MembershipPlanType, string> = { Unlimited: 'Безлимит', LimitedVisits: 'По посещениям' }

export const requestStatusLabel: Record<TrainerRequestStatus, string> = {
  Pending: 'Ожидает', Accepted: 'Принята', Rejected: 'Отклонена', Cancelled: 'Отменена',
}
export const requestStatusTone: Record<TrainerRequestStatus, Tone> = {
  Pending: 'orange', Accepted: 'green', Rejected: 'red', Cancelled: 'gray',
}

export const sessionStatusLabel: Record<TrainingSessionStatus, string> = {
  Scheduled: 'Запланирована', Completed: 'Проведена', Cancelled: 'Отменена',
}

export const userStatusLabel: Record<UserStatus, string> = { Active: 'Активен', Blocked: 'Заблокирован' }
export const genderLabel: Record<Gender, string> = { Male: 'Мужской', Female: 'Женский' }

export type Tone = 'green' | 'blue' | 'gray' | 'orange' | 'red'
