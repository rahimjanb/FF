using System.Text;
using System.Text.Json;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features.Ai;
using FitnessFormulasi.Api.Features.Nutrition;

namespace FitnessFormulasi.Api.Tests;

/// <summary>Nutrition Engine arithmetic, daily targets and validation of AI answers — no database, no network.</summary>
public class NutritionEngineTests
{
    private static Per100Values P(decimal kcal, decimal protein, decimal fat, decimal carbs, decimal? fiber = null, decimal? sodium = null) =>
        new(kcal, protein, fat, carbs, fiber, null, null, sodium);

    // USDA SR Legacy values of the seed database.
    private static readonly Per100Values Rice = new(130, 2.69m, 0.28m, 28.17m, 0.4m, 0.05m, 0.08m, 1);
    private static readonly Per100Values Beef = new(302, 30.12m, 19.22m, 0, 0, 0, 7.62m, 50);
    private static readonly Per100Values Carrot = new(35, 0.76m, 0.18m, 8.22m, 3, 3.45m, 0.03m, 58);
    private static readonly Per100Values Oil = new(884, 0, 100, 0, 0, 0, 25.9m, 0);

    [Fact]
    public void Values_are_per_100_g_times_the_weight()
    {
        var n = NutritionMath.For(Rice, 200)!;
        Assert.Equal(260m, n.Kcal);
        Assert.Equal(5.38m, n.Protein);
        Assert.Equal(0.56m, n.Fat);
        Assert.Equal(56.34m, n.Carbs);
        Assert.Equal(0.8m, n.Fiber);
        Assert.Equal(2m, n.SodiumMg);
        Assert.Null(NutritionMath.For((IPer100Nullable?)null, 100));
    }

    [Fact]
    public void A_dish_is_the_sum_of_its_ingredients_rounded_once()
    {
        var t = NutritionMath.Sum([
            new FoodAmount(200, Rice, 0.25m), new FoodAmount(80, Beef, 0.25m), new FoodAmount(60, Carrot, 0.25m), new FoodAmount(15, Oil, 0.5m),
        ]);
        Assert.Equal(355m, t.Grams);
        Assert.Equal(655.2m, t.Kcal); // 260 + 241.6 + 21 + 132.6
        var dto = t.ToDto();
        Assert.Equal(655m, dto.Values.Kcal);
        Assert.Equal(29.9m, dto.Values.Protein); // 5.38 + 24.096 + 0.456
        Assert.Equal(31.0m, dto.Values.Fat); // 0.56 + 15.376 + 0.108 + 15 = 31.044: no drift from rounding each line
        Assert.Equal(61.3m, dto.Values.Carbs); // 56.34 + 4.932
        // The oil is ±50 %, everything else ±25 %.
        Assert.Equal(458m, dto.KcalMin); // 522.6 × 0.75 + 132.6 × 0.5
        Assert.Equal(852m, dto.KcalMax); // 522.6 × 1.25 + 132.6 × 1.5
        Assert.False(dto.Incomplete);
    }

    [Fact]
    public void An_ingredient_without_values_makes_the_totals_incomplete_not_invented()
    {
        var t = NutritionMath.Sum([new FoodAmount(100, Rice, 0.1m), new FoodAmount(50, null, 0.1m)]);
        Assert.Equal(150m, t.Grams);
        Assert.Equal(130m, t.Kcal);
        Assert.True(t.Incomplete);
    }

    [Fact]
    public void Optional_nutrients_are_summed_only_where_known()
    {
        var t = NutritionMath.Sum([new FoodAmount(100, P(100, 1, 1, 1, fiber: 2), 0), new FoodAmount(100, P(100, 1, 1, 1), 0)]);
        Assert.Equal(2m, t.Fiber);
        Assert.Null(t.SodiumMg);
    }

