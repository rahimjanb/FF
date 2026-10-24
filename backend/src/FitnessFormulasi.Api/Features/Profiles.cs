using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features;

/// <summary>Resolves the role profile of the signed-in user. Ids always come from the token, never from the request.</summary>
public sealed class Profiles(AppDbContext db, ICurrentUser user)
{
    public async Task<Guid> ClientIdAsync(CancellationToken ct) =>
        await db.ClientProfiles.Where(c => c.UserId == user.Id).Select(c => (Guid?)c.Id).SingleOrDefaultAsync(ct)
        ?? throw ApiException.Forbidden("Client profile not found for the current user.");

    public async Task<Guid> TrainerIdAsync(CancellationToken ct) =>
        await db.TrainerProfiles.Where(t => t.UserId == user.Id).Select(t => (Guid?)t.Id).SingleOrDefaultAsync(ct)
        ?? throw ApiException.Forbidden("Trainer profile not found for the current user.");
}
