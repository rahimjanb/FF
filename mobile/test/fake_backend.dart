import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// TEST-ONLY fake of the backend HTTP API. Lives under test/ and is never bundled into the app.
class FakeBackend {
  final requests = <http.Request>[];
  String accessToken = 'access-1';
  bool expireNextAccess = false;
  bool loggedIn = false;
  bool mustChangePassword = false;
  String password = 'Secret123';

  static Map<String, dynamic> user(String role, {bool mustChange = false}) => {
    'id': 'u1',
    'phone': '+998901234567',
    'phoneConfirmed': false,
    'firstName': 'Aziz',
    'lastName': 'Karimov',
    'role': role,
    'mustChangePassword': mustChange,
  };

  static Map<String, dynamic> membership({String status = 'Active', int daysLeft = 12}) => {
    'id': 'm1',
    'clientId': 'c1',
    'clientName': 'Aziz Karimov',
    'planId': 'p1',
    'planName': 'Gold 30',
    'planType': 'Unlimited',
    'startDate': '2026-10-05',
    'endDate': '2026-11-03',
    'status': 'Active',
    'effectiveStatus': status,
    'visitLimit': null,
    'visitsUsed': 3,
    'daysLeft': daysLeft,
    'createdAt': '2026-10-05T07:00:00Z',
  };

  static Map<String, dynamic> dashboard() => {
    'firstName': 'Aziz',
    'currentMembership': membership(),
    'nextMembership': null,
    'nextSession': null,
    'trainer': null,
    'visits': {'thisMonth': 4, 'total': 17, 'lastVisitAt': '2026-10-20T13:00:00Z'},
    'pendingTrainerRequest': null,
    'unreadNotifications': 2,
  };

  String role = 'Client';

  /// Per-test responses: path -> JSON body, or an [http.Response] (e.g. an error).
  final routes = <String, Object Function(http.Request)>{};
  final calls = <String, int>{};

  MockClient get client => MockClient((req) async {
    requests.add(req);
    final auth = req.headers['Authorization'];
    http.Response json(Object body, [int status = 200]) =>
        http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});
    http.Response problem(int status, String code) => json({'title': code, 'status': status, 'code': code}, status);

    switch (req.url.path) {
      case '/api/auth/login':
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        if (body['password'] != password) return problem(401, 'invalid_credentials');
        loggedIn = true;
        return json({
          'accessToken': accessToken,
          'accessTokenExpiresAt': '',
          'refreshToken': 'refresh-1',
          'refreshTokenExpiresAt': '',
          'user': user(role, mustChange: mustChangePassword),
        });
      case '/api/auth/refresh':
        if (jsonDecode(req.body)['refreshToken'] != 'refresh-1') return problem(401, 'invalid_refresh_token');
        accessToken = 'access-2';
        return json({
          'accessToken': accessToken,
          'accessTokenExpiresAt': '',
          'refreshToken': 'refresh-1',
          'refreshTokenExpiresAt': '',
          'user': user(role),
        });
    }
    if (expireNextAccess && auth == 'Bearer access-1') {
      expireNextAccess = false;
      return problem(401, 'unauthorized');
    }
    if (!loggedIn || auth != 'Bearer $accessToken') return problem(401, 'unauthorized');
    if (req.url.path == '/api/auth/change-password') {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      if (body['currentPassword'] != password) return problem(400, 'invalid_password');
      password = body['newPassword'] as String;
      mustChangePassword = false;
      accessToken = 'access-3';
      return json({
        'accessToken': accessToken,
        'accessTokenExpiresAt': '',
        'refreshToken': 'refresh-1',
        'refreshTokenExpiresAt': '',
        'user': user(role),
      });
    }
    if (mustChangePassword && req.url.path != '/api/auth/me') return problem(403, 'password_change_required');
    calls.update(req.url.path, (n) => n + 1, ifAbsent: () => 1);
    final route = routes[req.url.path];
    if (route != null) {
      final result = route(req);
      return result is http.Response ? result : json(result);
    }
    return switch (req.url.path) {
      '/api/auth/me' => json(user(role)),
      '/api/me/dashboard' => json(dashboard()),
      '/api/me/memberships' => json([membership()]),
      _ => problem(404, 'not_found'),
    };
  });
}