    [Fact]
    public void Recipe_values_per_100_g_use_the_finished_weight()
    {
        // 500 g of ingredients that boil down to 400 g of dish.
        var v = NutritionMath.Per100Of([new FoodAmount(400, P(100, 10, 5, 2), 0), new FoodAmount(100, P(50, 0, 0, 12), 0)], 400);
        Assert.Equal(112.5m, v.Kcal); // (400 + 50) / 400 × 100
        Assert.Equal(10m, v.Protein);
        Assert.Equal(5m, v.Fat);
        Assert.Equal(5m, v.Carbs);
    }

    [Theory]
    [InlineData(WeightConfidence.High, IngredientRole.Main, 0.15)]
    [InlineData(WeightConfidence.Medium, IngredientRole.Main, 0.25)]
    [InlineData(WeightConfidence.Low, IngredientRole.Garnish, 0.40)]
    [InlineData(WeightConfidence.High, IngredientRole.Fat, 0.5)]
    [InlineData(WeightConfidence.Low, IngredientRole.Sauce, 0.5)]
    public void Weight_uncertainty_follows_confidence_and_fats_are_widest(WeightConfidence c, IngredientRole role, decimal expected) =>
        Assert.Equal(expected, NutritionMath.UncertaintyFor(c, role));

    [Theory]
    [InlineData(250, 10, 10, 30, true)] // 4·10 + 9·10 + 4·30 = 250
    [InlineData(884, 0, 100, 0, true)]
    [InlineData(500, 10, 10, 30, false)] // a misread digit
    [InlineData(35, 0, 0, 10, true)] // small gaps (fiber, rounding) are tolerated
    public void Energy_must_match_the_macronutrients(decimal kcal, decimal p, decimal f, decimal c, bool ok) =>
        Assert.Equal(ok, NutritionMath.EnergyConsistent(kcal, p, f, c));

    // ---- Targets ----

    private static readonly DateOnly Today = new(2026, 11, 18);

    [Fact]
    public void Target_uses_mifflin_st_jeor_with_activity_and_goal()
    {
        // Man, 30 years, 180 cm, 80 kg: BMR = 800 + 1125 − 150 + 5 = 1780; × 1.55 = 2759; −15 % = 2345.15.
        var profile = new NutritionProfile { WeightKg = 80, HeightCm = 180, Activity = ActivityLevel.Moderate, Goal = NutritionGoal.Lose };
        var t = NutritionTargets.Compute(profile, Gender.Male, new DateOnly(1996, 1, 1), Today)!;
        Assert.Equal(1780, t.Bmr);
        Assert.Equal(2759, t.Tdee);
        Assert.Equal(2350, t.Kcal); // rounded to 10
        Assert.Equal(144, t.ProteinG); // 1.8 g/kg
        Assert.Equal(78, t.FatG); // 30 % of energy / 9
        Assert.Equal(2300, t.SodiumMaxMg);
        Assert.Equal(33, t.FiberG); // 14 g per 1000 kcal
        Assert.Equal("MifflinStJeor", t.Method);
        Assert.Equal((int)Math.Round((2345.15m - 144 * 4 - 78.17m * 9) / 4), t.CarbsG, tolerance: 1);
    }

    [Fact]
    public void Target_for_a_woman_never_goes_below_1200()
    {
        // Woman, 60 years, 150 cm, 45 kg, sedentary, losing: 450 + 937.5 − 300 − 161 = 926.5 × 1.2 × 0.85 = 945 → 1200.
        var profile = new NutritionProfile { WeightKg = 45, HeightCm = 150, Activity = ActivityLevel.Sedentary, Goal = NutritionGoal.Lose };
        var t = NutritionTargets.Compute(profile, Gender.Female, new DateOnly(1966, 6, 1), Today)!;
        Assert.Equal(1200, t.Kcal);
    }

