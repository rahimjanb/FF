using System.ComponentModel.DataAnnotations;
using FitnessFormulasi.Api.Auth;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features;

public class UpdateMyProfileRequest
{
    [Required, StringLength(64, MinimumLength = 1)] public string FirstName { get; set; } = "";
    [Required, StringLength(64, MinimumLength = 1)] public string LastName { get; set; } = "";
    [EmailAddress, StringLength(256)] public string? Email { get; set; }
    [PastDate] public DateOnly? BirthDate { get; set; }
    public Gender? Gender { get; set; }
}

public enum SessionScope { Upcoming, History }

/// <summary>Client-facing endpoints. Every query is scoped to the signed-in client's own profile.</summary>
[ApiController]
[Route("api/me")]
[Authorize(Roles = RoleNames.Client)]
[Produces("application/json")]
public class ClientController(
    AppDbContext db, Profiles profiles, ICurrentUser currentUser, IClubClock clock,
    MembershipService memberships, TrainerRequestService requests, MembershipRequestService membershipRequests,
    PassTokenService passes, AccountDeletionService deletion) : ControllerBase
{
    /// <summary>
    /// Deletes the signed-in client's account for good (App Store and Google Play require it in the app). Personal
    /// data and the face photo are erased; memberships and visits stay without the name for the club's accounting.
    /// </summary>
    [HttpPost("delete-account")]
    [EnableRateLimiting(RateLimits.Auth)]
    public async Task<IActionResult> DeleteAccount(DeleteAccountRequest req, CancellationToken ct)
    {
        await deletion.DeleteOwnAsync(req.Password, ct);
        return NoContent();
    }

    [HttpGet("dashboard")]
    public async Task<ClientDashboardDto> Dashboard(CancellationToken ct)
    {
        var clientId = await profiles.ClientIdAsync(ct);
        var client = await db.ClientProfiles.Include(c => c.User).SingleAsync(c => c.Id == clientId, ct);
        var trainer = client.AssignedTrainerId is null ? null
            : await db.TrainerProfiles.Where(t => t.Id == client.AssignedTrainerId).Select(Projections.TrainerWithContacts).SingleOrDefaultAsync(ct);
        var nextSession = await db.TrainingSessions
            .Where(s => s.ClientProfileId == clientId && s.Status == TrainingSessionStatus.Scheduled && s.StartsAt >= clock.UtcNow)
            .OrderBy(s => s.StartsAt).Select(Projections.Session).FirstOrDefaultAsync(ct);
        var pending = await db.TrainerRequests.Where(r => r.ClientProfileId == clientId && r.Status == TrainerRequestStatus.Pending)
            .OrderByDescending(r => r.CreatedAt).Select(Projections.Request).FirstOrDefaultAsync(ct);
        var unread = await db.Notifications.CountAsync(n => n.UserId == currentUser.Id && n.ReadAt == null, ct);

        return new ClientDashboardDto(
            client.User.FirstName,
            await memberships.CurrentForClientAsync(clientId, ct),
            await memberships.NextForClientAsync(clientId, ct),
            nextSession, trainer, await VisitStatsAsync(clientId, ct), pending, unread, client.WithoutTrainer);
    }

    [HttpGet("profile")]
    public async Task<ClientProfileDto> GetProfile(CancellationToken ct) => await LoadProfileAsync(await profiles.ClientIdAsync(ct), ct);

    /// <summary>Updates the fields a client may change. The phone number is the login and is changed only by staff.</summary>
    [HttpPut("profile")]
    public async Task<ClientProfileDto> UpdateProfile(UpdateMyProfileRequest req, CancellationToken ct)
    {
        var clientId = await profiles.ClientIdAsync(ct);
        var client = await db.ClientProfiles.Include(c => c.User).SingleAsync(c => c.Id == clientId, ct);
        client.User.FirstName = req.FirstName.Trim();
        client.User.LastName = req.LastName.Trim();
        client.User.Email = string.IsNullOrWhiteSpace(req.Email) ? null : req.Email.Trim();
        client.BirthDate = req.BirthDate;
        client.Gender = req.Gender;
        await db.SaveChangesAsync(ct);
        return await LoadProfileAsync(clientId, ct);
    }

    [HttpGet("memberships")]
    public async Task<List<MembershipDto>> Memberships(CancellationToken ct) =>
        await memberships.ForClientAsync(await profiles.ClientIdAsync(ct), ct);

    /// <summary>
    /// Freezes the client's own membership: plans of six months or longer, three times per year of the plan,
    /// up to 30 days each. The end date moves forward by the frozen days.
    /// </summary>
    [HttpPost("memberships/{id:guid}/freeze")]
    public async Task<MembershipDto> FreezeMembership(Guid id, FreezeMembershipRequest req, CancellationToken ct) =>
        await memberships.FreezeAsync(id, req, ct, clientId: await profiles.ClientIdAsync(ct));

    /// <summary>Ends the current freeze today or cancels a planned one; unused days are taken back from the end date.</summary>
    [HttpPost("memberships/{id:guid}/unfreeze")]
    public async Task<MembershipDto> UnfreezeMembership(Guid id, CancellationToken ct) =>
        await memberships.UnfreezeAsync(id, ct, clientId: await profiles.ClientIdAsync(ct));

    /// <summary>
    /// The client trains on their own: the app stops asking to choose a trainer and pending trainer requests are
    /// withdrawn. Choosing a trainer later is still possible; the flag is cleared when one is assigned.
    /// </summary>
    [HttpPost("without-trainer")]
    public async Task<ClientProfileDto> TrainWithoutTrainer(CancellationToken ct)
    {
        var clientId = await profiles.ClientIdAsync(ct);
        var client = await db.ClientProfiles.SingleAsync(c => c.Id == clientId, ct);
        if (client.AssignedTrainerId is not null)
            throw ApiException.Conflict("trainer_assigned", "A trainer is already assigned to you.");
        client.WithoutTrainer = true;
        var now = clock.UtcNow;
        var pending = await db.TrainerRequests.Where(r => r.ClientProfileId == clientId && r.Status == TrainerRequestStatus.Pending).ToListAsync(ct);
        foreach (var r in pending)
        {
            r.Status = TrainerRequestStatus.Cancelled;
            r.RespondedAt = now;
            r.RespondedByUserId = currentUser.Id;
        }
        await db.SaveChangesAsync(ct);
        return await LoadProfileAsync(clientId, ct);
    }

    /// <summary>Plans currently on sale. Buying one is a membership request; payment is taken at the club desk.</summary>
    [HttpGet("plans")]
    public async Task<List<MembershipPlanDto>> Plans(CancellationToken ct) =>
        await db.MembershipPlans.Where(p => p.IsActive).OrderBy(p => p.DurationDays).ThenBy(p => p.Price).ThenBy(p => p.Id)
            .Select(Projections.Plan).ToListAsync(ct);

    /// <summary>
    /// QR pass for the club desk. The code changes every 30 seconds and is valid for 60; the app polls this endpoint
    /// while the pass is open, and <c>lastVisitAt</c> tells it when the scan has been accepted.
    /// </summary>
    [HttpGet("pass")]
    public async Task<PassDto> Pass(CancellationToken ct)
    {
        var clientId = await profiles.ClientIdAsync(ct);
        var now = clock.UtcNow;
        var token = passes.Issue(clientId, now);
        var lastVisit = await db.Visits.Where(v => v.ClientProfileId == clientId).MaxAsync(v => (DateTimeOffset?)v.VisitedAt, ct);
        var refreshIn = (int)Math.Ceiling((token.RefreshAt - now).TotalSeconds);
        return new PassDto(token.Code, token.ExpiresAt, token.RefreshAt, Math.Max(refreshIn, 1), lastVisit);
    }

    [HttpGet("membership-requests")]
    public async Task<List<MembershipRequestDto>> MembershipRequests(CancellationToken ct)
    {
        var clientId = await profiles.ClientIdAsync(ct);
        return await db.MembershipRequests.Where(r => r.ClientProfileId == clientId)
            .OrderByDescending(r => r.CreatedAt).Select(Projections.MembershipRequestExpr).Take(20).ToListAsync(ct);
    }

    /// <summary>Asks the club for a plan (new, renewal or change). Staff complete it after payment at the desk.</summary>
    [HttpPost("membership-requests")]
    public async Task<ActionResult<MembershipRequestDto>> CreateMembershipRequest(CreateMembershipRequest req, CancellationToken ct)
    {
        var dto = await membershipRequests.CreateAsync(await profiles.ClientIdAsync(ct), req, ct);
        return StatusCode(StatusCodes.Status201Created, dto);
    }

    [HttpPost("membership-requests/{id:guid}/cancel")]
    public async Task<MembershipRequestDto> CancelMembershipRequest(Guid id, CancellationToken ct) =>
        await membershipRequests.CancelByClientAsync(await profiles.ClientIdAsync(ct), id, ct);

    [HttpGet("trainer-requests")]
    public async Task<List<TrainerRequestDto>> TrainerRequests(CancellationToken ct)
    {
        var clientId = await profiles.ClientIdAsync(ct);
        return await db.TrainerRequests.Where(r => r.ClientProfileId == clientId)
            .OrderByDescending(r => r.CreatedAt).Select(Projections.Request).Take(50).ToListAsync(ct);
    }

    [HttpPost("trainer-requests")]
    public async Task<ActionResult<TrainerRequestDto>> CreateTrainerRequest(CreateTrainerRequest req, CancellationToken ct)
    {
        var dto = await requests.CreateAsync(await profiles.ClientIdAsync(ct), req, ct);
        return StatusCode(StatusCodes.Status201Created, dto);
    }

    [HttpPost("trainer-requests/{id:guid}/cancel")]
    public async Task<TrainerRequestDto> CancelTrainerRequest(Guid id, CancellationToken ct) =>
        await requests.CancelByClientAsync(await profiles.ClientIdAsync(ct), id, ct);

    /// <summary>
    /// Client's training sessions.
    /// <c>upcoming</c> (default): scheduled sessions that have not ended yet, soonest first.
    /// <c>history</c>: everything else (ended, completed, cancelled), most recent first, paged.
    /// </summary>
    [HttpGet("training-sessions")]
    public async Task<PagedResult<TrainingSessionDto>> TrainingSessions(
        [FromQuery] PageQuery paging, [FromQuery] SessionScope scope = SessionScope.Upcoming, CancellationToken ct = default)
    {
        var clientId = await profiles.ClientIdAsync(ct);
        var now = clock.UtcNow;
        var q = db.TrainingSessions.Where(s => s.ClientProfileId == clientId);
        var isUpcoming = (System.Linq.Expressions.Expression<Func<TrainingSession, bool>>)(s =>
            s.Status == TrainingSessionStatus.Scheduled && s.StartsAt.AddMinutes(s.DurationMinutes) > now);
        q = scope == SessionScope.Upcoming
            ? q.Where(isUpcoming).OrderBy(s => s.StartsAt).ThenBy(s => s.Id)
            : q.Where(s => !(s.Status == TrainingSessionStatus.Scheduled && s.StartsAt.AddMinutes(s.DurationMinutes) > now))
               .OrderByDescending(s => s.StartsAt).ThenBy(s => s.Id);
        return await q.Select(Projections.Session).ToPagedAsync(paging, ct);
    }

    [HttpGet("visits")]
    public async Task<PagedResult<VisitDto>> Visits([FromQuery] PageQuery paging, CancellationToken ct)
    {
        var clientId = await profiles.ClientIdAsync(ct);
        return await db.Visits.Where(v => v.ClientProfileId == clientId).OrderByDescending(v => v.VisitedAt).ThenBy(v => v.Id)
            .Select(Projections.VisitExpr).ToPagedAsync(paging, ct);
    }

    private async Task<VisitStatsDto> VisitStatsAsync(Guid clientId, CancellationToken ct)
    {
        var today = clock.Today;
        var monthStart = clock.StartOfDayUtc(new DateOnly(today.Year, today.Month, 1));
        var visits = db.Visits.Where(v => v.ClientProfileId == clientId);
        return new VisitStatsDto(
            await visits.CountAsync(v => v.VisitedAt >= monthStart, ct),
            await visits.CountAsync(ct),
            await visits.MaxAsync(v => (DateTimeOffset?)v.VisitedAt, ct));
    }

    private async Task<ClientProfileDto> LoadProfileAsync(Guid clientId, CancellationToken ct) =>
        await db.ClientProfiles.Where(c => c.Id == clientId).Select(c => new ClientProfileDto(
            c.Id, c.User.Phone, c.User.PhoneConfirmed, c.User.FirstName, c.User.LastName, c.User.Email, c.BirthDate, c.Gender,
            c.AssignedTrainer == null ? null : new TrainerPublicDto(
                c.AssignedTrainer.Id, c.AssignedTrainer.User.FirstName, c.AssignedTrainer.User.LastName,
                c.AssignedTrainer.Specialization, c.AssignedTrainer.Bio, c.AssignedTrainer.ExperienceYears,
                c.AssignedTrainer.IsAcceptingClients, c.AssignedTrainer.PhotoVersion,
                c.AssignedTrainer.Telegram, c.AssignedTrainer.Instagram),
            c.CreatedAt, c.WithoutTrainer)).SingleAsync(ct);
}
