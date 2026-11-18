import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../data/nutrition_models.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../theme.dart';

/// Numbers of the nutrition screens. Photo estimates are approximate, so values are rounded to what they can
/// honestly say: calories to 5 (or 10 when the range is wide), grams to 1 g, small macros to 0.1 g.
class NutritionFmt {
  NutritionFmt(this.t, this.locale);
  final AppLocalizations t;
  final String locale;

  /// A range wider than this share of the value is shown next to it.
  static const wideRange = 0.15;

  static bool isWide(NutritionTotals totals) =>
      totals.kcal > 0 && (totals.kcalMax - totals.kcalMin) / totals.kcal > wideRange;

  static double roundTo(double v, int step) => (v / step).round() * step.toDouble();

  /// A whole number with non-breaking spaces between thousands («1 350»), the same in Russian and Uzbek.
  static String _int(double v) {
    final n = v.round();
    final digits = n.abs().toString();
    final b = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) b.write('\u00A0');
      b.write(digits[i]);
    }
    return b.toString();
  }

  /// Calories without false precision: to 10 when the estimate is rough, to 5 otherwise.
  String kcal(double v, {bool rough = false}) => _int(roundTo(v, rough ? 10 : 5));

  /// A whole number of calories (targets, per-100 values).
  String kcalExact(double v) => _int(v);

  /// «≈ 640 ккал» for an estimate, «640 ккал» for exact data.
  String kcalTotal(NutritionTotals totals, {bool approximate = true}) {
    final wide = isWide(totals);
    final value = '${kcal(totals.kcal, rough: wide)} ${t.unitKcal}';
    return approximate ? '≈ $value' : value;
  }

  /// «520–780» when the estimate may be off by more than [wideRange], otherwise null.
  String? kcalRange(NutritionTotals totals) =>
      isWide(totals) ? '${kcal(totals.kcalMin, rough: true)}–${kcal(totals.kcalMax, rough: true)}' : null;

  String grams(double v) => '${_int(v)} ${t.unitG}';

  /// Macros: one decimal under 10 g, whole grams above.
  String macro(double? v) {
    if (v == null) return '—';
    if (v.abs() < 10) return NumberFormat('0.#', locale).format(v);
    return _int(v);
  }

  String macroG(double? v) => v == null ? '—' : '${macro(v)} ${t.unitG}';

  String mg(double? v) => v == null ? '—' : '${_int(v)} ${t.unitMg}';

  String percent(double v) => '${(v * 100).round()}%';
}

String mealTypeLabel(AppLocalizations t, MealType m) => switch (m) {
  MealType.breakfast => t.mealBreakfast,
  MealType.lunch => t.mealLunch,
  MealType.dinner => t.mealDinner,
  MealType.snack => t.mealSnack,
};

IconData mealTypeIcon(MealType m) => switch (m) {
  MealType.breakfast => Icons.free_breakfast_outlined,
  MealType.lunch => Icons.lunch_dining_outlined,
  MealType.dinner => Icons.dinner_dining_outlined,
  MealType.snack => Icons.cookie_outlined,
};

/// Meal type that fits the time of day (club time): breakfast before 11, lunch before 16, dinner before 21.
MealType mealTypeForTime(DateTime clubTime) {
  final h = clubTime.hour;
  if (h >= 4 && h < 11) return MealType.breakfast;
  if (h >= 11 && h < 16) return MealType.lunch;
  if (h >= 16 && h < 21) return MealType.dinner;
  return MealType.snack;
}

String foodCategoryLabel(AppLocalizations t, FoodCategory c) => switch (c) {
  FoodCategory.breakfast => t.foodCatBreakfast,
  FoodCategory.lunch => t.foodCatLunch,
  FoodCategory.dinner => t.foodCatDinner,
  FoodCategory.snacks => t.foodCatSnacks,
  FoodCategory.fruits => t.foodCatFruits,
  FoodCategory.vegetables => t.foodCatVegetables,
  FoodCategory.meat => t.foodCatMeat,
  FoodCategory.fish => t.foodCatFish,
  FoodCategory.dairy => t.foodCatDairy,
  FoodCategory.bakery => t.foodCatBakery,
  FoodCategory.desserts => t.foodCatDesserts,
  FoodCategory.fastFood => t.foodCatFastFood,
  FoodCategory.drinks => t.foodCatDrinks,
  FoodCategory.packagedFood => t.foodCatPackaged,
  FoodCategory.traditionalFood => t.foodCatTraditional,
  FoodCategory.grains => t.foodCatGrains,
  FoodCategory.legumes => t.foodCatLegumes,
  FoodCategory.nutsSeeds => t.foodCatNuts,
  FoodCategory.fatsOils => t.foodCatFats,
  FoodCategory.sauces => t.foodCatSauces,
  FoodCategory.eggs => t.foodCatEggs,
  FoodCategory.other => t.foodCatOther,
};

