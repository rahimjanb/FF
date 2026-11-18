using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features.Nutrition;
using FitnessFormulasi.Api.Tests.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using static FitnessFormulasi.Api.Tests.NutritionEngineTests;

namespace FitnessFormulasi.Api.Tests;

/// <summary>AI Food Scanner through the API: photo → recognition → Nutrition Engine → correction → diary.</summary>
[Collection(ApiCollection.Name)]
public class FoodScannerTests(ApiFactory factory)
{
    private readonly Scenario _s = new(factory);
    private static System.Text.Json.JsonSerializerOptions Json => ApiFactory.Json;
    private FakeAi Ai => factory.Ai;

    /// <summary>
    /// A JPEG whose APP15 segment carries <paramref name="marker"/> (the fake AI picks its answer by it) and whose
    /// EXIF segment carries a GPS position (it must never reach the AI or the disk).
    /// </summary>
    public static byte[] Photo(string marker, int width = 1024, int height = 768)
    {
        var bytes = new List<byte> { 0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, (byte)'J', (byte)'F', (byte)'I', (byte)'F', 0, 1, 1, 0, 0, 1, 0, 1, 0, 0 };
        var exif = Encoding.ASCII.GetBytes("Exif\0\0GPS 41.31N 69.28E");
        bytes.AddRange([0xFF, 0xE1, (byte)((exif.Length + 2) >> 8), (byte)((exif.Length + 2) & 0xFF), .. exif]);
        var m = Encoding.ASCII.GetBytes("MARK:" + marker);
        bytes.AddRange([0xFF, 0xEF, (byte)((m.Length + 2) >> 8), (byte)((m.Length + 2) & 0xFF), .. m]);
        bytes.AddRange([0xFF, 0xC0, 0x00, 0x11, 0x08, (byte)(height >> 8), (byte)height, (byte)(width >> 8), (byte)width, 3, 1, 0x22, 0, 2, 0x11, 1, 3, 0x11, 1]);
        bytes.AddRange([0xFF, 0xDA, 0x00, 0x08, 1, 1, 0, 0, 0x3F, 0, 0x55, 0xAA, 0xFF, 0xD9]);
        return [.. bytes];
    }

    private static MultipartFormDataContent Form(byte[] photo, string? hint = null, string? barcode = null)
    {
        var file = new ByteArrayContent(photo);
        file.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        var form = new MultipartFormDataContent { { file, "photo", "food.jpg" } };
        if (hint is not null) form.Add(new StringContent(hint), "hint");
        if (barcode is not null) form.Add(new StringContent(barcode), "barcode");
        return form;
    }

    private async Task<(HttpClient Http, Guid ClientId, string Phone)> ClientWithConsentAsync()
    {
        var phone = ApiFactory.NewPhone();
        var (http, _) = await _s.RegisterClientAsync(phone);
        (await http.PostAsync("/api/nutrition/ai-consent", null)).EnsureSuccessStatusCode();
        return (http, await _s.ClientIdAsync(http), phone);
    }

    private static async Task<FoodScanDto> AnalyzeAsync(HttpClient http, byte[] photo, string? hint = null)
    {
        var res = await http.PostAsync("/api/food-scanner/analyze", Form(photo, hint));
        Assert.True(res.IsSuccessStatusCode, $"{res.StatusCode}: {await res.Content.ReadAsStringAsync()}");
        return (await res.Content.ReadFromJsonAsync<FoodScanDto>(Json))!;
    }

    private static string Marker() => Guid.NewGuid().ToString("N")[..12];

