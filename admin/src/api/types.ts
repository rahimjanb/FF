// Mirrors backend DTOs (FitnessFormulasi.Api.Features). Enums are serialized as strings.

export type Role = 'Admin' | 'Trainer' | 'Client'
export type UserStatus = 'Active' | 'Blocked' | 'Deleted'
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
  /** Administrator allowed to view and change payment integrations. */
  canManageIntegrations: boolean
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
  /** Current or planned freeze (club-local dates); past freezes are already part of the end date. */
  freezeStartDate: string | null; freezeEndDate: string | null
  /** Freezes the membership may have in total (0: plan shorter than six months) and those already used. */
  freezesAllowed: number; freezesUsed: number
}

export type MembershipRequestKind = 'New' | 'Renew' | 'Change'
export type MembershipRequestStatus = 'Pending' | 'Completed' | 'Rejected' | 'Cancelled'
export interface MembershipRequest {
  id: string; kind: MembershipRequestKind; status: MembershipRequestStatus; responseComment: string | null
  createdAt: string; respondedAt: string | null; membershipId: string | null; plan: MembershipPlan
  client: PersonRef; clientPhone: string
}
export interface MembershipRequestAdmin {
  request: MembershipRequest; currentMembership: Membership | null; suggestedStartDate: string | null
}

export interface CheckInResult {
  allowed: boolean; reason: string | null; repeated: boolean
  client: { id: string; firstName: string; lastName: string; phone: string; assignedTrainer: PersonRef | null } | null
  membership: Membership | null; visit: Visit | null; visitsToday: number; previousVisitAt: string | null
}

export interface Client {
  id: string; userId: string; phone: string; phoneConfirmed: boolean; firstName: string; lastName: string
  email: string | null; birthDate: string | null; gender: Gender | null; notes: string | null; status: UserStatus
  assignedTrainer: PersonRef | null; currentMembership: Membership | null; createdAt: string
  /** The client chose in the app to train without a trainer. */
  withoutTrainer: boolean
  /** Set when the account was deleted (by the client in the app or by staff on request); personal data is gone. */
  deletedAt: string | null
}

export interface Trainer {
  id: string; userId: string; phone: string; firstName: string; lastName: string; specialization: string | null
  bio: string | null; experienceYears: number | null; isAcceptingClients: boolean; isActive: boolean
  userStatus: UserStatus; clientsCount: number; createdAt: string; photoUrl: string | null
  /** Usernames without "@"; a client sees them after sending a request to the trainer. */
  telegram: string | null; instagram: string | null
}

export interface TrainerRequest {
  id: string; status: TrainerRequestStatus; message: string | null; responseComment: string | null
  createdAt: string; respondedAt: string | null; trainer: PersonRef; client: PersonRef
}

export type BannerMediaKind = 'Image' | 'Video'
export interface BannerMedia { id: string; kind: BannerMediaKind; contentType: string; sizeBytes: number; url: string }
/** Home screen banner of the client app. `coverUrl` is the first photo of `media`. */
export interface Banner {
  id: string; title: string; description: string | null; isActive: boolean; sortOrder: number
  coverUrl: string | null; media: BannerMedia[]; createdAt: string; updatedAt: string
}

export interface TrainingSession {
  id: string; startsAt: string; durationMinutes: number; status: TrainingSessionStatus; notes: string | null
  trainer: PersonRef; client: PersonRef
}

export type VisitSource = 'Manual' | 'QrScan' | 'FaceTerminal'
export interface Visit { id: string; visitedAt: string; source: VisitSource; clientId: string; clientName: string; membershipId: string | null }

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

export type IntegrationProvider = 'Click' | 'Payme'
export type IntegrationMode = 'Test' | 'Production'
export type IntegrationStatus = 'NotConfigured' | 'Configured' | 'NeedsVerification' | 'Active'

/** Secrets never come from the API: only whether one is set and a fixed mask. */
export interface IntegrationSecretState { isSet: boolean; isReadable: boolean; mask: string | null; updatedAt: string | null }
export interface IntegrationModeState {
  values: Record<string, string | null>; secrets: Record<string, IntegrationSecretState>; missingFields: string[]
}
export interface Integration {
  provider: IntegrationProvider; status: IntegrationStatus; isEnabled: boolean; mode: IntegrationMode
  fields: { name: string; isSecret: boolean }[]; test: IntegrationModeState; production: IntegrationModeState
  updatedAt: string | null; updatedBy: string | null; lastVerifiedAt: string | null; encryptionConfigured: boolean; version: number
}
export interface AuditEntry { createdAt: string; action: string; target: string; details: string | null; userName: string | null }

// ---- Face entry through Hikvision terminals ----

/**
 * None: no photo. Waiting: saved, but not on the terminals (no membership days, or no terminal yet). Pending: being
 * sent. Ready: on every terminal. Rejected: a terminal found no face in the photo.
 */
export type FaceAccessStatus = 'None' | 'Waiting' | 'Pending' | 'Ready' | 'Rejected'
export type AccessSyncState = 'Pending' | 'Synced' | 'Failed' | 'PhotoRejected'

export interface FaceDeviceState { deviceId: string; deviceName: string; state: AccessSyncState; lastError: string | null; syncedAt: string | null }
export interface FaceAccessAdmin {
  status: FaceAccessStatus; version: number; uploadedAt: string | null; hasAccess: boolean; accessFrom: string | null; accessTo: string | null
  terminals: number; accessNo: number | null; consentAt: string | null; uploadedBy: string | null; devices: FaceDeviceState[]
}

export interface AccessDeviceStats { planned: number; synced: number; pending: number; failed: number; photoRejected: number }
/** The device password never comes from the API, only whether it is set. */
export interface AccessDevice {
  id: string; name: string; baseUrl: string; username: string; hasPassword: boolean; isActive: boolean; recordsVisits: boolean
  doorNo: number; eventPath: string; model: string | null; serialNumber: string | null; firmware: string | null
  lastContactAt: string | null; lastEventAt: string | null; lastError: string | null; lastErrorAt: string | null
  stats: AccessDeviceStats; encryptionConfigured: boolean
}
export interface AccessDeviceCheck {
  ok: boolean; error: string | null; clockSkewSeconds: number | null; timeZoneMatches: boolean | null; device: AccessDevice
}
export interface AccessSyncReport { written: number; facesUploaded: number; removed: number; failed: number; remaining: number; deviceError: string | null }
export interface AccessSyncResult { report: AccessSyncReport; device: AccessDevice }
export interface AccessIssue {
  clientId: string; clientName: string; employeeNo: string; state: AccessSyncState; lastError: string | null
  failedAttempts: number; retryAt: string | null
}
export interface AccessEvent {
  id: string; occurredAt: string; deviceId: string | null; deviceName: string; granted: boolean; minor: number
  employeeNo: string | null; client: PersonRef | null; visitId: string | null; note: string | null
}
