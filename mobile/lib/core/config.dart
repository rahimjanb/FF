import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

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

  /// Absolute URL for a path returned by the API (e.g. a trainer photo).
  static String resolve(String path) => '$apiBaseUrl$path';

  /// The club's privacy policy, a public page of the API (App Store and Google Play require a link in the app).
  static String get privacyPolicyUrl => resolve('/legal/privacy');

  /// Features that are not built yet («скоро»: chat, online payment, Face ID sign-in…) are shown in debug builds
  /// only, so store builds contain nothing that does not work. `--dart-define=SHOW_UPCOMING=false` hides them in a
  /// debug build too (store screenshots).
  static const _showUpcoming = bool.fromEnvironment('SHOW_UPCOMING', defaultValue: !kReleaseMode);

  /// Lets tests check the store build's screens; null uses the build setting.
  @visibleForTesting
  static bool? showUpcomingOverride;

  static bool get showUpcoming => showUpcomingOverride ?? _showUpcoming;
}