    [Fact]
    public async Task Photo_is_analysed_after_consent_and_nutrition_comes_from_the_database_not_the_ai()
    {
        var phone = ApiFactory.NewPhone();
        var (http, _) = await _s.RegisterClientAsync(phone);
        var marker = Marker();
        Ai.AnswerJson(marker, () => Vision());

        var refused = await http.PostAsync("/api/food-scanner/analyze", Form(Photo(marker)));
        Assert.Equal(HttpStatusCode.Conflict, refused.StatusCode);
        Assert.Equal("ai_consent_required", await Scenario.ErrorCodeAsync(refused));
        Assert.Equal(0, Ai.JsonCallsFor(marker));

        var consent = (await (await http.PostAsync("/api/nutrition/ai-consent", null)).Content.ReadFromJsonAsync<NutritionProfileDto>(Json))!;
        Assert.NotNull(consent.AiConsentAt);
        Assert.Equal("Fake AI", consent.AiProvider);

        var scan = await AnalyzeAsync(http, Photo(marker), "это плов");
        Assert.Equal(FoodScanStatus.Recognized, scan.Status);
        Assert.False(scan.Reused);
        Assert.True(scan.HasPhoto);
        var dish = Assert.Single(scan.Dishes);
        Assert.Equal("Плов", dish.Name);
        Assert.Equal("plov", dish.TraditionalDishKey);
        Assert.All(dish.Ingredients, i => Assert.Equal(IngredientMatch.CatalogKey, i.Match));
        Assert.All(dish.Ingredients, i => Assert.Equal(NutritionSource.Usda, i.Source));
        // USDA values × grams: rice 200 g = 260, beef 80 g = 241.6, cottonseed oil 15 g = 132.6 kcal.
        Assert.Equal(634m, dish.Totals.Values.Kcal);
        Assert.Equal(29.5m, dish.Totals.Values.Protein);
        Assert.Equal(30.9m, dish.Totals.Values.Fat);
        Assert.Equal(56.3m, dish.Totals.Values.Carbs);
        Assert.Equal(443m, dish.Totals.KcalMin); // medium weight confidence ±25 %, oil ±50 %
        Assert.Equal(826m, dish.Totals.KcalMax);
        Assert.Equal(295m, dish.Totals.Grams);
        Assert.Equal(132.6m, dish.Ingredients.Single(i => i.Role == IngredientRole.Fat).Nutrients!.Kcal);
        Assert.DoesNotContain("cooking_fat_missing", dish.Warnings);

        // What went to the AI: the photo without its EXIF (GPS), the hint, the catalog — not the person.
        var sent = Ai.JsonRequests.Last(r => Encoding.ASCII.GetString(r.Images[0].Data).Contains(marker));
        Assert.DoesNotContain("GPS", Encoding.ASCII.GetString(sent.Images[0].Data));
        Assert.Contains("это плов", sent.UserText);
        Assert.Contains("rice_white_cooked", sent.System);
        Assert.DoesNotContain(phone, sent.System + sent.UserText);
        Assert.DoesNotContain("Test Client", sent.System + sent.UserText);

        // The stored photo is clean too, and only its owner can get it.
        var photo = await http.GetAsync($"/api/food-scanner/result/{scan.Id}/photo");
        Assert.Equal("image/jpeg", photo.Content.Headers.ContentType?.MediaType);
        Assert.DoesNotContain("GPS", Encoding.ASCII.GetString(await photo.Content.ReadAsByteArrayAsync()));
        var (stranger, _) = await _s.RegisterClientAsync();
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.GetAsync($"/api/food-scanner/result/{scan.Id}/photo")).StatusCode);

        // Nothing is added to the diary without the client's confirmation.
        var day = (await http.GetFromJsonAsync<DiaryDayDto>("/api/food-diary", Json))!;
        Assert.All(day.Meals, m => Assert.Empty(m.Entries));
        var history = (await http.GetFromJsonAsync<PagedResult<FoodScanSummaryDto>>("/api/food-scanner/history", Json))!;
        var item = Assert.Single(history.Items);
        Assert.Equal(("Плов", 634m, (DateTimeOffset?)null), (item.Title, item.Kcal, item.AddedToDiaryAt));
    }

    [Fact]
    public async Task The_same_photo_again_reuses_the_result_without_a_new_ai_request()
    {
        var (http, _, _) = await ClientWithConsentAsync();
        var marker = Marker();
        Ai.AnswerJson(marker, () => Vision());
        var first = await AnalyzeAsync(http, Photo(marker));
        var again = await AnalyzeAsync(http, Photo(marker));
        Assert.True(again.Reused);
        Assert.Equal(first.Id, again.Id);
        Assert.Equal(1, Ai.JsonCallsFor(marker));
        // A different hint is a different question.
        await AnalyzeAsync(http, Photo(marker), "без масла");
        Assert.Equal(2, Ai.JsonCallsFor(marker));
    }

    [Fact]
    public async Task Client_corrects_the_dish_and_adds_it_to_the_diary()
    {
        var (http, _, _) = await ClientWithConsentAsync();
        var marker = Marker();
        Ai.AnswerJson(marker, () => Vision());
        var scan = await AnalyzeAsync(http, Photo(marker));
        var dish = scan.Dishes[0];
        var rice = dish.Ingredients.Single(i => i.Name == "Рис");
        var beef = dish.Ingredients.Single(i => i.Name == "Говядина");
        var cucumber = (await http.GetFromJsonAsync<FoodSearchResultDto>("/api/nutrition/foods/search?q=огурец", Json))!.Products[0];
        Assert.Equal(15m, cucumber.Per100.Kcal);

        // Less rice, no oil, a cucumber added.
        var res = await http.PutAsJsonAsync($"/api/food-scanner/result/{scan.Id}", new
        {
            dishIndex = 0, name = "Плов без масла",
            ingredients = new object[]
            {
                new { id = rice.Id, grams = 150, role = "Main" },
                new { id = beef.Id, grams = 80, role = "Main" },
                new { productId = cucumber.Id, grams = 100, role = "Garnish" },
            },
        }, Json);
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        var edited = (await res.Content.ReadFromJsonAsync<FoodScanDto>(Json))!.Dishes[0];
        Assert.Equal("Плов без масла", edited.Name);
        Assert.True(edited.UserEdited);
        Assert.Equal(452m, edited.Totals.Values.Kcal); // 195 + 241.6 + 15
        Assert.Equal(330m, edited.Totals.Grams);
        Assert.Equal(IngredientMatch.User, edited.Ingredients.Single(i => i.ProductId == cucumber.Id).Match);
        Assert.Equal(NutritionMath.UserWeightUncertainty, edited.Ingredients.Single(i => i.Id == rice.Id).Uncertainty);

        var bad = await http.PutAsJsonAsync($"/api/food-scanner/result/{scan.Id}",
            new { dishIndex = 0, ingredients = new[] { new { id = Guid.NewGuid(), grams = 10 } } }, Json);
        Assert.Equal("ingredient_not_found", await Scenario.ErrorCodeAsync(bad));

        // The client confirms: the edited dish goes to lunch.
        var created = await http.PostAsJsonAsync("/api/food-diary", new
        {
            mealType = "Lunch", scanId = scan.Id, name = edited.Name,
            items = edited.Ingredients.Select(i => new { scanIngredientId = i.Id, grams = i.Grams, role = i.Role }),
        }, Json);
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var entry = (await created.Content.ReadFromJsonAsync<DiaryEntryDto>(Json))!;
        Assert.Equal(452m, entry.Totals.Values.Kcal);
        Assert.True(entry.HasPhoto);
        Assert.Equal(MealType.Lunch, entry.MealType);

        var day = (await http.GetFromJsonAsync<DiaryDayDto>("/api/food-diary", Json))!;
        Assert.Equal([MealType.Breakfast, MealType.Lunch, MealType.Dinner, MealType.Snack], day.Meals.Select(m => m.MealType));
        Assert.Equal(entry.Id, Assert.Single(day.Meals[1].Entries).Id);
        Assert.Equal(452m, day.Totals.Values.Kcal);
        var daily = (await http.GetFromJsonAsync<NutritionDailyDto>("/api/nutrition/daily", Json))!;
        Assert.Equal(452m, daily.Totals.Values.Kcal);
        Assert.Equal(452m, daily.KcalByMeal[MealType.Lunch]);
        Assert.NotNull((await http.GetFromJsonAsync<FoodScanDto>($"/api/food-scanner/result/{scan.Id}", Json))!.AddedToDiaryAt);
    }

    [Fact]
    public async Task Unknown_ingredient_stays_without_values_until_the_client_picks_a_product()
    {
        var (http, _, _) = await ClientWithConsentAsync();
        var marker = Marker();
        Ai.AnswerJson(marker, () => Vision(new[]
        {
            Dish("Салат", "none", 0.8, 150, "high", "raw",
                Ingredient("Помидор", "tomato", "tomato_raw", 100), Ingredient("Неведомая трава", "mystery herb", null, 50, "garnish")),
        }));
        var dish = (await AnalyzeAsync(http, Photo(marker))).Dishes[0];
        var unknown = dish.Ingredients.Single(i => i.Name == "Неведомая трава");
        Assert.Equal(IngredientMatch.None, unknown.Match);
        Assert.Null(unknown.Per100);
        Assert.True(dish.Totals.Incomplete);
        Assert.Equal(18m, dish.Totals.Values.Kcal); // the tomato only; the herb is not guessed
        Assert.Contains("unmatched_ingredients", dish.Warnings);

        var cucumber = (await http.GetFromJsonAsync<FoodSearchResultDto>("/api/nutrition/foods/search?q=огурец", Json))!.Products[0];
        var tomato = dish.Ingredients.Single(i => i.Name == "Помидор");
        var scanId = (await http.GetFromJsonAsync<PagedResult<FoodScanSummaryDto>>("/api/food-scanner/history", Json))!.Items[0].Id;
        var fixedDish = (await (await http.PutAsJsonAsync($"/api/food-scanner/result/{scanId}", new
        {
            dishIndex = 0,
            ingredients = new object[] { new { id = tomato.Id, grams = 100 }, new { id = unknown.Id, productId = cucumber.Id, grams = 50 } },
        }, Json)).Content.ReadFromJsonAsync<FoodScanDto>(Json))!.Dishes[0];
        Assert.False(fixedDish.Totals.Incomplete);
        Assert.Equal(26m, fixedDish.Totals.Values.Kcal); // 18 + 7.5 = 25.5 → 26
        Assert.Equal("Неведомая трава", fixedDish.Ingredients[1].Name); // the client's own name for it stays
        Assert.Equal(IngredientMatch.User, fixedDish.Ingredients[1].Match);
    }

    [Fact]
    public async Task Unclear_photos_ask_for_clarification_and_a_known_dish_seen_vaguely_gets_its_typical_recipe()
    {
        var (http, _, _) = await ClientWithConsentAsync();
        var blurry = Marker();
        Ai.AnswerJson(blurry, () => System.Text.Json.JsonSerializer.Serialize(new
        {
            imageQuality = "blurry", containsFood = true, clarificationQuestion = "Это манты или чучвара?", dishes = Array.Empty<object>(),
        }));
        var unclear = await AnalyzeAsync(http, Photo(blurry));
        Assert.Equal(FoodScanStatus.NeedsClarification, unclear.Status);
        Assert.Equal("Это манты или чучвара?", unclear.ClarificationQuestion);
        Assert.Equal("blurry", unclear.ImageQuality);

        var empty = Marker();
        Ai.AnswerJson(empty, () => Vision(containsFood: false));
        Assert.Equal(FoodScanStatus.NotFood, (await AnalyzeAsync(http, Photo(empty))).Status);

        var vague = Marker();
        Ai.AnswerJson(vague, () => Vision(new[] { Dish("Плов", "plov", 0.7, 400, "low", "mixed") }));
        var dish = (await AnalyzeAsync(http, Photo(vague))).Dishes[0];
        Assert.True(dish.Ingredients.Count >= 4);
        Assert.Equal(400m, dish.Totals.Grams, 0); // the template scaled to the seen weight
        Assert.Contains(dish.Ingredients, i => i.Role == IngredientRole.Fat);
        Assert.Contains("weight_uncertain", dish.Warnings);
    }

    [Fact]
    public async Task Invalid_ai_answers_are_retried_once_then_rejected()
    {
        var (http, clientId, _) = await ClientWithConsentAsync();
        var once = Marker();
        Ai.AnswerJson(once, () => "{\"oops\": true}", () => Vision());
        Assert.Equal(FoodScanStatus.Recognized, (await AnalyzeAsync(http, Photo(once))).Status);
        Assert.Equal(2, Ai.JsonCallsFor(once));

        var never = Marker();
        Ai.AnswerJson(never, () => "not json", () => "still not json");
        var res = await http.PostAsync("/api/food-scanner/analyze", Form(Photo(never)));
        Assert.Equal(HttpStatusCode.BadGateway, res.StatusCode);
        Assert.Equal("ai_invalid_response", await Scenario.ErrorCodeAsync(res));

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var usage = await db.AiUsage.Where(u => u.ClientProfileId == clientId).ToListAsync();
        Assert.Equal(4, usage.Count); // every request is recorded with its tokens
        Assert.Equal(1, usage.Count(u => u.Success)); // only the usable answer counts against the daily limit
        Assert.All(usage, u => Assert.True(u.CostUsd == 0 && u.InputTokens == FakeAi.Usage.InputTokens)); // fake model: no price configured
    }

    [Fact]
    public async Task Ai_problems_and_limits_are_reported_with_stable_codes()
    {
        var (http, _, _) = await ClientWithConsentAsync();
        Ai.Configured = false;
        try
        {
            var off = await http.PostAsync("/api/food-scanner/analyze", Form(Photo(Marker())));
            Assert.Equal(HttpStatusCode.ServiceUnavailable, off.StatusCode);
            Assert.Equal("ai_not_configured", await Scenario.ErrorCodeAsync(off));
            Assert.False((await http.GetFromJsonAsync<NutritionProfileDto>("/api/nutrition/profile", Json))!.AiAvailable);
        }
        finally
        {
            Ai.Configured = true;
        }

        var down = Marker();
        Ai.AnswerJson(down, () => "unavailable");
        var unavailable = await http.PostAsync("/api/food-scanner/analyze", Form(Photo(down)));
        Assert.Equal("ai_unavailable", await Scenario.ErrorCodeAsync(unavailable));

        var marker = Marker();
        Ai.AnswerJson(marker, () => Vision());
        for (var i = 0; i < ApiFactory.PhotoScansPerDay; i++)
            await AnalyzeAsync(http, Photo(marker + i));
        var profile = (await http.GetFromJsonAsync<NutritionProfileDto>("/api/nutrition/profile", Json))!;
        Assert.Equal((ApiFactory.PhotoScansPerDay, ApiFactory.PhotoScansPerDay), (profile.ScansToday, profile.ScansPerDay));
        var limited = await http.PostAsync("/api/food-scanner/analyze", Form(Photo(marker + "x")));
        Assert.Equal(HttpStatusCode.TooManyRequests, limited.StatusCode);
        Assert.Equal("ai_quota_exceeded", await Scenario.ErrorCodeAsync(limited));
    }

    [Fact]
    public async Task A_second_photo_while_the_first_is_analysed_is_refused()
    {
        var (http, _, _) = await ClientWithConsentAsync();
        var marker = Marker();
        Ai.AnswerJson(marker, () => Vision());
        Ai.Gate = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        try
        {
            var first = http.PostAsync("/api/food-scanner/analyze", Form(Photo(marker + "a")));
            for (var i = 0; i < 100 && Ai.JsonCallsFor(marker + "a") == 0; i++) await Task.Delay(20);
            var second = await http.PostAsync("/api/food-scanner/analyze", Form(Photo(marker + "b")));
            Assert.Equal("scan_in_progress", await Scenario.ErrorCodeAsync(second));
            Ai.Gate.SetResult();
            Assert.Equal(HttpStatusCode.OK, (await first).StatusCode);
        }
        finally
        {
            Ai.Gate = null;
        }
    }

    [Fact]
    public async Task Photos_are_checked_before_anything_is_sent()
    {
        var (http, _, _) = await ClientWithConsentAsync();
        var before = Ai.JsonRequests.Count;
        var png = new ByteArrayContent([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0]);
        png.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        Assert.Equal("photo_invalid_format", await Scenario.ErrorCodeAsync(
            await http.PostAsync("/api/food-scanner/analyze", new MultipartFormDataContent { { png, "photo", "x.jpg" } })));
        Assert.Equal("photo_bad_size", await Scenario.ErrorCodeAsync(
            await http.PostAsync("/api/food-scanner/analyze", Form(Photo(Marker(), 200, 150)))));
        Assert.Equal("photo_invalid_format", await Scenario.ErrorCodeAsync(
            await http.PostAsync("/api/food-scanner/analyze", new MultipartFormDataContent { { new StringContent("x"), "hint" } })));
        Assert.Equal(before, Ai.JsonRequests.Count);
    }

    [Fact]
    public async Task Barcode_lookup_asks_open_food_facts_once_and_falls_back_cleanly()
    {
        var (http, _, _) = await ClientWithConsentAsync();
        var code = "487" + Random.Shared.NextInt64(1_000_000_000, 9_999_999_999);
        factory.FoodSources.Barcodes[code] = FakeFoodSources.Product(code, "Кефир Musaffo", 120, 3, 5, 12);

        var scan = (await (await http.PostAsJsonAsync("/api/food-scanner/barcode", new { code }, Json)).Content.ReadFromJsonAsync<FoodScanDto>(Json))!;
        Assert.Equal(FoodScanKind.Barcode, scan.Kind);
        Assert.Equal(("Кефир Musaffo", 120m, NutritionSource.OpenFoodFacts, code), (scan.Product!.Name, scan.Product.Per100.Kcal, scan.Product.Source, scan.Product.Barcode));
        Assert.Equal([Allergen.Milk], scan.Product.Allergens);
        await http.PostAsJsonAsync("/api/food-scanner/barcode", new { code }, Json);
        Assert.Equal(1, factory.FoodSources.BarcodeCalls[code]); // cached

        var entry = (await (await http.PostAsJsonAsync("/api/food-diary", new
        {
            mealType = "Snack", items = new[] { new { productId = scan.Product.Id, grams = 250 } },
        }, Json)).Content.ReadFromJsonAsync<DiaryEntryDto>(Json))!;
        Assert.Equal(300m, entry.Totals.Values.Kcal);
        Assert.Equal(1000m, entry.Totals.Values.SodiumMg); // 400 mg per 100 g
        Assert.Equal(NutritionMath.PackagedUncertainty, entry.Totals.KcalMax / entry.Totals.Values.Kcal - 1);

        var unknown = "4870000" + Random.Shared.Next(100000, 999999);
        var missing = await http.PostAsJsonAsync("/api/food-scanner/barcode", new { code = unknown }, Json);
        Assert.Equal(HttpStatusCode.NotFound, missing.StatusCode);
        Assert.Equal("barcode_not_found", await Scenario.ErrorCodeAsync(missing));
        await http.PostAsJsonAsync("/api/food-scanner/barcode", new { code = unknown }, Json);
        Assert.Equal(1, factory.FoodSources.BarcodeCalls[unknown]); // "not found" is remembered too

        factory.FoodSources.BarcodeDown = true;
        try
        {
            var down = await http.PostAsJsonAsync("/api/food-scanner/barcode", new { code = "46" + Random.Shared.NextInt64(10_000_000_000, 99_999_999_999) }, Json);
            Assert.Equal("food_db_unavailable", await Scenario.ErrorCodeAsync(down));
            // A product already cached is still served while the database is down.
            Assert.Equal(HttpStatusCode.OK, (await http.PostAsJsonAsync("/api/food-scanner/barcode", new { code }, Json)).StatusCode);
        }
        finally
        {
            factory.FoodSources.BarcodeDown = false;
        }
        Assert.Equal("validation_failed", await Scenario.ErrorCodeAsync(await http.PostAsJsonAsync("/api/food-scanner/barcode", new { code = "12ab" }, Json)));
    }

    [Fact]
    public async Task Label_photo_becomes_the_clients_own_product_found_by_its_barcode_later()
    {
        var (http, _, _) = await ClientWithConsentAsync();
        var marker = Marker();
        var code = "460" + Random.Shared.NextInt64(1_000_000_000, 9_999_999_999);
        Ai.AnswerJson(marker, () => System.Text.Json.JsonSerializer.Serialize(new
        {
            isNutritionLabel = true, legible = true, productName = "Сузьма домашняя", brand = "Ферма", basis = "per_100g",
            per100 = new { energyKcal = 160.0, energyKj = 670.0, protein = 9.0, fat = 12.0, carbs = 4.0, fiber = (double?)null, sugar = 4.0, saturatedFat = 7.5, sodiumMg = (double?)null, saltG = 0.5 },
            perServing = (object?)null, servingSizeGrams = (double?)null, packageWeightGrams = 400.0, ingredientsText = "молоко, закваска",
            allergensDeclared = new[] { "Milk" }, barcode = (string?)null, clarificationQuestion = (string?)null,
        }));
        var res = await http.PostAsync("/api/food-scanner/label", Form(Photo(marker), barcode: code));
        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        var scan = (await res.Content.ReadFromJsonAsync<FoodScanDto>(Json))!;
        Assert.Equal((FoodScanKind.Label, FoodScanStatus.Recognized), (scan.Kind, scan.Status));
        var product = scan.Product!;
        Assert.True(product.IsOwn);
        Assert.Equal((NutritionSource.Label, 160m, 200m, 400m), (product.Source, product.Per100.Kcal, product.Per100.SodiumMg!.Value, product.PackageGrams!.Value));
        Assert.Equal([Allergen.Milk], product.Allergens);

        var byBarcode = (await (await http.PostAsJsonAsync("/api/food-scanner/barcode", new { code }, Json)).Content.ReadFromJsonAsync<FoodScanDto>(Json))!;
        Assert.Equal(product.Id, byBarcode.Product!.Id);
        Assert.False(factory.FoodSources.BarcodeCalls.ContainsKey(code)); // the client's own label first
        var (other, _) = await _s.RegisterClientAsync();
        Assert.Equal("barcode_not_found", await Scenario.ErrorCodeAsync(await other.PostAsJsonAsync("/api/food-scanner/barcode", new { code }, Json)));
        Assert.Equal(HttpStatusCode.NotFound, (await other.GetAsync($"/api/nutrition/foods/{product.Id}")).StatusCode);
    }

    [Fact]
    public async Task Nutrition_data_is_private_to_its_owner()
    {
        var (owner, _, _) = await ClientWithConsentAsync();
        var marker = Marker();
        Ai.AnswerJson(marker, () => Vision());
        var scan = await AnalyzeAsync(owner, Photo(marker));
        var entry = (await (await owner.PostAsJsonAsync("/api/food-diary", new
        {
            mealType = "Dinner", scanId = scan.Id, items = scan.Dishes[0].Ingredients.Select(i => new { scanIngredientId = i.Id, grams = i.Grams }),
        }, Json)).Content.ReadFromJsonAsync<DiaryEntryDto>(Json))!;

        var (stranger, _) = await _s.RegisterClientAsync();
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.GetAsync($"/api/food-scanner/result/{scan.Id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.PutAsJsonAsync($"/api/food-scanner/result/{scan.Id}",
            new { dishIndex = 0, ingredients = new[] { new { id = scan.Dishes[0].Ingredients[0].Id, grams = 1 } } }, Json)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.DeleteAsync($"/api/food-scanner/result/{scan.Id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.GetAsync($"/api/food-diary/{entry.Id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.DeleteAsync($"/api/food-diary/{entry.Id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.PostAsJsonAsync($"/api/food-diary/{entry.Id}/repeat", new { }, Json)).StatusCode);
        // Someone else's scan ingredients cannot be copied into one's own diary.
        Assert.Equal("item_not_found", await Scenario.ErrorCodeAsync(await stranger.PostAsJsonAsync("/api/food-diary", new
        {
            mealType = "Dinner", items = new[] { new { scanIngredientId = scan.Dishes[0].Ingredients[0].Id, grams = 100 } },
        }, Json)));
        Assert.Empty((await stranger.GetFromJsonAsync<PagedResult<FoodScanSummaryDto>>("/api/food-scanner/history", Json))!.Items);
        Assert.Equal(0m, (await stranger.GetFromJsonAsync<DiaryDayDto>("/api/food-diary", Json))!.Totals.Values.Kcal);

        var admin = await factory.AdminAsync();
        var (trainer, _) = await _s.CreateTrainerAsync(admin);
        Assert.Equal(HttpStatusCode.Forbidden, (await trainer.GetAsync("/api/food-diary")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await admin.GetAsync("/api/food-scanner/history")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await factory.CreateClient().GetAsync("/api/nutrition/daily")).StatusCode);

        // The owner deletes the scan: the photo is gone, the diary entry stays without it.
        Assert.Equal(HttpStatusCode.NoContent, (await owner.DeleteAsync($"/api/food-scanner/result/{scan.Id}")).StatusCode);
        var kept = (await owner.GetFromJsonAsync<DiaryEntryDto>($"/api/food-diary/{entry.Id}", Json))!;
        Assert.False(kept.HasPhoto);
        Assert.Equal(entry.Totals.Values.Kcal, kept.Totals.Values.Kcal);
    }
}
