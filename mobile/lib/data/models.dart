// DTOs mirroring the backend (FitnessFormulasi.Api.Features). Enum values arrive as strings.

DateTime? _dt(Object? v) => v == null ? null : DateTime.parse(v as String);

/// Parses a club-local date (yyyy-MM-dd) as a calendar date without time zone conversion.
DateTime? _date(Object? v) {
  if (v == null) return null;
  final p = (v as String).split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String _dateOut(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class AuthUser {
  AuthUser({
    required this.id,
    required this.phone,
    required this.phoneConfirmed,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.mustChangePassword = false,
  });
  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    id: j['id'] as String,
    phone: j['phone'] as String,
    phoneConfirmed: j['phoneConfirmed'] as bool,
    firstName: j['firstName'] as String,
    lastName: j['lastName'] as String,
    role: j['role'] as String,
    mustChangePassword: j['mustChangePassword'] as bool? ?? false,
  );
  final String id, phone, firstName, lastName, role;
  final bool phoneConfirmed;

  /// The password was set by club staff and must be replaced before the app can be used.
  final bool mustChangePassword;
}

class PersonRef {
  PersonRef(this.id, this.firstName, this.lastName);
  factory PersonRef.fromJson(Map<String, dynamic> j) =>
      PersonRef(j['id'] as String, j['firstName'] as String, j['lastName'] as String);
  final String id, firstName, lastName;
  String get fullName => '$firstName $lastName'.trim();
}

enum MembershipEffectiveStatus { upcoming, active, expired, exhausted, frozen, cancelled }

class Membership {
  Membership({
    required this.id,
    required this.clientName,
    required this.planName,
    required this.planType,
    required this.startDate,
    required this.endDate,
    required this.effectiveStatus,
    required this.visitLimit,
    required this.visitsUsed,
    required this.daysLeft,
  });
  factory Membership.fromJson(Map<String, dynamic> j) => Membership(
    id: j['id'] as String,
    clientName: j['clientName'] as String? ?? '',
    planName: j['planName'] as String,
    planType: j['planType'] as String,
    startDate: _date(j['startDate'])!,
    endDate: _date(j['endDate'])!,
    effectiveStatus: _enum(MembershipEffectiveStatus.values, j['effectiveStatus']),
    visitLimit: j['visitLimit'] as int?,
    visitsUsed: j['visitsUsed'] as int,
    daysLeft: j['daysLeft'] as int,
  );
  final String id, clientName, planName, planType;
  final DateTime startDate, endDate;
  final MembershipEffectiveStatus effectiveStatus;
  final int? visitLimit;
  final int visitsUsed, daysLeft;

  bool get isUnlimited => planType == 'Unlimited';

  /// Usable today (not upcoming, expired, exhausted, frozen or cancelled).
  bool get isUsable => effectiveStatus == MembershipEffectiveStatus.active;
  int get totalDays => endDate.difference(startDate).inDays + 1;
}

/// A plan on sale. [price] is in UZS for the whole [durationDays].
class MembershipPlan {
  MembershipPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.durationDays,
    required this.visitLimit,
    required this.price,
  });
  factory MembershipPlan.fromJson(Map<String, dynamic> j) => MembershipPlan(
    id: j['id'] as String,
    name: j['name'] as String,
    description: j['description'] as String?,
    type: j['type'] as String,
    durationDays: j['durationDays'] as int,
    visitLimit: j['visitLimit'] as int?,
    price: (j['price'] as num).toDouble(),
  );
  final String id, name, type;
  final String? description;
  final int durationDays;
  final int? visitLimit;
  final double price;

  bool get isUnlimited => type == 'Unlimited';
}

class Trainer {
  Trainer({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.specialization,
    this.bio,
    this.experienceYears,
    required this.isAcceptingClients,
    this.photoUrl,
  });
  factory Trainer.fromJson(Map<String, dynamic> j) => Trainer(
    id: j['id'] as String,
    firstName: j['firstName'] as String,
    lastName: j['lastName'] as String,
    specialization: j['specialization'] as String?,
    bio: j['bio'] as String?,
    experienceYears: j['experienceYears'] as int?,
    isAcceptingClients: j['isAcceptingClients'] as bool,
    photoUrl: j['photoUrl'] as String?,
  );
  final String id, firstName, lastName;
  final String? specialization, bio;

