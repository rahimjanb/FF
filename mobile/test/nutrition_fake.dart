import 'dart:convert';

import 'package:http/http.dart' as http;

import 'fake_backend.dart';
import 'screen_harness.dart';

/// TEST-ONLY nutrition API on top of [FakeBackend]: profile, today, scan history, one scan that can be analysed and
/// corrected, the diary, barcodes, analytics and the consultant. The PUT of a dish recalculates its calories from
/// the per-100 g values of the ingredients, like the server does.

Map<String, dynamic> nutrientsJson(num kcal, num protein, num fat, num carbs) => {
  'kcal': kcal,
  'protein': protein,
  'fat': fat,
  'carbs': carbs,
  'fiber': 1.5,
  'sugar': 2,
  'saturatedFat': 1,
  'sodiumMg': 120,
};

Map<String, dynamic> totalsJson(num kcal, {num? min, num? max, num grams = 350, bool incomplete = false}) => {
  'values': nutrientsJson(kcal, 20, 25, 60),
  'grams': grams,
  'kcalMin': min ?? kcal * 0.9,
  'kcalMax': max ?? kcal * 1.1,
  'incomplete': incomplete,
};

Map<String, dynamic> targetJson() => {
  'kcal': 2200,
  'proteinG': 130,
  'fatG': 70,
  'carbsG': 260,
  'fiberG': 30,
  'sodiumMaxMg': 2300,
  'method': 'MifflinStJeor',
  'bmr': 1700,
  'tdee': 2400,
};

Map<String, dynamic> nutritionProfileJson({bool consent = true, bool ai = true, bool target = true}) => {
  'goal': target ? 'Maintain' : null,
  'weightKg': target ? 80 : null,
  'heightCm': target ? 180 : null,
  'activity': target ? 'Moderate' : null,
  'sex': 'Male',
  'birthDate': '1995-04-01',
  'customKcalTarget': null,
  'restrictions': null,
  'allergies': <String>[],
  'aiConsentAt': consent ? '2026-11-01T10:00:00Z' : null,
  'aiAvailable': ai,
  'aiProvider': ai ? 'Anthropic (Claude)' : null,
  'scansPerDay': 30,
  'scansToday': 2,
  'target': target ? targetJson() : null,
  'missingForTarget': target ? <String>[] : ['heightCm', 'weightKg', 'activity', 'goal'],
};

Map<String, dynamic> dailyJson({num kcal = 850}) => {
  'date': '2026-11-18',
  'target': targetJson(),
  'totals': totalsJson(kcal, grams: 600),
  'remainingKcal': 2200 - kcal,
  'kcalByMeal': {'Breakfast': 350, 'Lunch': kcal - 350, 'Dinner': 0, 'Snack': 0},
  'entries': 2,
  'trainingSessions': 1,
  'visited': true,
};

/// An ingredient: [kcal100] calories per 100 g; null = no product found.
Map<String, dynamic> ingredientJson(String id, String name, num grams, num? kcal100, {String role = 'Main'}) => {
  'id': id,
  'name': name,
  'productId': kcal100 == null ? null : 'p-$id',
  'productName': kcal100 == null ? null : '$name (USDA)',
  'grams': grams,
  'role': role,
  'match': kcal100 == null ? 'None' : 'CatalogKey',
  'uncertainty': role == 'Fat' ? 0.5 : 0.25,
  'per100': kcal100 == null ? null : nutrientsJson(kcal100, 5, 5, 20),
  'nutrients': kcal100 == null ? null : nutrientsJson(kcal100 * grams / 100, 1, 1, 1),
  'source': kcal100 == null ? null : 'Usda',
  'sourceRef': kcal100 == null ? null : '1001',
};

Map<String, dynamic> dishJson({
  String id = 'd1',
  int index = 0,
  String name = 'Плов',
  required List<Map<String, dynamic>> ingredients,
  List<String> warnings = const [],
}) {
  final kcal = _kcalOf(ingredients);
  return {
    'id': id,
    'index': index,
    'name': name,
    'nameUz': 'Osh',
    'nameEn': 'Plov',
    'category': 'TraditionalFood',
    'traditionalDishKey': 'plov',
    'confidence': 0.91,
    'estimatedWeightGrams': 350,
    'weightConfidence': 'Medium',
    'preparationMethod': 'Stewed',
    'preparationNote': null,
    'possibleAllergens': <String>[],
    'needsConfirmation': true,
    'notes': null,
    'userEdited': false,
    'totals': totalsJson(kcal, min: kcal * 0.7, max: kcal * 1.3, grams: _gramsOf(ingredients)),
    'ingredients': ingredients,
    'warnings': warnings,
  };
}

num _kcalOf(List<Map<String, dynamic>> ings) =>
    ings.fold<num>(0, (s, i) => s + (i['per100'] == null ? 0 : (i['per100']['kcal'] as num) * (i['grams'] as num) / 100));

num _gramsOf(List<Map<String, dynamic>> ings) => ings.fold<num>(0, (s, i) => s + (i['grams'] as num));

