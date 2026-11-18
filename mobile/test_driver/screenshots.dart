// Host side of integration_test/store_screenshots_test.dart: saves each screenshot the app takes as a PNG.
// Folder: SCREENSHOTS_DIR, default store/screenshots/raw (relative to mobile/).
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final dir = Platform.environment['SCREENSHOTS_DIR'] ?? 'store/screenshots/raw';
    final file = File('$dir/$name.png');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    stdout.writeln('screenshot: ${file.path}');
    return true;
  },
);