  /// Path of the photo on the API (versioned), or null.
  final String? photoUrl;
  final int? experienceYears;
  final bool isAcceptingClients;
  String get fullName => '$firstName $lastName'.trim();
}

enum TrainerRequestStatus { pending, accepted, rejected, cancelled }

class TrainerRequest {
  TrainerRequest({
    required this.id,
    required this.status,
    this.message,
    this.responseComment,
    required this.createdAt,
    required this.trainer,
    required this.client,
  });
  factory TrainerRequest.fromJson(Map<String, dynamic> j) => TrainerRequest(
    id: j['id'] as String,
    status: _enum(TrainerRequestStatus.values, j['status']),
    message: j['message'] as String?,
    responseComment: j['responseComment'] as String?,
    createdAt: _dt(j['createdAt'])!,
    trainer: PersonRef.fromJson(j['trainer'] as Map<String, dynamic>),
    client: PersonRef.fromJson(j['client'] as Map<String, dynamic>),
  );
  final String id;
  final TrainerRequestStatus status;
  final String? message, responseComment;
  final DateTime createdAt;
  final PersonRef trainer, client;
}

enum TrainingSessionStatus { scheduled, completed, cancelled }

class TrainingSession {
  TrainingSession({
    required this.id,
    required this.startsAt,
    required this.durationMinutes,
    required this.status,
    this.notes,
    required this.trainer,
    required this.client,
  });
  factory TrainingSession.fromJson(Map<String, dynamic> j) => TrainingSession(
    id: j['id'] as String,
    startsAt: _dt(j['startsAt'])!,
    durationMinutes: j['durationMinutes'] as int,
    status: _enum(TrainingSessionStatus.values, j['status']),
    notes: j['notes'] as String?,
    trainer: PersonRef.fromJson(j['trainer'] as Map<String, dynamic>),
    client: PersonRef.fromJson(j['client'] as Map<String, dynamic>),
  );
  final String id;
  final DateTime startsAt;
  final int durationMinutes;
  final TrainingSessionStatus status;
  final String? notes;
  final PersonRef trainer, client;

  DateTime get endsAt => startsAt.add(Duration(minutes: durationMinutes));

  /// Scheduled but already over and not marked by the trainer.
  bool hasEndedUnmarked(DateTime now) => status == TrainingSessionStatus.scheduled && !endsAt.isAfter(now);
}

class VisitStats {
  VisitStats(this.thisMonth, this.total, this.lastVisitAt);
  factory VisitStats.fromJson(Map<String, dynamic> j) =>
      VisitStats(j['thisMonth'] as int, j['total'] as int, _dt(j['lastVisitAt']));
  final int thisMonth, total;
  final DateTime? lastVisitAt;
}

class ClientDashboard {
  ClientDashboard({
    required this.firstName,
    this.currentMembership,
    this.nextMembership,
    this.nextSession,
    this.trainer,
    required this.visits,
    this.pendingTrainerRequest,
    required this.unreadNotifications,
  });
  factory ClientDashboard.fromJson(Map<String, dynamic> j) => ClientDashboard(
    firstName: j['firstName'] as String,
    currentMembership: _opt(j['currentMembership'], Membership.fromJson),
    nextMembership: _opt(j['nextMembership'], Membership.fromJson),
    nextSession: _opt(j['nextSession'], TrainingSession.fromJson),
    trainer: _opt(j['trainer'], Trainer.fromJson),
    visits: VisitStats.fromJson(j['visits'] as Map<String, dynamic>),
    pendingTrainerRequest: _opt(j['pendingTrainerRequest'], TrainerRequest.fromJson),
    unreadNotifications: j['unreadNotifications'] as int,
  );
  final String firstName;
  final Membership? currentMembership, nextMembership;
  final TrainingSession? nextSession;
  final Trainer? trainer;
  final VisitStats visits;
  final TrainerRequest? pendingTrainerRequest;
  final int unreadNotifications;
}

