// Mirrors backend DTOs (FitnessFormulasi.Api.Features). Enums are serialized as strings.

export type Role = 'Admin' | 'Trainer' | 'Client'
export type UserStatus = 'Active' | 'Blocked'
export type Gender = 'Male' | 'Female'
export type MembershipPlanType = 'Unlimited' | 'LimitedVisits'
export type MembershipStatus = 'Active' | 'Frozen' | 'Cancelled'
export type MembershipEffectiveStatus = 'Upcoming' | 'Active' | 'Expired' | 'Exhausted' | 'Frozen' | 'Cancelled'
export type MembershipFilter = 'Active' | 'Upcoming' | 'Expired' | 'Exhausted' | 'Frozen' | 'Cancelled' | 'ExpiringSoon'
export type TrainerRequestStatus = 'Pending' | 'Accepted' | 'Rejected' | 'Cancelled'
export type TrainingSessionStatus = 'Scheduled' | 'Completed' | 'Cancelled'

export interface AuthUser {
  id: string; phone: string; phoneConfirmed: boolean; firstName: string; lastName: string; role: Role
  /** Password was set by staff or bootstrap config; the API allows only changing it until done. */
  mustChangePassword: boolean
}
export interface AuthResponse {
  accessToken: string; accessTokenExpiresAt: string; refreshToken: string; refreshTokenExpiresAt: string; user: AuthUser
}

export interface Paged<T> { items: T[]; page: number; pageSize: number; totalCount: number; totalPages: number }
export interface PersonRef { id: string; firstName: string; lastName: string }

export interface MembershipPlan {
  id: string; name: string; description: string | null; type: MembershipPlanType; durationDays: number
  visitLimit: number | null; price: number; isActive: boolean
}

export interface Membership {
  id: string; clientId: string; clientName: string; planId: string; planName: string; planType: MembershipPlanType
  startDate: string; endDate: string; status: MembershipStatus; effectiveStatus: MembershipEffectiveStatus
  visitLimit: number | null; visitsUsed: number; daysLeft: number; createdAt: string
}

export interface Client {
  id: string; userId: string; phone: string; phoneConfirmed: boolean; firstName: string; lastName: string
  email: string | null; birthDate: string | null; gender: Gender | null; notes: string | null; status: UserStatus
  assignedTrainer: PersonRef | null; currentMembership: Membership | null; createdAt: string
}

export interface Trainer {
  id: string; userId: string; phone: string; firstName: string; lastName: string; specialization: string | null
  bio: string | null; experienceYears: number | null; isAcceptingClients: boolean; isActive: boolean
  userStatus: UserStatus; clientsCount: number; createdAt: string
}

export interface TrainerRequest {
  id: string; status: TrainerRequestStatus; message: string | null; responseComment: string | null
  createdAt: string; respondedAt: string | null; trainer: PersonRef; client: PersonRef
}

export interface TrainingSession {
  id: string; startsAt: string; durationMinutes: number; status: TrainingSessionStatus; notes: string | null
  trainer: PersonRef; client: PersonRef
}

export interface Visit { id: string; visitedAt: string; source: string; clientId: string; clientName: string; membershipId: string | null }

export interface AdminDashboard {
  totalClients: number; newClientsThisMonth: number; activeMemberships: number; expiringSoon: number
  activeTrainers: number; pendingTrainerRequests: number; visitsToday: number; sessionsToday: number; today: string
}

export interface CountByKey { key: string; count: number }
export interface Report {
  from: string; to: string; newClients: number; membershipsAssigned: number; membershipsByPlan: CountByKey[]
  visits: number; visitsByDay: { date: string; count: number }[]; trainerRequestsByStatus: CountByKey[]
  sessionsByStatus: CountByKey[]
  trainers: { trainerId: string; name: string; clients: number; sessionsCompleted: number; requestsReceived: number }[]
}
