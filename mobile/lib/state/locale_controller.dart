import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Selected UI language. Supported: ru (default), uz. Adding English = new ARB file + entry in [supported].
class LocaleController extends ChangeNotifier {
  static const supported = [Locale('ru'), Locale('uz')];
  static const _key = 'ff.locale';
  final _storage = const FlutterSecureStorage();

  Locale locale = const Locale('ru');

  Future<void> load() async {
    try {
      final saved = await _storage.read(key: _key);
      if (saved != null && supported.any((l) => l.languageCode == saved)) {
        locale = Locale(saved);
        notifyListeners();
      }
    } catch (_) {
      // Keep default locale if storage is unavailable.
    }
  }

  Future<void> set(Locale value) async {
    locale = value;
    notifyListeners();
    try {
      await _storage.write(key: _key, value: value.languageCode);
    } catch (_) {}
  }
}
