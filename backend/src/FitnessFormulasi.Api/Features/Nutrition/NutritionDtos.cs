using System.ComponentModel.DataAnnotations;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Domain;

namespace FitnessFormulasi.Api.Features.Nutrition;

// The API contract of the AI Food Scanner, food diary and analytics. JSON is camelCase, enums are strings.

/// <summary>Nutrition values: per 100 g (or 100 ml) of a product, or for a given weight. Null: the source has no value.</summary>
public record NutrientsDto(
    decimal Kcal, decimal Protein, decimal Fat, decimal Carbs,
    decimal? Fiber, decimal? Sugar, decimal? SaturatedFat, decimal? SodiumMg);

/// <summary>
/// Totals of a dish, a diary entry or a day. <see cref="KcalMin"/>–<see cref="KcalMax"/>: the range the estimate
/// may be off by (weights seen on a photo are approximate). Incomplete: an ingredient has no nutrition values, so
/// the real totals are higher.
/// </summary>
public record NutritionTotalsDto(NutrientsDto Values, decimal Grams, decimal KcalMin, decimal KcalMax, bool Incomplete);

public record FoodProductDto(
    Guid Id, string Name, string? NameUz, string? NameEn, string? Brand, FoodCategory Category, NutrientsDto Per100,
    bool Per100Ml, NutritionSource Source, string? SourceRef, decimal? ServingGrams, decimal? PackageGrams,
    IReadOnlyList<Allergen> Allergens, string? IngredientsText, string? Barcode, bool IsOwn);

public record FoodRecipeSummaryDto(
    Guid Id, string Name, string? NameUz, string? NameEn, FoodCategory Category, bool IsTraditional, string? DishKey,
    decimal PortionGrams, NutrientsDto Per100, bool IsOwn);

public record FoodRecipeIngredientDto(
    Guid ProductId, string Name, string? NameUz, string? NameEn, decimal Grams, IngredientRole Role, NutrientsDto Per100,
    NutritionSource Source, string? SourceRef);

public record FoodRecipeDto(
    Guid Id, string Name, string? NameUz, string? NameEn, FoodCategory Category, bool IsTraditional, string? DishKey,
    decimal PortionGrams, NutrientsDto Per100, bool IsOwn, string? Description, decimal? YieldGrams,
    IReadOnlyList<FoodRecipeIngredientDto> Ingredients);

public record FoodSearchResultDto(IReadOnlyList<FoodProductDto> Products, IReadOnlyList<FoodRecipeSummaryDto> Recipes);

// ---- Scanner -----------------------------------------------------------------------------------------------------

/// <summary>
/// Ingredient of a recognized dish. <see cref="Per100"/> is null when no product was found for it (Match None): it
/// counts as zero and makes the totals Incomplete until the client picks a product or removes it.
/// <see cref="Nutrients"/>: values for <see cref="Grams"/>.
/// </summary>
public record FoodScanIngredientDto(
    Guid Id, string Name, Guid? ProductId, string? ProductName, decimal Grams, IngredientRole Role, IngredientMatch Match,
    decimal Uncertainty, NutrientsDto? Per100, NutrientsDto? Nutrients, NutritionSource? Source, string? SourceRef);

/// <summary>
/// One dish on the photo. Warnings (codes): low_confidence, weight_uncertain, unmatched_ingredients,
/// cooking_fat_missing (fried, but no oil among the ingredients), multiple_dishes.
/// </summary>
public record FoodDishDto(
    Guid Id, int Index, string Name, string? NameUz, string? NameEn, FoodCategory Category, string? TraditionalDishKey,
    decimal Confidence, decimal EstimatedWeightGrams, WeightConfidence WeightConfidence, PreparationMethod PreparationMethod,
    string? PreparationNote, IReadOnlyList<Allergen> PossibleAllergens, bool NeedsConfirmation, string? Notes, bool UserEdited,
    NutritionTotalsDto Totals, IReadOnlyList<FoodScanIngredientDto> Ingredients, IReadOnlyList<string> Warnings);

/// <summary>
/// A scan. Photo: <see cref="Dishes"/>. Label and Barcode: <see cref="Product"/> (values per 100 g/ml).
/// <see cref="Reused"/>: the same photo was analysed before, its result is returned without a new AI request.
/// ImageQuality: good, blurry, dark, partial (from the AI).
/// </summary>
public record FoodScanDto(
    Guid Id, FoodScanKind Kind, FoodScanStatus Status, DateTimeOffset CreatedAt, bool HasPhoto, string? ImageQuality,
    string? ClarificationQuestion, string? Hint, bool Reused, IReadOnlyList<FoodDishDto> Dishes, FoodProductDto? Product,
    string? Barcode, DateTimeOffset? AddedToDiaryAt);

public record FoodScanSummaryDto(
    Guid Id, FoodScanKind Kind, FoodScanStatus Status, DateTimeOffset CreatedAt, bool HasPhoto, string Title,
    decimal? Kcal, int Dishes, DateTimeOffset? AddedToDiaryAt);

public class BarcodeRequest
{
    /// <summary>EAN-8, UPC-A, EAN-13 or GTIN-14 digits.</summary>
    [Required, RegularExpression(@"^\d{8,14}$")] public string Code { get; set; } = "";
}

