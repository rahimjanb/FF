using System.Globalization;
using System.Net;
using System.Text.Json;
using FitnessFormulasi.Api.Domain;
using Microsoft.Extensions.Options;

namespace FitnessFormulasi.Api.Features.Nutrition;

/// <summary>External food databases (section "FoodData"). USDA needs a free key from api.data.gov; Open Food Facts needs none.</summary>
public sealed class FoodDataOptions
{
    public const string Section = "FoodData";

    /// <summary>FoodData Central API key (secret). Without it the search uses the local database only.</summary>
    public string? UsdaApiKey { get; set; }
    public string UsdaBaseUrl { get; set; } = "https://api.nal.usda.gov/fdc/v1/";
    public bool OpenFoodFactsEnabled { get; set; } = true;
    public string OpenFoodFactsBaseUrl { get; set; } = "https://world.openfoodfacts.org/";
    /// <summary>Open Food Facts asks every client to identify itself.</summary>
    public string UserAgent { get; set; } = "FitnessFormulasi/1.0 (fitness club app)";
    public int TimeoutSeconds { get; set; } = 10;
    /// <summary>How long a product found by barcode is reused before it is asked for again.</summary>
    public int BarcodeCacheDays { get; set; } = 30;
    /// <summary>How long "not in Open Food Facts" is remembered.</summary>
    public int NotFoundCacheDays { get; set; } = 3;
}

/// <summary>A product from an external database, values per 100 g (or 100 ml).</summary>
public sealed record ExternalProduct(
    NutritionSource Source, string SourceRef, string Name, string? Brand, FoodCategory Category, Per100Values Per100, bool Per100Ml,
    decimal? ServingGrams, decimal? PackageGrams, IReadOnlyList<Allergen> Allergens, string? IngredientsText);

/// <summary>The external database did not answer (network, timeout, 5xx).</summary>
public sealed class FoodSourceUnavailableException(string source, Exception? inner = null)
    : Exception($"{source} is unavailable.", inner);

/// <summary>Product by barcode. Swappable: Open Food Facts today, another provider later.</summary>
public interface IBarcodeProductSource
{
    string Name { get; }
    bool IsEnabled { get; }
    /// <summary>Null: the barcode is unknown, or the product has no nutrition values.</summary>
    Task<ExternalProduct?> FindAsync(string barcode, CancellationToken ct);
}

/// <summary>Generic foods by name. Swappable: USDA FoodData Central today.</summary>
public interface IFoodSearchSource
{
    string Name { get; }
    bool IsEnabled { get; }
    Task<IReadOnlyList<ExternalProduct>> SearchAsync(string query, int take, CancellationToken ct);
}

