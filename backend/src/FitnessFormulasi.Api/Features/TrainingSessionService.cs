using System.ComponentModel.DataAnnotations;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Features;

public class CreateTrainingSessionRequest
{
    [Required] public Guid ClientId { get; set; }
    [Required] public DateTimeOffset StartsAt { get; set; }
    [Range(15, 480)] public int DurationMinutes { get; set; } = 60;
    [StringLength(1000)] public string? Notes { get; set; }
}

public sealed class TrainingSessionService(AppDbContext db, IClubClock clock, NotificationService notifications)
{
    public async Task<TrainingSessionDto> CreateAsync(Guid trainerId, CreateTrainingSessionRequest req, CancellationToken ct)
    {
        var client = await db.ClientProfiles.SingleOrDefaultAsync(c => c.Id == req.ClientId && c.AssignedTrainerId == trainerId, ct)
                     ?? throw ApiException.NotFound("Client"); // trainers only schedule their own clients
        var startsAt = req.StartsAt.ToUniversalTime();
        if (startsAt <= clock.UtcNow)
            throw ApiException.BadRequest("start_in_past", "The session must start in the future.");

        var endsAt = startsAt.AddMinutes(req.DurationMinutes);
        var overlap = await db.TrainingSessions.AnyAsync(s => s.TrainerProfileId == trainerId && s.Status == TrainingSessionStatus.Scheduled
                                                              && s.StartsAt < endsAt && s.StartsAt.AddMinutes(s.DurationMinutes) > startsAt, ct);
        if (overlap)
            throw ApiException.Conflict("session_overlap", "The trainer already has a session at this time.");

        var session = new TrainingSession
        {
            TrainerProfileId = trainerId,
            ClientProfileId = client.Id,
            StartsAt = startsAt,
            DurationMinutes = req.DurationMinutes,
            Notes = string.IsNullOrWhiteSpace(req.Notes) ? null : req.Notes.Trim(),
        };
        db.TrainingSessions.Add(session);
        notifications.Add(client.UserId, NotificationType.TrainingSessionScheduled, session.Id, null);
        await db.SaveChangesAsync(ct);
        return await GetAsync(session.Id, ct);
    }

    public async Task<TrainingSessionDto> SetStatusAsync(Guid trainerId, Guid sessionId, TrainingSessionStatus status, CancellationToken ct)
    {
        var session = await db.TrainingSessions.Include(s => s.ClientProfile)
                          .SingleOrDefaultAsync(s => s.Id == sessionId && s.TrainerProfileId == trainerId, ct)
                      ?? throw ApiException.NotFound("Training session");
        if (session.Status != TrainingSessionStatus.Scheduled)
            throw ApiException.Conflict("session_not_scheduled", "Only scheduled sessions can be changed.");
        if (status == TrainingSessionStatus.Completed && session.StartsAt > clock.UtcNow)
            throw ApiException.BadRequest("session_not_started", "A session cannot be completed before it starts.");

        session.Status = status;
        if (status == TrainingSessionStatus.Cancelled)
            notifications.Add(session.ClientProfile.UserId, NotificationType.TrainingSessionCancelled, session.Id, null);
        await db.SaveChangesAsync(ct);
        return await GetAsync(sessionId, ct);
    }

    public async Task<TrainingSessionDto> GetAsync(Guid id, CancellationToken ct) =>
        await db.TrainingSessions.Where(s => s.Id == id).Select(Projections.Session).SingleOrDefaultAsync(ct)
        ?? throw ApiException.NotFound("Training session");
}
