namespace FitnessFormulasi.Api.Domain;

// AI Food Scanner, food diary and nutrition analytics (Features/Nutrition). Every client-owned row carries the
// ClientProfileId taken from the token; nutrition values are always per 100 g (or 100 ml) with their source.

public enum MealType { Breakfast, Lunch, Dinner, Snack }

/// <summary>What a dish or product is. The first fifteen are the scanner's recognition categories.</summary>
public enum FoodCategory
{
    Breakfast, Lunch, Dinner, Snacks, Fruits, Vegetables, Meat, Fish, Dairy, Bakery, Desserts, FastFood, Drinks,
    PackagedFood, TraditionalFood, Grains, Legumes, NutsSeeds, FatsOils, Sauces, Eggs, Other,
}

/// <summary>
/// Where nutrition values come from. Usda: FoodData Central (SR Legacy / Foundation / API); OpenFoodFacts: the
/// product database by barcode; Label: read from the package photo; Recipe: computed from a recipe's ingredients;
/// User: typed in by the client.
/// </summary>
public enum NutritionSource { Usda, OpenFoodFacts, Label, Recipe, User }

/// <summary>The 14 allergens food labels must declare (EU 1169/2011, Annex II).</summary>
public enum Allergen { Gluten, Milk, Eggs, Nuts, Peanuts, Sesame, Soy, Fish, Shellfish, Molluscs, Celery, Mustard, Sulphites, Lupin }

/// <summary>Fat and Sauce weights are the hardest to see on a photo: they get the widest uncertainty.</summary>
public enum IngredientRole { Main, Fat, Sauce, Garnish, Drink }

public enum PreparationMethod { Raw, Boiled, Steamed, Fried, DeepFried, Baked, Grilled, Stewed, Mixed, Unknown }

public enum WeightConfidence { Low, Medium, High }

public enum FoodScanKind { Photo, Label, Barcode }

/// <summary>
/// Recognized: at least one dish with ingredients. NeedsClarification: the photo is unclear or the dish could not be
/// identified; the client is asked to retake it or name the dish. NotFood: nothing edible on the photo.
/// Failed: the AI service did not answer (the error code says why).
/// </summary>
public enum FoodScanStatus { Recognized, NeedsClarification, NotFood, Failed }

/// <summary>How a scan ingredient was tied to a product: by the AI's catalog key, a name search, an external
/// database, by the client, or not at all (no nutrition values).</summary>
public enum IngredientMatch { CatalogKey, NameSearch, External, User, None }

public enum NutritionGoal { Lose, Maintain, Gain }

public enum ActivityLevel { Sedentary, Light, Moderate, Active, VeryActive }

/// <summary>ConnectionCheck: the admin panel's test request to the provider (no client data).</summary>
public enum AiFeature { FoodPhoto, FoodLabel, Consultant, Report, ConnectionCheck }

public enum NutritionReportPeriod { Day, Week }

/// <summary>Nutrition values per 100 g (or 100 ml). Optional values are null when the source does not give them.</summary>
public interface IPer100
{
    decimal Kcal { get; }
    decimal Protein { get; }
    decimal Fat { get; }
    decimal Carbs { get; }
    decimal? Fiber { get; }
    decimal? Sugar { get; }
    decimal? SaturatedFat { get; }
    decimal? SodiumMg { get; }
}

/// <summary>
/// A food with nutrition values per 100 g: the shared database (USDA ingredients, Open Food Facts products cached by
/// barcode) and the client's own products (OwnerClientId set: typed in or read from a label).
/// </summary>
public class FoodProduct : Entity, IPer100
{
    /// <summary>Stable key of a built-in product (seed data); the AI vision prompt refers to products by it.</summary>
    public string? Key { get; set; }
    public required string Name { get; set; }
    public string? NameUz { get; set; }
    public string? NameEn { get; set; }
    public string? Brand { get; set; }
    public List<string> Aliases { get; set; } = [];
    /// <summary>Lower-case names and aliases for the search; maintained by the service on every change.</summary>
    public string SearchText { get; set; } = "";
    public FoodCategory Category { get; set; } = FoodCategory.Other;

