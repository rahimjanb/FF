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

    private IQueryable<TrainerProfile> Active() =>
        db.TrainerProfiles.Where(t => t.IsActive && t.User.Status == UserStatus.Active);
}
