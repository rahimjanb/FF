using FitnessFormulasi.Api.Domain;

namespace FitnessFormulasi.Api.Features;

public record PersonRef(Guid Id, string FirstName, string LastName);

public record MembershipPlanDto(
    Guid Id, string Name, string? Description, MembershipPlanType Type, int DurationDays, int? VisitLimit,
    decimal Price, bool IsActive);

public record MembershipDto(
    Guid Id, Guid ClientId, string ClientName, Guid PlanId, string PlanName, MembershipPlanType PlanType,
    DateOnly StartDate, DateOnly EndDate, MembershipStatus Status, MembershipEffectiveStatus EffectiveStatus,
    int? VisitLimit, int VisitsUsed, int DaysLeft, DateTimeOffset CreatedAt,
    DateOnly? FreezeStartDate = null, DateOnly? FreezeEndDate = null,
    // Freezes this membership may have in total (0: the plan is shorter than six months) and those already used.
    int FreezesAllowed = 0, int FreezesUsed = 0);

public record MembershipRequestDto(
    Guid Id, MembershipRequestKind Kind, MembershipRequestStatus Status, string? ResponseComment,
    DateTimeOffset CreatedAt, DateTimeOffset? RespondedAt, Guid? MembershipId, MembershipPlanDto Plan,
    PersonRef Client, string ClientPhone);

/// <summary>
/// <c>Telegram</c> and <c>Instagram</c> are filled only for the client's own trainer; the public directory has none.
/// A client gets them for other trainers with their request (<see cref="TrainerRequestDto"/>).
/// </summary>
public record TrainerPublicDto(
    Guid Id, string FirstName, string LastName, string? Specialization, string? Bio, int? ExperienceYears,
    bool IsAcceptingClients, int PhotoVersion, string? Telegram = null, string? Instagram = null)
{
    /// <summary>Relative URL of the photo, or null when there is none.</summary>
    public string? PhotoUrl => TrainerPhotoUrl.For(Id, PhotoVersion);
}

public record TrainerAdminDto(
    Guid Id, Guid UserId, string Phone, string FirstName, string LastName, string? Specialization, string? Bio,
    int? ExperienceYears, bool IsAcceptingClients, bool IsActive, UserStatus UserStatus, int ClientsCount,
    DateTimeOffset CreatedAt, int PhotoVersion, string? Telegram = null, string? Instagram = null)
{
    public string? PhotoUrl => TrainerPhotoUrl.For(Id, PhotoVersion);
}

public static class TrainerPhotoUrl
{
    /// <summary>The version in the query makes the URL change with the photo, so it can be cached for long.</summary>
    public static string? For(Guid trainerId, int version) =>
        version == 0 ? null : $"/api/trainers/{trainerId}/photo?v={version}";
}

public record ClientAdminDto(
    Guid Id, Guid UserId, string Phone, bool PhoneConfirmed, string FirstName, string LastName, string? Email,
    DateOnly? BirthDate, Gender? Gender, string? Notes, UserStatus Status, PersonRef? AssignedTrainer,
    MembershipDto? CurrentMembership, DateTimeOffset CreatedAt, bool WithoutTrainer = false, DateTimeOffset? DeletedAt = null);

/// <summary>What a trainer may see about an assigned client. Excludes internal staff notes.</summary>
public record TrainerClientDto(
    Guid Id, string FirstName, string LastName, string Phone, DateOnly? BirthDate, Gender? Gender,
    MembershipDto? CurrentMembership, DateTimeOffset? LastVisitAt);

public record ClientProfileDto(
    Guid Id, string Phone, bool PhoneConfirmed, string FirstName, string LastName, string? Email,
    DateOnly? BirthDate, Gender? Gender, TrainerPublicDto? AssignedTrainer, DateTimeOffset MemberSince,
    bool WithoutTrainer = false);

/// <summary>The trainer's Telegram and Instagram let the client contact them once the request is sent.</summary>
public record TrainerRequestDto(
    Guid Id, TrainerRequestStatus Status, string? Message, string? ResponseComment,
    DateTimeOffset CreatedAt, DateTimeOffset? RespondedAt, PersonRef Trainer, PersonRef Client,
    string? TrainerTelegram = null, string? TrainerInstagram = null);

public record TrainingSessionDto(
    Guid Id, DateTimeOffset StartsAt, int DurationMinutes, TrainingSessionStatus Status, string? Notes,
    PersonRef Trainer, PersonRef Client);

public record VisitDto(Guid Id, DateTimeOffset VisitedAt, VisitSource Source, Guid ClientId, string ClientName, Guid? MembershipId);

public record NotificationDto(Guid Id, NotificationType Type, Guid? RelatedEntityId, string? Payload, bool IsRead, DateTimeOffset CreatedAt);

/// <summary><c>RefreshInSeconds</c> is relative, so the app's countdown does not depend on the phone's clock.</summary>
public record PassDto(string Code, DateTimeOffset ExpiresAt, DateTimeOffset RefreshAt, int RefreshInSeconds, DateTimeOffset? LastVisitAt);

/// <summary>Pending requests carry what staff need to complete them: the client's current membership and the default start.</summary>
public record MembershipRequestAdminDto(MembershipRequestDto Request, MembershipDto? CurrentMembership, DateOnly? SuggestedStartDate);

public record VisitStatsDto(int ThisMonth, int Total, DateTimeOffset? LastVisitAt);

public record ClientDashboardDto(
    string FirstName, MembershipDto? CurrentMembership, MembershipDto? NextMembership,
    TrainingSessionDto? NextSession, TrainerPublicDto? Trainer, VisitStatsDto Visits,
    TrainerRequestDto? PendingTrainerRequest, int UnreadNotifications, bool WithoutTrainer = false);