    [Fact]
    public void Own_calorie_target_overrides_the_formula_and_missing_fields_are_listed()
    {
        var profile = new NutritionProfile { CustomKcalTarget = 2000, WeightKg = 70 };
        var t = NutritionTargets.Compute(profile, null, null, Today)!;
        Assert.Equal(2000, t.Kcal);
        Assert.Equal("Custom", t.Method);
        Assert.Equal(112, t.ProteinG); // no goal counts as maintaining: 1.6 g/kg
        Assert.Equal(["sex", "birthDate", "heightCm", "activity", "goal"], NutritionTargets.Missing(profile, null, null));
        Assert.Null(NutritionTargets.Compute(new NutritionProfile { WeightKg = 70 }, Gender.Male, null, Today));
    }

    [Theory]
    [InlineData("2000-11-18", 26)]
    [InlineData("2000-11-19", 25)]
    public void Age_counts_birthdays(string birth, int age) => Assert.Equal(age, NutritionTargets.Age(DateOnly.Parse(birth), Today));

    // ---- AI vision answers ----

    private static readonly HashSet<string> Keys = ["rice_white_cooked", "beef_chuck_braised", "oil_cottonseed"];
    private static readonly string[] Dishes = ["plov", "samsa"];

    public static string Vision(object? dishes = null, bool containsFood = true, string quality = "good") => JsonSerializer.Serialize(new
    {
        imageQuality = quality,
        containsFood,
        clarificationQuestion = (string?)null,
        dishes = dishes ?? new[]
        {
            Dish("Плов", "plov", 0.9, 350, "medium", "fried",
                Ingredient("Рис", "rice, cooked", "rice_white_cooked", 200),
                Ingredient("Говядина", "beef", "beef_chuck_braised", 80),
                Ingredient("Масло", "cottonseed oil", "oil_cottonseed", 15, "fat")),
        },
    });

    public static object Dish(string name, string dishKey, double confidence, double weight, string weightConfidence, string preparation,
        params object[] ingredients) => new
    {
        name, nameUz = name, nameEn = name, category = "TraditionalFood", traditionalDishKey = dishKey, confidence,
        estimatedWeightGrams = weight, weightConfidence, preparationMethod = preparation, preparationNote = (string?)null,
        ingredients, possibleAllergens = new[] { "Gluten", "NotAnAllergen" }, needsUserConfirmation = false, notes = (string?)null,
    };

    public static object Ingredient(string name, string nameEn, string? key, double grams, string role = "main") =>
        new { name, nameEn, productKey = key, estimatedWeightGrams = grams, role };

    [Fact]
    public void Vision_answer_is_validated_and_the_dish_weight_follows_the_ingredients()
    {
        var a = FoodRecognitionService.ParseVision(Vision(), Keys, Dishes);
        var dish = Assert.Single(a.Dishes);
        Assert.Equal("Плов", dish.Name);
        Assert.Equal("plov", dish.TraditionalDishKey);
        Assert.Equal(295m, dish.EstimatedWeightGrams); // 200 + 80 + 15, not the 350 the model said
        Assert.Equal(PreparationMethod.Fried, dish.Preparation);
        Assert.Equal(IngredientRole.Fat, dish.Ingredients[2].Role);
        Assert.Equal([Allergen.Gluten], dish.PossibleAllergens); // unknown allergen names are dropped
    }

    [Fact]
    public void Unknown_catalog_keys_and_dish_keys_are_dropped_and_extreme_values_clamped()
    {
        var json = Vision(new[]
        {
            Dish("Что-то", "borscht", 1.7, 100, "high", "boiled",
                Ingredient("Киноа", "quinoa, cooked", "quinoa_made_up", 120),
                Ingredient("Соль", "salt", null, 0),
                Ingredient("Гора риса", "rice", "rice_white_cooked", 9000)),
        });
        var dish = Assert.Single(FoodRecognitionService.ParseVision(json, Keys, Dishes).Dishes);
        Assert.Null(dish.TraditionalDishKey);
        Assert.Equal(1m, dish.Confidence);
        Assert.Null(dish.Ingredients[0].ProductKey); // looked up by name later
        Assert.Equal(2, dish.Ingredients.Count); // the 0 g line is skipped
        Assert.Equal(3000m, dish.Ingredients[1].Grams);
        Assert.True(dish.NeedsConfirmation);
    }

