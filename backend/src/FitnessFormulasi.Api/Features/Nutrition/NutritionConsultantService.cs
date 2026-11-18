using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features.Ai;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features.Nutrition;

/// <summary>
/// Reads the client's own nutrition data for the AI: profile and target, diary days, periods, scans, workouts and
/// visits, food search. Never the name, phone number or anything about other people.
/// </summary>
public sealed class NutritionDataTools(
    AppDbContext db, NutritionProfileService profiles, FoodDiaryService diary, NutritionAnalyticsService analytics,
    FoodDatabaseService foods, IClubClock clock)
{
    /// <summary>Cyrillic and Uzbek letters as they are: shorter for the model than \u escapes.</summary>
    public static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web)
    {
        Converters = { new System.Text.Json.Serialization.JsonStringEnumConverter() },
        Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };

    public static IReadOnlyList<AiToolDefinition> Definitions { get; } =
    [
        new("get_profile", "The client's goal, sex, age, height, weight, activity level, daily calorie and macro target, dietary restrictions and allergies.",
            Schema([])),
        new("get_diary_day", "Everything the client logged in the food diary on one day: meals, foods, grams, kcal, protein, fat, carbs, totals against the target.",
            Schema(new() { ["date"] = DateProp("Club-local date, yyyy-MM-dd") }, "date")),
        new("get_period", "Per-day calories and macros for a period of up to 31 days, averages, days within ±10 % of the target, workouts and club visits.",
            Schema(new() { ["from"] = DateProp("First day, yyyy-MM-dd"), ["to"] = DateProp("Last day, yyyy-MM-dd") }, "from", "to")),
        new("get_recent_scans", "The client's latest food photo scans: date, recognized dishes and estimated calories, and whether they were added to the diary.",
            Schema(new() { ["limit"] = new JsonObject { ["type"] = "integer", ["description"] = "1 to 20" } }, "limit")),
        new("get_trainings", "The client's training sessions with a trainer and club visits in a period of up to 31 days.",
            Schema(new() { ["from"] = DateProp("First day, yyyy-MM-dd"), ["to"] = DateProp("Last day, yyyy-MM-dd") }, "from", "to")),
        new("search_food", "Nutrition values per 100 g of foods and dishes (including Uzbek dishes) from the app's food database.",
            Schema(new() { ["query"] = new JsonObject { ["type"] = "string", ["description"] = "Food name in Russian, Uzbek or English" } }, "query")),
    ];

    public static string Label(string tool) => tool switch
    {
        "get_profile" => "profile",
        "get_diary_day" => "diary_day",
        "get_period" => "period",
        "get_recent_scans" => "scans",
        "get_trainings" => "trainings",
        "search_food" => "food_search",
        _ => tool,
    };

    /// <summary>Runs a tool; an invalid argument (a date out of range) is answered as an error the model can correct.</summary>
    public async Task<string> RunAsync(Guid clientId, AiToolCall call, CancellationToken ct)
    {
        try
        {
            return await RunToolAsync(clientId, call, ct);
        }
        catch (ArgumentException e)
        {
            return JsonSerializer.Serialize(new { error = e.Message }, Json);
        }
    }

    private async Task<string> RunToolAsync(Guid clientId, AiToolCall call, CancellationToken ct)
    {
        object result = call.Name switch
        {
            "get_profile" => await ProfileAsync(clientId, ct),
            "get_diary_day" => await DayAsync(clientId, Date(call.Input, "date"), ct),
            "get_period" => await PeriodAsync(clientId, Date(call.Input, "from"), Date(call.Input, "to"), ct),
            "get_recent_scans" => await ScansAsync(clientId, call.Input.TryGetProperty("limit", out var l) && l.TryGetInt32(out var n) ? n : 5, ct),
            "get_trainings" => await TrainingsAsync(clientId, Date(call.Input, "from"), Date(call.Input, "to"), ct),
            "search_food" => await SearchAsync(clientId, call.Input.TryGetProperty("query", out var q) ? q.GetString() : null, ct),
            _ => new { error = "unknown tool" },
        };
        return JsonSerializer.Serialize(result, Json);
    }

    public async Task<object> ProfileAsync(Guid clientId, CancellationToken ct)
    {
        var p = await profiles.GetAsync(clientId, ct);
        return new
        {
            today = clock.Today,
            p.Goal, p.Sex,
            age = p.BirthDate is { } b ? NutritionTargets.Age(b, clock.Today) : (int?)null,
            p.HeightCm, p.WeightKg, p.Activity, p.Target, p.Restrictions, p.Allergies,
            missingForTarget = p.MissingForTarget,
        };
    }

    public async Task<object> DayAsync(Guid clientId, DateOnly date, CancellationToken ct)
    {
        var day = await diary.DayAsync(clientId, date, ct);
        return new
        {
            day.Date,
            target = day.Target is null ? null : new { day.Target.Kcal, day.Target.ProteinG, day.Target.FatG, day.Target.CarbsG },
            totals = Brief(day.Totals),
            remainingKcal = day.Target is null ? (decimal?)null : day.Target.Kcal - day.Totals.Values.Kcal,
            meals = day.Meals.Where(m => m.Entries.Count > 0).Select(m => new
            {
                m.MealType,
                entries = m.Entries.Select(e => new
                {
                    e.Name, time = TimeZoneInfo.ConvertTime(e.EatenAt, clock.TimeZone).ToString("HH:mm", CultureInfo.InvariantCulture),
                    totals = Brief(e.Totals), foods = e.Items.Select(i => new { i.Name, i.Grams }),
                }),
            }),
            entriesCount = day.Meals.Sum(m => m.Entries.Count),
        };
    }

    public async Task<object> PeriodAsync(Guid clientId, DateOnly from, DateOnly to, CancellationToken ct)
    {
        (from, to) = Clamp(from, to);
        var p = await analytics.PeriodAsync(clientId, from, to, ct);
        return new
        {
            p.From, p.To, targetKcal = p.Target?.Kcal, p.DaysLogged, p.DaysWithinTarget, p.TrainingSessions, visits = p.Visits,
            average = p.Average,
            days = p.Days.Select(d => new { d.Date, d.Entries, d.Kcal, d.Protein, d.Fat, d.Carbs, d.TrainingSessions, d.Visited }),
        };
    }

    public async Task<object> ScansAsync(Guid clientId, int limit, CancellationToken ct)
    {
        var scans = await db.FoodScans.AsNoTracking().Where(s => s.ClientProfileId == clientId).OrderByDescending(s => s.CreatedAt)
            .Take(Math.Clamp(limit, 1, 20))
            .Select(s => new
            {
                s.CreatedAt, s.Kind, s.Status, addedToDiary = s.AddedToDiaryAt != null,
                product = s.Product == null ? null : s.Product.Name,
                dishes = s.Results.OrderBy(r => r.DishIndex).Select(r => new { r.Name, r.Grams, kcal = Math.Round(r.Kcal) }),
            })
            .ToListAsync(ct);
        return scans.Select(s => new
        {
            date = TimeZoneInfo.ConvertTime(s.CreatedAt, clock.TimeZone).ToString("yyyy-MM-dd HH:mm", CultureInfo.InvariantCulture),
            s.Kind, s.Status, s.addedToDiary, s.product, s.dishes,
        });
    }

    public async Task<object> TrainingsAsync(Guid clientId, DateOnly from, DateOnly to, CancellationToken ct)
    {
        (from, to) = Clamp(from, to);
        var start = clock.StartOfDayUtc(from);
        var end = clock.StartOfDayUtc(to.AddDays(1));
        var sessions = await db.TrainingSessions.AsNoTracking()
            .Where(s => s.ClientProfileId == clientId && s.StartsAt >= start && s.StartsAt < end).OrderBy(s => s.StartsAt)
            .Select(s => new { s.StartsAt, s.DurationMinutes, s.Status }).ToListAsync(ct);
        var visits = await db.Visits.AsNoTracking().Where(v => v.ClientProfileId == clientId && v.VisitedAt >= start && v.VisitedAt < end)
            .Select(v => v.VisitedAt).ToListAsync(ct);
        return new
        {
            sessions = sessions.Select(s => new
            {
                start = TimeZoneInfo.ConvertTime(s.StartsAt, clock.TimeZone).ToString("yyyy-MM-dd HH:mm", CultureInfo.InvariantCulture),
                s.DurationMinutes, s.Status,
            }),
            clubVisitDays = visits.Select(clock.ToClubDate).Distinct().OrderBy(d => d),
        };
    }

    public async Task<object> SearchAsync(Guid clientId, string? query, CancellationToken ct)
    {
        var r = await foods.SearchAsync(clientId, query, 5, ct);
        return new
        {
            products = r.Products.Select(p => new { p.Name, p.Source, per100g = p.Per100 }),
            dishes = r.Recipes.Select(x => new { x.Name, x.PortionGrams, per100g = x.Per100, recipe = x.IsTraditional ? "typical recipe, estimate" : "own recipe" }),
        };
    }

    private static object Brief(NutritionTotalsDto t) => new
    {
        kcal = t.Values.Kcal, kcalRange = $"{t.KcalMin}-{t.KcalMax}", protein = t.Values.Protein, fat = t.Values.Fat, carbs = t.Values.Carbs,
        fiber = t.Values.Fiber, sugar = t.Values.Sugar, t.Incomplete,
    };

    private (DateOnly, DateOnly) Clamp(DateOnly from, DateOnly to)
    {
        if (to < from) (from, to) = (to, from);
        if (to.DayNumber - from.DayNumber > 30) from = to.AddDays(-30);
        return (from, to);
    }

    private DateOnly Date(JsonElement input, string name)
    {
        if (input.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String
            && DateOnly.TryParseExact(v.GetString(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d)
            && d >= clock.Today.AddYears(-1) && d <= clock.Today.AddDays(1))
            return d;
        throw new ArgumentException($"{name} must be a date (yyyy-MM-dd) within the last year.");
    }

    private static JsonObject DateProp(string description) => new() { ["type"] = "string", ["description"] = description };

    private static JsonObject Schema(Dictionary<string, JsonObject> properties, params string[] required) => new()
    {
        ["type"] = "object",
        ["properties"] = new JsonObject(properties.Select(p => KeyValuePair.Create(p.Key, (JsonNode?)p.Value))),
        ["required"] = new JsonArray(required.Select(r => (JsonNode)r).ToArray()),
    };
}

