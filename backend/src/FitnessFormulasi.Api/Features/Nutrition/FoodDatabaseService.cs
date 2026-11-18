using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace FitnessFormulasi.Api.Features.Nutrition;

/// <summary>
/// The food database: built-in products (USDA) and traditional dishes, the client's own products and recipes, and
/// the external sources behind it (USDA search, Open Food Facts by barcode), whose answers are cached as products.
/// Values are never made up: a food that no source knows stays without values and is reported as such.
/// </summary>
public sealed class FoodDatabaseService(
    AppDbContext db, IFoodSearchSource searchSource, IBarcodeProductSource barcodeSource, IClubClock clock,
    IOptions<FoodDataOptions> options, ILogger<FoodDatabaseService> logger)
{
    // ---- Search ---------------------------------------------------------------------------------------------------

    public async Task<FoodSearchResultDto> SearchAsync(Guid clientId, string? query, int take, CancellationToken ct)
    {
        take = Math.Clamp(take, 1, 50);
        var q = Normalize(query);
        if (q.Length < 2) return new FoodSearchResultDto([], []);
        var pattern = "%" + EscapeLike(q) + "%";

        var products = await db.FoodProducts.AsNoTracking()
            .Where(p => (p.OwnerClientId == null || p.OwnerClientId == clientId) && EF.Functions.ILike(p.SearchText, pattern, "\\"))
            .OrderBy(p => p.Name.Length).Take(take * 4).ToListAsync(ct);
        var recipes = await db.FoodRecipes.AsNoTracking()
            .Where(r => (r.OwnerClientId == null || r.OwnerClientId == clientId) && EF.Functions.ILike(r.SearchText, pattern, "\\"))
            .OrderBy(r => r.Name.Length).Take(take * 2).ToListAsync(ct);

        if (products.Count + recipes.Count < 5 && searchSource.IsEnabled && q.Length >= 3)
        {
            try
            {
                foreach (var ext in await searchSource.SearchAsync(q, 8, ct))
                {
                    var p = await UpsertExternalAsync(ext, ct);
                    if (products.All(x => x.Id != p.Id)) products.Add(p);
                }
                await db.SaveChangesAsync(ct);
            }
            catch (FoodSourceUnavailableException e)
            {
                logger.LogInformation("External food search skipped: {Message}", e.Message); // local results are still useful
            }
        }

        return new FoodSearchResultDto(
            products.OrderBy(p => Rank(q, p.Name, p.NameUz, p.NameEn, p.Aliases)).ThenBy(p => p.OwnerClientId == null).ThenBy(p => p.Name.Length)
                .Take(take).Select(p => ToDto(p, clientId)).ToList(),
            recipes.OrderBy(r => Rank(q, r.Name, r.NameUz, r.NameEn, r.Aliases)).ThenBy(r => r.Name.Length)
                .Take(Math.Max(5, take / 2)).Select(r => RecipeSummary(r, clientId)).ToList());
    }

    /// <summary>
    /// Product for an ingredient the AI named: by its catalog key, then by name among the client's and built-in
    /// products, then (if configured) USDA by the English name. Null when nothing matches.
    /// </summary>
    public async Task<(FoodProduct? Product, IngredientMatch Match)> MatchIngredientAsync(
        Guid clientId, string? key, string name, string? nameEn, CancellationToken ct)
    {
        if (!string.IsNullOrWhiteSpace(key))
        {
            var byKey = await db.FoodProducts.AsNoTracking().SingleOrDefaultAsync(p => p.Key == key && p.OwnerClientId == null, ct);
            if (byKey is not null) return (byKey, IngredientMatch.CatalogKey);
        }
        foreach (var candidate in new[] { name, nameEn })
        {
            var q = Normalize(candidate);
            if (q.Length < 2) continue;
            var found = await db.FoodProducts.AsNoTracking()
                .Where(p => (p.OwnerClientId == null || p.OwnerClientId == clientId) && EF.Functions.ILike(p.SearchText, "%" + EscapeLike(q) + "%", "\\"))
                .OrderBy(p => p.Name.Length).Take(20).ToListAsync(ct);
            var best = found.OrderBy(p => Rank(q, p.Name, p.NameUz, p.NameEn, p.Aliases)).FirstOrDefault();
            if (best is not null && Rank(q, best.Name, best.NameUz, best.NameEn, best.Aliases) <= 2) return (best, IngredientMatch.NameSearch);
        }
        if (searchSource.IsEnabled && !string.IsNullOrWhiteSpace(nameEn))
        {
            try
            {
                var ext = (await searchSource.SearchAsync(nameEn, 3, ct)).FirstOrDefault();
                if (ext is not null)
                {
                    var p = await UpsertExternalAsync(ext, ct);
                    await db.SaveChangesAsync(ct);
                    return (p, IngredientMatch.External);
                }
            }
            catch (FoodSourceUnavailableException e)
            {
                logger.LogInformation("USDA lookup for an ingredient skipped: {Message}", e.Message);
            }
        }
        return (null, IngredientMatch.None);
    }

    /// <summary>A product the client may use: built-in or their own.</summary>
    public async Task<FoodProduct> ProductAsync(Guid clientId, Guid id, CancellationToken ct) =>
        await db.FoodProducts.AsNoTracking().SingleOrDefaultAsync(p => p.Id == id && (p.OwnerClientId == null || p.OwnerClientId == clientId), ct)
        ?? throw ApiException.NotFound("Product");

    public async Task<FoodRecipe> RecipeAsync(Guid clientId, Guid id, CancellationToken ct) =>
        await db.FoodRecipes.AsNoTracking().Include(r => r.Ingredients).ThenInclude(i => i.Product)
            .SingleOrDefaultAsync(r => r.Id == id && (r.OwnerClientId == null || r.OwnerClientId == clientId), ct)
        ?? throw ApiException.NotFound("Recipe");

    // ---- Barcodes -------------------------------------------------------------------------------------------------

    /// <summary>
    /// The client's own label for this barcode first, then the cached Open Food Facts answer, then Open Food Facts.
    /// When Open Food Facts is down a stale cached product is still returned.
    /// </summary>
    public async Task<FoodProduct> FindByBarcodeAsync(Guid clientId, string code, CancellationToken ct)
    {
        var own = await db.FoodBarcodes.AsNoTracking().Include(b => b.Product)
            .SingleOrDefaultAsync(b => b.OwnerClientId == clientId && b.Code == code, ct);
        if (own?.Product is not null) return own.Product;

        var now = clock.UtcNow;
        var shared = await db.FoodBarcodes.Include(b => b.Product).SingleOrDefaultAsync(b => b.OwnerClientId == null && b.Code == code, ct);
        var o = options.Value;
        if (shared is not null)
        {
            var fresh = shared.NotFound
                ? shared.CheckedAt > now.AddDays(-o.NotFoundCacheDays)
                : shared.CheckedAt > now.AddDays(-o.BarcodeCacheDays);
            if (fresh && shared.NotFound) throw BarcodeNotFound();
            if (fresh && shared.Product is not null) return shared.Product;
        }
        if (!barcodeSource.IsEnabled)
            return shared?.Product ?? throw BarcodeNotFound();

        ExternalProduct? ext;
        try
        {
            ext = await barcodeSource.FindAsync(code, ct);
        }
        catch (FoodSourceUnavailableException)
        {
            if (shared?.Product is not null) return shared.Product;
            throw new ApiException(StatusCodes.Status503ServiceUnavailable, "food_db_unavailable",
                "The product database is unavailable. Try again later or add the product by hand.");
        }

        if (shared is null)
        {
            shared = new FoodBarcode { Code = code };
            db.FoodBarcodes.Add(shared);
        }
        shared.CheckedAt = now;
        if (ext is null)
        {
            shared.NotFound = true;
            shared.FoodProductId = null;
            await db.SaveChangesAsync(ct);
            throw BarcodeNotFound();
        }
        var product = await UpsertExternalAsync(ext, ct);
        shared.NotFound = false;
        shared.Product = product;
        await db.SaveChangesAsync(ct);
        return product;
    }

    private static ApiException BarcodeNotFound() => new(StatusCodes.Status404NotFound, "barcode_not_found",
        "The product is not in the database. Photograph the nutrition label or add it by hand.");

    // ---- Own products ---------------------------------------------------------------------------------------------

    public async Task<FoodProduct> CreateOwnAsync(Guid clientId, CreateFoodProductRequest req, NutritionSource source,
        IReadOnlyList<Allergen>? allergens, string? ingredientsText, CancellationToken ct)
    {
        var n = req.Per100;
        var product = new FoodProduct
        {
            Name = req.Name.Trim(), Brand = Blank(req.Brand), Category = req.Category, OwnerClientId = clientId, Source = source,
            SourceRef = req.Barcode, Kcal = n.Kcal, Protein = n.Protein, Fat = n.Fat, Carbs = n.Carbs, Fiber = n.Fiber, Sugar = n.Sugar,
            SaturatedFat = n.SaturatedFat, SodiumMg = n.SodiumMg, Per100Ml = req.Per100Ml, ServingGrams = req.ServingGrams,
            PackageGrams = req.PackageGrams, Allergens = allergens?.Distinct().ToList() ?? [], IngredientsText = ingredientsText,
        };
        product.SearchText = SearchText(product.Name, product.Brand, null, null, []);
        db.FoodProducts.Add(product);
        if (req.Barcode is { } code)
        {
            var mapping = await db.FoodBarcodes.SingleOrDefaultAsync(b => b.OwnerClientId == clientId && b.Code == code, ct);
            if (mapping is null) db.FoodBarcodes.Add(new FoodBarcode { Code = code, OwnerClientId = clientId, Product = product, CheckedAt = clock.UtcNow });
            else
            {
                mapping.Product = product;
                mapping.CheckedAt = clock.UtcNow;
            }
        }
        await db.SaveChangesAsync(ct);
        return product;
    }

    public async Task DeleteOwnAsync(Guid clientId, Guid id, CancellationToken ct)
    {
        var product = await db.FoodProducts.SingleOrDefaultAsync(p => p.Id == id && p.OwnerClientId == clientId, ct)
                      ?? throw ApiException.NotFound("Product");
        if (await db.FoodRecipeIngredients.AnyAsync(i => i.FoodProductId == id, ct))
            throw ApiException.Conflict("product_in_use", "The product is used in one of your recipes. Remove it from the recipe first.");
        await db.FoodBarcodes.Where(b => b.FoodProductId == id && b.OwnerClientId == clientId).ExecuteDeleteAsync(ct);
        db.FoodProducts.Remove(product); // diary and scan rows keep their copied values (FK set to null)
        await db.SaveChangesAsync(ct);
    }

    // ---- Recipes --------------------------------------------------------------------------------------------------

    public async Task<FoodRecipe> SaveRecipeAsync(Guid clientId, Guid? id, SaveRecipeRequest req, CancellationToken ct)
    {
        var ids = req.Ingredients.Select(i => i.ProductId).Distinct().ToList();
        var products = await db.FoodProducts.AsNoTracking()
            .Where(p => ids.Contains(p.Id) && (p.OwnerClientId == null || p.OwnerClientId == clientId)).ToDictionaryAsync(p => p.Id, ct);
        if (products.Count != ids.Count) throw ApiException.BadRequest("product_not_found", "One of the products does not exist.");

        FoodRecipe recipe;
        if (id is null)
        {
            recipe = new FoodRecipe { Name = "", OwnerClientId = clientId };
            db.FoodRecipes.Add(recipe);
        }
        else
        {
            recipe = await db.FoodRecipes.Include(r => r.Ingredients).SingleOrDefaultAsync(r => r.Id == id && r.OwnerClientId == clientId, ct)
                     ?? throw ApiException.NotFound("Recipe");
            db.FoodRecipeIngredients.RemoveRange(recipe.Ingredients);
            recipe.Ingredients.Clear();
        }
        recipe.Name = req.Name.Trim();
        recipe.Category = req.Category;
        recipe.PortionGrams = req.PortionGrams;
        recipe.YieldGrams = req.YieldGrams;
        recipe.Description = Blank(req.Description);
        recipe.SearchText = SearchText(recipe.Name, null, null, null, []);
        var order = 0;
        foreach (var i in req.Ingredients)
            recipe.Ingredients.Add(new FoodRecipeIngredient { FoodProductId = i.ProductId, Grams = i.Grams, Role = i.Role, SortOrder = order++ });
        ApplyPer100(recipe, req.Ingredients.Select(i => new FoodAmount(i.Grams, NutritionMath.Nullable(products[i.ProductId]), 0)));
        await db.SaveChangesAsync(ct);
        return await RecipeAsync(clientId, recipe.Id, ct);
    }

    public async Task DeleteRecipeAsync(Guid clientId, Guid id, CancellationToken ct)
    {
        var deleted = await db.FoodRecipes.Where(r => r.Id == id && r.OwnerClientId == clientId).ExecuteDeleteAsync(ct);
        if (deleted == 0) throw ApiException.NotFound("Recipe");
    }

    public static void ApplyPer100(FoodRecipe recipe, IEnumerable<FoodAmount> items)
    {
        var v = NutritionMath.Per100Of(items, recipe.YieldGrams);
        recipe.Kcal = v.Kcal ?? 0;
        recipe.Protein = v.Protein ?? 0;
        recipe.Fat = v.Fat ?? 0;
        recipe.Carbs = v.Carbs ?? 0;
        recipe.Fiber = v.Fiber;
        recipe.Sugar = v.Sugar;
        recipe.SaturatedFat = v.SaturatedFat;
        recipe.SodiumMg = v.SodiumMg;
    }

    // ---- Mapping --------------------------------------------------------------------------------------------------

    public static FoodProductDto ToDto(FoodProduct p, Guid clientId) => new(
        p.Id, p.Name, p.NameUz, p.NameEn, p.Brand, p.Category, NutritionMath.Dto(p), p.Per100Ml, p.Source, p.SourceRef, p.ServingGrams,
        p.PackageGrams, p.Allergens, p.IngredientsText, p.Source == NutritionSource.Usda ? null : p.SourceRef, p.OwnerClientId == clientId);

    public static FoodRecipeSummaryDto RecipeSummary(FoodRecipe r, Guid clientId) => new(
        r.Id, r.Name, r.NameUz, r.NameEn, r.Category, r.IsTraditional, r.DishKey, r.PortionGrams, NutritionMath.Dto(r), r.OwnerClientId == clientId);

    public static FoodRecipeDto RecipeDto(FoodRecipe r, Guid clientId) => new(
        r.Id, r.Name, r.NameUz, r.NameEn, r.Category, r.IsTraditional, r.DishKey, r.PortionGrams, NutritionMath.Dto(r), r.OwnerClientId == clientId,
        r.Description, r.YieldGrams,
        r.Ingredients.OrderBy(i => i.SortOrder).Select(i => new FoodRecipeIngredientDto(
            i.FoodProductId, i.Product.Name, i.Product.NameUz, i.Product.NameEn, i.Grams, i.Role, NutritionMath.Dto(i.Product),
            i.Product.Source, i.Product.SourceRef)).ToList());

    private async Task<FoodProduct> UpsertExternalAsync(ExternalProduct ext, CancellationToken ct)
    {
        var product = await db.FoodProducts.SingleOrDefaultAsync(
                          p => p.OwnerClientId == null && p.Source == ext.Source && p.SourceRef == ext.SourceRef, ct)
                      ?? db.FoodProducts.Local.FirstOrDefault(p => p.OwnerClientId == null && p.Source == ext.Source && p.SourceRef == ext.SourceRef);
        if (product is null)
        {
            product = new FoodProduct { Name = ext.Name, Source = ext.Source, SourceRef = ext.SourceRef };
            db.FoodProducts.Add(product);
        }
        product.Name = ext.Name;
        product.Brand = ext.Brand;
        product.Category = ext.Category;
        product.Kcal = ext.Per100.Kcal ?? 0;
        product.Protein = ext.Per100.Protein ?? 0;
        product.Fat = ext.Per100.Fat ?? 0;
        product.Carbs = ext.Per100.Carbs ?? 0;
        product.Fiber = ext.Per100.Fiber;
        product.Sugar = ext.Per100.Sugar;
        product.SaturatedFat = ext.Per100.SaturatedFat;
        product.SodiumMg = ext.Per100.SodiumMg;
        product.Per100Ml = ext.Per100Ml;
        product.ServingGrams = ext.ServingGrams;
        product.PackageGrams = ext.PackageGrams;
        product.Allergens = ext.Allergens.ToList();
        product.IngredientsText = ext.IngredientsText;
        product.FetchedAt = clock.UtcNow;
        product.SearchText = SearchText(product.Name, product.Brand, ext.Source == NutritionSource.Usda ? ext.Name : null, null, []);
        if (ext.Source == NutritionSource.Usda) product.NameEn = ext.Name;
        return product;
    }

    /// <summary>Lower case, «ё» as «е», single spaces: the form names and queries are compared in.</summary>
    public static string Normalize(string? s) =>
        string.Join(' ', (s ?? "").ToLowerInvariant().Replace('ё', 'е').Replace('‘', '\'').Replace('ʻ', '\'').Replace('`', '\'')
            .Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));

    public static string SearchText(string name, string? brand, string? nameEn, string? nameUz, IEnumerable<string> aliases)
    {
        var text = string.Join(" | ", new[] { name, brand, nameEn, nameUz }.Concat(aliases).Where(s => !string.IsNullOrWhiteSpace(s)).Select(Normalize).Distinct());
        return text.Length <= 2000 ? text : text[..2000];
    }

    /// <summary>0: exact name or alias; 1: a name starts with the query; 2: an alias starts with it or a word does; 3: contains.</summary>
    public static int Rank(string q, string name, string? nameUz, string? nameEn, IReadOnlyList<string> aliases)
    {
        var names = new[] { name, nameUz, nameEn }.Where(n => n is not null).Select(n => Normalize(n)).ToList();
        var al = aliases.Select(Normalize).ToList();
        if (names.Contains(q) || al.Contains(q)) return 0;
        if (names.Any(n => n.StartsWith(q, StringComparison.Ordinal))) return 1;
        if (al.Any(a => a.StartsWith(q, StringComparison.Ordinal)) || names.Concat(al).Any(n => n.Contains(" " + q, StringComparison.Ordinal))) return 2;
        return 3;
    }

    private static string EscapeLike(string s) => s.Replace("\\", "\\\\").Replace("%", "\\%").Replace("_", "\\_");
    private static string? Blank(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();
}