    [Theory]
    [InlineData("not json at all")]
    [InlineData("[1, 2]")]
    [InlineData("""{"imageQuality":"good","containsFood":true,"clarificationQuestion":null}""")]
    [InlineData("""{"imageQuality":"great","containsFood":true,"clarificationQuestion":null,"dishes":[]}""")]
    [InlineData("""{"imageQuality":"good","containsFood":"yes","clarificationQuestion":null,"dishes":[]}""")]
    public void Malformed_vision_answers_are_rejected(string json) =>
        Assert.Throws<InvalidAiAnswerException>(() => FoodRecognitionService.ParseVision(json, Keys, Dishes));

    [Fact]
    public void Dish_with_a_non_numeric_weight_is_rejected()
    {
        var json = Vision(new[] { new { name = "Плов" } });
        Assert.Throws<InvalidAiAnswerException>(() => FoodRecognitionService.ParseVision(json, Keys, Dishes));
    }

    [Fact]
    public void No_food_means_no_dishes_and_text_is_cleaned()
    {
        Assert.Empty(FoodRecognitionService.ParseVision(Vision(containsFood: false), Keys, Dishes).Dishes);
        var json = Vision(new[] { Dish("<b>Плов</b>\u0007", "plov", 0.8, 100, "low", "fried", Ingredient("Рис", "rice", "rice_white_cooked", 100)) });
        Assert.Equal("bПлов/b", FoodRecognitionService.ParseVision(json, Keys, Dishes).Dishes[0].Name);
    }

    [Fact]
    public void Vision_schema_lists_the_dish_keys_and_requires_every_field()
    {
        var schema = FoodRecognitionService.VisionSchema(Dishes).ToJsonString();
        Assert.Contains("\"plov\"", schema);
        Assert.Contains("\"none\"", schema);
        Assert.Contains("\"additionalProperties\":false", schema);
        Assert.DoesNotContain("minimum", schema); // not supported by structured outputs: checked in code instead
    }

    // ---- Labels ----

    private static string Label(object? per100 = null, object? perServing = null, string basis = "per_100g", bool legible = true,
        double? serving = null) => JsonSerializer.Serialize(new
    {
        isNutritionLabel = true, legible, productName = "Йогурт", brand = "Nestle", basis,
        per100, perServing, servingSizeGrams = serving, packageWeightGrams = 500.0, ingredientsText = "молоко, закваска",
        allergensDeclared = new[] { "Milk" }, barcode = "4600000000001", clarificationQuestion = (string?)null,
    });

    private static object Values(double? kcal = null, double? kj = null, double? p = null, double? f = null, double? c = null,
        double? sodiumMg = null, double? salt = null) => new
    {
        energyKcal = kcal, energyKj = kj, protein = p, fat = f, carbs = c, fiber = (double?)null, sugar = (double?)4.0,
        saturatedFat = (double?)null, sodiumMg, saltG = salt,
    };

    [Fact]
    public void Label_values_per_100_g_are_taken_as_printed()
    {
        var r = FoodRecognitionService.ParseLabel(Label(Values(kcal: 60, p: 3, f: 2.5, c: 6, sodiumMg: 50)));
        Assert.True(r.Readable);
        Assert.Equal(60m, r.Per100!.Kcal);
        Assert.Equal(50m, r.Per100.SodiumMg);
        Assert.Equal([Allergen.Milk], r.Allergens);
        Assert.Equal("4600000000001", r.Barcode);
        Assert.Equal(500m, r.PackageGrams);
    }

