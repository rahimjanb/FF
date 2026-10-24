import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../data/models.dart';
import '../data/repositories.dart';

enum SessionStatus { unknown, signedOut, signedIn }

/// Owns the signed-in user. Screens choose the client or trainer experience from [user.role].
class SessionController extends ChangeNotifier {
  SessionController(this._auth, ApiClient api) {
    api.onSessionExpired = _expire;
  }

  final AuthRepository _auth;
  SessionStatus status = SessionStatus.unknown;
  AuthUser? user;

  /// Restores a previous session from the stored refresh token.
  Future<void> restore() async {
    try {
      user = await _auth.me();
      status = SessionStatus.signedIn;
    } catch (_) {
      user = null;
      status = SessionStatus.signedOut;
    }
    notifyListeners();
  }

  Future<void> login(String phone, String password) async => _signIn(await _auth.login(phone, password));

  Future<void> register({
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
  }) async => _signIn(await _auth.register(phone: phone, password: password, firstName: firstName, lastName: lastName));

  Future<void> changePassword(String current, String next) async {
    user = await _auth.changePassword(current, next);
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth.logout();
    _expire();
  }

  Future<void> _signIn(AuthUser u) async {
    if (u.role == 'Admin') {
      await _auth.logout();
      throw ApiException(403, 'admin_use_web', 'Admins use the web panel');
    }
    user = u;
    status = SessionStatus.signedIn;
    notifyListeners();
  }

  void _expire() {
    user = null;
    status = SessionStatus.signedOut;
    notifyListeners();
  }
}
