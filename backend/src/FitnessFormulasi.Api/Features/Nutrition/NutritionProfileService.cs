using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features.Ai;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features.Nutrition;

/// <summary>The client's nutrition settings, daily target and consent to the AI service.</summary>
public sealed class NutritionProfileService(AppDbContext db, AiGateway ai, IClubClock clock, ICurrentUser currentUser)
{
    public async Task<NutritionProfileDto> GetAsync(Guid clientId, CancellationToken ct)
    {
        var client = await db.ClientProfiles.AsNoTracking().SingleAsync(c => c.Id == clientId, ct);
        var profile = await db.NutritionProfiles.AsNoTracking().SingleOrDefaultAsync(p => p.ClientProfileId == clientId, ct);
        return new NutritionProfileDto(
            profile?.Goal, profile?.WeightKg, profile?.HeightCm, profile?.Activity, client.Gender, client.BirthDate,
            profile?.CustomKcalTarget, profile?.Restrictions, profile?.Allergies ?? [], profile?.AiConsentAt, ai.IsAvailable, ai.DisplayName,
            ai.DailyLimit(AiFeature.FoodPhoto), await ai.UsedTodayAsync(clientId, AiFeature.FoodPhoto, ct),
            NutritionTargets.Compute(profile, client.Gender, client.BirthDate, clock.Today),
            NutritionTargets.Missing(profile, client.Gender, client.BirthDate));
    }

    public async Task<NutritionTargetDto?> TargetAsync(Guid clientId, CancellationToken ct)
    {
        var client = await db.ClientProfiles.AsNoTracking().Where(c => c.Id == clientId).Select(c => new { c.Gender, c.BirthDate }).SingleAsync(ct);
        var profile = await db.NutritionProfiles.AsNoTracking().SingleOrDefaultAsync(p => p.ClientProfileId == clientId, ct);
        return NutritionTargets.Compute(profile, client.Gender, client.BirthDate, clock.Today);
    }

    public async Task<NutritionProfileDto> UpdateAsync(Guid clientId, UpdateNutritionProfileRequest req, CancellationToken ct)
    {
        var profile = await EnsureAsync(clientId, ct);
        profile.Goal = req.Goal;
        profile.WeightKg = req.WeightKg is { } w ? Math.Round(w, 1) : null;
        profile.HeightCm = req.HeightCm is { } h ? Math.Round(h, 1) : null;
        profile.Activity = req.Activity;
        profile.CustomKcalTarget = req.CustomKcalTarget;
        profile.Restrictions = string.IsNullOrWhiteSpace(req.Restrictions) ? null : req.Restrictions.Trim();
        profile.Allergies = req.Allergies.Distinct().ToList();
        // Sex and birth date are the client profile's own fields (the profile screen edits the same values).
        if (req.Sex is not null || req.BirthDate is not null)
        {
            var client = await db.ClientProfiles.SingleAsync(c => c.Id == clientId, ct);
            if (req.Sex is not null) client.Gender = req.Sex;
            if (req.BirthDate is not null) client.BirthDate = req.BirthDate;
        }
        await db.SaveChangesAsync(ct);
        return await GetAsync(clientId, ct);
    }

    /// <summary>
    /// The client agrees that food photos and nutrition data (never the name or phone number) are sent to the AI
    /// service. Required by App Store rules before personal data goes to a third-party AI.
    /// </summary>
    public async Task<NutritionProfileDto> SetConsentAsync(Guid clientId, bool consent, CancellationToken ct)
    {
        var profile = await EnsureAsync(clientId, ct);
        profile.AiConsentAt = consent ? clock.UtcNow : null;
        db.AuditLog.Add(new AuditLogEntry
        {
            UserId = currentUser.Id, Action = consent ? "nutrition.ai_consent_given" : "nutrition.ai_consent_revoked",
            Target = $"client:{clientId}", Details = ai.DisplayName,
        });
        await db.SaveChangesAsync(ct);
        return await GetAsync(clientId, ct);
    }

    public async Task EnsureAiConsentAsync(Guid clientId, CancellationToken ct)
    {
        if (!ai.IsAvailable) throw AiException.NotConfigured();
        var consent = await db.NutritionProfiles.Where(p => p.ClientProfileId == clientId).Select(p => p.AiConsentAt).SingleOrDefaultAsync(ct);
        if (consent is null)
            throw ApiException.Conflict("ai_consent_required", "Agree to sending photos and nutrition data to the AI service first.");
    }

    private async Task<NutritionProfile> EnsureAsync(Guid clientId, CancellationToken ct)
    {
        var profile = await db.NutritionProfiles.SingleOrDefaultAsync(p => p.ClientProfileId == clientId, ct);
        if (profile is not null) return profile;
        profile = new NutritionProfile { ClientProfileId = clientId };
        db.NutritionProfiles.Add(profile);
        return profile;
    }
}