    [Fact]
    public void Label_energy_in_kj_and_salt_are_converted()
    {
        var r = FoodRecognitionService.ParseLabel(Label(Values(kj: 251, p: 3, f: 2.5, c: 6, salt: 0.125)));
        Assert.Equal(59.99m, r.Per100!.Kcal); // 251 / 4.184
        Assert.Equal(50m, r.Per100.SodiumMg); // 0.125 g salt / 2.5 = 0.05 g sodium
    }

    [Fact]
    public void Label_with_per_serving_values_only_is_scaled_to_100_g()
    {
        var r = FoodRecognitionService.ParseLabel(Label(perServing: Values(kcal: 120, p: 6, f: 5, c: 12), basis: "per_serving_only", serving: 200));
        Assert.True(r.Readable);
        Assert.Equal(60m, r.Per100!.Kcal);
        Assert.Equal(3m, r.Per100.Protein);
    }

    [Fact]
    public void Misread_or_illegible_labels_are_not_used()
    {
        var misread = FoodRecognitionService.ParseLabel(Label(Values(kcal: 600, p: 3, f: 2.5, c: 6)));
        Assert.False(misread.Readable);
        Assert.Null(misread.Per100);
        Assert.NotNull(misread.ClarificationQuestion);
        Assert.False(FoodRecognitionService.ParseLabel(Label(Values(kcal: 60, p: 3, f: 2.5, c: 6), legible: false)).Readable);
        Assert.False(FoodRecognitionService.ParseLabel(Label(Values(kcal: 60, p: 3, c: 6))).Readable); // fat missing
    }

    // ---- Photos ----

    [Fact]
    public void Photo_metadata_is_removed_and_the_image_kept()
    {
        var exif = Encoding.ASCII.GetBytes("Exif\0\0GPS 41.3111N 69.2797E");
        var bytes = new List<byte> { 0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, (byte)'J', (byte)'F', (byte)'I', (byte)'F', 0, 1, 1, 0, 0, 1, 0, 1, 0, 0 };
        bytes.AddRange([0xFF, 0xE1, (byte)((exif.Length + 2) >> 8), (byte)((exif.Length + 2) & 0xFF), .. exif]);
        bytes.AddRange([0xFF, 0xC0, 0x00, 0x11, 0x08, 0x01, 0xE0, 0x02, 0x80, 3, 1, 0x22, 0, 2, 0x11, 1, 3, 0x11, 1]);
        bytes.AddRange([0xFF, 0xDA, 0x00, 0x08, 1, 1, 0, 0, 0x3F, 0, 0x12, 0x34, 0xFF, 0xD9]);
        var original = bytes.ToArray();

        var checkedPhoto = FoodImage.Check(original);
        Assert.Equal((640, 480), (checkedPhoto.Width, checkedPhoto.Height));
        Assert.DoesNotContain("GPS", Encoding.ASCII.GetString(checkedPhoto.Jpeg));
        Assert.Equal(original.Length - exif.Length - 4, checkedPhoto.Jpeg.Length);
        Assert.Equal(original[^6..], checkedPhoto.Jpeg[^6..]); // scan data untouched
        Assert.Equal(64, checkedPhoto.Sha256.Length);
    }

    [Fact]
    public void Only_jpeg_photos_of_a_usable_size_are_accepted()
    {
        Assert.Equal("photo_invalid_format", Assert.Throws<FitnessFormulasi.Api.Common.ApiException>(
            () => FoodImage.Check([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0])).Code);
        Assert.Equal("photo_bad_size", Assert.Throws<FitnessFormulasi.Api.Common.ApiException>(
            () => FoodImage.Check(FaceAccessTests.Jpeg(200, 200))).Code);
        Assert.Equal("photo_bad_size", Assert.Throws<FitnessFormulasi.Api.Common.ApiException>(
            () => FoodImage.Check(FaceAccessTests.Jpeg(5000, 3000))).Code);
    }

    // ---- External databases ----

