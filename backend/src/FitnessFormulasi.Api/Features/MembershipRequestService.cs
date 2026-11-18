using System.ComponentModel.DataAnnotations;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features;

public class CreateMembershipRequest
{
    [Required] public Guid PlanId { get; set; }
    [Required] public MembershipRequestKind Kind { get; set; }
}

public class CompleteMembershipRequest
{
    /// <summary>Club-local start date. Defaults to the day after the client's last membership, or today.</summary>
    public DateOnly? StartDate { get; set; }
    /// <summary>Start the new plan now: the membership covering the start date ends the day before.</summary>
    public bool CloseCurrent { get; set; }
}

public class RejectMembershipRequest
{
    [StringLength(500)] public string? Comment { get; set; }
}

/// <summary>
/// Renewal and plan change requested from the app. Payment is taken at the club desk; completing the request
/// assigns the membership (stage 2 adds online payment).
/// </summary>
public sealed class MembershipRequestService(
    AppDbContext db, IClubClock clock, ICurrentUser currentUser, MembershipService memberships, NotificationService notifications)
{
    public async Task<MembershipRequestDto> CreateAsync(Guid clientId, CreateMembershipRequest req, CancellationToken ct)
    {
        var plan = await db.MembershipPlans.SingleOrDefaultAsync(p => p.Id == req.PlanId, ct) ?? throw ApiException.NotFound("Membership plan");
        if (!plan.IsActive) throw ApiException.Conflict("plan_inactive", "The membership plan is not available.");
        if (await db.MembershipRequests.AnyAsync(r => r.ClientProfileId == clientId && r.Status == MembershipRequestStatus.Pending, ct))
            throw ApiException.Conflict("membership_request_pending", "There is already a pending membership request.");

        var request = new MembershipRequest { ClientProfileId = clientId, MembershipPlanId = plan.Id, Kind = req.Kind };
        db.MembershipRequests.Add(request);
        await db.SaveChangesAsync(ct);
        return await GetAsync(request.Id, ct);
    }

    public async Task<MembershipRequestDto> CancelByClientAsync(Guid clientId, Guid id, CancellationToken ct)
    {
        var request = await db.MembershipRequests.SingleOrDefaultAsync(r => r.Id == id && r.ClientProfileId == clientId, ct)
                      ?? throw ApiException.NotFound("Membership request");
        EnsurePending(request);
        request.Status = MembershipRequestStatus.Cancelled;
        await db.SaveChangesAsync(ct);
        return await GetAsync(id, ct);
    }

    /// <summary>Staff took the payment: assigns the membership and closes the request.</summary>
    public async Task<MembershipRequestDto> CompleteAsync(Guid id, CompleteMembershipRequest req, CancellationToken ct)
    {
        var today = clock.Today;
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var request = await db.MembershipRequests.SingleOrDefaultAsync(r => r.Id == id, ct) ?? throw ApiException.NotFound("Membership request");
        var client = await memberships.LockClientAsync(request.ClientProfileId, ct);
        EnsurePending(request);

        var start = req.StartDate ?? (req.CloseCurrent ? today : await DefaultStartAsync(client.Id, today, ct));
        if (start < today || start.DayNumber - today.DayNumber > 366)
            throw ApiException.BadRequest("invalid_start_date", "Start date must be between today and one year ahead.");
        if (req.CloseCurrent)
        {
            await memberships.CloseCoveringAsync(client.Id, start, ct);
            await db.SaveChangesAsync(ct);
        }

        var membership = await memberships.AddMembershipAsync(client, request.MembershipPlanId, start, ct);
        request.Status = MembershipRequestStatus.Completed;
        request.MembershipId = membership.Id;
        request.RespondedAt = clock.UtcNow;
        request.RespondedByUserId = currentUser.Id;
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return await GetAsync(id, ct);
    }

    public async Task<MembershipRequestDto> RejectAsync(Guid id, RejectMembershipRequest req, CancellationToken ct)
    {
        var request = await db.MembershipRequests.Include(r => r.Plan).Include(r => r.ClientProfile)
                          .SingleOrDefaultAsync(r => r.Id == id, ct) ?? throw ApiException.NotFound("Membership request");
        EnsurePending(request);
        request.Status = MembershipRequestStatus.Rejected;
        request.ResponseComment = string.IsNullOrWhiteSpace(req.Comment) ? null : req.Comment.Trim();
        request.RespondedAt = clock.UtcNow;
        request.RespondedByUserId = currentUser.Id;
        notifications.Add(request.ClientProfile.UserId, NotificationType.MembershipRequestRejected, request.Id, request.Plan.Name);
        await db.SaveChangesAsync(ct);
        return await GetAsync(id, ct);
    }

    public async Task<MembershipRequestDto> GetAsync(Guid id, CancellationToken ct) =>
        await db.MembershipRequests.Where(r => r.Id == id).Select(Projections.MembershipRequestExpr).SingleOrDefaultAsync(ct)
        ?? throw ApiException.NotFound("Membership request");

    /// <summary>The day after the client's last membership if it is still running or upcoming, otherwise today.</summary>
    public async Task<DateOnly> DefaultStartAsync(Guid clientId, DateOnly today, CancellationToken ct)
    {
        var lastEnd = await db.Memberships.Where(m => m.ClientProfileId == clientId && m.Status != MembershipStatus.Cancelled)
            .MaxAsync(m => (DateOnly?)m.EndDate, ct);
        return lastEnd is { } end && end >= today ? end.AddDays(1) : today;
    }

    private static void EnsurePending(MembershipRequest request)
    {
        if (request.Status != MembershipRequestStatus.Pending)
            throw ApiException.Conflict("membership_request_not_pending", "The request has already been processed.");
    }
}