class ClientProfile {
  ClientProfile({
    required this.id,
    required this.phone,
    required this.phoneConfirmed,
    required this.firstName,
    required this.lastName,
    this.email,
    this.birthDate,
    this.gender,
    this.assignedTrainer,
    this.memberSince,
  });
  factory ClientProfile.fromJson(Map<String, dynamic> j) => ClientProfile(
    id: j['id'] as String,
    phone: j['phone'] as String,
    phoneConfirmed: j['phoneConfirmed'] as bool,
    firstName: j['firstName'] as String,
    lastName: j['lastName'] as String,
    email: j['email'] as String?,
    birthDate: _date(j['birthDate']),
    gender: j['gender'] as String?,
    assignedTrainer: _opt(j['assignedTrainer'], Trainer.fromJson),
    memberSince: _dt(j['memberSince']),
  );
  final String id, phone, firstName, lastName;
  final bool phoneConfirmed;
  final String? email, gender;
  final DateTime? birthDate;
  final Trainer? assignedTrainer;

  /// When the client signed up.
  final DateTime? memberSince;
}

class ProfileUpdate {
  ProfileUpdate({required this.firstName, required this.lastName, this.email, this.birthDate, this.gender});
  final String firstName, lastName;
  final String? email, gender;
  final DateTime? birthDate;
  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'birthDate': birthDate == null ? null : _dateOut(birthDate!),
    'gender': gender,
  };
}

enum NotificationType {
  trainerRequestReceived,
  trainerRequestAccepted,
  trainerRequestRejected,
  trainingSessionScheduled,
  trainingSessionCancelled,
  membershipAssigned,
  unknown,
}

class AppNotification {
  AppNotification({required this.id, required this.type, this.payload, required this.isRead, required this.createdAt});
  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    type: _enum(NotificationType.values, j['type'], fallback: NotificationType.unknown),
    payload: j['payload'] as String?,
    isRead: j['isRead'] as bool,
    createdAt: _dt(j['createdAt'])!,
  );
  final String id;
  final NotificationType type;
  final String? payload;
  final bool isRead;
  final DateTime createdAt;
}

class TrainerSelfProfile {
  TrainerSelfProfile({
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.specialization,
    this.bio,
    this.experienceYears,
    required this.isAcceptingClients,
    required this.clientsCount,
    this.photoUrl,
  });
  factory TrainerSelfProfile.fromJson(Map<String, dynamic> j) => TrainerSelfProfile(
    firstName: j['firstName'] as String,
    lastName: j['lastName'] as String,
    phone: j['phone'] as String,
    specialization: j['specialization'] as String?,
    bio: j['bio'] as String?,
    experienceYears: j['experienceYears'] as int?,
    isAcceptingClients: j['isAcceptingClients'] as bool,
    clientsCount: j['clientsCount'] as int,
    photoUrl: j['photoUrl'] as String?,
  );
  final String firstName, lastName, phone;
  final String? specialization, bio, photoUrl;
  final int? experienceYears;
  final bool isAcceptingClients;
  final int clientsCount;
  String get fullName => '$firstName $lastName'.trim();
}

class TrainerClient {
  TrainerClient({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.birthDate,
    this.currentMembership,
    this.lastVisitAt,
  });
  factory TrainerClient.fromJson(Map<String, dynamic> j) => TrainerClient(
    id: j['id'] as String,
    firstName: j['firstName'] as String,
    lastName: j['lastName'] as String,
    phone: j['phone'] as String,
    birthDate: _date(j['birthDate']),
    currentMembership: _opt(j['currentMembership'], Membership.fromJson),
    lastVisitAt: _dt(j['lastVisitAt']),
  );
  final String id, firstName, lastName, phone;
  final DateTime? birthDate, lastVisitAt;
  final Membership? currentMembership;
  String get fullName => '$firstName $lastName'.trim();
}

class Paged<T> {
  Paged(this.items, this.page, this.totalPages, this.totalCount);
  factory Paged.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic>) item) => Paged(
    (j['items'] as List).map((e) => item(e as Map<String, dynamic>)).toList(),
    j['page'] as int,
    j['totalPages'] as int,
    j['totalCount'] as int,
  );
  final List<T> items;
  final int page, totalPages, totalCount;
}

T? _opt<T>(Object? v, T Function(Map<String, dynamic>) f) => v == null ? null : f(v as Map<String, dynamic>);

T _enum<T extends Enum>(List<T> values, Object? raw, {T? fallback}) {
  final s = (raw as String?)?.toLowerCase();
  return values.firstWhere(
    (v) => v.name.toLowerCase() == s,
    orElse: () => fallback ?? (throw FormatException('Unknown value $raw')),
  );
}
