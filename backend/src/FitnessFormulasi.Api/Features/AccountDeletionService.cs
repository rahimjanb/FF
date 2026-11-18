using System.ComponentModel.DataAnnotations;
using FitnessFormulasi.Api.Auth;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using FitnessFormulasi.Api.Features.Banners;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features;

public class DeleteAccountRequest
{
    [Required, StringLength(128)] public string Password { get; set; } = "";
}

/// <summary>
/// Deletes a client account, as App Store and Google Play require: by the client in the app, or by staff when the
/// client asks the club (the deletion web page). Personal data is erased, the face photo is removed (the next
/// synchronisation takes the person off the terminals), all sessions end and the phone number is free to register
/// again. Memberships (the current and future ones cancelled), visits and freezes stay with the anonymous profile: the
/// club keeps them for accounting.
/// Irreversible.
/// </summary>
public sealed class AccountDeletionService(
    AppDbContext db, IPasswordHasher<User> hasher, MembershipService memberships, ICurrentUser currentUser, IClubClock clock,
    MediaStorage media, ILogger<AccountDeletionService> logger)
{
    public const string DeletedFirstName = "Удалённый";
    public const string DeletedLastName = "клиент";

    /// <summary>The signed-in client deletes their own account; the password confirms it is them.</summary>
    public async Task DeleteOwnAsync(string password, CancellationToken ct)
    {
        var user = await db.Users.AsNoTracking().SingleAsync(u => u.Id == currentUser.Id, ct);
        if (hasher.VerifyHashedPassword(user, user.PasswordHash, password) == PasswordVerificationResult.Failed)
            throw ApiException.BadRequest("invalid_password", "The password is incorrect.");
        var clientId = await db.ClientProfiles.Where(c => c.UserId == user.Id).Select(c => c.Id).SingleAsync(ct);
        await DeleteAsync(clientId, "by the client in the app", ct);
    }

    public async Task DeleteAsync(Guid clientId, string details, CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        // Same row lock as membership changes, so a membership cannot be added while the account is being deleted.
        var client = await memberships.LockClientAsync(clientId, ct);
        var user = await db.Users.SingleAsync(u => u.Id == client.UserId, ct);
        if (user.Status == UserStatus.Deleted)
            throw ApiException.Conflict("client_deleted", "The account has already been deleted.");

        var now = clock.UtcNow;
        var oldName = user.FullName;
        var oldPhone = user.Phone;

        user.FirstName = DeletedFirstName;
        user.LastName = DeletedLastName;
        user.Email = null;
        // Unique and not a phone number, so it never matches a sign-in or a search by digits.
        user.Phone = $"del-{user.Id.ToString("N")[^12..]}";
        user.PhoneConfirmed = false;
        user.PasswordHash = ""; // matches no password
        user.MustChangePassword = false;
        user.CanManageIntegrations = false;
        user.AccessFailedCount = 0;
        user.LockoutEnd = null;
        user.Status = UserStatus.Deleted;
        user.DeletedAt = now;

        client.BirthDate = null;
        client.Gender = null;
        client.Notes = null;
        client.AssignedTrainerId = null;
        client.WithoutTrainer = false;

        // Tracked removal, so the access interceptor schedules the terminal synchronisation.
        var face = await db.ClientFaces.SingleOrDefaultAsync(f => f.ClientProfileId == clientId, ct);
        if (face is not null) db.ClientFaces.Remove(face);

        // The unused rest of current and future memberships is lost with the account. They stay in the history (and in
        // the reports, which count memberships by the day they were sold) as cancelled.
        var today = clock.Today;
        await db.Memberships.Where(m => m.ClientProfileId == clientId && m.Status != MembershipStatus.Cancelled && m.EndDate >= today)
            .ExecuteUpdateAsync(s => s.SetProperty(m => m.Status, MembershipStatus.Cancelled).SetProperty(m => m.UpdatedAt, now), ct);
        await db.RefreshTokens.Where(t => t.UserId == user.Id && t.RevokedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAt, now), ct);
        await db.Notifications.Where(n => n.UserId == user.Id).ExecuteDeleteAsync(ct);
        await db.PhoneVerificationCodes.Where(c => c.Phone == oldPhone).ExecuteDeleteAsync(ct);
        await db.MembershipRequests.Where(r => r.ClientProfileId == clientId && r.Status == MembershipRequestStatus.Pending)
            .ExecuteUpdateAsync(s => s.SetProperty(r => r.Status, MembershipRequestStatus.Cancelled).SetProperty(r => r.UpdatedAt, now), ct);
        await db.TrainerRequests.Where(r => r.ClientProfileId == clientId)
            .ExecuteUpdateAsync(s => s
                .SetProperty(r => r.Status, r => r.Status == TrainerRequestStatus.Pending ? TrainerRequestStatus.Cancelled : r.Status)
                .SetProperty(r => r.Message, (string?)null)
                .SetProperty(r => r.UpdatedAt, now), ct);
        await db.TrainingSessions.Where(s => s.ClientProfileId == clientId)
            .ExecuteUpdateAsync(s => s
                .SetProperty(x => x.Status, x => x.Status == TrainingSessionStatus.Scheduled && x.StartsAt > now ? TrainingSessionStatus.Cancelled : x.Status)
                .SetProperty(x => x.Notes, (string?)null)
                .SetProperty(x => x.UpdatedAt, now), ct);
        // Nutrition data (food photos, diary, own products and recipes, body measurements) has no accounting value:
        // all of it goes. AI spending records stay, without the link to the person.
        var foodPhotos = await db.FoodScans.Where(s => s.ClientProfileId == clientId && s.PhotoId != null).Select(s => s.PhotoId!.Value).ToListAsync(ct);
        await db.FoodDiaryEntries.Where(e => e.ClientProfileId == clientId).ExecuteDeleteAsync(ct);
        await db.FoodScans.Where(s => s.ClientProfileId == clientId).ExecuteDeleteAsync(ct);
        await db.FoodRecipes.Where(r => r.OwnerClientId == clientId).ExecuteDeleteAsync(ct);
        await db.FoodBarcodes.Where(b => b.OwnerClientId == clientId).ExecuteDeleteAsync(ct);
        await db.FoodProducts.Where(p => p.OwnerClientId == clientId).ExecuteDeleteAsync(ct);
        await db.NutritionDailySummaries.Where(x => x.ClientProfileId == clientId).ExecuteDeleteAsync(ct);
        await db.NutritionReports.Where(x => x.ClientProfileId == clientId).ExecuteDeleteAsync(ct);
        await db.NutritionProfiles.Where(x => x.ClientProfileId == clientId).ExecuteDeleteAsync(ct);
        await db.AiUsage.Where(u => u.ClientProfileId == clientId).ExecuteUpdateAsync(s => s.SetProperty(u => u.ClientProfileId, (Guid?)null), ct);

        // Earlier journal entries about the client may quote the name or phone number.
        await db.AuditLog.Where(a => a.Target == $"client:{clientId}" && a.Details != null)
            .ExecuteUpdateAsync(s => s.SetProperty(a => a.Details, a => a.Details!.Replace(oldName, "—").Replace(oldPhone, "—")), ct);

        db.AuditLog.Add(new AuditLogEntry
        {
            UserId = currentUser.Id, Action = "client.deleted", Target = $"client:{clientId}", Details = details,
        });
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        foreach (var photo in foodPhotos) media.Delete(photo);
        logger.LogInformation("Client {ClientId} account deleted {Details}", clientId, details);
    }
}
