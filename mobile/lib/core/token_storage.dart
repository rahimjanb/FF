import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tokens are kept in the platform keystore (iOS Keychain / Android Keystore-backed storage), never in plain prefs.
abstract class TokenStorage {
  Future<String?> accessToken();
  Future<String?> refreshToken();
  Future<void> save(String access, String refresh);
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  static const _access = 'ff.access';
  static const _refresh = 'ff.refresh';
  final _storage = const FlutterSecureStorage();
  String? _cachedAccess;

  @override
  Future<String?> accessToken() async => _cachedAccess ??= await _storage.read(key: _access);

  @override
  Future<String?> refreshToken() => _storage.read(key: _refresh);

  @override
  Future<void> save(String access, String refresh) async {
    _cachedAccess = access;
    await _storage.write(key: _access, value: access);
    await _storage.write(key: _refresh, value: refresh);
  }

  @override
  Future<void> clear() async {
    _cachedAccess = null;
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
  }
}

/// In-memory storage for tests.
class MemoryTokenStorage implements TokenStorage {
  String? _a;
  String? _r;
  @override
  Future<String?> accessToken() async => _a;
  @override
  Future<String?> refreshToken() async => _r;
  @override
  Future<void> save(String access, String refresh) async {
    _a = access;
    _r = refresh;
  }

  @override
  Future<void> clear() async => _a = _r = null;
}