List<Map<String, dynamic>> plovIngredients() => [
  ingredientJson('i1', 'Рис', 180, 130),
  ingredientJson('i2', 'Говядина', 70, 250),
  ingredientJson('i3', 'Морковь', 50, 40),
  ingredientJson('i4', 'Хлопковое масло', 25, 884, role: 'Fat'),
];

Map<String, dynamic> scanJson({
  String id = 's1',
  String status = 'Recognized',
  List<Map<String, dynamic>>? dishes,
  String? question,
  String? quality,
}) => {
  'id': id,
  'kind': 'Photo',
  'status': status,
  'createdAt': '2026-11-18T08:00:00Z',
  'hasPhoto': true,
  'imageQuality': quality ?? 'good',
  'clarificationQuestion': question,
  'hint': null,
  'reused': false,
  'dishes': dishes ?? [dishJson(ingredients: plovIngredients())],
  'product': null,
  'barcode': null,
  'addedToDiaryAt': null,
};

Map<String, dynamic> productJson({String id = 'prod1'}) => {
  'id': id,
  'name': 'Кефир 2,5%',
  'nameUz': 'Kefir 2,5%',
  'nameEn': null,
  'brand': 'Musaffo',
  'category': 'Dairy',
  'per100': nutrientsJson(53, 2.9, 2.5, 4),
  'per100Ml': true,
  'source': 'OpenFoodFacts',
  'sourceRef': '4780000000017',
  'servingGrams': 250,
  'packageGrams': 900,
  'allergens': ['Milk'],
  'ingredientsText': 'Молоко нормализованное, закваска',
  'barcode': '4780000000017',
  'isOwn': false,
};

Map<String, dynamic> diaryItemJson(String id, String name, num grams, {num kcal100 = 130}) => {
  'id': id,
  'name': name,
  'productId': 'p-$id',
  'recipeId': null,
  'grams': grams,
  'role': 'Main',
  'per100': nutrientsJson(kcal100, 3, 1, 28),
  'nutrients': nutrientsJson(kcal100 * grams / 100, 3, 1, 28),
  'source': 'Usda',
  'sourceRef': '1',
  'hasNutrition': true,
};

Map<String, dynamic> entryJson({
  String id = 'e1',
  String meal = 'Lunch',
  String name = 'Плов',
  List<Map<String, dynamic>>? items,
}) {
  final its = items ?? [diaryItemJson('it1', 'Рис', 200), diaryItemJson('it2', 'Говядина', 100, kcal100: 250)];
  final kcal = its.fold<num>(0, (s, i) => s + (i['nutrients']['kcal'] as num));
  return {
    'id': id,
    'date': '2026-11-18',
    'mealType': meal,
    'eatenAt': '2026-11-18T08:30:00Z',
    'name': name,
    'scanId': null,
    'hasPhoto': false,
    'totals': totalsJson(kcal, grams: its.fold<num>(0, (s, i) => s + (i['grams'] as num))),
    'items': its,
    'createdAt': '2026-11-18T08:31:00Z',
  };
}

Map<String, dynamic> dayJson(List<Map<String, dynamic>> entries) {
  Map<String, dynamic> meal(String m) {
    final es = entries.where((e) => e['mealType'] == m).toList();
    final kcal = es.fold<num>(0, (s, e) => s + (e['totals']['values']['kcal'] as num));
    return {'mealType': m, 'totals': totalsJson(kcal, grams: 0), 'entries': es};
  }

  final kcal = entries.fold<num>(0, (s, e) => s + (e['totals']['values']['kcal'] as num));
  return {
    'date': '2026-11-18',
    'target': targetJson(),
    'totals': totalsJson(kcal, grams: 500),
    'meals': [meal('Breakfast'), meal('Lunch'), meal('Dinner'), meal('Snack')],
  };
}

Map<String, dynamic> periodJson() => {
  'from': '2026-11-12',
  'to': '2026-11-18',
  'target': targetJson(),
  'days': [
    for (var d = 12; d <= 18; d++)
      {
        'date': '2026-11-${d.toString().padLeft(2, '0')}',
        'entries': d == 14 ? 0 : 3,
        'kcal': d == 14 ? 0 : 1800 + d * 20,
        'protein': 100,
        'fat': 60,
        'carbs': 220,
        'fiber': 20,
        'sugar': 40,
        'targetKcal': 2200,
        'trainingSessions': d.isEven ? 1 : 0,
        'visited': d.isEven,
      },
  ],
  'average': nutrientsJson(2120, 100, 60, 220),
  'daysLogged': 6,
  'daysWithinTarget': 4,
  'trainingSessions': 4,
  'visits': 4,
};