/// <summary>Open Food Facts API v2 (open data, ODbL). Values per 100 g/ml as published by the database.</summary>
public sealed class OpenFoodFactsSource(HttpClient http, IOptions<FoodDataOptions> options, ILogger<OpenFoodFactsSource> logger)
    : IBarcodeProductSource
{
    private const string Fields =
        "code,product_name,product_name_ru,product_name_uz,generic_name,brands,nutriments,serving_quantity,product_quantity," +
        "product_quantity_unit,quantity,allergens_tags,ingredients_text,ingredients_text_ru,categories_tags,nutrition_data_per";

    private static readonly Dictionary<string, Allergen> AllergenTags = new()
    {
        ["en:gluten"] = Allergen.Gluten, ["en:milk"] = Allergen.Milk, ["en:eggs"] = Allergen.Eggs, ["en:nuts"] = Allergen.Nuts,
        ["en:peanuts"] = Allergen.Peanuts, ["en:sesame-seeds"] = Allergen.Sesame, ["en:soybeans"] = Allergen.Soy,
        ["en:fish"] = Allergen.Fish, ["en:crustaceans"] = Allergen.Shellfish, ["en:molluscs"] = Allergen.Molluscs,
        ["en:celery"] = Allergen.Celery, ["en:mustard"] = Allergen.Mustard,
        ["en:sulphur-dioxide-and-sulphites"] = Allergen.Sulphites, ["en:lupin"] = Allergen.Lupin,
    };

    public string Name => "Open Food Facts";
    public bool IsEnabled => options.Value.OpenFoodFactsEnabled;

    public async Task<ExternalProduct?> FindAsync(string barcode, CancellationToken ct)
    {
        JsonDocument doc;
        try
        {
            using var res = await http.GetAsync($"api/v2/product/{barcode}.json?fields={Fields}", ct);
            if (res.StatusCode == HttpStatusCode.NotFound) return null;
            if (!res.IsSuccessStatusCode) throw new FoodSourceUnavailableException(Name);
            doc = await JsonDocument.ParseAsync(await res.Content.ReadAsStreamAsync(ct), cancellationToken: ct);
        }
        catch (Exception e) when (e is HttpRequestException or TaskCanceledException && !ct.IsCancellationRequested)
        {
            logger.LogWarning("Open Food Facts request failed: {Message}", e.Message);
            throw new FoodSourceUnavailableException(Name, e);
        }
        using (doc)
        {
            var root = doc.RootElement;
            if (!root.TryGetProperty("product", out var p) || (root.TryGetProperty("status", out var s) && s.ValueKind == JsonValueKind.Number && s.GetInt32() == 0))
                return null;
            return Parse(barcode, p);
        }
    }

    /// <summary>Reads the product; null when it lacks energy or one of the macronutrients (nothing to calculate with).</summary>
    public static ExternalProduct? Parse(string barcode, JsonElement p)
    {
        var n = p.TryGetProperty("nutriments", out var nn) ? nn : default;
        decimal? Num(string name) => n.ValueKind == JsonValueKind.Object && n.TryGetProperty(name, out var v) ? Number(v) : null;

        var kcal = Num("energy-kcal_100g") ?? (Num("energy_100g") is { } kj ? kj / 4.184m : null);
        decimal? protein = Num("proteins_100g"), fat = Num("fat_100g"), carbs = Num("carbohydrates_100g");
        decimal? fiber = Num("fiber_100g"), sugar = Num("sugars_100g"), sat = Num("saturated-fat_100g");
        var sodiumG = Num("sodium_100g") ?? (Num("salt_100g") is { } salt ? salt / 2.5m : null);
        var serving = p.TryGetProperty("serving_quantity", out var sq) ? Number(sq) : null;

        if (kcal is null && Num("energy-kcal_serving") is { } servingKcal && serving is > 0)
        {
            // Only per-serving values are published: convert to 100 g.
            var k = 100m / serving.Value;
            kcal = servingKcal * k;
            protein = Num("proteins_serving") * k;
            fat = Num("fat_serving") * k;
            carbs = Num("carbohydrates_serving") * k;
            fiber = Num("fiber_serving") * k;
            sugar = Num("sugars_serving") * k;
            sat = Num("saturated-fat_serving") * k;
            sodiumG = Num("sodium_serving") * k;
        }
        if (kcal is null || protein is null || fat is null || carbs is null) return null;
        if (kcal > 950 || protein > 100 || fat > 100 || carbs > 100 || kcal < 0 || protein < 0 || fat < 0 || carbs < 0) return null;

        var name = Text(p, "product_name_ru") ?? Text(p, "product_name") ?? Text(p, "generic_name") ?? barcode;
        var unit = Text(p, "product_quantity_unit")?.ToLowerInvariant();
        var quantity = Text(p, "quantity")?.ToLowerInvariant() ?? "";
        var liquid = unit is "ml" or "l" || quantity.EndsWith("ml") || quantity.EndsWith(" l") || quantity.EndsWith("мл");
        var allergens = new List<Allergen>();
        if (p.TryGetProperty("allergens_tags", out var tags) && tags.ValueKind == JsonValueKind.Array)
            foreach (var t in tags.EnumerateArray())
                if (t.GetString() is { } tag && AllergenTags.TryGetValue(tag, out var a) && !allergens.Contains(a)) allergens.Add(a);
        var categories = p.TryGetProperty("categories_tags", out var c) && c.ValueKind == JsonValueKind.Array
            ? c.EnumerateArray().Select(x => x.GetString() ?? "").ToList() : [];

        return new ExternalProduct(
            NutritionSource.OpenFoodFacts, barcode, Trim(name, 160), Text(p, "brands") is { } b ? Trim(b.Split(',')[0], 80) : null,
            categories.Any(x => x.Contains("beverages") || x.Contains("drinks")) ? FoodCategory.Drinks : FoodCategory.PackagedFood,
            new Per100Values(R(kcal), R(protein), R(fat), R(carbs), R(fiber), R(sugar), R(sat), sodiumG is null ? null : R(sodiumG * 1000)),
            liquid, serving is > 0 and < 5000 ? R(serving) : null,
            p.TryGetProperty("product_quantity", out var pq) && Number(pq) is > 0 and < 50000 and var q ? R(q) : null,
            allergens, (Text(p, "ingredients_text_ru") ?? Text(p, "ingredients_text")) is { } it ? Trim(it, 4000) : null);
    }

    private static decimal? Number(JsonElement v) => v.ValueKind switch
    {
        JsonValueKind.Number => v.GetDecimal(),
        JsonValueKind.String when decimal.TryParse(v.GetString(), NumberStyles.Float, CultureInfo.InvariantCulture, out var d) => d,
        _ => null,
    };

    private static string? Text(JsonElement p, string name) =>
        p.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String && !string.IsNullOrWhiteSpace(v.GetString())
            ? v.GetString()!.Trim() : null;

    private static string Trim(string s, int max) => s.Length <= max ? s : s[..max];
    private static decimal? R(decimal? v) => v is null ? null : Math.Round(v.Value, 2);
}

