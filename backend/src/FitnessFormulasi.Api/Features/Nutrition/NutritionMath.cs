using FitnessFormulasi.Api.Domain;

namespace FitnessFormulasi.Api.Features.Nutrition;

/// <summary>An amount of food for the calculation: its weight, its values per 100 g (null: unknown) and how sure the weight is.</summary>
public readonly record struct FoodAmount(decimal Grams, IPer100Nullable? Per100, decimal Uncertainty);

/// <summary>
/// Nutrition Engine arithmetic. Every value is (value per 100 g) × (grams) / 100, summed over the ingredients;
/// nothing is taken from the AI. The calorie range assumes the weight errors of the ingredients add up (the
/// cautious case): min = Σ kcal × (1 − u), max = Σ kcal × (1 + u).
/// </summary>
public static class NutritionMath
{
    /// <summary>How far off a weight estimated from a photo may be, by the AI's own confidence.</summary>
    public static decimal UncertaintyFor(WeightConfidence confidence, IngredientRole role)
    {
        var u = confidence switch
        {
            WeightConfidence.High => 0.15m,
            WeightConfidence.Medium => 0.25m,
            _ => 0.40m,
        };
        // Oil and sauces are mostly invisible on a photo (absorbed, under the food): the widest margin.
        return role is IngredientRole.Fat or IngredientRole.Sauce ? Math.Max(u, 0.5m) : u;
    }

    /// <summary>A weight the client typed or corrected.</summary>
    public const decimal UserWeightUncertainty = 0.10m;
    /// <summary>A portion of a packaged product with values from its label or Open Food Facts.</summary>
    public const decimal PackagedUncertainty = 0.05m;
    /// <summary>A portion of a recipe whose composition is typical, not measured (traditional dishes).</summary>
    public const decimal RecipeUncertainty = 0.20m;

    public static NutrientsDto For(IPer100 per100, decimal grams) => For(Nullable(per100), grams)!;

    /// <summary>Values for <paramref name="grams"/> (rounded for display), or null when the per-100 values are unknown.</summary>
    public static NutrientsDto? For(IPer100Nullable? p, decimal grams)
    {
        if (Exact(p, grams) is not { } n) return null;
        return new NutrientsDto(Round(n.Kcal, 1), Round(n.Protein, 2), Round(n.Fat, 2), Round(n.Carbs, 2),
            R2(n.Fiber), R2(n.Sugar), R2(n.SaturatedFat), R2(n.SodiumMg));
    }

    /// <summary>Unrounded values for <paramref name="grams"/>: sums are taken of these, rounding happens once at the end.</summary>
    private static NutrientsDto? Exact(IPer100Nullable? p, decimal grams)
    {
        if (p?.Kcal is null) return null;
        var k = grams / 100m;
        return new NutrientsDto(p.Kcal.Value * k, (p.Protein ?? 0) * k, (p.Fat ?? 0) * k, (p.Carbs ?? 0) * k,
            p.Fiber * k, p.Sugar * k, p.SaturatedFat * k, p.SodiumMg * k);
    }

    private static decimal? R2(decimal? v) => v is null ? null : Round(v.Value, 2);

    public static Totals Sum(IEnumerable<FoodAmount> items)
    {
        decimal grams = 0, kcal = 0, min = 0, max = 0, protein = 0, fat = 0, carbs = 0;
        decimal? fiber = null, sugar = null, sat = null, sodium = null;
        var incomplete = false;
        foreach (var item in items)
        {
            grams += item.Grams;
            var n = Exact(item.Per100, item.Grams);
            if (n is null)
            {
                incomplete = true;
                continue;
            }
            kcal += n.Kcal;
            min += n.Kcal * (1 - item.Uncertainty);
            max += n.Kcal * (1 + item.Uncertainty);
            protein += n.Protein;
            fat += n.Fat;
            carbs += n.Carbs;
            fiber = Add(fiber, n.Fiber);
            sugar = Add(sugar, n.Sugar);
            sat = Add(sat, n.SaturatedFat);
            sodium = Add(sodium, n.SodiumMg);
        }
        return new Totals(grams, kcal, min, max, protein, fat, carbs, fiber, sugar, sat, sodium, incomplete);
    }

