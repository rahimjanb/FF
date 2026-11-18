using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features.Nutrition;

/// <summary>Keeps NutritionDailySummaries equal to the sum of the day's diary entries.</summary>
public sealed class NutritionSummaryService(AppDbContext db, NutritionProfileService profiles)
{
    public async Task RecomputeAsync(Guid clientId, DateOnly date, CancellationToken ct)
    {
        var totals = await db.FoodDiaryEntries.Where(e => e.ClientProfileId == clientId && e.Date == date)
            .GroupBy(e => 1)
            .Select(g => new
            {
                Count = g.Count(), Kcal = g.Sum(e => e.Kcal), Protein = g.Sum(e => e.Protein), Fat = g.Sum(e => e.Fat), Carbs = g.Sum(e => e.Carbs),
                Fiber = g.Sum(e => e.Fiber ?? 0), Sugar = g.Sum(e => e.Sugar ?? 0), Sat = g.Sum(e => e.SaturatedFat ?? 0),
                Sodium = g.Sum(e => e.SodiumMg ?? 0), Incomplete = g.Any(e => e.NutritionIncomplete),
            })
            .SingleOrDefaultAsync(ct);
        var summary = await db.NutritionDailySummaries.SingleOrDefaultAsync(s => s.ClientProfileId == clientId && s.Date == date, ct);
        if (totals is null)
        {
            if (summary is not null) db.NutritionDailySummaries.Remove(summary);
            await db.SaveChangesAsync(ct);
            return;
        }
        if (summary is null)
        {
            summary = new NutritionDailySummary { ClientProfileId = clientId, Date = date };
            db.NutritionDailySummaries.Add(summary);
        }
        summary.Entries = totals.Count;
        summary.Kcal = totals.Kcal;
        summary.Protein = totals.Protein;
        summary.Fat = totals.Fat;
        summary.Carbs = totals.Carbs;
        summary.Fiber = totals.Fiber;
        summary.Sugar = totals.Sugar;
        summary.SaturatedFat = totals.Sat;
        summary.SodiumMg = totals.Sodium;
        summary.Incomplete = totals.Incomplete;
        summary.TargetKcal = (await profiles.TargetAsync(clientId, ct))?.Kcal;
        await db.SaveChangesAsync(ct);
    }
}

/// <summary>Daily, weekly and monthly nutrition with the club side of the picture: workouts and visits.</summary>
public sealed class NutritionAnalyticsService(AppDbContext db, NutritionProfileService profiles, IClubClock clock)
{
    public async Task<NutritionDailyDto> DailyAsync(Guid clientId, DateOnly? date, CancellationToken ct)
    {
        var day = date ?? clock.Today;
        var entries = await db.FoodDiaryEntries.AsNoTracking().Where(e => e.ClientProfileId == clientId && e.Date == day).ToListAsync(ct);
        var target = await profiles.TargetAsync(clientId, ct);
        var totals = FoodDiaryService.TotalsOf(entries).ToDto();
        var activity = await ActivityAsync(clientId, day, day, ct);
        return new NutritionDailyDto(
            day, target, totals, target is null ? null : Math.Round(target.Kcal - totals.Values.Kcal),
            Enum.GetValues<MealType>().ToDictionary(m => m, m => Math.Round(entries.Where(e => e.MealType == m).Sum(e => e.Kcal))),
            entries.Count, activity.GetValueOrDefault(day).Sessions, activity.GetValueOrDefault(day).Visited);
    }

    /// <summary>The 7 days ending at <paramref name="end"/> (today by default).</summary>
    public Task<NutritionPeriodDto> WeeklyAsync(Guid clientId, DateOnly? end, CancellationToken ct)
    {
        var to = end ?? clock.Today;
        return PeriodAsync(clientId, to.AddDays(-6), to, ct);
    }

