// The app's own camera screen for food photos. The camera itself needs a device; here: that a camera shot opens
// this screen (never the system camera app), and its states without a camera or without access, with the gallery
// as the way out.
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:fitness_formulasi/ui/client/nutrition/food_camera_screen.dart';
import 'package:fitness_formulasi/ui/client/nutrition/food_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'nutrition_scanner_test.dart' show foodJpeg;
import 'screen_harness.dart';

/// A screen with one button that asks for a photo the way the scanner does and keeps the answer.
class _Asker extends StatefulWidget {
  const _Asker({required this.ask});
  final Future<Uint8List?> Function(BuildContext context) ask;

  @override
  State<_Asker> createState() => _AskerState();
}

class _AskerState extends State<_Asker> {
  String result = 'none';

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            key: const Key('ask'),
            onPressed: () async {
              final jpeg = await widget.ask(context);
              setState(() => result = jpeg == null ? 'null' : 'jpeg:${jpeg.length}');
            },
            child: const Text('ask'),
          ),
          Text(result, key: const Key('result')),
        ],
      ),
    ),
  );
}

String resultText(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('result'))).data!;

void main() {
  testWidgets('a camera shot opens the app camera screen, not the system camera', (tester) async {
    await pumpScreen(tester, _Asker(ask: (context) => pickFoodPhoto(context, FoodPhotoSource.camera, label: true)));
    await tester.tap(find.byKey(const Key('ask')));
    // The real camera does not answer in a widget test: the screen keeps its spinner, so no pumpAndSettle here.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(FoodCameraScreen), findsOneWidget);
    expect(tester.widget<FoodCameraScreen>(find.byType(FoodCameraScreen)).label, isTrue);
    expect(find.text('Фото этикетки'), findsOneWidget);

    // Closing gives no photo.
    await tester.tap(find.byKey(const Key('camera-close')));
    await tester.pumpAndSettle();
    expect(find.byType(FoodCameraScreen), findsNothing);
    expect(resultText(tester), 'null');
  });

  testWidgets('without a camera the screen says so and the gallery photo comes back', (tester) async {
    var galleryCalls = 0;
    await pumpScreen(
      tester,
      _Asker(
        ask: (context) => Navigator.of(context).push<Uint8List>(
          MaterialPageRoute(
            builder: (_) => FoodCameraScreen(
              cameras: () async => [],
              gallery: () async {
                galleryCalls++;
                return foodJpeg;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('ask')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('camera-noCamera')), findsOneWidget);
    expect(find.text('Камера недоступна'), findsOneWidget);
    expect(find.text('Фото блюда'), findsOneWidget);
    expect(find.byKey(const Key('camera-shutter')), findsNothing);

    await tester.tap(find.byKey(const Key('camera-gallery-fallback')));
    await tester.pumpAndSettle();
    expect(galleryCalls, 1);
    expect(find.byType(FoodCameraScreen), findsNothing);
    expect(resultText(tester), 'jpeg:${foodJpeg.length}');
  });

  testWidgets('without camera access the screen explains how to allow it and offers the gallery', (tester) async {
    await pumpScreen(
      tester,
      _Asker(
        ask: (context) => Navigator.of(context).push<Uint8List>(
          MaterialPageRoute(
            builder: (_) => FoodCameraScreen(
              cameras: () async => throw CameraException('CameraAccessDenied', 'User denied the camera access.'),
              gallery: () async => null,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('ask')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('camera-noAccess')), findsOneWidget);
    expect(find.text('Нет доступа к камере'), findsOneWidget);
    expect(find.textContaining('в Настройках'), findsOneWidget);

    // The user cancels the gallery too: the camera screen stays.
    await tester.tap(find.byKey(const Key('camera-gallery-fallback')));
    await tester.pumpAndSettle();
    expect(find.byType(FoodCameraScreen), findsOneWidget);
  });

  testWidgets('a camera that fails to start can be retried', (tester) async {
    var attempts = 0;
    await pumpScreen(
      tester,
      FoodCameraScreen(
        cameras: () async {
          attempts++;
          throw CameraException('CameraNotFound', 'The camera is busy.');
        },
        gallery: () async => null,
      ),
    );
    expect(find.byKey(const Key('camera-failed')), findsOneWidget);
    await tester.tap(find.byKey(const Key('camera-retry')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });
}
