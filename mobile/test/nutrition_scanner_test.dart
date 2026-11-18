import 'dart:convert';
import 'dart:typed_data';

import 'package:fitness_formulasi/ui/client/nutrition/food_photo.dart';
import 'package:fitness_formulasi/ui/client/nutrition/nutrition_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'fake_backend.dart';
import 'nutrition_fake.dart';
import 'screen_harness.dart';

final foodJpeg = Uint8List.fromList(img.encodeJpg(img.Image(width: 640, height: 480)));

/// A picker that returns [foodJpeg] and remembers which source was asked for.
class FakePicker {
  final sources = <FoodPhotoSource>[];
  final labels = <bool>[];
  Future<Uint8List?> call(BuildContext context, FoodPhotoSource source, {bool label = false}) async {
    sources.add(source);
    labels.add(label);
    return foodJpeg;
  }
}

/// The screen's main vertical list (lists build their rows lazily, so off-screen rows must be scrolled to).
Finder get mainScroll =>
    find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) await tester.scrollUntilVisible(finder, 150, scrollable: mainScroll);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await reveal(tester, find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await settle(tester);
}

Future<(FakeBackend, NutritionFake, FakePicker)> pumpHub(
  WidgetTester tester, {
  bool consent = true,
  bool ai = true,
  void Function(NutritionFake n)? setup,
}) async {
  final b = FakeBackend();
  final n = NutritionFake(b, consent: consent, ai: ai);
  setup?.call(n);
  final picker = FakePicker();
  await pumpScreen(tester, NutritionHubScreen(picker: picker.call, useCamera: false), backend: b);
  return (b, n, picker);
}

/// Takes the photo with the camera button and runs the analysis; ends on the result screen.
Future<void> scanPlov(WidgetTester tester) async {
  await tapKey(tester, 'hub-camera');
  expect(find.byKey(const Key('scan-preview-photo')), findsOneWidget);
  await tapKey(tester, 'scan-analyze');
}

/// Lets the debounced correction go out and its answer come back.
Future<void> flushCorrections(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 450));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
  await settle(tester);
}

