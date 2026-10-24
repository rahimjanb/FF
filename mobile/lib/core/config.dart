import 'dart:io' show Platform;

/// Runtime configuration. Override the API address at build time:
/// `flutter run --dart-define=API_URL=https://api.example.uz`
class AppConfig {
  static const _apiUrl = String.fromEnvironment('API_URL');

  /// Default targets a backend running on the developer machine:
  /// the Android emulator reaches the host via 10.0.2.2, the iOS simulator via localhost.
  static String get apiBaseUrl {
    if (_apiUrl.isNotEmpty) return _apiUrl;
    return Platform.isAndroid ? 'http://10.0.2.2:5080' : 'http://127.0.0.1:5080';
  }

  /// Club time zone is Asia/Tashkent (UTC+5, no daylight saving time).
  /// Session times are always shown in club time regardless of the phone's settings.
  static const clubUtcOffset = Duration(hours: 5);
}
