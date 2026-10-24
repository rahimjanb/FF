using System.ComponentModel.DataAnnotations;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features;

public class UpdateTrainerSelfRequest
{
    [StringLength(128)] public string? Specialization { get; set; }
    [StringLength(2000)] public string? Bio { get; set; }
    public bool IsAcceptingClients { get; set; }
}

/// <summary>Trainer cabinet. Every query is scoped to the signed-in trainer; other trainers' clients are invisible.</summary>
[ApiController]
[Route("api/trainer")]
[Authorize(Roles = RoleNames.Trainer)]
[Produces("application/json")]
public class TrainerCabinetController(
    AppDbContext db, Profiles profiles, IClubClock clock, MembershipService memberships,
    TrainerRequestService requests, TrainingSessionService sessions) : ControllerBase
{
    public const int PastDays = 7;

    [HttpGet("profile")]
    public async Task<TrainerAdminDto> Profile(CancellationToken ct)
    {
        var id = await profiles.TrainerIdAsync(ct);
        return await db.TrainerProfiles.Where(t => t.Id == id).Select(Projections.TrainerAdmin).SingleAsync(ct);
    }

    [HttpPut("profile")]
    public async Task<TrainerAdminDto> UpdateProfile(UpdateTrainerSelfRequest req, CancellationToken ct)
    {
        var id = await profiles.TrainerIdAsync(ct);
        var trainer = await db.TrainerProfiles.SingleAsync(t => t.Id == id, ct);
        trainer.Specialization = req.Specialization?.Trim();
        trainer.Bio = req.Bio?.Trim();
        trainer.IsAcceptingClients = req.IsAcceptingClients;
        await db.SaveChangesAsync(ct);
        return await Profile(ct);
    }

    [HttpGet("clients")]
    public async Task<PagedResult<TrainerClientDto>> Clients([FromQuery] PageQuery paging, CancellationToken ct)
    {
        var trainerId = await profiles.TrainerIdAsync(ct);
        var result = await db.ClientProfiles.Where(c => c.AssignedTrainerId == trainerId)
            .OrderBy(c => c.User.FirstName).ThenBy(c => c.User.LastName).ThenBy(c => c.Id)
            .Select(c => new { c.Id, c.User.FirstName, c.User.LastName, c.User.Phone, c.BirthDate, c.Gender,
                               LastVisitAt = c.Visits.Max(v => (DateTimeOffset?)v.VisitedAt) })
            .ToPagedAsync(paging, ct);

        var items = new List<TrainerClientDto>();
        foreach (var c in result.Items)
            items.Add(new TrainerClientDto(c.Id, c.FirstName, c.LastName, c.Phone, c.BirthDate, c.Gender,
                await memberships.CurrentForClientAsync(c.Id, ct), c.LastVisitAt));
        return new PagedResult<TrainerClientDto>(items, result.Page, result.PageSize, result.TotalCount);
    }

    [HttpGet("clients/{clientId:guid}")]
    public async Task<TrainerClientDto> Client(Guid clientId, CancellationToken ct)
    {
        var trainerId = await profiles.TrainerIdAsync(ct);
        var c = await db.ClientProfiles.Where(x => x.Id == clientId && x.AssignedTrainerId == trainerId)
                    .Select(x => new { x.Id, x.User.FirstName, x.User.LastName, x.User.Phone, x.BirthDate, x.Gender,
                                       LastVisitAt = x.Visits.Max(v => (DateTimeOffset?)v.VisitedAt) })
                    .SingleOrDefaultAsync(ct)
                ?? throw ApiException.NotFound("Client");
        return new TrainerClientDto(c.Id, c.FirstName, c.LastName, c.Phone, c.BirthDate, c.Gender,
            await memberships.CurrentForClientAsync(c.Id, ct), c.LastVisitAt);
    }

    [HttpGet("requests")]
    public async Task<PagedResult<TrainerRequestDto>> Requests([FromQuery] TrainerRequestStatus? status, [FromQuery] PageQuery paging, CancellationToken ct)
    {
        var trainerId = await profiles.TrainerIdAsync(ct);
        var q = db.TrainerRequests.Where(r => r.TrainerProfileId == trainerId);
        if (status is not null) q = q.Where(r => r.Status == status);
        return await q.OrderByDescending(r => r.CreatedAt).ThenBy(r => r.Id).Select(Projections.Request).ToPagedAsync(paging, ct);
    }

    [HttpPost("requests/{id:guid}/accept")]
    public async Task<TrainerRequestDto> Accept(Guid id, RespondTrainerRequest req, CancellationToken ct) =>
        await requests.RespondAsync(id, true, req.Comment, await profiles.TrainerIdAsync(ct), ct);

    [HttpPost("requests/{id:guid}/reject")]
    public async Task<TrainerRequestDto> Reject(Guid id, RespondTrainerRequest req, CancellationToken ct) =>
        await requests.RespondAsync(id, false, req.Comment, await profiles.TrainerIdAsync(ct), ct);

    /// <summary>
    /// Trainer's sessions in a club-local date range. Default: the last 7 days (so sessions that were not
    /// marked can still be completed or cancelled) through the next 30 days.
    /// </summary>
    [HttpGet("sessions")]
    public async Task<List<TrainingSessionDto>> Sessions([FromQuery] DateOnly? from, [FromQuery] DateOnly? to, CancellationToken ct)
    {
        var trainerId = await profiles.TrainerIdAsync(ct);
        var start = clock.StartOfDayUtc(from ?? clock.Today.AddDays(-PastDays));
        var end = clock.StartOfDayUtc((to ?? clock.Today.AddDays(30)).AddDays(1));
        if (end <= start || (end - start).TotalDays > 120)
            throw ApiException.BadRequest("invalid_range", "Date range must be positive and at most 120 days.");
        return await db.TrainingSessions.Where(s => s.TrainerProfileId == trainerId && s.StartsAt >= start && s.StartsAt < end)
            .OrderBy(s => s.StartsAt).Select(Projections.Session).ToListAsync(ct);
    }

    [HttpPost("sessions")]
    public async Task<ActionResult<TrainingSessionDto>> CreateSession(CreateTrainingSessionRequest req, CancellationToken ct)
    {
        var dto = await sessions.CreateAsync(await profiles.TrainerIdAsync(ct), req, ct);
        return StatusCode(StatusCodes.Status201Created, dto);
    }

    [HttpPost("sessions/{id:guid}/cancel")]
    public async Task<TrainingSessionDto> CancelSession(Guid id, CancellationToken ct) =>
        await sessions.SetStatusAsync(await profiles.TrainerIdAsync(ct), id, TrainingSessionStatus.Cancelled, ct);

    [HttpPost("sessions/{id:guid}/complete")]
    public async Task<TrainingSessionDto> CompleteSession(Guid id, CancellationToken ct) =>
        await sessions.SetStatusAsync(await profiles.TrainerIdAsync(ct), id, TrainingSessionStatus.Completed, ct);
}