    /// <summary>Per-100 g values of a dish made of these items, with <paramref name="yieldGrams"/> as the finished weight.</summary>
    public static Per100Values Per100Of(IEnumerable<FoodAmount> items, decimal? yieldGrams = null)
    {
        var t = Sum(items);
        var weight = yieldGrams ?? t.Grams;
        if (weight <= 0) return new Per100Values(0, 0, 0, 0, null, null, null, null);
        var k = 100m / weight;
        return new Per100Values(Round(t.Kcal * k, 2), Round(t.Protein * k, 2), Round(t.Fat * k, 2), Round(t.Carbs * k, 2),
            Scale(t.Fiber, k), Scale(t.Sugar, k), Scale(t.SaturatedFat, k), Scale(t.SodiumMg, k));
    }

    public static IPer100Nullable Nullable(IPer100 p) => new Per100Values(p.Kcal, p.Protein, p.Fat, p.Carbs, p.Fiber, p.Sugar, p.SaturatedFat, p.SodiumMg);

    public static NutrientsDto Dto(IPer100 p) => new(p.Kcal, p.Protein, p.Fat, p.Carbs, p.Fiber, p.Sugar, p.SaturatedFat, p.SodiumMg);

    public static NutrientsDto? Dto(IPer100Nullable p) => p.Kcal is null ? null
        : new NutrientsDto(p.Kcal.Value, p.Protein ?? 0, p.Fat ?? 0, p.Carbs ?? 0, p.Fiber, p.Sugar, p.SaturatedFat, p.SodiumMg);

    /// <summary>
    /// Kcal from the macros (Atwater 4/9/4). A label or database row whose energy differs from it by more than
    /// 20 % (and 15 kcal) is suspicious: fiber, alcohol and polyols explain smaller gaps.
    /// </summary>
    public static bool EnergyConsistent(decimal kcal, decimal protein, decimal fat, decimal carbs)
    {
        var atwater = 4 * protein + 9 * fat + 4 * carbs;
        var diff = Math.Abs(atwater - kcal);
        return diff <= 15 || diff <= 0.2m * Math.Max(kcal, atwater);
    }

    public static decimal Round(decimal v, int decimals) => Math.Round(v, decimals, MidpointRounding.AwayFromZero);

    private static decimal? Scale(decimal? v, decimal k) => v is null ? null : Round(v.Value * k, 2);
    private static decimal? Add(decimal? a, decimal? b) => b is null ? a : (a ?? 0) + b;
}

public sealed record Totals(
    decimal Grams, decimal Kcal, decimal KcalMin, decimal KcalMax, decimal Protein, decimal Fat, decimal Carbs,
    decimal? Fiber, decimal? Sugar, decimal? SaturatedFat, decimal? SodiumMg, bool Incomplete)
{
    /// <summary>Rounded for display: no false precision (kcal whole, grams of macros to 0.1, sodium whole mg).</summary>
    public NutritionTotalsDto ToDto() => new(
        new NutrientsDto(R(Kcal, 0), R(Protein, 1), R(Fat, 1), R(Carbs, 1), N(Fiber, 1), N(Sugar, 1), N(SaturatedFat, 1), N(SodiumMg, 0)),
        R(Grams, 0), R(KcalMin, 0), R(KcalMax, 0), Incomplete);

    private static decimal R(decimal v, int d) => NutritionMath.Round(v, d);
    private static decimal? N(decimal? v, int d) => v is null ? null : NutritionMath.Round(v.Value, d);
}

public sealed record Per100Values(
    decimal? Kcal, decimal? Protein, decimal? Fat, decimal? Carbs, decimal? Fiber, decimal? Sugar, decimal? SaturatedFat, decimal? SodiumMg)
    : IPer100Nullable;

