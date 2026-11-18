using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features.Admin;

/// <summary>Club desk: QR pass scanning and undoing a visit recorded by mistake.</summary>
[ApiController]
[Route("api/admin")]
[Authorize(Roles = RoleNames.Admin)]
[Produces("application/json")]
public class AdminCheckInController(AppDbContext db, IClubClock clock, ICurrentUser currentUser, CheckInService checkIn) : ControllerBase
{
    public static readonly TimeSpan UndoWindow = TimeSpan.FromMinutes(15);

    /// <summary>
    /// Checks a scanned QR pass and, if the membership allows entry, records the visit. A refusal is a normal
    /// answer (200 with <c>allowed: false</c> and a reason), not an error.
    /// </summary>
    [HttpPost("check-in")]
    public Task<CheckInResultDto> CheckIn(CheckInRequest req, CancellationToken ct) => checkIn.CheckInAsync(req, ct);

    /// <summary>Removes a visit recorded in the last 15 minutes (wrong person scanned, double entry). Logged in the audit log.</summary>
    [HttpDelete("visits/{id:guid}")]
    public async Task<IActionResult> UndoVisit(Guid id, CancellationToken ct)
    {
        var visit = await db.Visits.Include(v => v.ClientProfile).ThenInclude(c => c.User).SingleOrDefaultAsync(v => v.Id == id, ct)
                    ?? throw ApiException.NotFound("Visit");
        if (visit.CreatedAt < clock.UtcNow - UndoWindow)
            throw ApiException.Conflict("visit_undo_expired", "Only a visit recorded in the last 15 minutes can be undone.");
        db.Visits.Remove(visit);
        db.AuditLog.Add(new AuditLogEntry
        {
            UserId = currentUser.Id, Action = "visit.undo", Target = $"client:{visit.ClientProfileId}",
            Details = $"{visit.Source} visit {visit.VisitedAt:O} ({visit.ClientProfile.User.FullName}) removed",
        });
        await db.SaveChangesAsync(ct);
        return NoContent();
    }
}