/// <summary>An ingredient after the client's correction: an existing one by Id, or a product they added.</summary>
public class DishIngredientInput
{
    /// <summary>Id of an ingredient of this dish (keeps its product), or null for a new one.</summary>
    public Guid? Id { get; set; }
    /// <summary>Product chosen by the client; replaces the matched one. Required for a new ingredient.</summary>
    public Guid? ProductId { get; set; }
    [StringLength(120)] public string? Name { get; set; }
    [Range(0.1, 5000)] public decimal Grams { get; set; }
    public IngredientRole Role { get; set; } = IngredientRole.Main;
}

/// <summary>The client corrected a dish: its name, weights, ingredients. The server recalculates the totals.</summary>
public class UpdateDishRequest
{
    [Range(0, 9)] public int DishIndex { get; set; }
    [StringLength(120)] public string? Name { get; set; }
    [Required, MinLength(1), MaxLength(30)] public List<DishIngredientInput> Ingredients { get; set; } = [];
}

// ---- Diary -------------------------------------------------------------------------------------------------------

/// <summary>
/// A diary item comes from exactly one of: a product (shared or own), a recipe, an ingredient of the client's scan.
/// A scan ingredient without a product has no values: it is saved, the entry is marked Incomplete.
/// </summary>
public class DiaryItemInput
{
    /// <summary>When editing an entry (PUT): an item of this entry, kept with its saved values (only grams/role/name change).</summary>
    public Guid? DiaryItemId { get; set; }
    public Guid? ProductId { get; set; }
    public Guid? RecipeId { get; set; }
    public Guid? ScanIngredientId { get; set; }
    [StringLength(120)] public string? Name { get; set; }
    [Range(0.1, 5000)] public decimal Grams { get; set; }
    public IngredientRole Role { get; set; } = IngredientRole.Main;
}

public class SaveDiaryEntryRequest
{
    /// <summary>Club-local date; today when omitted.</summary>
    public DateOnly? Date { get; set; }
    [Required] public MealType MealType { get; set; }
    /// <summary>When it was eaten; now when omitted.</summary>
    public DateTimeOffset? EatenAt { get; set; }
    /// <summary>Entry title; the first item's name when omitted.</summary>
    [StringLength(120)] public string? Name { get; set; }
    /// <summary>The scan the entry comes from (its photo becomes the entry's photo).</summary>
    public Guid? ScanId { get; set; }
    [Required, MinLength(1), MaxLength(40)] public List<DiaryItemInput> Items { get; set; } = [];
}

public class RepeatDiaryEntryRequest
{
    public DateOnly? Date { get; set; }
    public MealType? MealType { get; set; }
}

public record DiaryItemDto(
    Guid Id, string Name, Guid? ProductId, Guid? RecipeId, decimal Grams, IngredientRole Role, NutrientsDto? Per100,
    NutrientsDto Nutrients, NutritionSource? Source, string? SourceRef, bool HasNutrition);

public record DiaryEntryDto(
    Guid Id, DateOnly Date, MealType MealType, DateTimeOffset EatenAt, string Name, Guid? ScanId, bool HasPhoto,
    NutritionTotalsDto Totals, IReadOnlyList<DiaryItemDto> Items, DateTimeOffset CreatedAt);

public record DiaryMealDto(MealType MealType, NutritionTotalsDto Totals, IReadOnlyList<DiaryEntryDto> Entries);

/// <summary>One diary day: every meal type is present (possibly empty), in order Breakfast, Lunch, Dinner, Snack.</summary>
public record DiaryDayDto(DateOnly Date, NutritionTargetDto? Target, NutritionTotalsDto Totals, IReadOnlyList<DiaryMealDto> Meals);

// ---- Profile and target ------------------------------------------------------------------------------------------

/// <summary>
/// Daily target. Method: MifflinStJeor (computed from sex, age, height, weight, activity and goal) or Custom (the
/// client's own calorie number; macros are still derived from it). Bmr and Tdee are given for the computed one.
/// </summary>
public record NutritionTargetDto(
    int Kcal, int ProteinG, int FatG, int CarbsG, int FiberG, int SodiumMaxMg, string Method, int? Bmr, int? Tdee);

/// <summary>
/// AiAvailable: the server has an AI service configured. AiConsentAt: when the client agreed that photos and
/// nutrition data are sent to it (required before any AI feature). MissingForTarget: fields still needed to compute
/// the target (sex, birthDate, heightCm, weightKg, activity, goal).
/// </summary>
public record NutritionProfileDto(
    NutritionGoal? Goal, decimal? WeightKg, decimal? HeightCm, ActivityLevel? Activity, Gender? Sex, DateOnly? BirthDate,
    int? CustomKcalTarget, string? Restrictions, IReadOnlyList<Allergen> Allergies, DateTimeOffset? AiConsentAt,
    bool AiAvailable, string? AiProvider, int ScansPerDay, int ScansToday, NutritionTargetDto? Target,
    IReadOnlyList<string> MissingForTarget);