    [Fact]
    public void Open_food_facts_product_is_read_per_100_g_with_sodium_in_mg()
    {
        using var doc = JsonDocument.Parse("""
            {"product_name":"Kefir 2.5%","product_name_ru":"Кефир 2,5%","brands":"Musaffo, Other","product_quantity_unit":"ml","quantity":"900 ml",
             "serving_quantity":"200","product_quantity":900,"allergens_tags":["en:milk","en:unknown"],"ingredients_text":"молоко",
             "nutriments":{"energy-kcal_100g":53,"proteins_100g":2.9,"fat_100g":2.5,"carbohydrates_100g":4,"sugars_100g":4,"salt_100g":0.1}}
            """);
        var p = OpenFoodFactsSource.Parse("4780000000001", doc.RootElement)!;
        Assert.Equal("Кефир 2,5%", p.Name);
        Assert.Equal("Musaffo", p.Brand);
        Assert.Equal(53m, p.Per100.Kcal);
        Assert.Equal(40m, p.Per100.SodiumMg); // 0.1 g salt → 0.04 g sodium
        Assert.True(p.Per100Ml);
        Assert.Equal(200m, p.ServingGrams);
        Assert.Equal([Allergen.Milk], p.Allergens);
    }

    [Fact]
    public void Open_food_facts_product_without_macros_or_with_impossible_values_is_not_used()
    {
        using var noFat = JsonDocument.Parse("""{"product_name":"X","nutriments":{"energy-kcal_100g":53,"proteins_100g":2.9,"carbohydrates_100g":4}}""");
        Assert.Null(OpenFoodFactsSource.Parse("1", noFat.RootElement));
        using var kj = JsonDocument.Parse("""{"product_name":"X","nutriments":{"energy_100g":418.4,"proteins_100g":1,"fat_100g":1,"carbohydrates_100g":20}}""");
        Assert.Equal(100m, OpenFoodFactsSource.Parse("1", kj.RootElement)!.Per100.Kcal);
        using var bad = JsonDocument.Parse("""{"product_name":"X","nutriments":{"energy-kcal_100g":5000,"proteins_100g":1,"fat_100g":1,"carbohydrates_100g":1}}""");
        Assert.Null(OpenFoodFactsSource.Parse("1", bad.RootElement));
    }

    [Fact]
    public void Usda_search_result_is_read_by_nutrient_id()
    {
        using var doc = JsonDocument.Parse("""
            {"fdcId":168917,"description":"Quinoa, cooked","foodNutrients":[
              {"nutrientId":1003,"value":4.4},{"nutrientId":1004,"value":1.92},{"nutrientId":1005,"value":21.3},
              {"nutrientId":1008,"value":120},{"nutrientId":1079,"value":2.8},{"nutrientId":1093,"value":7}]}
            """);
        var p = UsdaFoodSearchSource.Parse(doc.RootElement)!;
        Assert.Equal(("168917", "Quinoa, cooked", 120m, 4.4m), (p.SourceRef, p.Name, p.Per100.Kcal!.Value, p.Per100.Protein!.Value));
        Assert.Null(p.Per100.Sugar);
        Assert.Equal(7m, p.Per100.SodiumMg);
    }

    // ---- AI cost ----

    [Fact]
    public void Ai_cost_is_computed_from_the_configured_prices()
    {
        var options = new AiOptions();
        var price = options.Prices["claude-opus-5-5"];
        var usage = new AiUsage(10_000, 2_000, 50_000, 0);
        var cost = (10_000 * price.InputPerMTok + 2_000 * price.OutputPerMTok + 50_000 * price.CacheReadPerMTok) / 1_000_000m;
        Assert.Equal(0.09m, cost); // 0.04 + 0.04 + 0.01
        Assert.False(options.IsEnabled); // no provider and no key by default: AI is off
        Assert.Equal(usage.InputTokens * 2, usage.Add(usage).InputTokens);
    }
}