/// <summary>USDA FoodData Central search (public domain data): Foundation and SR Legacy foods, values per 100 g.</summary>
public sealed class UsdaFoodSearchSource(HttpClient http, IOptions<FoodDataOptions> options, ILogger<UsdaFoodSearchSource> logger)
    : IFoodSearchSource
{
    public string Name => "USDA FoodData Central";
    public bool IsEnabled => !string.IsNullOrWhiteSpace(options.Value.UsdaApiKey);

    public async Task<IReadOnlyList<ExternalProduct>> SearchAsync(string query, int take, CancellationToken ct)
    {
        if (!IsEnabled) return [];
        JsonDocument doc;
        try
        {
            var url = $"foods/search?query={Uri.EscapeDataString(query)}&dataType=Foundation,SR%20Legacy&pageSize={Math.Clamp(take, 1, 25)}"
                      + $"&api_key={Uri.EscapeDataString(options.Value.UsdaApiKey!)}";
            using var res = await http.GetAsync(url, ct);
            if (!res.IsSuccessStatusCode) throw new FoodSourceUnavailableException(Name);
            doc = await JsonDocument.ParseAsync(await res.Content.ReadAsStreamAsync(ct), cancellationToken: ct);
        }
        catch (Exception e) when (e is HttpRequestException or TaskCanceledException && !ct.IsCancellationRequested)
        {
            logger.LogWarning("USDA FoodData Central request failed: {Message}", e.Message);
            throw new FoodSourceUnavailableException(Name, e);
        }
        using (doc)
        {
            var list = new List<ExternalProduct>();
            if (!doc.RootElement.TryGetProperty("foods", out var foods)) return list;
            foreach (var f in foods.EnumerateArray())
                if (Parse(f) is { } p) list.Add(p);
            return list;
        }
    }

    /// <summary>Nutrient ids of FoodData Central: energy kcal 1008 (or Atwater 2047/2048), protein 1003, fat 1004,
    /// carbohydrate 1005, fiber 1079, sugars 2000 (or 1063), saturated fat 1258, sodium 1093 (mg).</summary>
    public static ExternalProduct? Parse(JsonElement f)
    {
        var values = new Dictionary<int, decimal>();
        if (f.TryGetProperty("foodNutrients", out var nutrients))
            foreach (var n in nutrients.EnumerateArray())
            {
                var id = n.TryGetProperty("nutrientId", out var i) && i.ValueKind == JsonValueKind.Number ? i.GetInt32() : 0;
                if (id != 0 && n.TryGetProperty("value", out var v) && v.ValueKind == JsonValueKind.Number) values.TryAdd(id, v.GetDecimal());
            }
        decimal? Get(params int[] ids) => ids.Select(id => values.TryGetValue(id, out var v) ? v : (decimal?)null).FirstOrDefault(v => v is not null);
        var kcal = Get(1008, 2047, 2048);
        var protein = Get(1003);
        var fat = Get(1004);
        var carbs = Get(1005);
        if (kcal is null || protein is null || fat is null || carbs is null) return null;
        var fdcId = f.TryGetProperty("fdcId", out var fid) ? fid.GetInt32().ToString(CultureInfo.InvariantCulture) : null;
        var description = f.TryGetProperty("description", out var d) ? d.GetString() : null;
        if (fdcId is null || string.IsNullOrWhiteSpace(description)) return null;
        return new ExternalProduct(NutritionSource.Usda, fdcId, description.Length > 160 ? description[..160] : description, null,
            FoodCategory.Other,
            new Per100Values(R(kcal), R(protein), R(fat), R(carbs), R(Get(1079)), R(Get(2000, 1063)), R(Get(1258)), R(Get(1093))),
            false, null, null, [], null);
    }

    private static decimal? R(decimal? v) => v is null ? null : Math.Round(v.Value, 2);
}
