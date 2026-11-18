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
    this.planId = '',
    this.freezeStart,
    this.freezeEnd,
    this.freezesAllowed = 0,
    this.freezesUsed = 0,
  });
  factory Membership.fromJson(Map<String, dynamic> j) => Membership(
    id: j['id'] as String,
    clientName: j['clientName'] as String? ?? '',
    planId: j['planId'] as String? ?? '',
    planName: j['planName'] as String,
    planType: j['planType'] as String,
    startDate: _date(j['startDate'])!,
    endDate: _date(j['endDate'])!,
    effectiveStatus: _enum(MembershipEffectiveStatus.values, j['effectiveStatus']),
    visitLimit: j['visitLimit'] as int?,
    visitsUsed: j['visitsUsed'] as int,
    daysLeft: j['daysLeft'] as int,
    freezeStart: _date(j['freezeStartDate']),
    freezeEnd: _date(j['freezeEndDate']),
    freezesAllowed: j['freezesAllowed'] as int? ?? 0,
    freezesUsed: j['freezesUsed'] as int? ?? 0,
  );
  final String id, clientName, planId, planName, planType;

  /// Current or planned freeze; the end date already includes these days.
  final DateTime? freezeStart, freezeEnd;

  /// Freezes this membership may have in total (0: the plan is shorter than six months) and those already used.
  final int freezesAllowed, freezesUsed;

  /// Longest single freeze, enforced by the API (MembershipService.MaxFreezeDays).
  static const maxFreezeDays = 30;

  int get freezesLeft => (freezesAllowed - freezesUsed).clamp(0, freezesAllowed);
  bool get hasFreeze => freezeStart != null && freezeEnd != null;
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

/// first: no membership yet ("New" in the API); renew: the same plan after the current one; change: another plan.
enum MembershipRequestKind {
  first('New'),
  renew('Renew'),
  change('Change');

  const MembershipRequestKind(this.api);
  final String api;
}

enum MembershipRequestStatus { pending, completed, rejected, cancelled }

/// A plan the client asked for in the app; the club completes it after payment at the desk.
class MembershipRequest {
  MembershipRequest({
    required this.id,
    required this.kind,
    required this.status,
    required this.plan,
    required this.createdAt,
    this.responseComment,
  });
  factory MembershipRequest.fromJson(Map<String, dynamic> j) => MembershipRequest(
    id: j['id'] as String,
    kind: MembershipRequestKind.values.firstWhere((k) => k.api == j['kind'], orElse: () => MembershipRequestKind.first),
    status: _enum(MembershipRequestStatus.values, j['status']),
    plan: MembershipPlan.fromJson(j['plan'] as Map<String, dynamic>),
    createdAt: _dt(j['createdAt'])!,
    responseComment: j['responseComment'] as String?,
  );
  final String id;
  final MembershipRequestKind kind;
  final MembershipRequestStatus status;
  final MembershipPlan plan;
  final DateTime createdAt;
  final String? responseComment;
}

/// Short-lived QR pass. [refreshIn] is relative to the response, so the countdown does not rely on the phone clock.
class QrPass {
  QrPass({required this.code, required this.refreshIn, this.lastVisitAt});
  factory QrPass.fromJson(Map<String, dynamic> j) => QrPass(
    code: j['code'] as String,
    refreshIn: Duration(seconds: j['refreshInSeconds'] as int),
    lastVisitAt: _dt(j['lastVisitAt']),
  );
  final String code;
  final Duration refreshIn;
  final DateTime? lastVisitAt;
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
    this.contacts = TrainerContacts.none,
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
    contacts: TrainerContacts(j['telegram'] as String?, j['instagram'] as String?),
  );
  final String id, firstName, lastName;
  final String? specialization, bio;

  /// Path of the photo on the API (versioned), or null.
  final String? photoUrl;

  /// Filled only for the client's own trainer; the public list has no contacts.
  final TrainerContacts contacts;
  final int? experienceYears;
  final bool isAcceptingClients;
  String get fullName => '$firstName $lastName'.trim();
}

/// Telegram and Instagram usernames (without "@"). The client sees them after sending a request to the trainer.
class TrainerContacts {
  const TrainerContacts(this.telegram, this.instagram);
  static const none = TrainerContacts(null, null);
  final String? telegram, instagram;

