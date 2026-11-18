// The app's own food camera on a real device or simulator. With a camera: live preview, a shot, and the prepared
// JPEG comes back (orientation applied, metadata removed, at most 1568 px). Without one (the iOS simulator): the
// screen says so and offers the gallery.
//   flutter drive --driver=test_driver/screenshots.dart --target=integration_test/food_camera_test.dart -d <device>
// SCREENSHOTS_DIR=<folder> keeps a screenshot of every step. On a phone, allow the camera when iOS asks.
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:fitness_formulasi/l10n/gen/app_localizations.dart';
import 'package:fitness_formulasi/ui/client/nutrition/food_camera_screen.dart';
import 'package:fitness_formulasi/ui/client/nutrition/food_photo.dart';
import 'package:fitness_formulasi/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

Future<void> waitFor(WidgetTester tester, Finder finder, {int seconds = 20}) async {
  for (var i = 0; i < seconds * 10 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final label in [false, true]) {
    testWidgets('food camera (${label ? 'label' : 'dish'})', (tester) async {
      Uint8List? shot;
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDarkTheme(),
          locale: const Locale('ru'),
          supportedLocales: const [Locale('ru'), Locale('uz')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open'),
                  onPressed: () async {
                    shot = await pickFoodPhoto(context, FoodPhotoSource.camera, label: label);
                    closed = true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(FoodCameraScreen), findsOneWidget);

      final cameras = await availableCameras();
      final name = label ? 'label' : 'dish';
      if (cameras.isEmpty) {
        await waitFor(tester, find.byKey(const Key('camera-noCamera')));
        await tester.pump(const Duration(milliseconds: 400));
        await binding.takeScreenshot('camera-$name-no-camera');
        expect(find.byKey(const Key('camera-gallery-fallback')), findsOneWidget);
        await tester.tap(find.byKey(const Key('camera-close')));
        await tester.pump(const Duration(milliseconds: 600));
        expect(closed, isTrue);
        expect(shot, isNull);
        return;
      }

      await waitFor(tester, find.byKey(const Key('camera-shutter')));
      await tester.pump(const Duration(seconds: 2)); // exposure settles
      await binding.takeScreenshot('camera-$name-preview');
      await tester.tap(find.byKey(const Key('camera-flash')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('camera-shutter')));
      for (var i = 0; i < 200 && !closed; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(closed, isTrue);
      expect(shot, isNotNull);
      final decoded = img.decodeJpg(shot!)!;
      expect(decoded.width > decoded.height, isFalse, reason: 'a portrait shot stays portrait');
      expect(decoded.height, lessThanOrEqualTo(foodMaxSide));
      expect(decoded.exif.isEmpty, isTrue, reason: 'no metadata leaves the phone');
    });
  }
}
