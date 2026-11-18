import 'dart:typed_data';

import '../core/api_client.dart';
import 'models.dart';

/// All network access goes through these repositories; screens never build URLs themselves.
class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<AuthUser> login(String phone, String password) =>
      _auth(_api.post('/api/auth/login', {'phone': phone, 'password': password}));

  Future<AuthUser> register({
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
  }) => _auth(
    _api.post('/api/auth/register', {
      'phone': phone,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
    }),
  );

  /// Returns the updated user; the server issues a new token pair and signs out other devices.
  Future<AuthUser> changePassword(String current, String next) =>
      _auth(_api.post('/api/auth/change-password', {'currentPassword': current, 'newPassword': next}));

  Future<AuthUser> me() async => AuthUser.fromJson(await _api.get('/api/auth/me') as Map<String, dynamic>);

  Future<void> logout() async {
    final refresh = await _api.tokens.refreshToken();
    if (refresh != null) {
      try {
        await _api.post('/api/auth/logout', {'refreshToken': refresh});
      } catch (_) {
        // Local sign-out proceeds even if the server is unreachable.
      }
    }
    await _api.tokens.clear();
  }

  /// Deletes the client's own account (personal data is erased on the server). The server has already ended every
  /// session, so only the local tokens are cleared; no logout call is needed.
  Future<void> deleteAccount(String password) async {
    await _api.post('/api/me/delete-account', {'password': password});
    await _api.tokens.clear();
  }

  Future<AuthUser> _auth(Future<dynamic> call) async {
    final json = await call as Map<String, dynamic>;
    await _api.tokens.save(json['accessToken'] as String, json['refreshToken'] as String);
    return AuthUser.fromJson(json['user'] as Map<String, dynamic>);
  }
}

class ClientRepository {
  ClientRepository(this._api);
  final ApiClient _api;

  Future<ClientDashboard> dashboard() async =>
      ClientDashboard.fromJson(await _api.get('/api/me/dashboard') as Map<String, dynamic>);

  Future<List<Membership>> memberships() async => (await _api.get('/api/me/memberships') as List)
      .map((e) => Membership.fromJson(e as Map<String, dynamic>))
      .toList();

  /// Plans currently on sale (read-only; purchase is at the club desk in stage 1).
  Future<List<MembershipPlan>> plans() async =>
      (await _api.get('/api/me/plans') as List).map((e) => MembershipPlan.fromJson(e as Map<String, dynamic>)).toList();

  Future<QrPass> pass() async => QrPass.fromJson(await _api.get('/api/me/pass') as Map<String, dynamic>);

  Future<List<MembershipRequest>> membershipRequests() async => (await _api.get('/api/me/membership-requests') as List)
      .map((e) => MembershipRequest.fromJson(e as Map<String, dynamic>))
      .toList();

  /// Asks the club for [planId]; staff complete it after payment at the desk.
  Future<MembershipRequest> requestMembership(String planId, MembershipRequestKind kind) async =>
      MembershipRequest.fromJson(
        await _api.post('/api/me/membership-requests', {'planId': planId, 'kind': kind.api}) as Map<String, dynamic>,
      );

  Future<void> cancelMembershipRequest(String id) => _api.post('/api/me/membership-requests/$id/cancel');

  /// Freezes the client's own membership for the club-local days [from]..[to] (inclusive).
  Future<Membership> freezeMembership(String id, DateTime from, DateTime to) async => Membership.fromJson(
    await _api.post('/api/me/memberships/$id/freeze', {'startDate': _day(from), 'endDate': _day(to)})
        as Map<String, dynamic>,
  );

  /// Ends the current freeze today or cancels a planned one.
  Future<Membership> unfreezeMembership(String id) async =>
      Membership.fromJson(await _api.post('/api/me/memberships/$id/unfreeze') as Map<String, dynamic>);

  /// Banners shown at the top of the home screen.
  Future<List<PromoBanner>> banners() async =>
      (await _api.get('/api/banners') as List).map((e) => PromoBanner.fromJson(e as Map<String, dynamic>)).toList();

  /// The client trains on their own; pending trainer requests are withdrawn.
  Future<ClientProfile> trainWithoutTrainer() async =>
      ClientProfile.fromJson(await _api.post('/api/me/without-trainer') as Map<String, dynamic>);

  /// Entry by face through the turnstile: whether the photo is on the terminals and for which days.
  Future<FaceAccess> faceAccess() async => FaceAccess.fromJson(await _api.get('/api/me/face') as Map<String, dynamic>);

  /// The client's own face photo (JPEG).
  Future<Uint8List> facePhoto() => _api.getBytes('/api/me/face/photo');

  /// Uploads the face photo (JPEG up to 200 KB) with the client's consent to its processing for entry.
  Future<FaceAccess> uploadFace(Uint8List jpeg) async => FaceAccess.fromJson(
    await _api.putMultipart(
      '/api/me/face',
      fields: {'consent': 'true'},
      files: [UploadFile('file', jpeg, filename: 'face.jpg', contentType: 'image/jpeg')],
    ) as Map<String, dynamic>,
  );

  /// Deletes the photo; the client is removed from the turnstile.
  Future<FaceAccess> deleteFace() async =>
      FaceAccess.fromJson(await _api.delete('/api/me/face') as Map<String, dynamic>);

  Future<ClientProfile> profile() async =>
      ClientProfile.fromJson(await _api.get('/api/me/profile') as Map<String, dynamic>);

  Future<ClientProfile> updateProfile(ProfileUpdate update) async =>
      ClientProfile.fromJson(await _api.put('/api/me/profile', update.toJson()) as Map<String, dynamic>);