    public decimal Kcal { get; set; }
    public decimal Protein { get; set; }
    public decimal Fat { get; set; }
    public decimal Carbs { get; set; }
    public decimal? Fiber { get; set; }
    public decimal? Sugar { get; set; }
    public decimal? SaturatedFat { get; set; }
    public decimal? SodiumMg { get; set; }
    /// <summary>Values are per 100 ml (drinks); a millilitre is counted as a gram.</summary>
    public bool Per100Ml { get; set; }

    public NutritionSource Source { get; set; }
    /// <summary>Id in the source: FDC id for USDA, the barcode for Open Food Facts.</summary>
    public string? SourceRef { get; set; }
    public decimal? ServingGrams { get; set; }
    public decimal? PackageGrams { get; set; }
    public List<Allergen> Allergens { get; set; } = [];
    public string? IngredientsText { get; set; }
    /// <summary>Null: shared product. Set: the client's own product, visible to them only.</summary>
    public Guid? OwnerClientId { get; set; }
    /// <summary>When an external source was last asked (cache age).</summary>
    public DateTimeOffset? FetchedAt { get; set; }
}

/// <summary>
/// Barcode lookup cache. Shared rows (OwnerClientId null) cache Open Food Facts answers, including "not found";
/// a client's own row links a barcode to the product they read from the label.
/// </summary>
public class FoodBarcode : Entity
{
    public required string Code { get; set; }
    public Guid? FoodProductId { get; set; }
    public FoodProduct? Product { get; set; }
    public bool NotFound { get; set; }
    public DateTimeOffset CheckedAt { get; set; }
    public Guid? OwnerClientId { get; set; }
}

/// <summary>
/// A dish made of products: the built-in Uzbek dishes (typical recipe compositions, several variants per dish) and
/// the client's own recipes. Values per 100 g are computed from the ingredients and cached on the row.
/// </summary>
public class FoodRecipe : Entity, IPer100
{
    public string? Key { get; set; }
    public required string Name { get; set; }
    public string? NameUz { get; set; }
    public string? NameEn { get; set; }
    public List<string> Aliases { get; set; } = [];
    public string SearchText { get; set; } = "";
    public FoodCategory Category { get; set; } = FoodCategory.Other;
    /// <summary>Dish family of a traditional dish (plov, samsa…), shared by its variants.</summary>
    public string? DishKey { get; set; }
    public bool IsTraditional { get; set; }
    public string? Description { get; set; }
    /// <summary>A typical portion.</summary>
    public decimal PortionGrams { get; set; }
    /// <summary>Weight of the finished dish when it differs from the sum of the ingredients (water lost or absorbed).</summary>
    public decimal? YieldGrams { get; set; }
    public Guid? OwnerClientId { get; set; }

    public decimal Kcal { get; set; }
    public decimal Protein { get; set; }
    public decimal Fat { get; set; }
    public decimal Carbs { get; set; }
    public decimal? Fiber { get; set; }
    public decimal? Sugar { get; set; }
    public decimal? SaturatedFat { get; set; }
    public decimal? SodiumMg { get; set; }

    public ICollection<FoodRecipeIngredient> Ingredients { get; set; } = [];
}

public class FoodRecipeIngredient : Entity
{
    public Guid FoodRecipeId { get; set; }
    public Guid FoodProductId { get; set; }
    public FoodProduct Product { get; set; } = null!;
    public decimal Grams { get; set; }
    public IngredientRole Role { get; set; }
    public int SortOrder { get; set; }
}

/// <summary>One scan: a food photo, a package label or a barcode. The photo file is kept by MediaStorage under PhotoId.</summary>
public class FoodScan : Entity
{
    public Guid ClientProfileId { get; set; }
    public FoodScanKind Kind { get; set; }
    public FoodScanStatus Status { get; set; }
    public Guid? PhotoId { get; set; }
    /// <summary>SHA-256 of the uploaded photo: the same photo sent again reuses the result instead of a new AI request.</summary>
    public string? ImageHash { get; set; }
    /// <summary>What the client said about the photo ("это лагман").</summary>
    public string? Hint { get; set; }
    public string? Barcode { get; set; }
    /// <summary>Product found by barcode or read from the label.</summary>
    public Guid? FoodProductId { get; set; }
    public FoodProduct? Product { get; set; }
    public string? ImageQuality { get; set; }
    public string? ClarificationQuestion { get; set; }
    public string? ErrorCode { get; set; }
    public string? AiModel { get; set; }
    /// <summary>The AI answer after validation, kept for the history and for checking a calculation later.</summary>
    public string? AiResponseJson { get; set; }
    public DateTimeOffset? AddedToDiaryAt { get; set; }

