using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features;

[ApiController]
[Route("api/notifications")]
[Authorize]
[Produces("application/json")]
public class NotificationsController(AppDbContext db, ICurrentUser currentUser, IClubClock clock) : ControllerBase
{
    [HttpGet]
    public Task<PagedResult<NotificationDto>> List([FromQuery] PageQuery paging, CancellationToken ct) =>
        db.Notifications.Where(n => n.UserId == currentUser.Id).OrderByDescending(n => n.CreatedAt).ThenBy(n => n.Id)
            .Select(Projections.NotificationExpr).ToPagedAsync(paging, ct);

    [HttpPost("{id:guid}/read")]
    public async Task<IActionResult> MarkRead(Guid id, CancellationToken ct)
    {
        var updated = await db.Notifications.Where(n => n.Id == id && n.UserId == currentUser.Id && n.ReadAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(n => n.ReadAt, clock.UtcNow), ct);
        if (updated == 0 && !await db.Notifications.AnyAsync(n => n.Id == id && n.UserId == currentUser.Id, ct))
            throw ApiException.NotFound("Notification");
        return NoContent();
    }

    [HttpPost("read-all")]
    public async Task<IActionResult> MarkAllRead(CancellationToken ct)
    {
        await db.Notifications.Where(n => n.UserId == currentUser.Id && n.ReadAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(n => n.ReadAt, clock.UtcNow), ct);
        return NoContent();
    }
}
