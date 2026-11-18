import 'dart:convert';

import 'package:fitness_formulasi/ui/client/nutrition/analytics_screen.dart';
import 'package:fitness_formulasi/ui/client/nutrition/barcode_screen.dart';
import 'package:fitness_formulasi/ui/client/nutrition/consultant_screen.dart';
import 'package:fitness_formulasi/ui/client/nutrition/diary_screen.dart';
import 'package:fitness_formulasi/data/nutrition_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fake_backend.dart';
import 'nutrition_fake.dart';
import 'nutrition_scanner_test.dart' show reveal, tapKey;
import 'screen_harness.dart';

NutritionProfile profile() => NutritionProfile.fromJson(nutritionProfileJson());

void main() {
  group('barcode', () {
    testWidgets('a found product opens its card; adding it sends the product and the grams', (tester) async {
      final b = FakeBackend();
      final n = NutritionFake(b);
      await pumpScreen(tester, BarcodeScreen(profile: profile(), useCamera: false), backend: b);
      await tester.enterText(find.byKey(const Key('barcode-field')), '4780000000017');
      await tapKey(tester, 'barcode-find');
      expect(n.barcodes, ['4780000000017']);
      expect(find.byKey(const Key('product-screen')), findsOneWidget);
      expect(find.text('Кефир 2,5%'), findsOneWidget);
      expect(find.text('Open Food Facts'), findsOneWidget);
      await tapKey(tester, 'meal-snack');
      await tapKey(tester, 'product-add');
      final body = n.diaryPosts.single;
      expect(body['mealType'], 'Snack');
      expect(body['scanId'], 'bc1');
      final item = (body['items'] as List).single as Map<String, dynamic>;
      expect(item['productId'], 'prod1');
      expect(item['grams'], 250, reason: 'one serving by default');
    });

    testWidgets('an unknown barcode offers the label photo, a manual search or an own product', (tester) async {
      final b = FakeBackend();
      final n = NutritionFake(b);
      await pumpScreen(tester, BarcodeScreen(profile: profile(), useCamera: false), backend: b);
      await tester.enterText(find.byKey(const Key('barcode-field')), '4600000000001');
      await tapKey(tester, 'barcode-find');
      expect(n.barcodes, ['4600000000001']);
      expect(find.byKey(const Key('barcode-not-found')), findsOneWidget);
      expect(find.byKey(const Key('barcode-photo-label')), findsOneWidget);
      expect(find.byKey(const Key('barcode-search')), findsOneWidget);
      expect(find.byKey(const Key('barcode-create')), findsOneWidget);
      expect(n.diaryPosts, isEmpty);
    });

    testWidgets('a code of the wrong length is not sent', (tester) async {
      final b = FakeBackend();
      final n = NutritionFake(b);
      await pumpScreen(tester, BarcodeScreen(profile: profile(), useCamera: false), backend: b);
      await tester.enterText(find.byKey(const Key('barcode-field')), '12345');
      await tapKey(tester, 'barcode-find');
      expect(n.barcodes, isEmpty);
      expect(find.textContaining('Неверный штрихкод'), findsOneWidget);
    });
  });

  group('diary', () {
    late FakeBackend b;
    late NutritionFake n;
    final puts = <Map<String, dynamic>>[];
    var deletes = 0;
    var repeats = 0;

    setUp(() {
      b = FakeBackend();
      n = NutritionFake(b);
      n.entries.add(entryJson());
      puts.clear();
      deletes = 0;
      repeats = 0;
      b.routes['/api/food-diary/e1'] = (req) {
        if (req.method == 'PUT') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          puts.add(body);
          final items = [
            for (final i in (body['items'] as List).cast<Map<String, dynamic>>())
              diaryItemJson(
                i['diaryItemId'] as String,
                i['name'] as String,
                i['grams'] as num,
                kcal100: i['diaryItemId'] == 'it2' ? 250 : 130,
              ),
          ];
          final saved = entryJson(items: items);
          n.entries[0] = saved;
          return saved;
        }
        if (req.method == 'DELETE') {
          deletes++;
          n.entries.clear();
          return http.Response('', 204);
        }
        return n.entries.first;
      };
      b.routes['/api/food-diary/e1/repeat'] = (_) {
        repeats++;
        return entryJson(id: 'e2');
      };
    });

    testWidgets('the day shows every meal, the entry with its calories and the totals against the target', (
      tester,
    ) async {
      await pumpScreen(tester, FoodDiaryScreen(profile: profile(), useCamera: false), backend: b);
      expect(find.byKey(const Key('diary-totals')), findsOneWidget);
      expect(find.text('Сегодня'), findsOneWidget);
      await reveal(tester, find.byKey(const Key('entry-e1')));
      expect(find.text('Плов'), findsOneWidget);
      // 200 g × 130 + 100 g × 250 = 510 kcal.
      expect(find.descendant(of: find.byKey(const Key('entry-e1')), matching: find.text('510')), findsOneWidget);
      for (final m in ['breakfast', 'lunch', 'dinner', 'snack']) {
        await reveal(tester, find.byKey(Key('meal-section-$m')));
      }
    });

    testWidgets('portion ×2 doubles every item and saves them by their diary ids', (tester) async {
      await pumpScreen(tester, FoodDiaryScreen(profile: profile(), useCamera: false), backend: b);
      await tapKey(tester, 'entry-e1');
      expect(find.byKey(const Key('diary-entry')), findsOneWidget);
      expect(find.byKey(const Key('entry-save')), findsNothing, reason: 'nothing to save yet');
      await tapKey(tester, 'entry-scale-2.0');
      await tapKey(tester, 'entry-save');
      final items = (puts.single['items'] as List).cast<Map<String, dynamic>>();
      expect(items.map((i) => i['diaryItemId']), ['it1', 'it2']);
      expect(items.map((i) => i['grams']), [400, 200]);
      expect(items.every((i) => i['productId'] == null && i['scanIngredientId'] == null), isTrue);
      // 400 g × 130 + 200 g × 250 = 1020 kcal, recalculated by the server.
      expect(find.text('≈ 1\u00A0020 ккал'), findsOneWidget, reason: 'server totals after saving');
    });

    testWidgets('repeat copies the entry to today; delete asks first and removes it', (tester) async {
      await pumpScreen(tester, FoodDiaryScreen(profile: profile(), useCamera: false), backend: b);
      await tapKey(tester, 'entry-e1');
      await tapKey(tester, 'entry-repeat');
      expect(repeats, 1);
      await tapKey(tester, 'entry-delete');
      expect(find.byKey(const Key('confirm-sheet')), findsOneWidget);
      expect(deletes, 0);
      await tapKey(tester, 'confirm-yes');
      expect(deletes, 1);
      expect(find.byKey(const Key('food-diary')), findsOneWidget);
      expect(find.byKey(const Key('entry-e1')), findsNothing);
    });

    testWidgets('adding to a meal from the search sends the product with the grams and that meal', (tester) async {
      await pumpScreen(tester, FoodDiaryScreen(profile: profile(), useCamera: false), backend: b);
      await tapKey(tester, 'meal-add-dinner');
      await tapKey(tester, 'add-search');
      await tester.enterText(find.byKey(const Key('food-search-field')), 'кефир');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      await tapKey(tester, 'product-prod2');
      expect(find.byKey(const Key('grams-sheet')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('grams-field')), '300');
      await tapKey(tester, 'grams-ok');
      final body = n.diaryPosts.single;
      expect(body['mealType'], 'Dinner');
      final item = (body['items'] as List).single as Map<String, dynamic>;
      expect(item['productId'], 'prod2');
      expect(item['grams'], 300);
    });
  });

  testWidgets('analytics week: averages, logged days, the calorie chart and the AI report', (tester) async {
    final b = FakeBackend();
    NutritionFake(b);
    await pumpScreen(tester, NutritionAnalyticsScreen(profile: profile()), backend: b);
    expect(find.byKey(const Key('stat-average')), findsOneWidget);
    expect(find.text('2 120'), findsOneWidget);
    expect(find.text('6/7'), findsOneWidget);
    expect(find.byKey(const Key('kcal-chart')), findsOneWidget);
    await tapKey(tester, 'ai-report-button');
    await reveal(tester, find.byKey(const Key('ai-report')));
    expect(find.textContaining('2120 ккал'), findsOneWidget);
  });

  testWidgets('analytics day shows calories per meal and the workout of the day', (tester) async {
    final b = FakeBackend();
    NutritionFake(b);
    await pumpScreen(tester, NutritionAnalyticsScreen(profile: profile()), backend: b);
    await tester.tap(find.text('День'));
    await settle(tester);
    expect(find.byKey(const Key('analytics-day')), findsOneWidget);
    expect(find.text('1 тренировка'), findsOneWidget);
    expect(find.text('Посещение клуба'), findsOneWidget);
  });

  testWidgets('consultant: a suggested question is sent with the locale and the answer shows its sources', (
    tester,
  ) async {
    final b = FakeBackend();
    final n = NutritionFake(b);
    await pumpScreen(tester, ConsultantScreen(profile: profile()), backend: b);
    await tapKey(tester, 'suggestion-0');
    expect(n.chats, hasLength(1));
    expect(n.chats.single['locale'], 'ru');
    final messages = (n.chats.single['messages'] as List).cast<Map<String, dynamic>>();
    expect(messages.single, {'role': 'user', 'text': 'Сколько калорий я сегодня съел?'});
    expect(find.text('Сегодня вы съели 850 ккал, осталось 1350 ккал.'), findsOneWidget);
    expect(find.text('на основе: дневник, профиль'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('consultant-input')), 'А белка?');
    await tapKey(tester, 'consultant-send');
    final second = (n.chats.last['messages'] as List).cast<Map<String, dynamic>>();
    expect(second.map((m) => m['role']), ['user', 'assistant', 'user'], reason: 'the conversation goes along');
  });

  testWidgets('consultant errors are shown with a retry', (tester) async {
    final b = FakeBackend();
    NutritionFake(b);
    b.routes['/api/nutrition/consultant/chat'] = (_) => problemResponse(503, 'ai_unavailable');
    await pumpScreen(tester, ConsultantScreen(profile: profile()), backend: b);
    await tapKey(tester, 'suggestion-1');
    expect(find.byKey(const Key('consultant-error')), findsOneWidget);
    expect(find.textContaining('ИИ-сервис сейчас недоступен'), findsOneWidget);
  });
}
