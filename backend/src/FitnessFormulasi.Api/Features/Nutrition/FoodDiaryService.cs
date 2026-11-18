using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features.Nutrition;

/// <summary>
/// The food diary. Items copy the per-100 g values of their source, totals are computed here (never taken from the
/// app), and the day's summary row is recomputed after every change.
/// </summary>
public sealed class FoodDiaryService(
    AppDbContext db, FoodDatabaseService foods, NutritionProfileService profiles, NutritionSummaryService summaries, IClubClock clock)
{
    private static readonly MealType[] MealOrder = [MealType.Breakfast, MealType.Lunch, MealType.Dinner, MealType.Snack];

    public async Task<DiaryDayDto> DayAsync(Guid clientId, DateOnly? date, CancellationToken ct)
    {
        var day = date ?? clock.Today;
        var entries = await db.FoodDiaryEntries.AsNoTracking().Include(e => e.Items).Include(e => e.Scan)
            .Where(e => e.ClientProfileId == clientId && e.Date == day).OrderBy(e => e.EatenAt).ThenBy(e => e.CreatedAt).ToListAsync(ct);
        var meals = MealOrder.Select(m =>
        {
            var list = entries.Where(e => e.MealType == m).ToList();
            return new DiaryMealDto(m, TotalsOf(list).ToDto(), list.Select(ToDto).ToList());
        }).ToList();
        return new DiaryDayDto(day, await profiles.TargetAsync(clientId, ct), TotalsOf(entries).ToDto(), meals);
    }

    public async Task<DiaryEntryDto> GetAsync(Guid clientId, Guid id, CancellationToken ct) => ToDto(await LoadAsync(clientId, id, true, ct));

    public async Task<List<DiaryEntryDto>> RecentAsync(Guid clientId, int take, CancellationToken ct)
    {
        var recent = await db.FoodDiaryEntries.AsNoTracking().Include(e => e.Items).Include(e => e.Scan)
            .Where(e => e.ClientProfileId == clientId).OrderByDescending(e => e.CreatedAt).Take(100).ToListAsync(ct);
        // One per name: "repeat" lists what the client eats, not every occurrence.
        return recent.DistinctBy(e => FoodDatabaseService.Normalize(e.Name)).Take(Math.Clamp(take, 1, 50)).Select(ToDto).ToList();
    }

    public async Task<DiaryEntryDto> CreateAsync(Guid clientId, SaveDiaryEntryRequest req, CancellationToken ct)
    {
        var entry = new FoodDiaryEntry { ClientProfileId = clientId, Name = "" };
        await FillAsync(clientId, entry, req, ct);
        db.FoodDiaryEntries.Add(entry);
        if (entry.FoodScanId is { } scanId)
            await db.FoodScans.Where(s => s.Id == scanId && s.AddedToDiaryAt == null)
                .ExecuteUpdateAsync(s => s.SetProperty(x => x.AddedToDiaryAt, clock.UtcNow), ct);
        await db.SaveChangesAsync(ct);
        await summaries.RecomputeAsync(clientId, entry.Date, ct);
        return await GetAsync(clientId, entry.Id, ct);
    }

    public async Task<DiaryEntryDto> UpdateAsync(Guid clientId, Guid id, SaveDiaryEntryRequest req, CancellationToken ct)
    {
        var entry = await LoadAsync(clientId, id, false, ct);
        var oldDate = entry.Date;
        await FillAsync(clientId, entry, req, ct);
        await db.SaveChangesAsync(ct);
        await summaries.RecomputeAsync(clientId, entry.Date, ct);
        if (oldDate != entry.Date) await summaries.RecomputeAsync(clientId, oldDate, ct);
        return await GetAsync(clientId, id, ct);
    }

    public async Task DeleteAsync(Guid clientId, Guid id, CancellationToken ct)
    {
        var entry = await LoadAsync(clientId, id, false, ct);
        db.FoodDiaryEntries.Remove(entry);
        await db.SaveChangesAsync(ct);
        await summaries.RecomputeAsync(clientId, entry.Date, ct);
    }

    /// <summary>The same food again (today unless a date is given), with the same items and weights.</summary>
    public async Task<DiaryEntryDto> RepeatAsync(Guid clientId, Guid id, RepeatDiaryEntryRequest req, CancellationToken ct)
    {
        var source = await LoadAsync(clientId, id, true, ct);
        var date = req.Date ?? clock.Today;
        var copy = new FoodDiaryEntry
        {
            ClientProfileId = clientId, Date = date, MealType = req.MealType ?? source.MealType, EatenAt = EatenAt(date, null),
            Name = source.Name, FoodScanId = source.FoodScanId,
        };
        var order = 0;
        foreach (var i in source.Items.OrderBy(x => x.SortOrder))
            copy.Items.Add(new FoodDiaryItem
            {
                SortOrder = order++, Name = i.Name, FoodProductId = i.FoodProductId, FoodRecipeId = i.FoodRecipeId, Grams = i.Grams, Role = i.Role,
                Uncertainty = i.Uncertainty, Kcal = i.Kcal, Protein = i.Protein, Fat = i.Fat, Carbs = i.Carbs, Fiber = i.Fiber, Sugar = i.Sugar,
                SaturatedFat = i.SaturatedFat, SodiumMg = i.SodiumMg, Source = i.Source, SourceRef = i.SourceRef,
            });
        ApplyTotals(copy);
        db.FoodDiaryEntries.Add(copy);
        await db.SaveChangesAsync(ct);
        await summaries.RecomputeAsync(clientId, date, ct);
        return await GetAsync(clientId, copy.Id, ct);
    }

    // ---- Building -------------------------------------------------------------------------------------------------

    private async Task FillAsync(Guid clientId, FoodDiaryEntry entry, SaveDiaryEntryRequest req, CancellationToken ct)
    {
        var today = clock.Today;
        var date = req.Date ?? (req.EatenAt is { } at ? clock.ToClubDate(at) : today);
        if (date > today.AddDays(1) || date < today.AddYears(-2))
            throw ApiException.BadRequest("invalid_date", "The date must be within the last two years and not in the future.");

        if (req.ScanId is { } scanId && !await db.FoodScans.AnyAsync(s => s.Id == scanId && s.ClientProfileId == clientId, ct))
            throw ApiException.NotFound("Scan");

        var previous = entry.Items.ToDictionary(i => i.Id);
        var items = new List<FoodDiaryItem>();
        var order = 0;
        foreach (var input in req.Items)
        {
            var sources = new[] { input.DiaryItemId, input.ProductId, input.RecipeId, input.ScanIngredientId }.Count(x => x is not null);
            if (sources != 1)
                throw ApiException.BadRequest("item_source_required",
                    "Each item needs exactly one of diaryItemId, productId, recipeId or scanIngredientId.");
            FoodDiaryItem item;
            if (input.DiaryItemId is { } itemId)
            {
                item = previous.GetValueOrDefault(itemId) ?? throw ApiException.BadRequest("item_not_found", "Unknown item of this entry.");
                if (item.Grams != input.Grams) item.Uncertainty = Math.Min(item.Uncertainty, NutritionMath.UserWeightUncertainty);
                previous.Remove(itemId);
            }
            else
            {
                item = new FoodDiaryItem { Name = "" };
                await SnapshotAsync(clientId, item, input, req.ScanId, ct);
            }
            item.Grams = input.Grams;
            item.Role = input.Role;
            item.SortOrder = order++;
            if (!string.IsNullOrWhiteSpace(input.Name)) item.Name = input.Name.Trim();
            items.Add(item);
        }
        foreach (var removed in previous.Values) db.FoodDiaryItems.Remove(removed);
        foreach (var item in items.Where(i => !entry.Items.Contains(i))) entry.Items.Add(item);
        foreach (var gone in entry.Items.Where(i => !items.Contains(i)).ToList()) entry.Items.Remove(gone);

        entry.Date = date;
        entry.MealType = req.MealType;
        entry.EatenAt = req.EatenAt
                        ?? (entry.EatenAt == default || clock.ToClubDate(entry.EatenAt) != date ? EatenAt(date, null) : entry.EatenAt);
        entry.FoodScanId = req.ScanId ?? entry.FoodScanId;
        entry.Name = !string.IsNullOrWhiteSpace(req.Name) ? req.Name.Trim()
            : !string.IsNullOrWhiteSpace(entry.Name) ? entry.Name
            : items.Count == 1 ? items[0].Name : string.Join(", ", items.Take(3).Select(i => i.Name));
        if (entry.Name.Length > 160) entry.Name = entry.Name[..160];
        ApplyTotals(entry);
    }

    private async Task SnapshotAsync(Guid clientId, FoodDiaryItem item, DiaryItemInput input, Guid? scanId, CancellationToken ct)
    {
        if (input.ProductId is { } productId)
        {
            var p = await foods.ProductAsync(clientId, productId, ct);
            item.FoodProductId = p.Id;
            item.Name = p.Name;
            Copy(item, NutritionMath.Nullable(p), p.Source, p.SourceRef);
            item.Uncertainty = p.Source is NutritionSource.OpenFoodFacts or NutritionSource.Label or NutritionSource.User
                ? NutritionMath.PackagedUncertainty : NutritionMath.UserWeightUncertainty;
        }
        else if (input.RecipeId is { } recipeId)
        {
            var r = await foods.RecipeAsync(clientId, recipeId, ct);
            item.FoodRecipeId = r.Id;
            item.Name = r.Name;
            Copy(item, NutritionMath.Nullable(r), NutritionSource.Recipe, r.Key);
            item.Uncertainty = r.IsTraditional ? NutritionMath.RecipeUncertainty : NutritionMath.UserWeightUncertainty;
        }
        else
        {
            var i = await db.FoodRecognitionIngredients.AsNoTracking()
                        .Where(x => x.Id == input.ScanIngredientId)
                        .Join(db.FoodRecognitionResults, x => x.FoodRecognitionResultId, r => r.Id, (x, r) => new { x, r.FoodScanId })
                        .Join(db.FoodScans, a => a.FoodScanId, s => s.Id, (a, s) => new { a.x, s.ClientProfileId, ScanId = s.Id })
                        .SingleOrDefaultAsync(a => a.ClientProfileId == clientId, ct)
                    ?? throw ApiException.BadRequest("item_not_found", "Unknown scan ingredient.");
            if (scanId is not null && i.ScanId != scanId)
                throw ApiException.BadRequest("item_not_found", "The ingredient belongs to another scan.");
            item.FoodProductId = i.x.FoodProductId;
            item.Name = i.x.Name;
            item.Uncertainty = i.x.Grams == input.Grams ? i.x.Uncertainty : NutritionMath.UserWeightUncertainty;
            // An ingredient without a product is kept without values: the entry is marked incomplete.
            Copy(item, i.x.Kcal is null ? null : i.x, i.x.Source, i.x.SourceRef);
        }
    }

    private static void Copy(FoodDiaryItem item, IPer100Nullable? p, NutritionSource? source, string? sourceRef)
    {
        item.Kcal = p?.Kcal;
        item.Protein = p?.Protein;
        item.Fat = p?.Fat;
        item.Carbs = p?.Carbs;
        item.Fiber = p?.Fiber;
        item.Sugar = p?.Sugar;
        item.SaturatedFat = p?.SaturatedFat;
        item.SodiumMg = p?.SodiumMg;
        item.Source = p is null ? null : source;
        item.SourceRef = p is null ? null : sourceRef;
    }

    private static void ApplyTotals(FoodDiaryEntry e)
    {
        var t = NutritionMath.Sum(e.Items.Select(i => new FoodAmount(i.Grams, i.Kcal is null ? null : i, i.Uncertainty)));
        e.Grams = t.Grams;
        e.Kcal = t.Kcal;
        e.KcalMin = t.KcalMin;
        e.KcalMax = t.KcalMax;
        e.Protein = t.Protein;
        e.Fat = t.Fat;
        e.Carbs = t.Carbs;
        e.Fiber = t.Fiber;
        e.Sugar = t.Sugar;
        e.SaturatedFat = t.SaturatedFat;
        e.SodiumMg = t.SodiumMg;
        e.NutritionIncomplete = t.Incomplete;
    }

    private DateTimeOffset EatenAt(DateOnly date, DateTimeOffset? given)
    {
        if (given is { } g) return g;
        // Today: now. Another day: the same clock time on that day (the client fills in the diary afterwards).
        var now = clock.UtcNow;
        if (date == clock.Today) return now;
        var local = TimeZoneInfo.ConvertTime(now, clock.TimeZone);
        return clock.StartOfDayUtc(date) + local.TimeOfDay;
    }

    private async Task<FoodDiaryEntry> LoadAsync(Guid clientId, Guid id, bool readOnly, CancellationToken ct)
    {
        var query = db.FoodDiaryEntries.Include(e => e.Items).Include(e => e.Scan).AsQueryable();
        if (readOnly) query = query.AsNoTracking();
        return await query.SingleOrDefaultAsync(e => e.Id == id && e.ClientProfileId == clientId, ct) ?? throw ApiException.NotFound("Diary entry");
    }

    // ---- Mapping --------------------------------------------------------------------------------------------------

    public static Totals TotalsOf(IEnumerable<FoodDiaryEntry> entries)
    {
        var list = entries.ToList();
        decimal? Sum(Func<FoodDiaryEntry, decimal?> f) => list.Any(e => f(e) is not null) ? list.Sum(e => f(e) ?? 0) : null;
        return new Totals(list.Sum(e => e.Grams), list.Sum(e => e.Kcal), list.Sum(e => e.KcalMin), list.Sum(e => e.KcalMax),
            list.Sum(e => e.Protein), list.Sum(e => e.Fat), list.Sum(e => e.Carbs), Sum(e => e.Fiber), Sum(e => e.Sugar),
            Sum(e => e.SaturatedFat), Sum(e => e.SodiumMg), list.Any(e => e.NutritionIncomplete));
    }

    public static DiaryEntryDto ToDto(FoodDiaryEntry e) => new(
        e.Id, e.Date, e.MealType, e.EatenAt, e.Name, e.FoodScanId, e.Scan?.PhotoId is not null,
        new Totals(e.Grams, e.Kcal, e.KcalMin, e.KcalMax, e.Protein, e.Fat, e.Carbs, e.Fiber, e.Sugar, e.SaturatedFat, e.SodiumMg,
            e.NutritionIncomplete).ToDto(),
        e.Items.OrderBy(i => i.SortOrder).Select(i => new DiaryItemDto(
            i.Id, i.Name, i.FoodProductId, i.FoodRecipeId, i.Grams, i.Role, NutritionMath.Dto(i),
            NutritionMath.For(i.Kcal is null ? null : i, i.Grams) ?? new NutrientsDto(0, 0, 0, 0, null, null, null, null),
            i.Source, i.SourceRef, i.Kcal is not null)).ToList(),
        e.CreatedAt);
}
