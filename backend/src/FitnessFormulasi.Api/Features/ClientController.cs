using System.ComponentModel.DataAnnotations;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
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
    MembershipService memberships, TrainerRequestService requests) : ControllerBase
{
    [HttpGet("dashboard")]
    public async Task<ClientDashboardDto> Dashboard(CancellationToken ct)
    {
        var clientId = await profiles.ClientIdAsync(ct);
        var client = await db.ClientProfiles.Include(c => c.User).SingleAsync(c => c.Id == clientId, ct);
        var trainer = client.AssignedTrainerId is null ? null
            : await db.TrainerProfiles.Where(t => t.Id == client.AssignedTrainerId).Select(Projections.TrainerPublic).SingleOrDefaultAsync(ct);
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
            nextSession, trainer, await VisitStatsAsync(clientId, ct), pending, unread);
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

    /// <summary>Plans currently on sale, for the client to compare. Read-only: purchase happens at the club desk in stage 1.</summary>
    [HttpGet("plans")]
    public async Task<List<MembershipPlanDto>> Plans(CancellationToken ct) =>
        await db.MembershipPlans.Where(p => p.IsActive).OrderBy(p => p.DurationDays).ThenBy(p => p.Price).ThenBy(p => p.Id)
            .Select(Projections.Plan).ToListAsync(ct);

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
                c.AssignedTrainer.IsAcceptingClients, c.AssignedTrainer.PhotoVersion),
            c.CreatedAt)).SingleAsync(ct);
}
