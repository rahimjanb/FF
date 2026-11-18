using System.Collections.Concurrent;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features.Ai;
using FitnessFormulasi.Api.Features.Banners;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features.Nutrition;

/// <summary>
/// Scanning: a food photo (AI vision → ingredients → Nutrition Engine), a package label (AI reads it), a barcode
/// (Open Food Facts). Every scan is kept in the client's history with its calculation; nothing goes to the diary
/// until the client confirms it.
/// </summary>
public sealed class FoodScannerService(
    AppDbContext db, FoodRecognitionService recognition, FoodDatabaseService foods, NutritionProfileService profiles,
    MediaStorage media, IClubClock clock, ILogger<FoodScannerService> logger)
{
    /// <summary>One analysis at a time per client: a double tap must not pay for two AI requests.</summary>
    private static readonly ConcurrentDictionary<Guid, SemaphoreSlim> Running = new();

    /// <summary>The same photo (and hint) sent again within this time returns the earlier result.</summary>
    private static readonly TimeSpan ReuseWindow = TimeSpan.FromDays(7);

    public async Task<FoodScanDto> AnalyzePhotoAsync(Guid clientId, IFormFile? photo, string? hint, CancellationToken ct)
    {
        await profiles.EnsureAiConsentAsync(clientId, ct);
        var image = await FoodImage.ReadAsync(photo, ct);
        hint = Hint(hint);

        var since = clock.UtcNow - ReuseWindow;
        var earlier = await db.FoodScans.AsNoTracking()
            .Where(s => s.ClientProfileId == clientId && s.Kind == FoodScanKind.Photo && s.ImageHash == image.Sha256 && s.Hint == hint
                        && s.CreatedAt >= since && s.Status != FoodScanStatus.Failed)
            .OrderByDescending(s => s.CreatedAt).Select(s => s.Id).FirstOrDefaultAsync(ct);
        if (earlier != Guid.Empty) return await GetAsync(clientId, earlier, ct) with { Reused = true };

        await using var _ = await LockAsync(clientId, ct);
        var analysis = await recognition.AnalyzeAsync(clientId, image.Jpeg, hint, ct);

        var scan = new FoodScan
        {
            ClientProfileId = clientId, Kind = FoodScanKind.Photo, ImageHash = image.Sha256, Hint = hint,
            ImageQuality = analysis.ImageQuality, ClarificationQuestion = analysis.ClarificationQuestion, AiModel = analysis.Model,
            AiResponseJson = analysis.Json,
        };
        var index = 0;
        foreach (var dish in analysis.Dishes)
            scan.Results.Add(await BuildDishAsync(clientId, dish, index++, ct));

        scan.Status = !analysis.ContainsFood ? FoodScanStatus.NotFood
            : scan.Results.Count == 0 || scan.Results.All(r => r.Confidence < 0.35m || r.Ingredients.Count == 0) ? FoodScanStatus.NeedsClarification
            : FoodScanStatus.Recognized;
        if (scan.Status == FoodScanStatus.NeedsClarification && scan.ClarificationQuestion is null)
            scan.ClarificationQuestion = "Не удалось уверенно определить блюдо. Напишите, что на фото, или переснимите при хорошем свете.";

        await SavePhotoAsync(scan, image.Jpeg, ct);
        db.FoodScans.Add(scan);
        await db.SaveChangesAsync(ct);
        logger.LogInformation("Food photo {ScanId}: {Status}, {Dishes} dishes", scan.Id, scan.Status, scan.Results.Count);
        return await GetAsync(clientId, scan.Id, ct);
    }

    public async Task<FoodScanDto> ReadLabelAsync(Guid clientId, IFormFile? photo, string? barcode, CancellationToken ct)
    {
        await profiles.EnsureAiConsentAsync(clientId, ct);
        var image = await FoodImage.ReadAsync(photo, ct);
        if (barcode is not null && !System.Text.RegularExpressions.Regex.IsMatch(barcode, @"^\d{8,14}$"))
            throw ApiException.BadRequest("barcode_invalid", "The barcode must be 8 to 14 digits.");

        await using var _ = await LockAsync(clientId, ct);
        var label = await recognition.ReadLabelAsync(clientId, image.Jpeg, ct);
        var scan = new FoodScan
        {
            ClientProfileId = clientId, Kind = FoodScanKind.Label, ImageHash = image.Sha256, Barcode = barcode ?? label.Barcode,
            ClarificationQuestion = label.ClarificationQuestion, AiModel = label.Model, AiResponseJson = label.Json,
            Status = label.Readable ? FoodScanStatus.Recognized : FoodScanStatus.NeedsClarification,
        };
        if (label.Readable && label.Per100 is { } v)
        {
            var product = await foods.CreateOwnAsync(clientId, new CreateFoodProductRequest
            {
                Name = label.ProductName ?? "Продукт с этикетки",
                Brand = label.Brand,
                Category = FoodCategory.PackagedFood,
                Per100 = new NutrientsInput
                {
                    Kcal = v.Kcal!.Value, Protein = v.Protein!.Value, Fat = v.Fat!.Value, Carbs = v.Carbs!.Value, Fiber = v.Fiber,
                    Sugar = v.Sugar, SaturatedFat = v.SaturatedFat, SodiumMg = v.SodiumMg is > 40000 ? null : v.SodiumMg,
                },
                Per100Ml = label.Per100Ml,
                ServingGrams = label.ServingGrams,
                PackageGrams = label.PackageGrams,
                Barcode = scan.Barcode,
            }, NutritionSource.Label, label.Allergens, label.IngredientsText, ct);
            scan.FoodProductId = product.Id;
        }
        await SavePhotoAsync(scan, image.Jpeg, ct);
        db.FoodScans.Add(scan);
        await db.SaveChangesAsync(ct);
        return await GetAsync(clientId, scan.Id, ct);
    }

    public async Task<FoodScanDto> BarcodeAsync(Guid clientId, string code, CancellationToken ct)
    {
        var product = await foods.FindByBarcodeAsync(clientId, code, ct);
        var scan = new FoodScan
        {
            ClientProfileId = clientId, Kind = FoodScanKind.Barcode, Barcode = code, FoodProductId = product.Id,
            Status = FoodScanStatus.Recognized,
        };
        db.FoodScans.Add(scan);
        await db.SaveChangesAsync(ct);
        return await GetAsync(clientId, scan.Id, ct);
    }

    public async Task<PagedResult<FoodScanSummaryDto>> HistoryAsync(Guid clientId, PageQuery page, CancellationToken ct)
    {
        var query = db.FoodScans.AsNoTracking().Where(s => s.ClientProfileId == clientId).OrderByDescending(s => s.CreatedAt)
            .Select(s => new
            {
                s.Id, s.Kind, s.Status, s.CreatedAt, s.PhotoId, s.AddedToDiaryAt,
                Product = s.Product == null ? null : s.Product.Name,
                Dishes = s.Results.OrderBy(r => r.DishIndex).Select(r => new { r.Name, r.Kcal }).ToList(),
            });
        var paged = await query.ToPagedAsync(page, ct);
        return new PagedResult<FoodScanSummaryDto>(paged.Items.Select(s => new FoodScanSummaryDto(
            s.Id, s.Kind, s.Status, s.CreatedAt, s.PhotoId is not null,
            s.Product ?? (s.Dishes.Count > 0 ? string.Join(", ", s.Dishes.Select(d => d.Name)) : ""),
            s.Dishes.Count > 0 ? Math.Round(s.Dishes.Sum(d => d.Kcal)) : null, s.Dishes.Count, s.AddedToDiaryAt)).ToList(),
            paged.Page, paged.PageSize, paged.TotalCount);
    }

    public async Task<FoodScanDto> GetAsync(Guid clientId, Guid id, CancellationToken ct)
    {
        var scan = await db.FoodScans.AsNoTracking().AsSplitQuery()
                       .Include(s => s.Product)
                       .Include(s => s.Results).ThenInclude(r => r.Ingredients).ThenInclude(i => i.Product)
                       .SingleOrDefaultAsync(s => s.Id == id && s.ClientProfileId == clientId, ct)
                   ?? throw ApiException.NotFound("Scan");
        return ToDto(scan, clientId);
    }

    /// <summary>
    /// The client corrected a dish: weights, removed or added ingredients, a product chosen for an unknown one, the
    /// name. The totals are recalculated from the database values; the AI is not asked again.
    /// </summary>
    public async Task<FoodScanDto> UpdateDishAsync(Guid clientId, Guid scanId, UpdateDishRequest req, CancellationToken ct)
    {
        var result = await db.FoodRecognitionResults.Include(r => r.Ingredients)
                         .SingleOrDefaultAsync(r => r.FoodScanId == scanId && r.DishIndex == req.DishIndex && r.Scan.ClientProfileId == clientId, ct)
                     ?? throw ApiException.NotFound("Dish");
        var existing = result.Ingredients.ToDictionary(i => i.Id);
        var keep = new List<FoodRecognitionIngredient>();
        var order = 0;
        foreach (var input in req.Ingredients)
        {
            FoodRecognitionIngredient ingredient;
            if (input.Id is { } id)
            {
                ingredient = existing.GetValueOrDefault(id) ?? throw ApiException.BadRequest("ingredient_not_found", "Unknown ingredient of this dish.");
                if (ingredient.Grams != input.Grams) ingredient.Uncertainty = NutritionMath.UserWeightUncertainty;
            }
            else
            {
                if (input.ProductId is null)
                    throw ApiException.BadRequest("product_required", "Choose a product for the new ingredient.");
                ingredient = new FoodRecognitionIngredient
                {
                    Name = "", FoodRecognitionResultId = result.Id, Uncertainty = NutritionMath.UserWeightUncertainty,
                };
                db.FoodRecognitionIngredients.Add(ingredient);
            }
            if (input.ProductId is { } productId && productId != ingredient.FoodProductId)
            {
                var product = await foods.ProductAsync(clientId, productId, ct);
                Snapshot(ingredient, product);
                ingredient.Match = IngredientMatch.User;
                if (input.Id is null || string.IsNullOrWhiteSpace(ingredient.Name)) ingredient.Name = product.Name;
            }
            if (!string.IsNullOrWhiteSpace(input.Name)) ingredient.Name = input.Name.Trim();
            ingredient.Grams = input.Grams;
            ingredient.Role = input.Role;
            ingredient.SortOrder = order++;
            keep.Add(ingredient);
        }
        foreach (var removed in result.Ingredients.Where(i => !keep.Contains(i)).ToList())
            db.FoodRecognitionIngredients.Remove(removed);
        if (!string.IsNullOrWhiteSpace(req.Name)) result.Name = req.Name.Trim();
        result.UserEdited = true;
        result.NeedsConfirmation = false;
        ApplyTotals(result, keep);
        result.EstimatedWeightGrams = Math.Round(keep.Sum(i => i.Grams));
        await db.SaveChangesAsync(ct);
        return await GetAsync(clientId, scanId, ct);
    }

    /// <summary>Deletes the scan and its photo. Diary entries made from it stay (without the photo).</summary>
    public async Task DeleteAsync(Guid clientId, Guid id, CancellationToken ct)
    {
        var scan = await db.FoodScans.SingleOrDefaultAsync(s => s.Id == id && s.ClientProfileId == clientId, ct)
                   ?? throw ApiException.NotFound("Scan");
        var photo = scan.PhotoId;
        db.FoodScans.Remove(scan);
        await db.SaveChangesAsync(ct);
        if (photo is { } p) media.Delete(p);
    }

    public async Task DeletePhotoAsync(Guid clientId, Guid id, CancellationToken ct)
    {
        var scan = await db.FoodScans.SingleOrDefaultAsync(s => s.Id == id && s.ClientProfileId == clientId, ct)
                   ?? throw ApiException.NotFound("Scan");
        if (scan.PhotoId is not { } photo) return;
        scan.PhotoId = null;
        await db.SaveChangesAsync(ct);
        media.Delete(photo);
    }

    public async Task<string> PhotoPathAsync(Guid clientId, Guid id, CancellationToken ct)
    {
        var photo = await db.FoodScans.Where(s => s.Id == id && s.ClientProfileId == clientId).Select(s => s.PhotoId).SingleOrDefaultAsync(ct);
        if (photo is not { } p || !media.Exists(p)) throw ApiException.NotFound("Photo");
        return media.PathFor(p);
    }

    // ---- Building and calculating ---------------------------------------------------------------------------------

    private async Task<FoodRecognitionResult> BuildDishAsync(Guid clientId, VisionDish dish, int index, CancellationToken ct)
    {
        var result = new FoodRecognitionResult
        {
            DishIndex = index, Name = dish.Name, NameUz = dish.NameUz, NameEn = dish.NameEn, Category = dish.Category,
            TraditionalDishKey = dish.TraditionalDishKey, Confidence = dish.Confidence, EstimatedWeightGrams = dish.EstimatedWeightGrams,
            WeightConfidence = dish.WeightConfidence, PreparationMethod = dish.Preparation, PreparationNote = dish.PreparationNote,
            PossibleAllergens = dish.PossibleAllergens.ToList(), NeedsConfirmation = dish.NeedsConfirmation || dish.Confidence < 0.6m,
            Notes = dish.Notes,
        };
        var ingredients = dish.Ingredients.ToList();
        if (ingredients.Count == 0 && dish.TraditionalDishKey is { } key)
            ingredients = await FromTemplateAsync(key, dish.EstimatedWeightGrams, ct); // a known dish seen too vaguely: the typical recipe

        var order = 0;
        foreach (var i in ingredients)
        {
            var (product, match) = await foods.MatchIngredientAsync(clientId, i.ProductKey, i.Name, i.NameEn, ct);
            var ingredient = new FoodRecognitionIngredient
            {
                SortOrder = order++, Name = i.Name, Grams = i.Grams, Role = i.Role, Match = match,
                Uncertainty = NutritionMath.UncertaintyFor(dish.WeightConfidence, i.Role),
            };
            if (product is not null) Snapshot(ingredient, product);
            result.Ingredients.Add(ingredient);
        }
        ApplyTotals(result, result.Ingredients);
        return result;
    }

    private async Task<List<VisionIngredient>> FromTemplateAsync(string dishKey, decimal weight, CancellationToken ct)
    {
        var recipe = await db.FoodRecipes.AsNoTracking().Include(r => r.Ingredients).ThenInclude(i => i.Product)
            .Where(r => r.DishKey == dishKey && r.IsTraditional && r.OwnerClientId == null).OrderBy(r => r.Key).FirstOrDefaultAsync(ct);
        if (recipe is null || weight <= 0) return [];
        var total = recipe.Ingredients.Sum(i => i.Grams);
        return recipe.Ingredients.OrderBy(i => i.SortOrder)
            .Select(i => new VisionIngredient(i.Product.Name, i.Product.NameEn, i.Product.Key, Math.Round(i.Grams / total * weight, 1), i.Role))
            .Where(i => i.Grams > 0).ToList();
    }

    private static void Snapshot(FoodRecognitionIngredient i, FoodProduct p)
    {
        i.FoodProductId = p.Id;
        i.Product = null;
        i.Kcal = p.Kcal;
        i.Protein = p.Protein;
        i.Fat = p.Fat;
        i.Carbs = p.Carbs;
        i.Fiber = p.Fiber;
        i.Sugar = p.Sugar;
        i.SaturatedFat = p.SaturatedFat;
        i.SodiumMg = p.SodiumMg;
        i.Source = p.Source;
        i.SourceRef = p.SourceRef;
    }

    private static void ApplyTotals(FoodRecognitionResult r, IEnumerable<FoodRecognitionIngredient> ingredients)
    {
        var t = NutritionMath.Sum(ingredients.Select(i => new FoodAmount(i.Grams, i.Kcal is null ? null : i, i.Uncertainty)));
        r.Grams = t.Grams;
        r.Kcal = t.Kcal;
        r.KcalMin = t.KcalMin;
        r.KcalMax = t.KcalMax;
        r.Protein = t.Protein;
        r.Fat = t.Fat;
        r.Carbs = t.Carbs;
        r.Fiber = t.Fiber;
        r.Sugar = t.Sugar;
        r.SaturatedFat = t.SaturatedFat;
        r.SodiumMg = t.SodiumMg;
        r.NutritionIncomplete = t.Incomplete;
    }

    private async Task SavePhotoAsync(FoodScan scan, byte[] jpeg, CancellationToken ct)
    {
        scan.PhotoId = Guid.CreateVersion7();
        using var stream = new MemoryStream(jpeg, writable: false);
        await media.SaveAsync(scan.PhotoId.Value, stream, ct);
    }

    private static async Task<IAsyncDisposable> LockAsync(Guid clientId, CancellationToken ct)
    {
        var gate = Running.GetOrAdd(clientId, _ => new SemaphoreSlim(1, 1));
        if (!await gate.WaitAsync(0, ct))
            throw ApiException.Conflict("scan_in_progress", "The previous photo is still being analysed.");
        return new Release(gate);
    }

    private sealed class Release(SemaphoreSlim gate) : IAsyncDisposable
    {
        public ValueTask DisposeAsync()
        {
            gate.Release();
            return ValueTask.CompletedTask;
        }
    }

    private static string? Hint(string? hint)
    {
        if (string.IsNullOrWhiteSpace(hint)) return null;
        var clean = new string(hint.Where(c => !char.IsControl(c)).ToArray()).Trim();
        return clean.Length <= 200 ? clean : clean[..200];
    }

    // ---- Mapping --------------------------------------------------------------------------------------------------

    public static FoodScanDto ToDto(FoodScan s, Guid clientId) => new(
        s.Id, s.Kind, s.Status, s.CreatedAt, s.PhotoId is not null, s.ImageQuality, s.ClarificationQuestion, s.Hint, false,
        s.Results.OrderBy(r => r.DishIndex).Select(r => DishDto(r, s.Results.Count)).ToList(),
        s.Product is null ? null : FoodDatabaseService.ToDto(s.Product, clientId), s.Barcode, s.AddedToDiaryAt);

    private static FoodDishDto DishDto(FoodRecognitionResult r, int dishCount)
    {
        var ingredients = r.Ingredients.OrderBy(i => i.SortOrder).ToList();
        var warnings = new List<string>();
        if (!r.UserEdited && r.Confidence < 0.6m) warnings.Add("low_confidence");
        if (!r.UserEdited && r.WeightConfidence == WeightConfidence.Low) warnings.Add("weight_uncertain");
        if (ingredients.Any(i => i.Kcal is null)) warnings.Add("unmatched_ingredients");
        if (r.PreparationMethod is PreparationMethod.Fried or PreparationMethod.DeepFried && ingredients.All(i => i.Role != IngredientRole.Fat))
            warnings.Add("cooking_fat_missing");
        if (dishCount > 1) warnings.Add("multiple_dishes");
        var totals = new Totals(r.Grams, r.Kcal, r.KcalMin, r.KcalMax, r.Protein, r.Fat, r.Carbs, r.Fiber, r.Sugar, r.SaturatedFat,
            r.SodiumMg, r.NutritionIncomplete);
        return new FoodDishDto(
            r.Id, r.DishIndex, r.Name, r.NameUz, r.NameEn, r.Category, r.TraditionalDishKey, r.Confidence, r.EstimatedWeightGrams,
            r.WeightConfidence, r.PreparationMethod, r.PreparationNote, r.PossibleAllergens, r.NeedsConfirmation, r.Notes, r.UserEdited,
            totals.ToDto(),
            ingredients.Select(i => new FoodScanIngredientDto(
                i.Id, i.Name, i.FoodProductId, i.Product?.Name, i.Grams, i.Role, i.Match, i.Uncertainty, NutritionMath.Dto(i),
                NutritionMath.For(i.Kcal is null ? null : i, i.Grams), i.Source, i.SourceRef)).ToList(),
            warnings);
    }
}
