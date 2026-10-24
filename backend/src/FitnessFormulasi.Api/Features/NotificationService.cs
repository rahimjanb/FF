using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;

namespace FitnessFormulasi.Api.Features;

/// <summary>In-app notifications only. Push delivery is out of scope for stage 1.</summary>
public sealed class NotificationService(AppDbContext db)
{
    /// <summary>Adds a notification to the current unit of work; the caller saves.</summary>
    public void Add(Guid userId, NotificationType type, Guid? relatedId, string? payload) =>
        db.Notifications.Add(new Notification { UserId = userId, Type = type, RelatedEntityId = relatedId, Payload = payload });
}