String sourceLabel(AppLocalizations t, NutritionSource s) => switch (s) {
  NutritionSource.usda => 'USDA',
  NutritionSource.openFoodFacts => 'Open Food Facts',
  NutritionSource.label => t.sourceLabel,
  NutritionSource.recipe => t.sourceRecipe,
  NutritionSource.user => t.sourceUser,
};

Color sourceColor(NutritionSource s) => switch (s) {
  NutritionSource.usda => Brand.clock,
  NutritionSource.openFoodFacts => Brand.successText,
  NutritionSource.label => Brand.warningText,
  NutritionSource.recipe => Brand.purple,
  NutritionSource.user => Brand.blueIcon,
};

String allergenLabel(AppLocalizations t, Allergen a) => switch (a) {
  Allergen.gluten => t.allergenGluten,
  Allergen.milk => t.allergenMilk,
  Allergen.eggs => t.allergenEggs,
  Allergen.nuts => t.allergenNuts,
  Allergen.peanuts => t.allergenPeanuts,
  Allergen.sesame => t.allergenSesame,
  Allergen.soy => t.allergenSoy,
  Allergen.fish => t.allergenFish,
  Allergen.shellfish => t.allergenShellfish,
  Allergen.molluscs => t.allergenMolluscs,
  Allergen.celery => t.allergenCelery,
  Allergen.mustard => t.allergenMustard,
  Allergen.sulphites => t.allergenSulphites,
  Allergen.lupin => t.allergenLupin,
};

String goalLabel(AppLocalizations t, NutritionGoal g) => switch (g) {
  NutritionGoal.lose => t.goalLose,
  NutritionGoal.maintain => t.goalMaintain,
  NutritionGoal.gain => t.goalGain,
};

String activityLabel(AppLocalizations t, ActivityLevel a) => switch (a) {
  ActivityLevel.sedentary => t.activitySedentary,
  ActivityLevel.light => t.activityLight,
  ActivityLevel.moderate => t.activityModerate,
  ActivityLevel.active => t.activityActive,
  ActivityLevel.veryActive => t.activityVeryActive,
};

String activityHint(AppLocalizations t, ActivityLevel a) => switch (a) {
  ActivityLevel.sedentary => t.activitySedentaryHint,
  ActivityLevel.light => t.activityLightHint,
  ActivityLevel.moderate => t.activityModerateHint,
  ActivityLevel.active => t.activityActiveHint,
  ActivityLevel.veryActive => t.activityVeryActiveHint,
};

String preparationLabel(AppLocalizations t, PreparationMethod p) => switch (p) {
  PreparationMethod.raw => t.prepRaw,
  PreparationMethod.boiled => t.prepBoiled,
  PreparationMethod.steamed => t.prepSteamed,
  PreparationMethod.fried => t.prepFried,
  PreparationMethod.deepFried => t.prepDeepFried,
  PreparationMethod.baked => t.prepBaked,
  PreparationMethod.grilled => t.prepGrilled,
  PreparationMethod.stewed => t.prepStewed,
  PreparationMethod.mixed => t.prepMixed,
  PreparationMethod.unknown => t.prepUnknown,
};

String roleLabel(AppLocalizations t, IngredientRole r) => switch (r) {
  IngredientRole.main => t.roleMain,
  IngredientRole.fat => t.roleFat,
  IngredientRole.sauce => t.roleSauce,
  IngredientRole.garnish => t.roleGarnish,
  IngredientRole.drink => t.roleDrink,
};

/// A dish warning code from the server; unknown codes are not shown.
String? warningText(AppLocalizations t, String code) => switch (code) {
  'low_confidence' => t.warnLowConfidence,
  'weight_uncertain' => t.warnWeightUncertain,
  'unmatched_ingredients' => t.warnUnmatched,
  'cooking_fat_missing' => t.warnCookingFatMissing,
  'multiple_dishes' => t.warnMultipleDishes,
  _ => null,
};

/// Why the photo could not be analysed well (the AI's image quality verdict).
String? imageQualityText(AppLocalizations t, String? quality) => switch (quality) {
  'blurry' => t.imageBlurry,
  'dark' => t.imageDark,
  'partial' => t.imagePartial,
  _ => null,
};

/// The consultant's data sources as a short caption.
String dataUsedLabel(AppLocalizations t, String code) => switch (code) {
  'profile' => t.dataProfile,
  'diary_day' => t.dataDiaryDay,
  'period' => t.dataPeriod,
  'scans' => t.dataScans,
  'trainings' => t.dataTrainings,
  'food_search' => t.dataFoodSearch,
  _ => code,
};

String weightConfidenceLabel(AppLocalizations t, WeightConfidence c) => switch (c) {
  WeightConfidence.low => t.weightConfLow,
  WeightConfidence.medium => t.weightConfMedium,
  WeightConfidence.high => t.weightConfHigh,
};

bool isConsentError(Object error) => error is ApiException && error.code == 'ai_consent_required';
