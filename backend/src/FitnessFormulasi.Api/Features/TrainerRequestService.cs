using System.ComponentModel.DataAnnotations;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace FitnessFormulasi.Api.Features;

public class CreateTrainerRequest
{
    [Required] public Guid TrainerId { get; set; }
    [StringLength(500)] public string? Message { get; set; }
}

public class RespondTrainerRequest
{
    [StringLength(500)] public string? Comment { get; set; }
}

public sealed class TrainerRequestService(AppDbContext db, ICurrentUser currentUser, IClubClock clock, NotificationService notifications)
{
    public async Task<TrainerRequestDto> CreateAsync(Guid clientId, CreateTrainerRequest req, CancellationToken ct)
    {
        var trainer = await db.TrainerProfiles.Include(t => t.User).SingleOrDefaultAsync(t => t.Id == req.TrainerId, ct);
        if (trainer is null || !trainer.IsActive || trainer.User.Status != UserStatus.Active)
            throw ApiException.NotFound("Trainer");
        if (!trainer.IsAcceptingClients)
            throw ApiException.Conflict("trainer_not_accepting", "The trainer is not accepting new clients.");

        var client = await db.ClientProfiles.SingleAsync(c => c.Id == clientId, ct);
        if (client.AssignedTrainerId == trainer.Id)
            throw ApiException.Conflict("already_assigned", "This trainer is already assigned to you.");
        if (await db.TrainerRequests.AnyAsync(r => r.ClientProfileId == clientId && r.TrainerProfileId == trainer.Id
                                                   && r.Status == TrainerRequestStatus.Pending, ct))
            throw DuplicateRequest();

        var request = new TrainerRequest
        {
            ClientProfileId = clientId,
            TrainerProfileId = trainer.Id,
            Message = string.IsNullOrWhiteSpace(req.Message) ? null : req.Message.Trim(),
        };
        db.TrainerRequests.Add(request);
        notifications.Add(trainer.UserId, NotificationType.TrainerRequestReceived, request.Id, null);
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException e) when (e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            throw DuplicateRequest(); // concurrent duplicate caught by the partial unique index
        }
        return await GetAsync(request.Id, ct);
    }

    public async Task<TrainerRequestDto> CancelByClientAsync(Guid clientId, Guid requestId, CancellationToken ct)
    {
        var request = await db.TrainerRequests.SingleOrDefaultAsync(r => r.Id == requestId && r.ClientProfileId == clientId, ct)
                      ?? throw ApiException.NotFound("Trainer request");
        EnsurePending(request);
        request.Status = TrainerRequestStatus.Cancelled;
        request.RespondedAt = clock.UtcNow;
        request.RespondedByUserId = currentUser.Id;
        await db.SaveChangesAsync(ct);
        return await GetAsync(requestId, ct);
    }

    /// <summary>
    /// Accepts or rejects a request. When <paramref name="trainerId"/> is set (trainer cabinet), the request must
    /// belong to that trainer; otherwise the caller is an admin.
    /// </summary>
    public async Task<TrainerRequestDto> RespondAsync(Guid requestId, bool accept, string? comment, Guid? trainerId, CancellationToken ct)
    {
        var request = await db.TrainerRequests
            .Include(r => r.ClientProfile)
            .Include(r => r.TrainerProfile).ThenInclude(t => t.User)
            .SingleOrDefaultAsync(r => r.Id == requestId && (trainerId == null || r.TrainerProfileId == trainerId), ct)
            ?? throw ApiException.NotFound("Trainer request");
        EnsurePending(request);

        var now = clock.UtcNow;
        request.Status = accept ? TrainerRequestStatus.Accepted : TrainerRequestStatus.Rejected;
        request.ResponseComment = string.IsNullOrWhiteSpace(comment) ? null : comment.Trim();
        request.RespondedAt = now;
        request.RespondedByUserId = currentUser.Id;

        if (accept)
        {
            request.ClientProfile.AssignedTrainerId = request.TrainerProfileId;
            // A client has one trainer: other pending requests of this client are closed automatically.
            var others = await db.TrainerRequests.Where(r => r.ClientProfileId == request.ClientProfileId && r.Id != request.Id
                                                             && r.Status == TrainerRequestStatus.Pending).ToListAsync(ct);
            foreach (var other in others)
            {
                other.Status = TrainerRequestStatus.Cancelled;
                other.RespondedAt = now;
                other.ResponseComment = "Closed automatically: another trainer was assigned.";
            }
        }
        notifications.Add(request.ClientProfile.UserId,
            accept ? NotificationType.TrainerRequestAccepted : NotificationType.TrainerRequestRejected,
            request.Id, request.TrainerProfile.User.FullName);
        await db.SaveChangesAsync(ct);
        return await GetAsync(requestId, ct);
    }

    public async Task<TrainerRequestDto> GetAsync(Guid id, CancellationToken ct) =>
        await db.TrainerRequests.Where(r => r.Id == id).Select(Projections.Request).SingleOrDefaultAsync(ct)
        ?? throw ApiException.NotFound("Trainer request");

    private static void EnsurePending(TrainerRequest r)
    {
        if (r.Status != TrainerRequestStatus.Pending)
            throw ApiException.Conflict("request_not_pending", "The request has already been processed.");
    }

    private static ApiException DuplicateRequest() =>
        ApiException.Conflict("duplicate_request", "You already have a pending request to this trainer.");
}
