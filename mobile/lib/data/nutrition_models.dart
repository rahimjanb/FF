// DTOs of the AI Food Scanner, food diary and nutrition analytics, mirroring the backend
// (FitnessFormulasi.Api.Features.Nutrition.NutritionDtos). Enums arrive and leave as their C# names.

DateTime? _dt(Object? v) => v == null ? null : DateTime.parse(v as String);

/// A club-local calendar date (yyyy-MM-dd) without time zone conversion.
DateTime? _date(Object? v) {
  if (v == null) return null;
  final p = (v as String).split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// yyyy-MM-dd for a calendar date.
String dateParam(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// yyyy-MM for a month.
String monthParam(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

double _num(Object? v) => (v as num).toDouble();
double? _numOrNull(Object? v) => v == null ? null : (v as num).toDouble();

T _enum<T extends Enum>(List<T> values, Object? raw, T fallback) {
  final s = (raw as String?)?.toLowerCase();
  return values.firstWhere((v) => v.name.toLowerCase() == s, orElse: () => fallback);
}

T? _enumOrNull<T extends Enum>(List<T> values, Object? raw) {
  if (raw == null) return null;
  final s = (raw as String).toLowerCase();
  for (final v in values) {
    if (v.name.toLowerCase() == s) return v;
  }
  return null;
}

List<T> _enumList<T extends Enum>(List<T> values, Object? raw) => [
  for (final v in (raw as List? ?? const []))
    if (_enumOrNull(values, v) case final T e) e,
];

/// The C# name of a Dart enum value (deepFried → DeepFried).
String wireName(Enum e) => e.name[0].toUpperCase() + e.name.substring(1);

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) f) =>
    [for (final e in (raw as List? ?? const [])) f(e as Map<String, dynamic>)];

enum MealType { breakfast, lunch, dinner, snack }

enum FoodCategory {
  breakfast,
  lunch,
  dinner,
  snacks,
  fruits,
  vegetables,
  meat,
  fish,
  dairy,
  bakery,
  desserts,
  fastFood,
  drinks,
  packagedFood,
  traditionalFood,
  grains,
  legumes,
  nutsSeeds,
  fatsOils,
  sauces,
  eggs,
  other,
}

enum NutritionSource { usda, openFoodFacts, label, recipe, user }

enum Allergen { gluten, milk, eggs, nuts, peanuts, sesame, soy, fish, shellfish, molluscs, celery, mustard, sulphites, lupin }

enum IngredientRole { main, fat, sauce, garnish, drink }

enum PreparationMethod { raw, boiled, steamed, fried, deepFried, baked, grilled, stewed, mixed, unknown }

enum WeightConfidence { low, medium, high }

enum FoodScanKind { photo, label, barcode }

enum FoodScanStatus { recognized, needsClarification, notFood, failed }

enum IngredientMatch { catalogKey, nameSearch, external, user, none }

enum NutritionGoal { lose, maintain, gain }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

enum NutritionReportPeriod { day, week }

enum Sex { male, female }

/// Nutrition values per 100 g (or 100 ml) of a product, or for a given weight. Null: the source has no value.
class Nutrients {
  const Nutrients({
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.fiber,
    this.sugar,
    this.saturatedFat,
    this.sodiumMg,
  });
  factory Nutrients.fromJson(Map<String, dynamic> j) => Nutrients(
    kcal: _num(j['kcal']),
    protein: _num(j['protein']),
    fat: _num(j['fat']),
    carbs: _num(j['carbs']),
    fiber: _numOrNull(j['fiber']),
    sugar: _numOrNull(j['sugar']),
    saturatedFat: _numOrNull(j['saturatedFat']),
    sodiumMg: _numOrNull(j['sodiumMg']),
  );
  static const zero = Nutrients(kcal: 0, protein: 0, fat: 0, carbs: 0);

  final double kcal, protein, fat, carbs;
  final double? fiber, sugar, saturatedFat, sodiumMg;

  /// Values for [grams] of a food whose values per 100 g these are (shown before the server answers).
  Nutrients forGrams(double grams) {
    double? s(double? v) => v == null ? null : v * grams / 100;
    return Nutrients(
      kcal: kcal * grams / 100,
      protein: protein * grams / 100,
      fat: fat * grams / 100,
      carbs: carbs * grams / 100,
      fiber: s(fiber),
      sugar: s(sugar),
      saturatedFat: s(saturatedFat),
      sodiumMg: s(sodiumMg),
    );
  }
}

/// Totals of a dish, an entry or a day; [kcalMin]..[kcalMax] is how far off the estimate may be.
class NutritionTotals {
  const NutritionTotals({
    required this.values,
    required this.grams,
    required this.kcalMin,
    required this.kcalMax,
    required this.incomplete,
  });
  factory NutritionTotals.fromJson(Map<String, dynamic> j) => NutritionTotals(
    values: Nutrients.fromJson(j['values'] as Map<String, dynamic>),
    grams: _num(j['grams']),
    kcalMin: _num(j['kcalMin']),
    kcalMax: _num(j['kcalMax']),
    incomplete: j['incomplete'] as bool? ?? false,
  );
  static const empty = NutritionTotals(values: Nutrients.zero, grams: 0, kcalMin: 0, kcalMax: 0, incomplete: false);

  final Nutrients values;
  final double grams, kcalMin, kcalMax;

  /// An ingredient has no nutrition values, so the real totals are higher.
  final bool incomplete;

  double get kcal => values.kcal;
}

class FoodProduct {
  FoodProduct({
    required this.id,
    required this.name,
    this.nameUz,
    this.nameEn,
    this.brand,
    required this.category,
    required this.per100,
    this.per100Ml = false,
    required this.source,
    this.sourceRef,
    this.servingGrams,
    this.packageGrams,
    this.allergens = const [],
    this.ingredientsText,
    this.barcode,
    this.isOwn = false,
  });
  factory FoodProduct.fromJson(Map<String, dynamic> j) => FoodProduct(
    id: j['id'] as String,
    name: j['name'] as String,
    nameUz: j['nameUz'] as String?,
    nameEn: j['nameEn'] as String?,
    brand: j['brand'] as String?,
    category: _enum(FoodCategory.values, j['category'], FoodCategory.other),
    per100: Nutrients.fromJson(j['per100'] as Map<String, dynamic>),
    per100Ml: j['per100Ml'] as bool? ?? false,
    source: _enum(NutritionSource.values, j['source'], NutritionSource.user),
    sourceRef: j['sourceRef'] as String?,
    servingGrams: _numOrNull(j['servingGrams']),
    packageGrams: _numOrNull(j['packageGrams']),
    allergens: _enumList(Allergen.values, j['allergens']),
    ingredientsText: j['ingredientsText'] as String?,
    barcode: j['barcode'] as String?,
    isOwn: j['isOwn'] as bool? ?? false,
  );
  final String id, name;
  final String? nameUz, nameEn, brand, sourceRef, ingredientsText, barcode;
  final FoodCategory category;
  final Nutrients per100;

  /// Values are per 100 ml (a drink).
  final bool per100Ml;
  final NutritionSource source;
  final double? servingGrams, packageGrams;
  final List<Allergen> allergens;
  final bool isOwn;

  String localName(String lang) => lang == 'uz' ? (nameUz ?? name) : name;
}

class FoodRecipeSummary {
  FoodRecipeSummary({
    required this.id,
    required this.name,
    this.nameUz,
    this.nameEn,
    required this.category,
    required this.isTraditional,
    this.dishKey,
    required this.portionGrams,
    required this.per100,
    this.isOwn = false,
  });
  factory FoodRecipeSummary.fromJson(Map<String, dynamic> j) => FoodRecipeSummary(
    id: j['id'] as String,
    name: j['name'] as String,
    nameUz: j['nameUz'] as String?,
    nameEn: j['nameEn'] as String?,
    category: _enum(FoodCategory.values, j['category'], FoodCategory.other),
    isTraditional: j['isTraditional'] as bool? ?? false,
    dishKey: j['dishKey'] as String?,
    portionGrams: _num(j['portionGrams']),
    per100: Nutrients.fromJson(j['per100'] as Map<String, dynamic>),
    isOwn: j['isOwn'] as bool? ?? false,
  );
  final String id, name;
  final String? nameUz, nameEn, dishKey;
  final FoodCategory category;
  final bool isTraditional, isOwn;
  final double portionGrams;
  final Nutrients per100;

  String localName(String lang) => lang == 'uz' ? (nameUz ?? name) : name;
}

class FoodRecipeIngredient {
  FoodRecipeIngredient({
    required this.productId,
    required this.name,
    this.nameUz,
    required this.grams,
    required this.role,
    required this.per100,
    required this.source,
  });
  factory FoodRecipeIngredient.fromJson(Map<String, dynamic> j) => FoodRecipeIngredient(
    productId: j['productId'] as String,
    name: j['name'] as String,
    nameUz: j['nameUz'] as String?,
    grams: _num(j['grams']),
    role: _enum(IngredientRole.values, j['role'], IngredientRole.main),
    per100: Nutrients.fromJson(j['per100'] as Map<String, dynamic>),
    source: _enum(NutritionSource.values, j['source'], NutritionSource.usda),
  );
  final String productId, name;
  final String? nameUz;
  final double grams;
  final IngredientRole role;
  final Nutrients per100;
  final NutritionSource source;

  String localName(String lang) => lang == 'uz' ? (nameUz ?? name) : name;
}

class FoodRecipe {
  FoodRecipe({required this.summary, this.description, this.yieldGrams, required this.ingredients});
  factory FoodRecipe.fromJson(Map<String, dynamic> j) => FoodRecipe(
    summary: FoodRecipeSummary.fromJson(j),
    description: j['description'] as String?,
    yieldGrams: _numOrNull(j['yieldGrams']),
    ingredients: _list(j['ingredients'], FoodRecipeIngredient.fromJson),
  );
  final FoodRecipeSummary summary;
  final String? description;
  final double? yieldGrams;
  final List<FoodRecipeIngredient> ingredients;
}

class FoodSearchResult {
  FoodSearchResult(this.products, this.recipes);
  factory FoodSearchResult.fromJson(Map<String, dynamic> j) => FoodSearchResult(
    _list(j['products'], FoodProduct.fromJson),
    _list(j['recipes'], FoodRecipeSummary.fromJson),
  );
  final List<FoodProduct> products;
  final List<FoodRecipeSummary> recipes;
}

/// An ingredient of a recognized dish. [per100] null: no product found, it counts as zero.
class FoodScanIngredient {
  FoodScanIngredient({
    required this.id,
    required this.name,
    this.productId,
    this.productName,
    required this.grams,
    required this.role,
    required this.match,
    required this.uncertainty,
    this.per100,
    this.nutrients,
    this.source,
    this.sourceRef,
  });
  factory FoodScanIngredient.fromJson(Map<String, dynamic> j) => FoodScanIngredient(
    id: j['id'] as String,
    name: j['name'] as String,
    productId: j['productId'] as String?,
    productName: j['productName'] as String?,
    grams: _num(j['grams']),
    role: _enum(IngredientRole.values, j['role'], IngredientRole.main),
    match: _enum(IngredientMatch.values, j['match'], IngredientMatch.none),
    uncertainty: _numOrNull(j['uncertainty']) ?? 0,
    per100: j['per100'] == null ? null : Nutrients.fromJson(j['per100'] as Map<String, dynamic>),
    nutrients: j['nutrients'] == null ? null : Nutrients.fromJson(j['nutrients'] as Map<String, dynamic>),
    source: _enumOrNull(NutritionSource.values, j['source']),
    sourceRef: j['sourceRef'] as String?,
  );
  final String id, name;
  final String? productId, productName, sourceRef;
  final double grams, uncertainty;
  final IngredientRole role;
  final IngredientMatch match;
  final Nutrients? per100, nutrients;
  final NutritionSource? source;

  bool get matched => per100 != null;
}

class FoodDish {
  FoodDish({
    required this.id,
    required this.index,
    required this.name,
    this.nameUz,
    this.nameEn,
    required this.category,
    this.traditionalDishKey,
    required this.confidence,
    required this.estimatedWeightGrams,
    required this.weightConfidence,
    required this.preparationMethod,
    this.preparationNote,
    this.possibleAllergens = const [],
    this.needsConfirmation = false,
    this.notes,
    this.userEdited = false,
    required this.totals,
    required this.ingredients,
    this.warnings = const [],
  });
  factory FoodDish.fromJson(Map<String, dynamic> j) => FoodDish(
    id: j['id'] as String,
    index: j['index'] as int? ?? 0,
    name: j['name'] as String,
    nameUz: j['nameUz'] as String?,
    nameEn: j['nameEn'] as String?,
    category: _enum(FoodCategory.values, j['category'], FoodCategory.other),
    traditionalDishKey: j['traditionalDishKey'] as String?,
    confidence: _numOrNull(j['confidence']) ?? 0,
    estimatedWeightGrams: _numOrNull(j['estimatedWeightGrams']) ?? 0,
    weightConfidence: _enum(WeightConfidence.values, j['weightConfidence'], WeightConfidence.medium),
    preparationMethod: _enum(PreparationMethod.values, j['preparationMethod'], PreparationMethod.unknown),
    preparationNote: j['preparationNote'] as String?,
    possibleAllergens: _enumList(Allergen.values, j['possibleAllergens']),
    needsConfirmation: j['needsConfirmation'] as bool? ?? false,
    notes: j['notes'] as String?,
    userEdited: j['userEdited'] as bool? ?? false,
    totals: NutritionTotals.fromJson(j['totals'] as Map<String, dynamic>),
    ingredients: _list(j['ingredients'], FoodScanIngredient.fromJson),
    warnings: [for (final w in (j['warnings'] as List? ?? const [])) w as String],
  );
  final String id, name;
  final String? nameUz, nameEn, traditionalDishKey, preparationNote, notes;
  final int index;
  final FoodCategory category;
  final double confidence, estimatedWeightGrams;
  final WeightConfidence weightConfidence;
  final PreparationMethod preparationMethod;
  final List<Allergen> possibleAllergens;
  final bool needsConfirmation, userEdited;
  final NutritionTotals totals;
  final List<FoodScanIngredient> ingredients;

  /// Codes: low_confidence, weight_uncertain, unmatched_ingredients, cooking_fat_missing, multiple_dishes.
  final List<String> warnings;

  String localName(String lang) => lang == 'uz' ? (nameUz ?? name) : name;
}

class FoodScan {
  FoodScan({
    required this.id,
    required this.kind,
    required this.status,
    required this.createdAt,
    required this.hasPhoto,
    this.imageQuality,
    this.clarificationQuestion,
    this.hint,
    this.reused = false,
    this.dishes = const [],
    this.product,
    this.barcode,
    this.addedToDiaryAt,
  });
  factory FoodScan.fromJson(Map<String, dynamic> j) => FoodScan(
    id: j['id'] as String,
    kind: _enum(FoodScanKind.values, j['kind'], FoodScanKind.photo),
    status: _enum(FoodScanStatus.values, j['status'], FoodScanStatus.failed),
    createdAt: _dt(j['createdAt'])!,
    hasPhoto: j['hasPhoto'] as bool? ?? false,
    imageQuality: j['imageQuality'] as String?,
    clarificationQuestion: j['clarificationQuestion'] as String?,
    hint: j['hint'] as String?,
    reused: j['reused'] as bool? ?? false,
    dishes: _list(j['dishes'], FoodDish.fromJson),
    product: j['product'] == null ? null : FoodProduct.fromJson(j['product'] as Map<String, dynamic>),
    barcode: j['barcode'] as String?,
    addedToDiaryAt: _dt(j['addedToDiaryAt']),
  );
  final String id;
  final FoodScanKind kind;
  final FoodScanStatus status;
  final DateTime createdAt;
  final bool hasPhoto, reused;

  /// good, blurry, dark, partial.
  final String? imageQuality, clarificationQuestion, hint, barcode;
  final List<FoodDish> dishes;
  final FoodProduct? product;
  final DateTime? addedToDiaryAt;
}

class FoodScanSummary {
  FoodScanSummary({
    required this.id,
    required this.kind,
    required this.status,
    required this.createdAt,
    required this.hasPhoto,
    required this.title,
    this.kcal,
    this.dishes = 0,
    this.addedToDiaryAt,
  });
  factory FoodScanSummary.fromJson(Map<String, dynamic> j) => FoodScanSummary(
    id: j['id'] as String,
    kind: _enum(FoodScanKind.values, j['kind'], FoodScanKind.photo),
    status: _enum(FoodScanStatus.values, j['status'], FoodScanStatus.failed),
    createdAt: _dt(j['createdAt'])!,
    hasPhoto: j['hasPhoto'] as bool? ?? false,
    title: j['title'] as String? ?? '',
    kcal: _numOrNull(j['kcal']),
    dishes: j['dishes'] as int? ?? 0,
    addedToDiaryAt: _dt(j['addedToDiaryAt']),
  );
  final String id, title;
  final FoodScanKind kind;
  final FoodScanStatus status;
  final DateTime createdAt;
  final bool hasPhoto;
  final double? kcal;
  final int dishes;
  final DateTime? addedToDiaryAt;
}

// ---- Diary ------------------------------------------------------------------------------------------------------

class DiaryItem {
  DiaryItem({
    required this.id,
    required this.name,
    this.productId,
    this.recipeId,
    required this.grams,
    required this.role,
    this.per100,
    required this.nutrients,
    this.source,
    this.sourceRef,
    required this.hasNutrition,
  });
  factory DiaryItem.fromJson(Map<String, dynamic> j) => DiaryItem(
    id: j['id'] as String,
    name: j['name'] as String,
    productId: j['productId'] as String?,
    recipeId: j['recipeId'] as String?,
    grams: _num(j['grams']),
    role: _enum(IngredientRole.values, j['role'], IngredientRole.main),
    per100: j['per100'] == null ? null : Nutrients.fromJson(j['per100'] as Map<String, dynamic>),
    nutrients: Nutrients.fromJson(j['nutrients'] as Map<String, dynamic>),
    source: _enumOrNull(NutritionSource.values, j['source']),
    sourceRef: j['sourceRef'] as String?,
    hasNutrition: j['hasNutrition'] as bool? ?? true,
  );
  final String id, name;
  final String? productId, recipeId, sourceRef;
  final double grams;
  final IngredientRole role;
  final Nutrients? per100;
  final Nutrients nutrients;
  final NutritionSource? source;
  final bool hasNutrition;
}

class DiaryEntry {
  DiaryEntry({
    required this.id,
    required this.date,
    required this.mealType,
    required this.eatenAt,
    required this.name,
    this.scanId,
    this.hasPhoto = false,
    required this.totals,
    required this.items,
    required this.createdAt,
  });
  factory DiaryEntry.fromJson(Map<String, dynamic> j) => DiaryEntry(
    id: j['id'] as String,
    date: _date(j['date'])!,
    mealType: _enum(MealType.values, j['mealType'], MealType.snack),
    eatenAt: _dt(j['eatenAt'])!,
    name: j['name'] as String,
    scanId: j['scanId'] as String?,
    hasPhoto: j['hasPhoto'] as bool? ?? false,
    totals: NutritionTotals.fromJson(j['totals'] as Map<String, dynamic>),
    items: _list(j['items'], DiaryItem.fromJson),
    createdAt: _dt(j['createdAt']) ?? DateTime.now(),
  );
  final String id, name;
  final DateTime date, eatenAt, createdAt;
  final MealType mealType;
  final String? scanId;
  final bool hasPhoto;
  final NutritionTotals totals;
  final List<DiaryItem> items;
}

class DiaryMeal {
  DiaryMeal(this.mealType, this.totals, this.entries);
  factory DiaryMeal.fromJson(Map<String, dynamic> j) => DiaryMeal(
    _enum(MealType.values, j['mealType'], MealType.snack),
    NutritionTotals.fromJson(j['totals'] as Map<String, dynamic>),
    _list(j['entries'], DiaryEntry.fromJson),
  );
  final MealType mealType;
  final NutritionTotals totals;
  final List<DiaryEntry> entries;
}

class DiaryDay {
  DiaryDay({required this.date, this.target, required this.totals, required this.meals});
  factory DiaryDay.fromJson(Map<String, dynamic> j) => DiaryDay(
    date: _date(j['date'])!,
    target: j['target'] == null ? null : NutritionTarget.fromJson(j['target'] as Map<String, dynamic>),
    totals: NutritionTotals.fromJson(j['totals'] as Map<String, dynamic>),
    meals: _list(j['meals'], DiaryMeal.fromJson),
  );
  final DateTime date;
  final NutritionTarget? target;
  final NutritionTotals totals;
  final List<DiaryMeal> meals;

  /// The meal section of [type]; empty when the server left it out.
  DiaryMeal meal(MealType type) =>
      meals.firstWhere((m) => m.mealType == type, orElse: () => DiaryMeal(type, NutritionTotals.empty, const []));
}

// ---- Profile and target -----------------------------------------------------------------------------------------

class NutritionTarget {
  NutritionTarget({
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.fiberG,
    required this.sodiumMaxMg,
    required this.method,
    this.bmr,
    this.tdee,
  });
  factory NutritionTarget.fromJson(Map<String, dynamic> j) => NutritionTarget(
    kcal: j['kcal'] as int,
    proteinG: j['proteinG'] as int,
    fatG: j['fatG'] as int,
    carbsG: j['carbsG'] as int,
    fiberG: j['fiberG'] as int? ?? 0,
    sodiumMaxMg: j['sodiumMaxMg'] as int? ?? 0,
    method: j['method'] as String? ?? '',
    bmr: j['bmr'] as int?,
    tdee: j['tdee'] as int?,
  );
  final int kcal, proteinG, fatG, carbsG, fiberG, sodiumMaxMg;

  /// MifflinStJeor or Custom.
  final String method;
  final int? bmr, tdee;
}

class NutritionProfile {
  NutritionProfile({
    this.goal,
    this.weightKg,
    this.heightCm,
    this.activity,
    this.sex,
    this.birthDate,
    this.customKcalTarget,
    this.restrictions,
    this.allergies = const [],
    this.aiConsentAt,
    this.aiAvailable = false,
    this.aiProvider,
    this.scansPerDay = 0,
    this.scansToday = 0,
    this.target,
    this.missingForTarget = const [],
  });
  factory NutritionProfile.fromJson(Map<String, dynamic> j) => NutritionProfile(
    goal: _enumOrNull(NutritionGoal.values, j['goal']),
    weightKg: _numOrNull(j['weightKg']),
    heightCm: _numOrNull(j['heightCm']),
    activity: _enumOrNull(ActivityLevel.values, j['activity']),
    sex: _enumOrNull(Sex.values, j['sex']),
    birthDate: _date(j['birthDate']),
    customKcalTarget: j['customKcalTarget'] as int?,
    restrictions: j['restrictions'] as String?,
    allergies: _enumList(Allergen.values, j['allergies']),
    aiConsentAt: _dt(j['aiConsentAt']),
    aiAvailable: j['aiAvailable'] as bool? ?? false,
    aiProvider: j['aiProvider'] as String?,
    scansPerDay: j['scansPerDay'] as int? ?? 0,
    scansToday: j['scansToday'] as int? ?? 0,
    target: j['target'] == null ? null : NutritionTarget.fromJson(j['target'] as Map<String, dynamic>),
    missingForTarget: [for (final m in (j['missingForTarget'] as List? ?? const [])) m as String],
  );
  final NutritionGoal? goal;
  final double? weightKg, heightCm;
  final ActivityLevel? activity;
  final Sex? sex;
  final DateTime? birthDate;
  final int? customKcalTarget;
  final String? restrictions;
  final List<Allergen> allergies;

  /// When the client agreed to sending photos and nutrition data to the AI service; null: not yet.
  final DateTime? aiConsentAt;

  /// The club has an AI service connected.
  final bool aiAvailable;
  final String? aiProvider;
  final int scansPerDay, scansToday;
  final NutritionTarget? target;
  final List<String> missingForTarget;

  bool get hasAiConsent => aiConsentAt != null;
}

class NutritionProfileUpdate {
  NutritionProfileUpdate({
    this.goal,
    this.weightKg,
    this.heightCm,
    this.activity,
    this.sex,
    this.birthDate,
    this.customKcalTarget,
    this.restrictions,
    this.allergies = const [],
  });
  final NutritionGoal? goal;
  final double? weightKg, heightCm;
  final ActivityLevel? activity;
  final Sex? sex;
  final DateTime? birthDate;
  final int? customKcalTarget;
  final String? restrictions;
  final List<Allergen> allergies;

  Map<String, dynamic> toJson() => {
    'goal': goal == null ? null : wireName(goal!),
    'weightKg': weightKg,
    'heightCm': heightCm,
    'activity': activity == null ? null : wireName(activity!),
    'sex': sex == null ? null : wireName(sex!),
    'birthDate': birthDate == null ? null : dateParam(birthDate!),
    'customKcalTarget': customKcalTarget,
    'restrictions': restrictions,
    'allergies': [for (final a in allergies) wireName(a)],
  };
}

// ---- Analytics --------------------------------------------------------------------------------------------------

class NutritionDayStat {
  NutritionDayStat({
    required this.date,
    required this.entries,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.fiber,
    required this.sugar,
    this.targetKcal,
    this.trainingSessions = 0,
    this.visited = false,
  });
  factory NutritionDayStat.fromJson(Map<String, dynamic> j) => NutritionDayStat(
    date: _date(j['date'])!,
    entries: j['entries'] as int? ?? 0,
    kcal: _num(j['kcal']),
    protein: _num(j['protein']),
    fat: _num(j['fat']),
    carbs: _num(j['carbs']),
    fiber: _numOrNull(j['fiber']) ?? 0,
    sugar: _numOrNull(j['sugar']) ?? 0,
    targetKcal: j['targetKcal'] as int?,
    trainingSessions: j['trainingSessions'] as int? ?? 0,
    visited: j['visited'] as bool? ?? false,
  );
  final DateTime date;
  final int entries, trainingSessions;
  final double kcal, protein, fat, carbs, fiber, sugar;
  final int? targetKcal;
  final bool visited;
}

class NutritionDaily {
  NutritionDaily({
    required this.date,
    this.target,
    required this.totals,
    this.remainingKcal,
    required this.kcalByMeal,
    required this.entries,
    this.trainingSessions = 0,
    this.visited = false,
  });
  factory NutritionDaily.fromJson(Map<String, dynamic> j) => NutritionDaily(
    date: _date(j['date'])!,
    target: j['target'] == null ? null : NutritionTarget.fromJson(j['target'] as Map<String, dynamic>),
    totals: NutritionTotals.fromJson(j['totals'] as Map<String, dynamic>),
    remainingKcal: _numOrNull(j['remainingKcal']),
    kcalByMeal: {
      for (final e in (j['kcalByMeal'] as Map<String, dynamic>? ?? const {}).entries)
        if (_enumOrNull(MealType.values, e.key) case final MealType m) m: _num(e.value),
    },
    entries: j['entries'] as int? ?? 0,
    trainingSessions: j['trainingSessions'] as int? ?? 0,
    visited: j['visited'] as bool? ?? false,
  );
  final DateTime date;
  final NutritionTarget? target;
  final NutritionTotals totals;
  final double? remainingKcal;
  final Map<MealType, double> kcalByMeal;
  final int entries, trainingSessions;
  final bool visited;
}

class NutritionPeriod {
  NutritionPeriod({
    required this.from,
    required this.to,
    this.target,
    required this.days,
    this.average,
    required this.daysLogged,
    required this.daysWithinTarget,
    this.trainingSessions = 0,
    this.visits = 0,
  });
  factory NutritionPeriod.fromJson(Map<String, dynamic> j) => NutritionPeriod(
    from: _date(j['from'])!,
    to: _date(j['to'])!,
    target: j['target'] == null ? null : NutritionTarget.fromJson(j['target'] as Map<String, dynamic>),
    days: _list(j['days'], NutritionDayStat.fromJson),
    average: j['average'] == null ? null : Nutrients.fromJson(j['average'] as Map<String, dynamic>),
    daysLogged: j['daysLogged'] as int? ?? 0,
    daysWithinTarget: j['daysWithinTarget'] as int? ?? 0,
    trainingSessions: j['trainingSessions'] as int? ?? 0,
    visits: j['visits'] as int? ?? 0,
  );
  final DateTime from, to;
  final NutritionTarget? target;
  final List<NutritionDayStat> days;
  final Nutrients? average;
  final int daysLogged, daysWithinTarget, trainingSessions, visits;
}

class NutritionReport {
  NutritionReport({
    required this.period,
    required this.from,
    required this.to,
    required this.text,
    required this.generatedAt,
    this.cached = false,
  });
  factory NutritionReport.fromJson(Map<String, dynamic> j) => NutritionReport(
    period: _enum(NutritionReportPeriod.values, j['period'], NutritionReportPeriod.day),
    from: _date(j['from'])!,
    to: _date(j['to'])!,
    text: j['text'] as String? ?? '',
    generatedAt: _dt(j['generatedAt']) ?? DateTime.now(),
    cached: j['cached'] as bool? ?? false,
  );
  final NutritionReportPeriod period;
  final DateTime from, to, generatedAt;
  final String text;
  final bool cached;
}

// ---- Consultant -------------------------------------------------------------------------------------------------

class ChatMessage {
  const ChatMessage({required this.fromUser, required this.text, this.dataUsed = const []});
  final bool fromUser;
  final String text;

  /// Which of the client's data the answer was based on (assistant messages).
  final List<String> dataUsed;

  Map<String, dynamic> toJson() => {'role': fromUser ? 'user' : 'assistant', 'text': text};
}

class ConsultantReply {
  ConsultantReply(this.text, this.dataUsed);
  factory ConsultantReply.fromJson(Map<String, dynamic> j) =>
      ConsultantReply(j['text'] as String? ?? '', [for (final d in (j['dataUsed'] as List? ?? const [])) d as String]);
  final String text;
  final List<String> dataUsed;
}

// ---- Requests ---------------------------------------------------------------------------------------------------

/// An ingredient after the client's correction: an existing one by [id], or a product they added.
class DishIngredientInput {
  const DishIngredientInput({this.id, this.productId, this.name, required this.grams, this.role = IngredientRole.main});
  final String? id, productId, name;
  final double grams;
  final IngredientRole role;

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'name': name,
    'grams': double.parse(grams.toStringAsFixed(1)),
    'role': wireName(role),
  };
}