void main() {
  group('food photo preparation', () {
    test('a large photo is scaled to 1568 px on the longer side and its EXIF is removed', () {
      final source = img.Image(width: 4000, height: 3000)..exif.imageIfd['Make'] = 'TestCam';
      final raw = img.encodeJpg(source, quality: 95);
      expect(img.decodeJpgExif(raw)?.imageIfd['Make'], isNotNull, reason: 'the source carries EXIF');
      final (jpeg, problem) = prepareFoodPhoto(raw);
      expect(problem, isNull);
      final out = img.decodeJpg(jpeg!)!;
      expect(out.width, 1568);
      expect(out.height, 1176);
      expect(jpeg.length, lessThanOrEqualTo(foodMaxBytes));
      final exif = img.decodeJpgExif(jpeg);
      expect(exif == null || exif.isEmpty, isTrue, reason: 'no camera data or GPS leaves the phone');
    });

    test('a photo smaller than 320 px on the short side is rejected', () {
      final (jpeg, problem) = prepareFoodPhoto(img.encodeJpg(img.Image(width: 800, height: 200)));
      expect(jpeg, isNull);
      expect(problem, FoodPhotoProblem.tooSmall);
    });

    test('something that is not an image is rejected', () {
      final (jpeg, problem) = prepareFoodPhoto(Uint8List.fromList(utf8.encode('not a photo')));
      expect(jpeg, isNull);
      expect(problem, FoodPhotoProblem.unreadable);
    });
  });

  testWidgets('hub shows today against the target and the recent scans', (tester) async {
    await pumpHub(tester);
    expect(find.byKey(const Key('hub-today')), findsOneWidget);
    expect(find.text('Съедено 850 ккал'), findsOneWidget);
    expect(find.text('Осталось 1\u00A0350 ккал'), findsOneWidget);
    expect(find.byKey(const Key('hub-camera')), findsOneWidget);
    await reveal(tester, find.byKey(const Key('history-s1')));
    expect(find.text('Плов'), findsWidgets);
  });

  testWidgets('camera photo → preview → analysis → result with range and ingredients; nothing added on its own', (
    tester,
  ) async {
    final (b, n, picker) = await pumpHub(tester);
    await scanPlov(tester);
    expect(picker.sources, [FoodPhotoSource.camera]);
    expect(n.analyzeRequests, hasLength(1));
    expect(n.analyzeRequests.single.headers['content-type'], startsWith('multipart/form-data'));
    expect(find.byKey(const Key('scan-result')), findsOneWidget);
    expect(find.text('Плов'), findsWidgets);
    // 180 g rice 130, 70 g beef 250, 50 g carrot 40, 25 g oil 884 → 650 kcal, with a wide range (±30 %).
    expect(find.text('≈ 650 ккал'), findsOneWidget);
    expect(find.byKey(const Key('dish-range')), findsOneWidget);
    await reveal(tester, find.text('Рис'));
    await reveal(tester, find.text('Хлопковое масло'));
    expect(n.diaryPosts, isEmpty, reason: 'the dish goes to the diary only on the tap');
    expect(b.calls['/api/food-diary'], isNull);
  });

  testWidgets('gallery photo with a hint sends the hint along', (tester) async {
    final (_, n, picker) = await pumpHub(tester);
    await tapKey(tester, 'hub-gallery');
    expect(picker.sources, [FoodPhotoSource.gallery]);
    await tester.enterText(find.byKey(const Key('scan-hint')), 'домашний плов');
    await tapKey(tester, 'scan-analyze');
    expect(utf8.decode(n.analyzeRequests.single.bodyBytes, allowMalformed: true), contains('домашний плов'));
    expect(find.byKey(const Key('scan-result')), findsOneWidget);
  });

  testWidgets('changing grams sends the correction after a pause and shows the server totals', (tester) async {
    final (_, n, _) = await pumpHub(tester);
    await scanPlov(tester);
    await reveal(tester, find.byKey(const Key('ing-plus-i1')));
    await tester.tap(find.byKey(const Key('ing-plus-i1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ing-plus-i1')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(n.puts, isEmpty, reason: 'corrections wait for a pause');
    await flushCorrections(tester);
    expect(n.puts, hasLength(1), reason: 'two quick taps make one request');
    final rice = (n.puts.single['ingredients'] as List).first as Map<String, dynamic>;
    expect(rice['id'], 'i1');
    expect(rice['grams'], 200);
    // 200 g rice instead of 180: +26 kcal → 676, rounded to 10 for a rough estimate.
    await tester.scrollUntilVisible(find.text('≈ 680 ккал'), -150, scrollable: mainScroll);
    expect(find.text('≈ 680 ккал'), findsOneWidget);
  });

  testWidgets('removing an ingredient sends the dish without it', (tester) async {
    final (_, n, _) = await pumpHub(tester);
    await scanPlov(tester);
    await reveal(tester, find.byKey(const Key('ing-remove-i4')));
    await tester.tap(find.byKey(const Key('ing-remove-i4')));
    await flushCorrections(tester);
    final ids = [for (final i in (n.puts.last['ingredients'] as List)) (i as Map)['id']];
    expect(ids, ['i1', 'i2', 'i3']);
    expect(find.text('Хлопковое масло'), findsNothing);
    // Without 221 kcal of oil: 429 → 430.
    await tester.scrollUntilVisible(find.text('≈ 430 ккал'), -150, scrollable: mainScroll);
    expect(find.text('≈ 430 ккал'), findsOneWidget);
  });

  testWidgets('adding to the diary sends the scan ingredients and the chosen meal', (tester) async {
    final (_, n, _) = await pumpHub(tester);
    await scanPlov(tester);
    await tapKey(tester, 'meal-dinner');
    await tapKey(tester, 'scan-add-to-diary');
    expect(n.diaryPosts, hasLength(1));
    final body = n.diaryPosts.single;
    expect(body['scanId'], 's1');
    expect(body['mealType'], 'Dinner');
    final items = (body['items'] as List).cast<Map<String, dynamic>>();
    expect(items.map((i) => i['scanIngredientId']), ['i1', 'i2', 'i3', 'i4']);
    expect(items.first['grams'], 180);
    expect(items.last['role'], 'Fat');
    expect(find.byKey(const Key('scan-result')), findsNothing, reason: 'back on the hub');
  });

  testWidgets('an unclear photo asks what is on it; «Уточнить» re-runs the analysis with the hint', (tester) async {
    final (_, n, _) = await pumpHub(
      tester,
      setup: (n) => n.scan = scanJson(
        status: 'NeedsClarification',
        dishes: [],
        question: 'Это суп или второе блюдо?',
        quality: 'blurry',
      ),
    );
    await scanPlov(tester);
    expect(find.byKey(const Key('scan-clarify')), findsOneWidget);
    expect(find.textContaining('Это суп или второе блюдо?'), findsOneWidget);
    expect(find.textContaining('Фото размыто'), findsOneWidget);
    expect(find.byKey(const Key('scan-add-to-diary')), findsNothing);
    await tapKey(tester, 'scan-clarify-name');
    await tester.enterText(find.byKey(const Key('text-sheet-field')), 'мастава');
    n.scan = scanJson();
    await tapKey(tester, 'text-sheet-ok');
    expect(find.byKey(const Key('scan-preview-photo')), findsOneWidget);
    await tapKey(tester, 'scan-analyze');
    expect(n.analyzeRequests, hasLength(2));
    expect(utf8.decode(n.analyzeRequests.last.bodyBytes, allowMalformed: true), contains('мастава'));
    expect(find.byKey(const Key('scan-add-to-diary')), findsOneWidget);
  });

  testWidgets('a photo without food says so and offers to retake it', (tester) async {
    await pumpHub(tester, setup: (n) => n.scan = scanJson(status: 'NotFood', dishes: []));
    await scanPlov(tester);
    expect(find.byKey(const Key('scan-not-food')), findsOneWidget);
    expect(find.text('Еда не найдена'), findsOneWidget);
    expect(find.byKey(const Key('scan-add-to-diary')), findsNothing);
  });

  testWidgets('without a target the hub offers to compute it; the profile form sends the measurements', (tester) async {
    final b = FakeBackend();
    final n = NutritionFake(b, target: false);
    n.daily = {...dailyJson(), 'target': null, 'remainingKcal': null};
    await pumpScreen(tester, NutritionHubScreen(picker: FakePicker().call, useCamera: false), backend: b);
    expect(find.text('Норма не рассчитана'), findsOneWidget);
    await tapKey(tester, 'hub-setup-target');
    expect(find.text('Профиль питания'), findsOneWidget);
    await tapKey(tester, 'goal-lose');
    await tester.enterText(find.byKey(const Key('nutrition-height')), '178');
    await tester.enterText(find.byKey(const Key('nutrition-weight')), '82,5');
    await tapKey(tester, 'activity-moderate');
    await tapKey(tester, 'allergy-nuts');
    await tapKey(tester, 'nutrition-profile-save');
    final body = n.profileUpdates.single;
    expect(body['goal'], 'Lose');
    expect(body['heightCm'], 178);
    expect(body['weightKg'], 82.5);
    expect(body['activity'], 'Moderate');
    expect(body['sex'], 'Male');
    expect(body['allergies'], ['Nuts']);
    expect(find.byKey(const Key('nutrition-hub')), findsOneWidget, reason: 'back on the hub after saving');
  });

  group('errors', () {
    testWidgets('no connection: the photo stays and the error is explained', (tester) async {
      final (b, _, _) = await pumpHub(tester);
      await tapKey(tester, 'hub-camera');
      b.routes['/api/food-scanner/analyze'] = (_) => throw http.ClientException('offline');
      await tapKey(tester, 'scan-analyze');
      expect(find.byKey(const Key('scan-error')), findsOneWidget);
      expect(find.text('Нет соединения с сервером'), findsOneWidget);
      expect(find.byKey(const Key('scan-preview-photo')), findsOneWidget);
    });

    testWidgets('daily limit reached: says so and suggests adding the dish by hand', (tester) async {
      await pumpHub(tester, setup: (n) => n.analyzeError = problemResponse(429, 'ai_quota_exceeded'));
      await scanPlov(tester);
      expect(find.textContaining('Дневной лимит ИИ-анализов исчерпан'), findsOneWidget);
    });

    testWidgets('AI not connected in the club: no broken photo buttons, barcode and manual entry stay', (tester) async {
      await pumpHub(tester, ai: false);
      expect(find.byKey(const Key('hub-ai-off')), findsOneWidget);
      expect(find.byKey(const Key('hub-camera')), findsNothing);
      expect(find.byKey(const Key('hub-gallery')), findsNothing);
      expect(find.byKey(const Key('hub-barcode')), findsOneWidget);
      expect(find.byKey(const Key('hub-manual')), findsOneWidget);
      expect(find.byKey(const Key('hub-consultant')), findsNothing);
    });

    testWidgets('AI service not configured on the server is explained after the attempt', (tester) async {
      await pumpHub(tester, setup: (n) => n.analyzeError = problemResponse(503, 'ai_not_configured'));
      await scanPlov(tester);
      expect(find.textContaining('ИИ-анализ не подключён в клубе'), findsOneWidget);
    });

    testWidgets('without consent the consent sheet comes first; agreeing records it and opens the camera', (
      tester,
    ) async {
      final (_, n, picker) = await pumpHub(tester, consent: false);
      await tapKey(tester, 'hub-camera');
      expect(find.byKey(const Key('ai-consent-sheet')), findsOneWidget);
      expect(find.textContaining('Anthropic (Claude)'), findsOneWidget);
      expect(picker.sources, isEmpty, reason: 'no photo before the consent');
      await tapKey(tester, 'ai-consent-agree');
      expect(n.consentCalls, ['POST']);
      expect(picker.sources, [FoodPhotoSource.camera]);
      expect(find.byKey(const Key('scan-preview-photo')), findsOneWidget);
    });

    testWidgets('declining the consent sends nothing', (tester) async {
      final (_, n, picker) = await pumpHub(tester, consent: false);
      await tapKey(tester, 'hub-camera');
      await tapKey(tester, 'ai-consent-decline');
      expect(n.consentCalls, isEmpty);
      expect(picker.sources, isEmpty);
      expect(n.analyzeRequests, isEmpty);
    });

    testWidgets('consent revoked on another device: 409 brings the sheet back and the analysis is retried', (
      tester,
    ) async {
      final (_, n, _) = await pumpHub(tester);
      var first = true;
      n.b.routes['/api/food-scanner/analyze'] = (req) {
        n.analyzeRequests.add(req);
        if (first) {
          first = false;
          return problemResponse(409, 'ai_consent_required');
        }
        return n.scan;
      };
      await tapKey(tester, 'hub-camera');
      await tapKey(tester, 'scan-analyze');
      expect(find.byKey(const Key('ai-consent-sheet')), findsOneWidget);
      await tapKey(tester, 'ai-consent-agree');
      expect(n.analyzeRequests, hasLength(2));
      expect(find.byKey(const Key('scan-result')), findsOneWidget);
    });
  });
}