public class UpdateNutritionProfileRequest
{
    public NutritionGoal? Goal { get; set; }
    [Range(25, 350)] public decimal? WeightKg { get; set; }
    [Range(100, 250)] public decimal? HeightCm { get; set; }
    public ActivityLevel? Activity { get; set; }
    /// <summary>Saved to the client profile (the same field the profile screen edits).</summary>
    public Gender? Sex { get; set; }
    [PastDate] public DateOnly? BirthDate { get; set; }
    [Range(800, 6000)] public int? CustomKcalTarget { get; set; }
    [StringLength(500)] public string? Restrictions { get; set; }
    [MaxLength(14)] public List<Allergen> Allergies { get; set; } = [];
}

// ---- Analytics ---------------------------------------------------------------------------------------------------

public record NutritionDayStatDto(
    DateOnly Date, int Entries, decimal Kcal, decimal Protein, decimal Fat, decimal Carbs, decimal Fiber, decimal Sugar,
    int? TargetKcal, int TrainingSessions, bool Visited);

/// <summary>Today (or any date): totals against the target and what is left, calories per meal, workouts that day.</summary>
public record NutritionDailyDto(
    DateOnly Date, NutritionTargetDto? Target, NutritionTotalsDto Totals, decimal? RemainingKcal,
    IReadOnlyDictionary<MealType, decimal> KcalByMeal, int Entries, int TrainingSessions, bool Visited);

/// <summary>
/// A week or a month, one row per day (days without entries included). Average: over the days with entries.
/// DaysWithinTarget: days whose calories are within ±10 % of the target.
/// </summary>
public record NutritionPeriodDto(
    DateOnly From, DateOnly To, NutritionTargetDto? Target, IReadOnlyList<NutritionDayStatDto> Days, NutrientsDto? Average,
    int DaysLogged, int DaysWithinTarget, int TrainingSessions, int Visits);

public record NutritionReportDto(NutritionReportPeriod Period, DateOnly From, DateOnly To, string Text, DateTimeOffset GeneratedAt, bool Cached);

// ---- Consultant --------------------------------------------------------------------------------------------------

public class ConsultantMessageInput
{
    /// <summary>"user" or "assistant".</summary>
    [Required, RegularExpression("^(user|assistant)$")] public string Role { get; set; } = "user";
    [Required, StringLength(2000, MinimumLength = 1)] public string Text { get; set; } = "";
}

public class ConsultantChatRequest
{
    /// <summary>The conversation so far, oldest first, ending with the client's question. Kept by the app.</summary>
    [Required, MinLength(1), MaxLength(20)] public List<ConsultantMessageInput> Messages { get; set; } = [];
    /// <summary>Answer language: ru or uz.</summary>
    [RegularExpression("^(ru|uz)$")] public string? Locale { get; set; }
}

/// <summary>DataUsed: which of the client's data the answer was based on (profile, diary_day, period, scans, trainings, food_search).</summary>
public record ConsultantReplyDto(string Text, IReadOnlyList<string> DataUsed);

// ---- Own products and recipes ------------------------------------------------------------------------------------

public class NutrientsInput
{
    [Range(0, 950)] public decimal Kcal { get; set; }
    [Range(0, 100)] public decimal Protein { get; set; }
    [Range(0, 100)] public decimal Fat { get; set; }
    [Range(0, 100)] public decimal Carbs { get; set; }
    [Range(0, 100)] public decimal? Fiber { get; set; }
    [Range(0, 100)] public decimal? Sugar { get; set; }
    [Range(0, 100)] public decimal? SaturatedFat { get; set; }
    [Range(0, 40000)] public decimal? SodiumMg { get; set; }
}

public class CreateFoodProductRequest
{
    [Required, StringLength(120, MinimumLength = 1)] public string Name { get; set; } = "";
    [StringLength(80)] public string? Brand { get; set; }
    public FoodCategory Category { get; set; } = FoodCategory.Other;
    [Required] public NutrientsInput Per100 { get; set; } = new();
    public bool Per100Ml { get; set; }
    [Range(1, 5000)] public decimal? ServingGrams { get; set; }
    [Range(1, 20000)] public decimal? PackageGrams { get; set; }
    [RegularExpression(@"^\d{8,14}$")] public string? Barcode { get; set; }
}

public class RecipeIngredientInput
{
    [Required] public Guid ProductId { get; set; }
    [Range(0.1, 20000)] public decimal Grams { get; set; }
    public IngredientRole Role { get; set; } = IngredientRole.Main;
}

public class SaveRecipeRequest
{
    [Required, StringLength(120, MinimumLength = 1)] public string Name { get; set; } = "";
    public FoodCategory Category { get; set; } = FoodCategory.Other;
    [Range(1, 5000)] public decimal PortionGrams { get; set; } = 300;
    /// <summary>Weight of the finished dish, when cooking changes it (e.g. 1 kg of ingredients gives 800 g of soup).</summary>
    [Range(1, 50000)] public decimal? YieldGrams { get; set; }
    [StringLength(1000)] public string? Description { get; set; }
    [Required, MinLength(1), MaxLength(40)] public List<RecipeIngredientInput> Ingredients { get; set; } = [];
}