    /// <summary>A calendar month ("yyyy-MM"); the current month by default.</summary>
    public Task<NutritionPeriodDto> MonthlyAsync(Guid clientId, string? month, CancellationToken ct)
    {
        DateOnly first;
        if (string.IsNullOrWhiteSpace(month)) first = new DateOnly(clock.Today.Year, clock.Today.Month, 1);
        else if (!DateOnly.TryParseExact(month + "-01", "yyyy-MM-dd", out first))
            throw ApiException.BadRequest("invalid_month", "The month must look like 2026-11.");
        return PeriodAsync(clientId, first, first.AddMonths(1).AddDays(-1), ct);
    }

    public async Task<NutritionPeriodDto> PeriodAsync(Guid clientId, DateOnly from, DateOnly to, CancellationToken ct)
    {
        if (to < from || to.DayNumber - from.DayNumber > 92) throw ApiException.BadRequest("invalid_period", "The period is too long.");
        var summaries = await db.NutritionDailySummaries.AsNoTracking()
            .Where(s => s.ClientProfileId == clientId && s.Date >= from && s.Date <= to).ToDictionaryAsync(s => s.Date, ct);
        var target = await profiles.TargetAsync(clientId, ct);
        var activity = await ActivityAsync(clientId, from, to, ct);

        var days = new List<NutritionDayStatDto>();
        for (var d = from; d <= to; d = d.AddDays(1))
        {
            var s = summaries.GetValueOrDefault(d);
            var a = activity.GetValueOrDefault(d);
            days.Add(new NutritionDayStatDto(d, s?.Entries ?? 0, Math.Round(s?.Kcal ?? 0), Math.Round(s?.Protein ?? 0, 1),
                Math.Round(s?.Fat ?? 0, 1), Math.Round(s?.Carbs ?? 0, 1), Math.Round(s?.Fiber ?? 0, 1), Math.Round(s?.Sugar ?? 0, 1),
                s?.TargetKcal ?? (d == clock.Today ? target?.Kcal : null), a.Sessions, a.Visited));
        }
        var logged = days.Where(d => d.Entries > 0).ToList();
        NutrientsDto? average = logged.Count == 0 ? null : new NutrientsDto(
            Math.Round(logged.Average(d => d.Kcal)), Math.Round(logged.Average(d => d.Protein), 1), Math.Round(logged.Average(d => d.Fat), 1),
            Math.Round(logged.Average(d => d.Carbs), 1), Math.Round(logged.Average(d => d.Fiber), 1), Math.Round(logged.Average(d => d.Sugar), 1),
            null, null);
        var within = logged.Count(d => d.TargetKcal is { } t && t > 0 && Math.Abs(d.Kcal - t) <= t * 0.10m);
        return new NutritionPeriodDto(from, to, target, days, average, logged.Count, within, days.Sum(d => d.TrainingSessions),
            days.Count(d => d.Visited));
    }

    /// <summary>Training sessions (not cancelled) and club visits per club-local day.</summary>
    public async Task<Dictionary<DateOnly, (int Sessions, bool Visited)>> ActivityAsync(Guid clientId, DateOnly from, DateOnly to, CancellationToken ct)
    {
        var start = clock.StartOfDayUtc(from);
        var end = clock.StartOfDayUtc(to.AddDays(1));
        var sessions = await db.TrainingSessions.AsNoTracking()
            .Where(s => s.ClientProfileId == clientId && s.Status != TrainingSessionStatus.Cancelled && s.StartsAt >= start && s.StartsAt < end)
            .Select(s => s.StartsAt).ToListAsync(ct);
        var visits = await db.Visits.AsNoTracking()
            .Where(v => v.ClientProfileId == clientId && v.VisitedAt >= start && v.VisitedAt < end).Select(v => v.VisitedAt).ToListAsync(ct);
        var result = new Dictionary<DateOnly, (int Sessions, bool Visited)>();
        foreach (var s in sessions)
        {
            var d = clock.ToClubDate(s);
            var cur = result.GetValueOrDefault(d);
            result[d] = (cur.Sessions + 1, cur.Visited);
        }
        foreach (var v in visits)
        {
            var d = clock.ToClubDate(v);
            result[d] = (result.GetValueOrDefault(d).Sessions, true);
        }
        return result;
    }
}