  bool get isEmpty => (telegram ?? '').isEmpty && (instagram ?? '').isEmpty;
  Uri? get telegramUri => (telegram ?? '').isEmpty ? null : Uri.https('t.me', '/$telegram');
  Uri? get instagramUri => (instagram ?? '').isEmpty ? null : Uri.https('instagram.com', '/$instagram');
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
    this.trainerContacts = TrainerContacts.none,
  });
  factory TrainerRequest.fromJson(Map<String, dynamic> j) => TrainerRequest(
    id: j['id'] as String,
    status: _enum(TrainerRequestStatus.values, j['status']),
    message: j['message'] as String?,
    responseComment: j['responseComment'] as String?,
    createdAt: _dt(j['createdAt'])!,
    trainer: PersonRef.fromJson(j['trainer'] as Map<String, dynamic>),
    client: PersonRef.fromJson(j['client'] as Map<String, dynamic>),
    trainerContacts: TrainerContacts(j['trainerTelegram'] as String?, j['trainerInstagram'] as String?),
  );
  final String id;
  final TrainerRequestStatus status;
  final String? message, responseComment;
  final DateTime createdAt;
  final PersonRef trainer, client;
  final TrainerContacts trainerContacts;
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
    this.withoutTrainer = false,
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
    withoutTrainer: j['withoutTrainer'] as bool? ?? false,
  );
  final String firstName;

  /// The client chose to train on their own (only meaningful while no trainer is assigned).
  final bool withoutTrainer;
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
    this.withoutTrainer = false,
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
    withoutTrainer: j['withoutTrainer'] as bool? ?? false,
  );
  final String id, phone, firstName, lastName;
  final bool phoneConfirmed;
  final String? email, gender;
  final DateTime? birthDate;
  final Trainer? assignedTrainer;

  /// When the client signed up.
  final DateTime? memberSince;

  /// The client chose to train on their own (only meaningful while no trainer is assigned).
  final bool withoutTrainer;
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
  membershipFrozen,
  membershipUnfrozen,
  membershipRequestRejected,
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

enum BannerMediaKind { image, video }

class BannerMedia {
  BannerMedia({required this.id, required this.kind, required this.url});
  factory BannerMedia.fromJson(Map<String, dynamic> j) => BannerMedia(
    id: j['id'] as String,
    kind: _enum(BannerMediaKind.values, j['kind'], fallback: BannerMediaKind.image),
    url: j['url'] as String,
  );
  final String id;
  final BannerMediaKind kind;

  /// Path on the API, e.g. /api/banners/media/{id}.mp4.
  final String url;
}

/// Home screen banner set up by the club. [coverUrl] is the first photo; [media] opens on tap.
class PromoBanner {
  PromoBanner({required this.id, required this.title, this.description, this.coverUrl, this.media = const []});
  factory PromoBanner.fromJson(Map<String, dynamic> j) => PromoBanner(
    id: j['id'] as String,
    title: j['title'] as String,
    description: j['description'] as String?,
    coverUrl: j['coverUrl'] as String?,
    media: (j['media'] as List? ?? const []).map((e) => BannerMedia.fromJson(e as Map<String, dynamic>)).toList(),
  );
  final String id, title;
  final String? description, coverUrl;
  final List<BannerMedia> media;

  bool get hasVideo => media.any((m) => m.kind == BannerMediaKind.video);
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

/// Entry through the turnstile by face (Hikvision terminal). none: no photo; waiting: saved, but not on the
/// terminal (no membership to enter with, or no terminal connected); pending: being sent; ready: entry by face works;
/// rejected: the terminal found no face in the photo.
enum FaceAccessStatus { none, waiting, pending, ready, rejected }

class FaceAccess {
  const FaceAccess({
    required this.status,
    this.version = 0,
    this.uploadedAt,
    this.hasAccess = false,
    this.accessFrom,
    this.accessTo,
    this.terminals = 0,
  });
  factory FaceAccess.fromJson(Map<String, dynamic> j) => FaceAccess(
    status: _enum(FaceAccessStatus.values, j['status'], fallback: FaceAccessStatus.waiting),
    version: j['version'] as int? ?? 0,
    uploadedAt: j['uploadedAt'] == null ? null : DateTime.parse(j['uploadedAt'] as String),
    hasAccess: j['hasAccess'] as bool? ?? false,
    accessFrom: _date(j['accessFrom']),
    accessTo: _date(j['accessTo']),
    terminals: j['terminals'] as int? ?? 0,
  );
  final FaceAccessStatus status;

  /// Bumped on every new photo; part of the preview cache key.
  final int version;
  final DateTime? uploadedAt;

  /// The client has a current or upcoming membership; [accessFrom]..[accessTo] are the days the terminal lets them in.
  final bool hasAccess;
  final DateTime? accessFrom, accessTo;

  /// Terminals connected in the club.
  final int terminals;

  bool get hasPhoto => status != FaceAccessStatus.none;
}

T? _opt<T>(Object? v, T Function(Map<String, dynamic>) f) => v == null ? null : f(v as Map<String, dynamic>);

T _enum<T extends Enum>(List<T> values, Object? raw, {T? fallback}) {
  final s = (raw as String?)?.toLowerCase();
  return values.firstWhere(
    (v) => v.name.toLowerCase() == s,
    orElse: () => fallback ?? (throw FormatException('Unknown value $raw')),
  );
}