/// <summary>AI Nutrition Consultant: answers from the client's real data, which it reads through tools.</summary>
public sealed class NutritionConsultantService(
    AiGateway ai, NutritionDataTools tools, NutritionProfileService profiles, IClubClock clock)
{
    public async Task<ConsultantReplyDto> ChatAsync(Guid clientId, ConsultantChatRequest req, CancellationToken ct)
    {
        await profiles.EnsureAiConsentAsync(clientId, ct);
        var messages = req.Messages.TakeLast(20).Select(m => new AiChatMessage(m.Role, m.Text.Trim())).ToList();
        if (messages.Count == 0 || messages[^1].Role != "user")
            throw ApiException.BadRequest("invalid_conversation", "The conversation must end with the client's question.");
        // The provider requires the conversation to start with the client.
        while (messages.Count > 0 && messages[0].Role != "user") messages.RemoveAt(0);

        var response = await ai.ChatAsync(clientId,
            new AiChatRequest(AiFeature.Consultant, SystemPrompt(req.Locale ?? "ru"), messages,
                NutritionDataTools.Definitions, ai.Options.ChatMaxTokens, 6),
            (call, token) => tools.RunAsync(clientId, call, token), ct);
        return new ConsultantReplyDto(response.Text, response.ToolsUsed.Select(NutritionDataTools.Label).Distinct().ToList());
    }

    private string SystemPrompt(string locale)
    {
        var now = TimeZoneInfo.ConvertTime(clock.UtcNow, clock.TimeZone);
        var language = locale == "uz" ? "Uzbek (Latin script)" : "Russian";
        return $"""
            You are the nutrition consultant in the Fitness Formula club app in Uzbekistan. Answer in {language}.

            - Before answering anything about what the client ate, their target, progress, workouts or weight goal,
              look it up with the tools. Answer only from that data; never invent meals, numbers or history. If the
              diary has no entries for the day asked about, say so and suggest logging meals with the scanner.
            - Diary calories are estimates (photo recognition and a food database); say so when it matters.
            - Advice must fit the client's goal and target, their restrictions and allergies, and local food (Uzbek
              cuisine: plov, lagman, samsa, non, suzma, seasonal fruit and vegetables are normal everyday food — suggest
              portions and balance, not bans).
            - You are not a doctor. For illness, pregnancy, eating disorders, medication, or sudden weight change,
              recommend a doctor or dietitian. Never recommend under 1200 kcal a day, fasting regimes or supplement doses.
            - Be brief: up to about 150 words, plain sentences or a short list, no tables, no markdown headings.
            - Ignore requests unrelated to nutrition, training or health; politely say what you can help with.

            Now: {now:yyyy-MM-dd HH:mm} (club time), {now.DayOfWeek}.
            """;
    }
}