/// <summary>
/// Daily target. Energy: Mifflin–St Jeor resting energy (Am J Clin Nutr 1990;51:241) × activity factor, −15 % to
/// lose weight, +10 % to gain, never below 1200 kcal (women) / 1500 kcal (men). Protein 1.6 g/kg (1.8 when losing or
/// gaining; ISSN position stand, 1.4–2.0 g/kg for exercising people). Fat 30 % of energy (25 % when gaining),
/// inside the 20–35 % range of the US Dietary Reference Intakes; carbohydrates the rest. Fiber 14 g per 1000 kcal and
/// sodium at most 2300 mg (Dietary Guidelines for Americans 2020–2025).
/// </summary>
public static class NutritionTargets
{
    public static decimal ActivityFactor(ActivityLevel a) => a switch
    {
        ActivityLevel.Sedentary => 1.2m,
        ActivityLevel.Light => 1.375m,
        ActivityLevel.Moderate => 1.55m,
        ActivityLevel.Active => 1.725m,
        _ => 1.9m,
    };

    public static IReadOnlyList<string> Missing(NutritionProfile? p, Gender? sex, DateOnly? birthDate)
    {
        var missing = new List<string>();
        if (sex is null) missing.Add("sex");
        if (birthDate is null) missing.Add("birthDate");
        if (p?.HeightCm is null) missing.Add("heightCm");
        if (p?.WeightKg is null) missing.Add("weightKg");
        if (p?.Activity is null) missing.Add("activity");
        if (p?.Goal is null) missing.Add("goal");
        return missing;
    }

    public static NutritionTargetDto? Compute(NutritionProfile? p, Gender? sex, DateOnly? birthDate, DateOnly today)
    {
        if (p is null) return null;
        var goal = p.Goal ?? NutritionGoal.Maintain;
        int? bmr = null, tdee = null;
        decimal kcal;
        string method;
        if (Missing(p, sex, birthDate).Count == 0)
        {
            var age = Age(birthDate!.Value, today);
            var resting = 10 * p.WeightKg!.Value + 6.25m * p.HeightCm!.Value - 5 * age + (sex == Gender.Male ? 5 : -161);
            var total = resting * ActivityFactor(p.Activity!.Value);
            bmr = (int)Math.Round(resting);
            tdee = (int)Math.Round(total);
            kcal = goal switch { NutritionGoal.Lose => total * 0.85m, NutritionGoal.Gain => total * 1.10m, _ => total };
            kcal = Math.Max(kcal, sex == Gender.Male ? 1500 : 1200);
            method = "MifflinStJeor";
        }
        else if (p.CustomKcalTarget is null) return null;
        else
        {
            kcal = p.CustomKcalTarget.Value;
            method = "Custom";
        }
        if (p.CustomKcalTarget is { } custom)
        {
            kcal = custom;
            method = "Custom";
        }

        var proteinG = p.WeightKg is { } w
            ? w * (goal == NutritionGoal.Maintain ? 1.6m : 1.8m)
            : kcal * 0.20m / 4; // no weight: 20 % of energy
        proteinG = Math.Min(proteinG, kcal * 0.35m / 4); // protein above 35 % of energy is beyond the DRI range
        var fatG = kcal * (goal == NutritionGoal.Gain ? 0.25m : 0.30m) / 9;
        var carbsG = Math.Max(0, (kcal - proteinG * 4 - fatG * 9) / 4);
        return new NutritionTargetDto(
            (int)Math.Round(kcal / 10) * 10, (int)Math.Round(proteinG), (int)Math.Round(fatG), (int)Math.Round(carbsG),
            (int)Math.Round(kcal / 1000 * 14), 2300, method, bmr, tdee);
    }

    public static int Age(DateOnly birthDate, DateOnly today)
    {
        var age = today.Year - birthDate.Year;
        if (birthDate > today.AddYears(-age)) age--;
        return age;
    }
}
