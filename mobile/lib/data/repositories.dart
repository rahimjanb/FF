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

  /// Ended, completed and cancelled sessions, most recent first, one page at a time.
  Future<Paged<TrainingSession>> sessionHistory({int page = 1}) async => Paged.fromJson(
    await _api.get('/api/me/training-sessions', query: {'scope': 'History', 'page': '$page', 'pageSize': '20'})
        as Map<String, dynamic>,
    TrainingSession.fromJson,
  );
}

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