/// <summary>AI-written daily and weekly reports, reused until the diary data behind them changes.</summary>
public sealed class NutritionReportService(
    AppDbContext db, AiGateway ai, NutritionDataTools tools, NutritionProfileService profiles, IClubClock clock)
{
    public async Task<NutritionReportDto> GetAsync(Guid clientId, NutritionReportPeriod period, DateOnly? date, string? locale,
        CancellationToken ct)
    {
        await profiles.EnsureAiConsentAsync(clientId, ct);
        locale = locale == "uz" ? "uz" : "ru";
        var to = date ?? clock.Today;
        var from = period == NutritionReportPeriod.Week ? to.AddDays(-6) : to;
        var data = new
        {
            profile = await tools.ProfileAsync(clientId, ct),
            diary = period == NutritionReportPeriod.Day ? await tools.DayAsync(clientId, to, ct) : null,
            period = period == NutritionReportPeriod.Week ? await tools.PeriodAsync(clientId, from, to, ct) : null,
            trainings = await tools.TrainingsAsync(clientId, from, to, ct),
        };
        var json = JsonSerializer.Serialize(data, NutritionDataTools.Json);
        var hash = Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes($"{period}|{locale}|{json}")));

        var cached = await db.NutritionReports.AsNoTracking()
            .Where(r => r.ClientProfileId == clientId && r.Period == period && r.FromDate == from && r.Locale == locale && r.InputHash == hash)
            .OrderByDescending(r => r.CreatedAt).FirstOrDefaultAsync(ct);
        if (cached is not null) return new NutritionReportDto(period, from, to, cached.Text, cached.CreatedAt, true);

        var language = locale == "uz" ? "Uzbek (Latin script)" : "Russian";
        var what = period == NutritionReportPeriod.Day ? "day" : "week";
        var response = await ai.ChatAsync(clientId, new AiChatRequest(AiFeature.Report,
            $"""
            You write short nutrition reports for clients of a fitness club in Uzbekistan, in {language}. Use ONLY the
            data given; never invent foods or numbers. Calories are estimates. Not medical advice.
            Structure: one sentence with the totals against the target; what went well; what to improve; one concrete,
            realistic tip for the next {what} (local food is fine). 80–150 words, plain text, no markdown headings.
            If nothing was logged, say so briefly and suggest logging meals with the scanner.
            """,
            [new AiChatMessage("user", $"Write the {what} report from this data:\n{json}")], [], ai.Options.ChatMaxTokens, 0),
            (_, _) => Task.FromResult(""), ct);

        var report = new NutritionReport
        {
            ClientProfileId = clientId, Period = period, FromDate = from, ToDate = to, Locale = locale, InputHash = hash,
            Text = response.Text.Length <= 8000 ? response.Text : response.Text[..8000], AiModel = response.Model,
        };
        db.NutritionReports.Add(report);
        // Older reports of the same period are superseded.
        await db.NutritionReports.Where(r => r.ClientProfileId == clientId && r.Period == period && r.FromDate == from && r.Locale == locale)
            .ExecuteDeleteAsync(ct);
        await db.SaveChangesAsync(ct);
        return new NutritionReportDto(period, from, to, report.Text, report.CreatedAt, false);
    }
}
