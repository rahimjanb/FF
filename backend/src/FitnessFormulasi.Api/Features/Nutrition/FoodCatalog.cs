using System.Globalization;
using System.Text;
using FitnessFormulasi.Api.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

namespace FitnessFormulasi.Api.Features.Nutrition;

/// <summary>
/// The built-in product keys and traditional dish compositions the vision prompt refers to. Built from the database
/// once and cached (the prompt stays byte-identical between requests, so the provider can cache it too).
/// </summary>
public sealed class FoodCatalog(IMemoryCache cache, IServiceScopeFactory scopes)
{
    private const string CacheKey = "nutrition:catalog";

    public sealed record Snapshot(string ProductList, string TraditionalDishes, IReadOnlySet<string> ProductKeys, IReadOnlyList<string> DishKeys);

    public async Task<Snapshot> GetAsync(CancellationToken ct)
    {
        if (cache.TryGetValue(CacheKey, out Snapshot? cached) && cached is not null) return cached;
        using var scope = scopes.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var products = await db.FoodProducts.AsNoTracking().Where(p => p.Key != null && p.OwnerClientId == null)
            .OrderBy(p => p.Key).Select(p => new { p.Key, p.Name, p.NameEn }).ToListAsync(ct);
        var recipes = await db.FoodRecipes.AsNoTracking().Where(r => r.IsTraditional && r.OwnerClientId == null)
            .OrderBy(r => r.DishKey).ThenBy(r => r.Key)
            .Select(r => new
            {
                r.DishKey, r.Name, r.PortionGrams, r.YieldGrams,
                Ingredients = r.Ingredients.OrderBy(i => i.SortOrder).Select(i => new { i.Product.Key, i.Grams }).ToList(),
            })
            .ToListAsync(ct);

        var list = new StringBuilder();
        foreach (var p in products) list.Append(p.Key).Append(" — ").Append(p.Name).Append('\n');
        var dishes = new StringBuilder();
        foreach (var r in recipes)
        {
            // Composition per 100 g of the finished dish, as-eaten weights.
            var total = r.YieldGrams ?? r.Ingredients.Sum(i => i.Grams);
            if (total <= 0) continue;
            dishes.Append(r.DishKey).Append(" | ").Append(r.Name).Append(" | portion ~")
                .Append(r.PortionGrams.ToString("0", CultureInfo.InvariantCulture)).Append(" g | per 100 g: ")
                .Append(string.Join(", ", r.Ingredients.Select(i =>
                    $"{i.Key} {(i.Grams * 100 / total).ToString("0.#", CultureInfo.InvariantCulture)} g")))
                .Append('\n');
        }
        var snapshot = new Snapshot(list.ToString(), dishes.ToString(),
            products.Select(p => p.Key!).ToHashSet(), recipes.Select(r => r.DishKey!).Where(k => k is not null).Distinct().ToList());
        cache.Set(CacheKey, snapshot, TimeSpan.FromHours(6));
        return snapshot;
    }

    public void Invalidate() => cache.Remove(CacheKey);
}
