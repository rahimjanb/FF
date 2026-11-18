import 'dart:typed_data';

import '../core/api_client.dart';
import 'models.dart' show Paged;
import 'nutrition_models.dart';

/// AI Food Scanner, food diary, nutrition profile, analytics and the AI consultant.
class NutritionRepository {
  NutritionRepository(this._api);
  final ApiClient _api;

  /// Photo analysis and label reading wait for the AI service: up to a minute or so.
  static const aiTimeout = Duration(seconds: 120);

  /// Reports and consultant answers are shorter texts.
  static const textTimeout = Duration(seconds: 90);

  // ---- Scanner -----------------------------------------------------------------------------------------------

  /// Sends a food photo (JPEG) for recognition; [hint] is what the client says is on it.
  Future<FoodScan> analyze(Uint8List jpeg, {String? hint}) async => FoodScan.fromJson(
    await _api.postMultipart(
      '/api/food-scanner/analyze',
      fields: {if (hint != null && hint.trim().isNotEmpty) 'hint': hint.trim()},
      files: [UploadFile('photo', jpeg, filename: 'food.jpg', contentType: 'image/jpeg')],
      timeout: aiTimeout,
    ) as Map<String, dynamic>,
  );

  /// Reads the nutrition facts of a package from its label photo; [barcode] links the product to it.
  Future<FoodScan> readLabel(Uint8List jpeg, {String? barcode}) async => FoodScan.fromJson(
    await _api.postMultipart(
      '/api/food-scanner/label',
      fields: {'barcode': ?barcode},
      files: [UploadFile('photo', jpeg, filename: 'label.jpg', contentType: 'image/jpeg')],
      timeout: aiTimeout,
    ) as Map<String, dynamic>,
  );

  /// Looks a product up by barcode; throws ApiException `barcode_not_found` when no database knows it.
  Future<FoodScan> barcode(String code) async =>
      FoodScan.fromJson(await _api.post('/api/food-scanner/barcode', {'code': code}) as Map<String, dynamic>);

  Future<Paged<FoodScanSummary>> history({int page = 1, int pageSize = 20}) async => Paged.fromJson(
    await _api.get('/api/food-scanner/history', query: {'page': '$page', 'pageSize': '$pageSize'})
        as Map<String, dynamic>,
    FoodScanSummary.fromJson,
  );

  Future<FoodScan> scan(String id) async =>
      FoodScan.fromJson(await _api.get('/api/food-scanner/result/$id') as Map<String, dynamic>);

  /// Saves the client's correction of a dish; the answer carries the recalculated totals.
  Future<FoodScan> updateDish(
    String scanId, {
    required int dishIndex,
    String? name,
    required List<DishIngredientInput> ingredients,
  }) async => FoodScan.fromJson(
    await _api.put('/api/food-scanner/result/$scanId', {
          'dishIndex': dishIndex,
          'name': name,
          'ingredients': [for (final i in ingredients) i.toJson()],
        })
        as Map<String, dynamic>,
  );

  /// Deletes the scan and its photo.
  Future<void> deleteScan(String id) => _api.delete('/api/food-scanner/result/$id');

  Future<Uint8List> scanPhoto(String id) => _api.getBytes('/api/food-scanner/result/$id/photo');

  Future<void> deleteScanPhoto(String id) => _api.delete('/api/food-scanner/result/$id/photo');

  // ---- Diary -------------------------------------------------------------------------------------------------

  Future<DiaryDay> diaryDay(DateTime date) async =>
      DiaryDay.fromJson(await _api.get('/api/food-diary', query: {'date': dateParam(date)}) as Map<String, dynamic>);

  Future<List<DiaryEntry>> recentEntries({int take = 20}) async =>
      (await _api.get('/api/food-diary/recent', query: {'take': '$take'}) as List)
          .map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<DiaryEntry> addEntry(SaveDiaryEntry entry) async =>
      DiaryEntry.fromJson(await _api.post('/api/food-diary', entry.toJson()) as Map<String, dynamic>);

  Future<DiaryEntry> entry(String id) async =>
      DiaryEntry.fromJson(await _api.get('/api/food-diary/$id') as Map<String, dynamic>);

  Future<DiaryEntry> updateEntry(String id, SaveDiaryEntry entry) async =>
      DiaryEntry.fromJson(await _api.put('/api/food-diary/$id', entry.toJson()) as Map<String, dynamic>);