    public ICollection<FoodRecognitionResult> Results { get; set; } = [];
}

/// <summary>One dish recognized on a photo (a photo may show several), with its totals as last calculated.</summary>
public class FoodRecognitionResult : Entity
{
    public Guid FoodScanId { get; set; }
    public FoodScan Scan { get; set; } = null!;
    public int DishIndex { get; set; }
    public required string Name { get; set; }
    public string? NameUz { get; set; }
    public string? NameEn { get; set; }
    public FoodCategory Category { get; set; }
    public string? TraditionalDishKey { get; set; }
    public decimal Confidence { get; set; }
    public decimal EstimatedWeightGrams { get; set; }
    public WeightConfidence WeightConfidence { get; set; }
    public PreparationMethod PreparationMethod { get; set; }
    public string? PreparationNote { get; set; }
    public List<Allergen> PossibleAllergens { get; set; } = [];
    public bool NeedsConfirmation { get; set; }
    public string? Notes { get; set; }
    public bool UserEdited { get; set; }

    public decimal Grams { get; set; }
    public decimal Kcal { get; set; }
    public decimal KcalMin { get; set; }
    public decimal KcalMax { get; set; }
    public decimal Protein { get; set; }
    public decimal Fat { get; set; }
    public decimal Carbs { get; set; }
    public decimal? Fiber { get; set; }
    public decimal? Sugar { get; set; }
    public decimal? SaturatedFat { get; set; }
    public decimal? SodiumMg { get; set; }
    public bool NutritionIncomplete { get; set; }

    public ICollection<FoodRecognitionIngredient> Ingredients { get; set; } = [];
}

/// <summary>An ingredient of a recognized dish with the per-100 g values of its product copied at calculation time.</summary>
public class FoodRecognitionIngredient : Entity, IPer100Nullable
{
    public Guid FoodRecognitionResultId { get; set; }
    public int SortOrder { get; set; }
    public required string Name { get; set; }
    public Guid? FoodProductId { get; set; }
    public FoodProduct? Product { get; set; }
    public decimal Grams { get; set; }
    public IngredientRole Role { get; set; }
    public IngredientMatch Match { get; set; }
    /// <summary>Relative uncertainty of the weight (0.15 = ±15 %), used for the calorie range.</summary>
    public decimal Uncertainty { get; set; }

    public decimal? Kcal { get; set; }
    public decimal? Protein { get; set; }
    public decimal? Fat { get; set; }
    public decimal? Carbs { get; set; }
    public decimal? Fiber { get; set; }
    public decimal? Sugar { get; set; }
    public decimal? SaturatedFat { get; set; }
    public decimal? SodiumMg { get; set; }
    public NutritionSource? Source { get; set; }
    public string? SourceRef { get; set; }
}

/// <summary>Per-100 values that may be missing altogether (an ingredient with no product found).</summary>
public interface IPer100Nullable
{
    decimal? Kcal { get; }
    decimal? Protein { get; }
    decimal? Fat { get; }
    decimal? Carbs { get; }
    decimal? Fiber { get; }
    decimal? Sugar { get; }
    decimal? SaturatedFat { get; }
    decimal? SodiumMg { get; }
}

/// <summary>A meal in the food diary, on a club-local date. Totals are computed from the items by the server.</summary>
public class FoodDiaryEntry : Entity
{
    public Guid ClientProfileId { get; set; }
    public DateOnly Date { get; set; }
    public MealType MealType { get; set; }
    public DateTimeOffset EatenAt { get; set; }
    public required string Name { get; set; }
    /// <summary>The scan the entry came from; its photo is the entry's photo.</summary>
    public Guid? FoodScanId { get; set; }
    public FoodScan? Scan { get; set; }

    public decimal Grams { get; set; }
    public decimal Kcal { get; set; }
    public decimal KcalMin { get; set; }
    public decimal KcalMax { get; set; }
    public decimal Protein { get; set; }
    public decimal Fat { get; set; }
    public decimal Carbs { get; set; }
    public decimal? Fiber { get; set; }
    public decimal? Sugar { get; set; }
    public decimal? SaturatedFat { get; set; }
    public decimal? SodiumMg { get; set; }
    public bool NutritionIncomplete { get; set; }