  Future<List<Trainer>> trainers() async =>
      (await _api.get('/api/trainers') as List).map((e) => Trainer.fromJson(e as Map<String, dynamic>)).toList();

  Future<List<TrainerRequest>> trainerRequests() async => (await _api.get('/api/me/trainer-requests') as List)
      .map((e) => TrainerRequest.fromJson(e as Map<String, dynamic>))
      .toList();

  Future<TrainerRequest> requestTrainer(String trainerId, String? message) async => TrainerRequest.fromJson(
    await _api.post('/api/me/trainer-requests', {'trainerId': trainerId, 'message': message}) as Map<String, dynamic>,
  );

  Future<void> cancelRequest(String id) => _api.post('/api/me/trainer-requests/$id/cancel');

  /// Scheduled sessions that have not ended yet, soonest first. One page of 100 is enough: trainers schedule
  /// individual sessions at most 120 days ahead, so a client cannot realistically have more pending.
  Future<List<TrainingSession>> upcomingSessions() async => Paged.fromJson(
    await _api.get('/api/me/training-sessions', query: {'scope': 'Upcoming', 'pageSize': '100'})
        as Map<String, dynamic>,
    TrainingSession.fromJson,
  ).items;

  /// Times of the latest visits, newest first (one page of 50 — enough for the weekly chart on Home).
  Future<List<DateTime>> recentVisitTimes() async =>
      ((await _api.get('/api/me/visits', query: {'pageSize': '50'}) as Map<String, dynamic>)['items'] as List)
          .map((e) => DateTime.parse((e as Map<String, dynamic>)['visitedAt'] as String))
          .toList();

  /// Ended, completed and cancelled sessions, most recent first, one page at a time.
  Future<Paged<TrainingSession>> sessionHistory({int page = 1}) async => Paged.fromJson(
    await _api.get('/api/me/training-sessions', query: {'scope': 'History', 'page': '$page', 'pageSize': '20'})
        as Map<String, dynamic>,
    TrainingSession.fromJson,
  );
}

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class NotificationRepository {
  NotificationRepository(this._api);
  final ApiClient _api;

  Future<Paged<AppNotification>> list({int page = 1}) async => Paged.fromJson(
    await _api.get('/api/notifications', query: {'page': '$page', 'pageSize': '30'}) as Map<String, dynamic>,
    AppNotification.fromJson,
  );

  Future<void> markAllRead() => _api.post('/api/notifications/read-all');
}

class TrainerRepository {
  TrainerRepository(this._api);
  final ApiClient _api;

  Future<TrainerSelfProfile> profile() async =>
      TrainerSelfProfile.fromJson(await _api.get('/api/trainer/profile') as Map<String, dynamic>);

  Future<TrainerSelfProfile> updateProfile({
    String? specialization,
    String? bio,
    required bool isAcceptingClients,
  }) async => TrainerSelfProfile.fromJson(
    await _api.put('/api/trainer/profile', {
      'specialization': specialization,
      'bio': bio,
      'isAcceptingClients': isAcceptingClients,
    }) as Map<String, dynamic>,
  );

  /// Requests, newest first. Without [status] the list mixes pending and processed ones.
  Future<Paged<TrainerRequest>> requests({TrainerRequestStatus? status, int page = 1, int pageSize = 30}) async =>
      Paged.fromJson(
        await _api.get(
          '/api/trainer/requests',
          query: {'status': status?.name, 'page': '$page', 'pageSize': '$pageSize'},
        ) as Map<String, dynamic>,
        TrainerRequest.fromJson,
      );

  /// Every pending request, so none is hidden behind newer processed ones. At most one per client, read 100 at a time.
  Future<List<TrainerRequest>> allPendingRequests() async {
    final all = <TrainerRequest>[];
    for (var page = 1; ; page++) {
      final p = await requests(status: TrainerRequestStatus.pending, page: page, pageSize: 100);
      all.addAll(p.items);
      if (p.items.isEmpty || page >= p.totalPages) return all;
    }
  }

  Future<void> respond(String id, {required bool accept, String? comment}) =>
      _api.post('/api/trainer/requests/$id/${accept ? 'accept' : 'reject'}', {'comment': comment});

  Future<Paged<TrainerClient>> clients({int page = 1, int pageSize = 30}) async => Paged.fromJson(
    await _api.get('/api/trainer/clients', query: {'page': '$page', 'pageSize': '$pageSize'}) as Map<String, dynamic>,
    TrainerClient.fromJson,
  );

  /// Every assigned client, for the client picker. Bounded by one trainer's client count, read 100 at a time.
  Future<List<TrainerClient>> allClients() async {
    final all = <TrainerClient>[];
    for (var page = 1; ; page++) {
      final p = await clients(page: page, pageSize: 100);
      all.addAll(p.items);
      if (p.items.isEmpty || page >= p.totalPages) return all;
    }
  }

  Future<List<TrainingSession>> sessions() async => (await _api.get('/api/trainer/sessions') as List)
      .map((e) => TrainingSession.fromJson(e as Map<String, dynamic>))
      .toList();

  Future<void> createSession({
    required String clientId,
    required DateTime startsAtUtc,
    required int durationMinutes,
    String? notes,
  }) => _api.post('/api/trainer/sessions', {
    'clientId': clientId,
    'startsAt': startsAtUtc.toUtc().toIso8601String(),
    'durationMinutes': durationMinutes,
    'notes': notes,
  });

  Future<void> setSessionStatus(String id, {required bool completed}) =>
      _api.post('/api/trainer/sessions/$id/${completed ? 'complete' : 'cancel'}');
}