  Future<void> deleteEntry(String id) => _api.delete('/api/food-diary/$id');

  /// Copies the entry to [date] (today by default).
  Future<DiaryEntry> repeatEntry(String id, {DateTime? date, MealType? mealType}) async => DiaryEntry.fromJson(
    await _api.post('/api/food-diary/$id/repeat', {
          'date': date == null ? null : dateParam(date),
          'mealType': mealType == null ? null : wireName(mealType),
        })
        as Map<String, dynamic>,
  );

  // ---- Profile -----------------------------------------------------------------------------------------------

  Future<NutritionProfile> profile() async =>
      NutritionProfile.fromJson(await _api.get('/api/nutrition/profile') as Map<String, dynamic>);

  Future<NutritionProfile> updateProfile(NutritionProfileUpdate update) async =>
      NutritionProfile.fromJson(await _api.put('/api/nutrition/profile', update.toJson()) as Map<String, dynamic>);

  Future<NutritionProfile> giveAiConsent() async =>
      NutritionProfile.fromJson(await _api.post('/api/nutrition/ai-consent') as Map<String, dynamic>);

  Future<NutritionProfile> revokeAiConsent() async =>
      NutritionProfile.fromJson(await _api.delete('/api/nutrition/ai-consent') as Map<String, dynamic>);

  // ---- Analytics ---------------------------------------------------------------------------------------------

  Future<NutritionDaily> daily([DateTime? date]) async => NutritionDaily.fromJson(
    await _api.get('/api/nutrition/daily', query: {'date': date == null ? null : dateParam(date)})
        as Map<String, dynamic>,
  );

  Future<NutritionPeriod> weekly([DateTime? end]) async => NutritionPeriod.fromJson(
    await _api.get('/api/nutrition/weekly', query: {'end': end == null ? null : dateParam(end)})
        as Map<String, dynamic>,
  );

  Future<NutritionPeriod> monthly(DateTime month) async => NutritionPeriod.fromJson(
    await _api.get('/api/nutrition/monthly', query: {'month': monthParam(month)}) as Map<String, dynamic>,
  );

  /// The AI-written report for the day or the week ending on [date].
  Future<NutritionReport> report(NutritionReportPeriod period, DateTime date, String locale) async =>
      NutritionReport.fromJson(
        await _api.get(
              '/api/nutrition/report',
              query: {'period': wireName(period), 'date': dateParam(date), 'locale': locale},
              timeout: textTimeout,
            )
            as Map<String, dynamic>,
      );

  // ---- Consultant --------------------------------------------------------------------------------------------

  /// Sends the conversation (the last 20 messages, ending with the client's question) and returns the answer.
  Future<ConsultantReply> ask(List<ChatMessage> conversation, String locale) async {
    final recent = conversation.length > 20 ? conversation.sublist(conversation.length - 20) : conversation;
    // The server expects the conversation to start with the client.
    final start = recent.indexWhere((m) => m.fromUser);
    return ConsultantReply.fromJson(
      await _api.send(
            'POST',
            '/api/nutrition/consultant/chat',
            body: {
              'messages': [for (final m in recent.sublist(start < 0 ? 0 : start)) m.toJson()],
              'locale': locale,
            },
            timeout: textTimeout,
          )
          as Map<String, dynamic>,
    );
  }

  // ---- Food database -----------------------------------------------------------------------------------------

  Future<FoodSearchResult> search(String query, {int take = 20}) async => FoodSearchResult.fromJson(
    await _api.get('/api/nutrition/foods/search', query: {'q': query, 'take': '$take'}) as Map<String, dynamic>,
  );

  Future<FoodProduct> product(String id) async =>
      FoodProduct.fromJson(await _api.get('/api/nutrition/foods/$id') as Map<String, dynamic>);

  Future<FoodProduct> createProduct(NewFoodProduct product) async =>
      FoodProduct.fromJson(await _api.post('/api/nutrition/foods', product.toJson()) as Map<String, dynamic>);

  Future<void> deleteProduct(String id) => _api.delete('/api/nutrition/foods/$id');

  Future<FoodRecipe> recipe(String id) async =>
      FoodRecipe.fromJson(await _api.get('/api/nutrition/recipes/$id') as Map<String, dynamic>);
}