    public ICollection<FoodDiaryItem> Items { get; set; } = [];
}

/// <summary>An ingredient or product of a diary entry; per-100 g values are copied, so later edits of a product do not change history.</summary>
public class FoodDiaryItem : Entity, IPer100Nullable
{
    public Guid FoodDiaryEntryId { get; set; }
    public int SortOrder { get; set; }
    public required string Name { get; set; }
    public Guid? FoodProductId { get; set; }
    public Guid? FoodRecipeId { get; set; }
    public decimal Grams { get; set; }
    public IngredientRole Role { get; set; }
    public decimal Uncertainty { get; set; }

    public decimal? Kcal { get; set; }
    public decimal? Protein { get; set; }
    public decimal? Fat { get; set; }
    public decimal? Carbs { get; set; }
    public decimal? Fiber { get; set; }
    public decimal? Sugar { get; set; }
    public decimal? SaturatedFat { get; set; }
    public decimal? SodiumMg { get; set; }
    public NutritionSource? Source { get; set; }
    public string? SourceRef { get; set; }
}

/// <summary>
/// The client's nutrition settings: goal, body measurements for the daily calorie target, dietary restrictions and
/// consent to sending photos and nutrition data to the AI service. Sex and birth date live on ClientProfile.
/// </summary>
public class NutritionProfile : Entity
{
    public Guid ClientProfileId { get; set; }
    public NutritionGoal? Goal { get; set; }
    public decimal? WeightKg { get; set; }
    public decimal? HeightCm { get; set; }
    public ActivityLevel? Activity { get; set; }
    /// <summary>The client's own calorie target, instead of the computed one.</summary>
    public int? CustomKcalTarget { get; set; }
    public string? Restrictions { get; set; }
    public List<Allergen> Allergies { get; set; } = [];
    public DateTimeOffset? AiConsentAt { get; set; }
    /// <summary>
    /// The AI provider the consent was given for ("OpenAI", "Anthropic"). The consent names the recipient of the data,
    /// so after a switch to another provider the client is asked again. Null: given before this was recorded, when
    /// Anthropic was the only provider.
    /// </summary>
    public string? AiConsentProvider { get; set; }
}

/// <summary>Totals of one diary day, recomputed whenever an entry of that day changes; analytics read these.</summary>
public class NutritionDailySummary : Entity
{
    public Guid ClientProfileId { get; set; }
    public DateOnly Date { get; set; }
    public int Entries { get; set; }
    public decimal Kcal { get; set; }
    public decimal Protein { get; set; }
    public decimal Fat { get; set; }
    public decimal Carbs { get; set; }
    public decimal Fiber { get; set; }
    public decimal Sugar { get; set; }
    public decimal SaturatedFat { get; set; }
    public decimal SodiumMg { get; set; }
    public bool Incomplete { get; set; }
    /// <summary>The calorie target on that day (it changes with the client's weight and goal).</summary>
    public int? TargetKcal { get; set; }
}

/// <summary>AI-written daily or weekly nutrition report, reused while the diary data it was written from is unchanged.</summary>
public class NutritionReport : Entity
{
    public Guid ClientProfileId { get; set; }
    public NutritionReportPeriod Period { get; set; }
    public DateOnly FromDate { get; set; }
    public DateOnly ToDate { get; set; }
    public required string Locale { get; set; }
    public required string InputHash { get; set; }
    public required string Text { get; set; }
    public string? AiModel { get; set; }
}

/// <summary>One request to the AI service: tokens, cost and time, for spending limits and monitoring.</summary>
public class AiUsageRecord : Entity
{
    public Guid? ClientProfileId { get; set; }
    public AiFeature Feature { get; set; }
    public required string Provider { get; set; }
    public required string Model { get; set; }
    public int InputTokens { get; set; }
    public int OutputTokens { get; set; }
    public int CacheReadTokens { get; set; }
    public int CacheWriteTokens { get; set; }
    public decimal CostUsd { get; set; }
    public int DurationMs { get; set; }
    public bool Success { get; set; }
    public string? ErrorCode { get; set; }
}