http.Response problemResponse(int status, String code) => http.Response(
  jsonEncode({'title': code, 'status': status, 'code': code}),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class NutritionFake {
  NutritionFake(this.b, {bool consent = true, bool ai = true, bool target = true})
    : profile = nutritionProfileJson(consent: consent, ai: ai, target: target) {
    b.routes['/api/nutrition/profile'] = (req) {
      if (req.method == 'PUT') {
        profileUpdates.add(jsonDecode(req.body) as Map<String, dynamic>);
        profile = {...profile, 'target': targetJson(), 'missingForTarget': <String>[]};
      }
      return profile;
    };
    b.routes['/api/nutrition/ai-consent'] = (req) {
      consentCalls.add(req.method);
      profile = {...profile, 'aiConsentAt': req.method == 'POST' ? '2026-11-18T09:00:00Z' : null};
      return profile;
    };
    b.routes['/api/nutrition/daily'] = (_) => daily;
    b.routes['/api/food-scanner/history'] = (_) => paged(history);
    b.routes['/api/food-scanner/analyze'] = (req) {
      analyzeRequests.add(req);
      final error = analyzeError;
      if (error != null) return error;
      return scan;
    };
    b.routes['/api/food-scanner/result/s1'] = (req) {
      if (req.method == 'PUT') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        puts.add(body);
        final dishes = (scan['dishes'] as List).cast<Map<String, dynamic>>();
        final index = body['dishIndex'] as int;
        final old = dishes[index];
        final known = {
          for (final i in (old['ingredients'] as List).cast<Map<String, dynamic>>()) i['id'] as String: i,
        };
        var n = 0;
        final ingredients = [
          for (final i in (body['ingredients'] as List).cast<Map<String, dynamic>>())
            if (i['id'] != null && known.containsKey(i['id']))
              {...known[i['id']]!, 'grams': i['grams']}
            else
              ingredientJson('new${n++}', i['name'] as String? ?? 'Новый', i['grams'] as num, 100),
        ];
        dishes[index] = dishJson(
          id: old['id'] as String,
          index: index,
          name: body['name'] as String? ?? old['name'] as String,
          ingredients: ingredients,
        );
        scan = {...scan, 'dishes': dishes};
      }
      if (req.method == 'DELETE') {
        deleted = true;
        return http.Response('', 204);
      }
      return scan;
    };
    b.routes['/api/food-scanner/result/s1/photo'] = (_) => http.Response('', 404);
    b.routes['/api/food-diary'] = (req) {
      if (req.method == 'POST') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        diaryPosts.add(body);
        final entry = entryJson(id: 'new${diaryPosts.length}', meal: body['mealType'] as String);
        entries.add(entry);
        return http.Response(jsonEncode(entry), 201, headers: {'content-type': 'application/json'});
      }
      return dayJson(entries);
    };
    b.routes['/api/food-diary/recent'] = (_) => entries;
    b.routes['/api/food-scanner/barcode'] = (req) {
      final code = jsonDecode(req.body)['code'] as String;
      barcodes.add(code);
      if (code != '4780000000017') return problemResponse(404, 'barcode_not_found');
      return {
        ...scanJson(id: 'bc1', dishes: []),
        'kind': 'Barcode',
        'hasPhoto': false,
        'product': productJson(),
        'barcode': code,
      };
    };
    b.routes['/api/nutrition/weekly'] = (_) => periodJson();
    b.routes['/api/nutrition/monthly'] = (_) => periodJson();
    b.routes['/api/nutrition/report'] = (_) => {
      'period': 'Week',
      'from': '2026-11-12',
      'to': '2026-11-18',
      'text': 'За неделю вы в среднем съедали 2120 ккал — чуть ниже нормы.',
      'generatedAt': '2026-11-18T09:00:00Z',
      'cached': false,
    };
    b.routes['/api/nutrition/consultant/chat'] = (req) {
      chats.add(jsonDecode(req.body) as Map<String, dynamic>);
      return {
        'text': 'Сегодня вы съели 850 ккал, осталось 1350 ккал.',
        'dataUsed': ['diary_day', 'profile'],
      };
    };
    b.routes['/api/nutrition/foods/search'] = (_) => {
      'products': [productJson(id: 'prod2')],
      'recipes': <Object>[],
    };
  }

  final FakeBackend b;
  Map<String, dynamic> profile;
  Map<String, dynamic> daily = dailyJson();
  Map<String, dynamic> scan = scanJson();
  List<Map<String, dynamic>> history = [
    {
      'id': 's1',
      'kind': 'Photo',
      'status': 'Recognized',
      'createdAt': '2026-11-18T08:00:00Z',
      'hasPhoto': false,
      'title': 'Плов',
      'kcal': 640,
      'dishes': 1,
      'addedToDiaryAt': null,
    },
  ];
  final entries = <Map<String, dynamic>>[];

  /// Answer of the analyze endpoint instead of [scan] (an error).
  http.Response? analyzeError;

  final analyzeRequests = <http.Request>[];
  final puts = <Map<String, dynamic>>[];
  final diaryPosts = <Map<String, dynamic>>[];
  final consentCalls = <String>[];
  final profileUpdates = <Map<String, dynamic>>[];
  final barcodes = <String>[];
  final chats = <Map<String, dynamic>>[];
  bool deleted = false;
}