/// One diary item, from exactly one source: an item the entry already has ([diaryItemId], when editing; its saved
/// values are kept), a product, a recipe or an ingredient of the client's scan.
class DiaryItemInput {
  const DiaryItemInput({
    this.diaryItemId,
    this.productId,
    this.recipeId,
    this.scanIngredientId,
    this.name,
    required this.grams,
    this.role = IngredientRole.main,
  });
  final String? diaryItemId, productId, recipeId, scanIngredientId, name;
  final double grams;
  final IngredientRole role;

  Map<String, dynamic> toJson() => {
    'diaryItemId': diaryItemId,
    'productId': productId,
    'recipeId': recipeId,
    'scanIngredientId': scanIngredientId,
    'name': name,
    'grams': double.parse(grams.toStringAsFixed(1)),
    'role': wireName(role),
  };
}

class SaveDiaryEntry {
  const SaveDiaryEntry({
    this.date,
    required this.mealType,
    this.eatenAt,
    this.name,
    this.scanId,
    required this.items,
  });
  final DateTime? date, eatenAt;
  final MealType mealType;
  final String? name, scanId;
  final List<DiaryItemInput> items;

  Map<String, dynamic> toJson() => {
    'date': date == null ? null : dateParam(date!),
    'mealType': wireName(mealType),
    'eatenAt': eatenAt?.toUtc().toIso8601String(),
    'name': name,
    'scanId': scanId,
    'items': [for (final i in items) i.toJson()],
  };
}

class NewFoodProduct {
  const NewFoodProduct({
    required this.name,
    this.brand,
    this.category = FoodCategory.other,
    required this.per100,
    this.per100Ml = false,
    this.servingGrams,
    this.packageGrams,
    this.barcode,
  });
  final String name;
  final String? brand, barcode;
  final FoodCategory category;
  final Nutrients per100;
  final bool per100Ml;
  final double? servingGrams, packageGrams;

  Map<String, dynamic> toJson() => {
    'name': name,
    'brand': brand,
    'category': wireName(category),
    'per100': {
      'kcal': per100.kcal,
      'protein': per100.protein,
      'fat': per100.fat,
      'carbs': per100.carbs,
      'fiber': per100.fiber,
      'sugar': per100.sugar,
      'saturatedFat': per100.saturatedFat,
      'sodiumMg': per100.sodiumMg,
    },
    'per100Ml': per100Ml,
    'servingGrams': servingGrams,
    'packageGrams': packageGrams,
    'barcode': barcode,
  };
}
