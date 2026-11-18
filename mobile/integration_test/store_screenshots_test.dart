// Store screenshots of the client app, taken against a running backend with demo data (docs/STORE.md, section 11).
// iPhone 17 Pro Max simulator gives the 1320 × 2868 px App Store size:
//   flutter drive --driver=test_driver/screenshots.dart --target=integration_test/store_screenshots_test.dart \
//     -d "iPhone 17 Pro Max" --dart-define=API_URL=http://127.0.0.1:5080 --dart-define=SHOW_UPCOMING=false \
//     --dart-define=SHOTS_PHONE=+998901112233 --dart-define=SHOTS_PASSWORD=...
// Use a demo account only: no real client names, phone numbers or photos in store screenshots.
import 'dart:io';

import 'package:fitness_formulasi/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const phone = String.fromEnvironment('SHOTS_PHONE');
const password = String.fromEnvironment('SHOTS_PASSWORD');

Future<void> settle(WidgetTester tester, [int seconds = 2]) async {
  for (var i = 0; i < seconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> waitFor(WidgetTester tester, Finder finder, {int seconds = 20}) async {
  for (var i = 0; i < seconds * 10 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await settle(tester, 3);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Runs only for the screenshot session (SHOTS_PHONE given), not with every `flutter test integration_test`.
  testWidgets('store screenshots', skip: phone.isEmpty, (tester) async {
    expect(phone, isNotEmpty, reason: 'Pass SHOTS_PHONE and SHOTS_PASSWORD via --dart-define');
    app.main();
    await settle(tester, 4);

    // Signed in from an earlier run: sign out first, so every run starts the same way.
    if (find.byKey(const Key('login-phone')).evaluate().isEmpty) {
      await openTab(tester, 'Профиль');
      final button = find.byKey(const Key('profile-logout'));
      await tester.scrollUntilVisible(button, 300, scrollable: find.byType(Scrollable).last);
      await tester.tap(button);
      await settle(tester);
      await tester.tap(find.byKey(const Key('logout-confirm')));
      await settle(tester);
    }

    await tester.enterText(find.byKey(const Key('login-phone')), phone);
    await tester.enterText(find.byKey(const Key('login-password')), password);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.tap(find.byKey(const Key('login-submit')));
    await waitFor(tester, find.byKey(const Key('home-qr-pass')));
    await settle(tester, 4); // banner image and counters

    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    Future<void> shot(String name) async {
      await settle(tester, 2);
      await binding.takeScreenshot(name);
    }

    await shot('01-home');

    await openTab(tester, 'Абонемент');
    await shot('02-membership');

    await tester.tap(find.byKey(const Key('show-qr-pass')));
    await settle(tester, 3);
    await shot('03-qr-pass');
    await tester.tapAt(const Offset(20, 120)); // outside the sheet
    await settle(tester);

    final face = find.byKey(const Key('face-access-tile'));
    await tester.scrollUntilVisible(face, 300, scrollable: find.byType(Scrollable).last);
    await tester.tap(face);
    await settle(tester, 3);
    await shot('04-face-access');
    await tester.binding.handlePopRoute(); // the screen has its own back button
    await settle(tester);

    await openTab(tester, 'Тренеры');
    await shot('05-trainers');

    await openTab(tester, 'Тренировки');
    await shot('06-workouts');
  });
}
