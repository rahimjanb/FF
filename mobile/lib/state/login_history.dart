import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// What this device knows about previous sign-ins: the last login (kept in the Keychain / Keystore to prefill the
/// phone) and whether biometrics are set up. Biometric sign-in is offered only to returning users.
class LoginHistory {
  static const _key = 'ff.lastLogin';
  static const _storage = FlutterSecureStorage();

  // Replaceable in tests: the platform plugins are not available there.
  static Future<String?> Function() lastLogin = _read;
  static Future<bool> Function() biometricsAvailable = _biometrics;

  static Future<void> remember(String login) async {
    try {
      await _storage.write(key: _key, value: login);
    } catch (_) {
      // Prefill is a convenience; sign-in works without it.
    }
  }

  static Future<String?> _read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _biometrics() async {
    try {
      final auth = LocalAuthentication();
      return await auth.isDeviceSupported() && (await auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
