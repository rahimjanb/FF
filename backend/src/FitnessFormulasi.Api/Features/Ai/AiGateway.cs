using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace FitnessFormulasi.Api.Features.Ai;

/// <summary>
/// The only way business code reaches the AI provider: picks the provider in use (<see cref="AiConnectionProvider"/>)
/// and its models, checks the client's daily limits and the monthly budget before a request, and records the tokens,
/// cost and time of every request (successful or not) in AiUsage.
/// </summary>
public sealed partial class AiGateway(
    AiConnectionProvider connections, AppDbContext db, IServiceScopeFactory scopes, IOptions<AiOptions> options, IClubClock clock,
    ILogger<AiGateway> logger)
{
    public AiOptions Options { get; } = options.Value;

    /// <summary>The provider in use now (it may be switched in the admin panel at any time).</summary>
    public Task<AiConnection> ConnectionAsync(CancellationToken ct) => connections.GetAsync(ct);

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
    public async Task EnsureAllowedAsync(Guid clientId, AiFeature feature, CancellationToken ct) =>
        await EnsureAllowedAsync(await connections.GetAsync(ct), clientId, feature, ct);

    private async Task EnsureAllowedAsync(AiConnection connection, Guid clientId, AiFeature feature, CancellationToken ct)
    {
        if (!connection.IsConfigured) throw AiException.NotConfigured();
        var limit = DailyLimit(feature);
        if (limit > 0 && await UsedTodayAsync(clientId, feature, ct) >= limit)
            throw new AiException(StatusCodes.Status429TooManyRequests, "ai_quota_exceeded",
                $"The daily limit of {limit} AI requests of this kind is reached. It resets at midnight.");
        if (connection.MonthlyBudgetUsd > 0)
        {
            var spent = await SpentThisMonthAsync(ct);
            if (spent >= connection.MonthlyBudgetUsd)
            {
                logger.LogWarning("AI monthly budget of {Budget} USD is spent ({Spent} USD); AI requests are paused",
                    connection.MonthlyBudgetUsd, spent);
                throw new AiException(StatusCodes.Status503ServiceUnavailable, "ai_budget_exceeded",
                    "AI analysis is paused until next month: the club's monthly limit is reached.");
            }
        }
    }

    /// <summary>Spent on AI requests since the start of the calendar month (UTC), USD.</summary>
    public async Task<decimal> SpentThisMonthAsync(CancellationToken ct)
    {
        var since = MonthStart();
        return await db.AiUsage.Where(u => u.CreatedAt >= since).SumAsync(u => (decimal?)u.CostUsd, ct) ?? 0;
    }

    public DateTimeOffset MonthStart()
    {
        var now = clock.UtcNow;
        return new DateTimeOffset(now.Year, now.Month, 1, 0, 0, 0, TimeSpan.Zero);
    }

    public async Task<AiJsonResponse> GenerateJsonAsync(Guid clientId, AiJsonRequest request, CancellationToken ct)
    {
        var connection = await connections.GetAsync(ct);
        await EnsureAllowedAsync(connection, clientId, request.Feature, ct);
        request = request with { Model = connection.ModelFor(request.Feature), Effort = connection.EffortFor(request.Feature) };
        var provider = connection.Provider;
        try
        {
            var response = await connection.Client.GenerateJsonAsync(request, ct);
            var id = await RecordAsync(clientId, request.Feature, provider, response.Model, response.Usage, response.Duration, null, ct);
            return response with { UsageId = id };
        }
        catch (AiException e)
        {
            await RecordAsync(clientId, request.Feature, provider, e.Model ?? request.Model, e.Usage, TimeSpan.Zero, e.Code, ct);
            throw;
        }
    }

    public async Task<AiChatResponse> ChatAsync(Guid clientId, AiChatRequest request,
        Func<AiToolCall, CancellationToken, Task<string>> runTool, CancellationToken ct)
    {
        var connection = await connections.GetAsync(ct);
        await EnsureAllowedAsync(connection, clientId, request.Feature, ct);
        request = request with { Model = connection.ModelFor(request.Feature), Effort = connection.EffortFor(request.Feature) };
        var provider = connection.Provider;
        try
        {
            var response = await connection.Client.ChatAsync(request, runTool, ct);
            await RecordAsync(clientId, request.Feature, provider, response.Model, response.Usage, response.Duration, null, ct);
            return response;
        }
        catch (AiException e)
        {
            await RecordAsync(clientId, request.Feature, provider, e.Model ?? request.Model, e.Usage, TimeSpan.Zero, e.Code, ct);
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
        // OpenAI answers with a dated snapshot id (gpt-6.1-terra-2026-10-26): it costs what its model costs.
        if (!Options.Prices.TryGetValue(model, out var price)
            && !Options.Prices.TryGetValue(SnapshotSuffix().Replace(model, ""), out price))
        {
            logger.LogWarning("No AI price configured for model {Model}; set Ai__Prices__{Model}__InputPerMTok etc. Cost recorded as 0", model, model);
            return 0;
        }
        return (usage.InputTokens * price.InputPerMTok + usage.OutputTokens * price.OutputPerMTok
                + usage.CacheReadTokens * price.CacheReadPerMTok + usage.CacheWriteTokens * price.CacheWritePerMTok) / 1_000_000m;
    }

    [System.Text.RegularExpressions.GeneratedRegex(@"-\d{4}-\d{2}-\d{2}$")]
    private static partial System.Text.RegularExpressions.Regex SnapshotSuffix();

    // Written through its own scope, so the caller's unsaved changes are never flushed with it.
    public async Task<Guid?> RecordAsync(Guid? clientId, AiFeature feature, string provider, string model, AiUsage usage,
        TimeSpan duration, string? error, CancellationToken ct)
    {
        var cost = CostOf(model, usage);
        logger.LogInformation(
            "AI {Feature} {Provider}/{Model}: {Input} in (+{CacheRead} cached, {CacheWrite} cache write), {Output} out, {Cost:F4} USD, {Ms} ms, {Result}",
            feature, provider, model, usage.InputTokens, usage.CacheReadTokens, usage.CacheWriteTokens, usage.OutputTokens,
            cost, (int)duration.TotalMilliseconds, error ?? "ok");
        try
        {
            using var scope = scopes.CreateScope();
            var usageDb = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var record = new AiUsageRecord
            {
                ClientProfileId = clientId, Feature = feature, Provider = provider, Model = model,
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
