using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features;

/// <summary>Public trainer directory for signed-in users. Exposes no contact data.</summary>
[ApiController]
[Route("api/trainers")]
[Authorize]
[Produces("application/json")]
public class TrainersController(AppDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<List<TrainerPublicDto>> List(CancellationToken ct) =>
        await Active().OrderByDescending(t => t.IsAcceptingClients).ThenBy(t => t.User.FirstName)
            .Select(Projections.TrainerPublic).ToListAsync(ct);

    [HttpGet("{id:guid}")]
    public async Task<TrainerPublicDto> Get(Guid id, CancellationToken ct) =>
        await Active().Where(t => t.Id == id).Select(Projections.TrainerPublic).SingleOrDefaultAsync(ct)
        ?? throw ApiException.NotFound("Trainer");

    /// <summary>
    /// Trainer photo. Anonymous so that image widgets and &lt;img&gt; tags can load it without a bearer token:
    /// it is the same picture the club shows to every client. The versioned URL lets it be cached for long.
    /// </summary>
    [HttpGet("{id:guid}/photo")]
    [AllowAnonymous]
    [Produces("image/jpeg", "image/png", "image/webp")]
    public async Task<IActionResult> Photo(Guid id, CancellationToken ct)
    {
        var photo = await db.TrainerPhotos.AsNoTracking().SingleOrDefaultAsync(p => p.TrainerProfileId == id, ct)
            ?? throw ApiException.NotFound("Photo");
        Response.Headers.CacheControl = "public, max-age=31536000, immutable";
        return File(photo.Data, photo.ContentType);
    }

    private IQueryable<TrainerProfile> Active() =>
        db.TrainerProfiles.Where(t => t.IsActive && t.User.Status == UserStatus.Active);
}
