// End-to-end check of the AI Food Scanner against a REAL running backend: photo → AI analysis → result →
// correction → food diary → AI consultant → analytics. The photo comes from a file instead of the camera
// (the simulator has none) and goes through the same preparation as a camera photo (prepareFoodPhoto).
// The backend may use the real AI provider or a local stand-in of its API (docs/TESTING.md):
//   flutter drive --driver=test_driver/screenshots.dart --target=integration_test/food_scanner_e2e_test.dart \
//     -d <simulator> --dart-define=API_URL=http://127.0.0.1:5080 \
//     --dart-define=E2E_CLIENT_PHONE=+998... --dart-define=E2E_CLIENT_PASSWORD=... \
//     --dart-define=E2E_FOOD_PHOTO=/absolute/path/to/food.jpg
// SCREENSHOTS_DIR=<folder> keeps a screenshot of every step.
import 'dart:io';

import 'package:fitness_formulasi/main.dart' as app;
import 'package:fitness_formulasi/ui/client/client_shell.dart';
import 'package:fitness_formulasi/ui/client/nutrition/food_photo.dart';
import 'package:fitness_formulasi/ui/client/nutrition/nutrition_hub_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const phone = String.fromEnvironment('E2E_CLIENT_PHONE');
const password = String.fromEnvironment('E2E_CLIENT_PASSWORD');
const photoPath = String.fromEnvironment('E2E_FOOD_PHOTO');

Future<void> settle(WidgetTester tester, [int seconds = 2]) async {
  for (var i = 0; i < seconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> waitFor(WidgetTester tester, Finder finder, {int seconds = 30}) async {
  for (var i = 0; i < seconds * 10 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 250, scrollable: find.byType(Scrollable).last);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder);
}

/// The camera of the test: the photo file, prepared exactly like a camera photo.
Future<Uint8List?> filePicker(FoodPhotoSource source) async {
  final (jpeg, problem) = await compute(prepareFoodPhoto, File(photoPath).readAsBytesSync());
  if (problem != null) throw FoodPhotoException(problem);
  return jpeg;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> shot(String name) => binding.takeScreenshot(name);

  // Runs only when a photo is given, so `flutter test integration_test` without it still runs the other checks.
  testWidgets('food photo to diary, consultant and analytics', skip: photoPath.isEmpty, (tester) async {
    expect(phone, isNotEmpty, reason: 'Pass E2E_CLIENT_PHONE, E2E_CLIENT_PASSWORD and E2E_FOOD_PHOTO via --dart-define');
    app.main();
    await settle(tester, 4);
    if (find.byKey(const Key('login-phone')).evaluate().isNotEmpty) {
      await tester.enterText(find.byKey(const Key('login-phone')), phone);
      await tester.enterText(find.byKey(const Key('login-password')), password);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.tap(find.byKey(const Key('login-submit')));
    }
    await waitFor(tester, find.byKey(const Key('home-nutrition')));
    await settle(tester, 3);
    await tester.scrollUntilVisible(find.byKey(const Key('home-nutrition')), 250, scrollable: find.byType(Scrollable).first);
    await settle(tester);
    await shot('01-home-card');

    // The hub as the home card opens it, with the file instead of the camera.
    Navigator.of(tester.element(find.byType(ClientShell))).push(
      MaterialPageRoute<void>(builder: (_) => const NutritionHubScreen(picker: filePicker, useCamera: false)),
    );
    await waitFor(tester, find.byKey(const Key('hub-camera')));
    await settle(tester, 3);
    await shot('02-hub');

    await tester.tap(find.byKey(const Key('hub-camera')));
    await settle(tester, 2);
    if (find.byKey(const Key('ai-consent-sheet')).evaluate().isNotEmpty) {
      await shot('03-consent');
      await tester.tap(find.byKey(const Key('ai-consent-agree')));
      await settle(tester, 3);
    }
    await waitFor(tester, find.byKey(const Key('scan-analyze')));
    await settle(tester);
    await shot('04-preview');

    await tester.tap(find.byKey(const Key('scan-analyze')));
    await settle(tester, 1);
    await shot('05-analyzing');
    await waitFor(tester, find.byKey(const Key('scan-result')), seconds: 120);
    await settle(tester, 3);
    expect(find.textContaining('Плов'), findsWidgets);
    await shot('06-result');

    // A correction: less oil. The server recalculates.
    await tapVisible(tester, find.byKey(const Key('fat-less')));
    await settle(tester, 3);
    await shot('07-result-less-oil');
    await tester.scrollUntilVisible(find.textContaining('Баранина').first, 250, scrollable: find.byType(Scrollable).last);
    await settle(tester);
    await shot('08-ingredients');

    await tapVisible(tester, find.byKey(const Key('scan-add-to-diary')));
    await waitFor(tester, find.byKey(const Key('hub-camera')));
    await settle(tester, 3);
    await shot('09-hub-after');

    await tapVisible(tester, find.byKey(const Key('hub-diary')));
    await waitFor(tester, find.byKey(const Key('diary-totals')));
    await settle(tester, 3);
    await shot('10-diary');
    for (var i = 0; i < 6 && find.textContaining('Плов').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
      await settle(tester, 1);
    }
    expect(find.textContaining('Плов'), findsWidgets);
    await shot('10b-diary-entry');
    await tester.binding.handlePopRoute(); // the screens use their own glass back button
    await settle(tester, 2);

    await tapVisible(tester, find.byKey(const Key('hub-consultant')));
    await waitFor(tester, find.byKey(const Key('consultant-input')));
    await tester.enterText(find.byKey(const Key('consultant-input')), 'Сколько калорий я сегодня съел?');
    await tester.tap(find.byKey(const Key('consultant-send')));
    await waitFor(tester, find.textContaining('По вашему дневнику'), seconds: 90);
    await settle(tester, 2);
    await shot('11-consultant');
    await tester.binding.handlePopRoute(); // the screens use their own glass back button
    await settle(tester, 2);

    await tapVisible(tester, find.byKey(const Key('hub-analytics')));
    await waitFor(tester, find.byKey(const Key('kcal-chart')));
    await settle(tester, 3);
    await shot('12-analytics');
  });
}
