using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace FitnessFormulasi.Api.Features.Ai;

/// <summary>
/// The only way business code reaches the AI provider: checks the client's daily limits and the monthly budget
/// before a request, and records the tokens, cost and time of every request (successful or not) in AiUsage.
/// </summary>
public sealed class AiGateway(
    IAiModelClient client, AppDbContext db, IServiceScopeFactory scopes, IOptions<AiOptions> options, IClubClock clock,
    ILogger<AiGateway> logger)
{
    public AiOptions Options { get; } = options.Value;
    public bool IsAvailable => client.IsConfigured;
    public string? DisplayName => client.IsConfigured ? client.DisplayName : null;

    public int DailyLimit(AiFeature feature) => feature switch
    {
        AiFeature.FoodPhoto => Options.PhotoScansPerDay,
        AiFeature.FoodLabel => Options.LabelScansPerDay,
        AiFeature.Consultant => Options.ChatMessagesPerDay,
        AiFeature.Report => Options.ReportsPerDay,
        _ => 0,
    };

    /// <summary>Successful requests of the client today (club-local day) for the feature.</summary>
    public Task<int> UsedTodayAsync(Guid clientId, AiFeature feature, CancellationToken ct)
    {
        var since = clock.StartOfDayUtc(clock.Today);
        return db.AiUsage.CountAsync(u => u.ClientProfileId == clientId && u.Feature == feature && u.Success && u.CreatedAt >= since, ct);
    }

    /// <summary>Throws the error the app shows when the request may not be made now.</summary>
    public async Task EnsureAllowedAsync(Guid clientId, AiFeature feature, CancellationToken ct)
    {
        if (!client.IsConfigured) throw AiException.NotConfigured();
        var limit = DailyLimit(feature);
        if (limit > 0 && await UsedTodayAsync(clientId, feature, ct) >= limit)
            throw new AiException(StatusCodes.Status429TooManyRequests, "ai_quota_exceeded",
                $"The daily limit of {limit} AI requests of this kind is reached. It resets at midnight.");
        if (Options.MonthlyBudgetUsd > 0)
        {
            var now = clock.UtcNow;
            var monthStart = new DateTimeOffset(now.Year, now.Month, 1, 0, 0, 0, TimeSpan.Zero);
            var spent = await db.AiUsage.Where(u => u.CreatedAt >= monthStart).SumAsync(u => (decimal?)u.CostUsd, ct) ?? 0;
            if (spent >= Options.MonthlyBudgetUsd)
            {
                logger.LogWarning("AI monthly budget of {Budget} USD is spent ({Spent} USD); AI requests are paused", Options.MonthlyBudgetUsd, spent);
                throw new AiException(StatusCodes.Status503ServiceUnavailable, "ai_budget_exceeded",
                    "AI analysis is paused until next month: the club's monthly limit is reached.");
            }
        }
    }

    public async Task<AiJsonResponse> GenerateJsonAsync(Guid clientId, AiJsonRequest request, CancellationToken ct)
    {
        await EnsureAllowedAsync(clientId, request.Feature, ct);
        try
        {
            var response = await client.GenerateJsonAsync(request, ct);
            var id = await RecordAsync(clientId, request.Feature, response.Model, response.Usage, response.Duration, null, ct);
            return response with { UsageId = id };
        }
        catch (AiException e)
        {
            await RecordAsync(clientId, request.Feature, e.Model ?? request.Model, e.Usage, TimeSpan.Zero, e.Code, ct);
            throw;
        }
    }

    public async Task<AiChatResponse> ChatAsync(Guid clientId, AiChatRequest request,
        Func<AiToolCall, CancellationToken, Task<string>> runTool, CancellationToken ct)
    {
        await EnsureAllowedAsync(clientId, request.Feature, ct);
        try
        {
            var response = await client.ChatAsync(request, runTool, ct);
            await RecordAsync(clientId, request.Feature, response.Model, response.Usage, response.Duration, null, ct);
            return response;
        }
        catch (AiException e)
        {
            await RecordAsync(clientId, request.Feature, e.Model ?? request.Model, e.Usage, TimeSpan.Zero, e.Code, ct);
            throw;
        }
    }

    /// <summary>The answer was unusable after all (business validation failed): the request does not count as successful.</summary>
    public async Task MarkFailedAsync(Guid? usageId, string errorCode, CancellationToken ct)
    {
        if (usageId is null) return;
        using var scope = scopes.CreateScope();
        var usageDb = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        await usageDb.AiUsage.Where(u => u.Id == usageId)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.Success, false).SetProperty(u => u.ErrorCode, errorCode), ct);
    }

    public decimal CostOf(string model, AiUsage usage)
    {
        if (!Options.Prices.TryGetValue(model, out var price))
        {
            logger.LogWarning("No AI price configured for model {Model}; set Ai__Prices__{Model}__InputPerMTok etc. Cost recorded as 0", model, model);
            return 0;
        }
        return (usage.InputTokens * price.InputPerMTok + usage.OutputTokens * price.OutputPerMTok
                + usage.CacheReadTokens * price.CacheReadPerMTok + usage.CacheWriteTokens * price.CacheWritePerMTok) / 1_000_000m;
    }

    // Written through its own scope, so the caller's unsaved changes are never flushed with it.
    private async Task<Guid?> RecordAsync(Guid clientId, AiFeature feature, string model, AiUsage usage, TimeSpan duration, string? error,
        CancellationToken ct)
    {
        var cost = CostOf(model, usage);
        logger.LogInformation(
            "AI {Feature} {Provider}/{Model}: {Input} in (+{CacheRead} cached, {CacheWrite} cache write), {Output} out, {Cost:F4} USD, {Ms} ms, {Result}",
            feature, client.ProviderId, model, usage.InputTokens, usage.CacheReadTokens, usage.CacheWriteTokens, usage.OutputTokens,
            cost, (int)duration.TotalMilliseconds, error ?? "ok");
        try
        {
            using var scope = scopes.CreateScope();
            var usageDb = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var record = new AiUsageRecord
            {
                ClientProfileId = clientId, Feature = feature, Provider = client.ProviderId, Model = model,
                InputTokens = usage.InputTokens, OutputTokens = usage.OutputTokens, CacheReadTokens = usage.CacheReadTokens,
                CacheWriteTokens = usage.CacheWriteTokens, CostUsd = cost, DurationMs = (int)duration.TotalMilliseconds,
                Success = error is null, ErrorCode = error,
            };
            usageDb.AiUsage.Add(record);
            await usageDb.SaveChangesAsync(CancellationToken.None);
            return record.Id;
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            logger.LogError(e, "Could not record AI usage");
            return null;
        }
    }
}
