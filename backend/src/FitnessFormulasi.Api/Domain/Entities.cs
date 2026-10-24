namespace FitnessFormulasi.Api.Domain;

/// <summary>Base type for all persisted entities. Timestamps are maintained by AppDbContext.</summary>
public abstract class Entity
{
    public Guid Id { get; set; } = Guid.CreateVersion7();
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

public static class RoleNames
{
    public const string Admin = "Admin";
    public const string Trainer = "Trainer";
    public const string Client = "Client";
}

public class Role
{
    public int Id { get; set; }
    public required string Name { get; set; }
    public required string Description { get; set; }
    public ICollection<User> Users { get; set; } = [];
}

public enum UserStatus { Active, Blocked }

public class User : Entity
{
    /// <summary>E.164 phone number, e.g. +998901234567. Unique login identifier.</summary>
    public required string Phone { get; set; }
    public bool PhoneConfirmed { get; set; }
    public required string PasswordHash { get; set; }
    public required string FirstName { get; set; }
    public required string LastName { get; set; }
    public string? Email { get; set; }
    public UserStatus Status { get; set; } = UserStatus.Active;
    /// <summary>
    /// Set when staff assigned the password (account created or reset by an administrator).
    /// Until the user sets their own password, the API only allows changing it.
    /// </summary>
    public bool MustChangePassword { get; set; }
    public int AccessFailedCount { get; set; }
    public DateTimeOffset? LockoutEnd { get; set; }
    public DateTimeOffset? LastLoginAt { get; set; }

    public int RoleId { get; set; }
    public Role Role { get; set; } = null!;
    public ClientProfile? ClientProfile { get; set; }
    public TrainerProfile? TrainerProfile { get; set; }

    public string FullName => $"{FirstName} {LastName}".Trim();
}

public class RefreshToken : Entity
{
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;
    /// <summary>SHA-256 hash of the token; the raw token is never stored.</summary>
    public required string TokenHash { get; set; }
    public DateTimeOffset ExpiresAt { get; set; }
    public DateTimeOffset? RevokedAt { get; set; }
    public Guid? ReplacedByTokenId { get; set; }
}

public enum VerificationPurpose { PhoneConfirmation }

/// <summary>One-time code sent by SMS. Stage 1 only prepares the flow; delivery is via ISmsSender.</summary>
public class PhoneVerificationCode : Entity
{
    public required string Phone { get; set; }
    public VerificationPurpose Purpose { get; set; }
    public required string CodeHash { get; set; }
    public DateTimeOffset ExpiresAt { get; set; }
    public int Attempts { get; set; }
    public DateTimeOffset? ConsumedAt { get; set; }
}

public enum Gender { Male, Female }

public class ClientProfile : Entity
{
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;
    public DateOnly? BirthDate { get; set; }
    public Gender? Gender { get; set; }
    /// <summary>Internal staff note, never exposed to the client.</summary>
    public string? Notes { get; set; }

    public Guid? AssignedTrainerId { get; set; }
    public TrainerProfile? AssignedTrainer { get; set; }

    public ICollection<Membership> Memberships { get; set; } = [];
    public ICollection<Visit> Visits { get; set; } = [];
}

public class TrainerProfile : Entity
{
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;
    public string? Specialization { get; set; }
    public string? Bio { get; set; }
    public int? ExperienceYears { get; set; }
    public bool IsAcceptingClients { get; set; } = true;
    public bool IsActive { get; set; } = true;

    public ICollection<ClientProfile> Clients { get; set; } = [];
}

public enum MembershipPlanType { Unlimited, LimitedVisits }

public class MembershipPlan : Entity
{
    public required string Name { get; set; }
    public string? Description { get; set; }
    public MembershipPlanType Type { get; set; }
    public int DurationDays { get; set; }
    /// <summary>Only for LimitedVisits plans.</summary>
    public int? VisitLimit { get; set; }
    /// <summary>List price in UZS. Payments are out of scope for stage 1.</summary>
    public decimal Price { get; set; }
    public bool IsActive { get; set; } = true;
}

/// <summary>Status set by staff. The effective status also depends on dates, see MembershipStatusCalculator.</summary>
public enum MembershipStatus { Active, Frozen, Cancelled }

public enum MembershipEffectiveStatus { Upcoming, Active, Expired, Exhausted, Frozen, Cancelled }

public class Membership : Entity
{
    public Guid ClientProfileId { get; set; }
    public ClientProfile ClientProfile { get; set; } = null!;
    public Guid MembershipPlanId { get; set; }
    public MembershipPlan Plan { get; set; } = null!;

    /// <summary>First valid day, club-local date.</summary>
    public DateOnly StartDate { get; set; }
    /// <summary>Last valid day (inclusive), club-local date.</summary>
    public DateOnly EndDate { get; set; }
    public MembershipStatus Status { get; set; } = MembershipStatus.Active;
    /// <summary>Snapshot of the plan's visit limit at assignment time.</summary>
    public int? VisitLimit { get; set; }
    public Guid? CreatedByUserId { get; set; }
    /// <summary>Optimistic concurrency token (PostgreSQL xmin).</summary>
    public uint Version { get; set; }

    public ICollection<Visit> Visits { get; set; } = [];
}

public enum TrainerRequestStatus { Pending, Accepted, Rejected, Cancelled }

public class TrainerRequest : Entity
{
    public Guid ClientProfileId { get; set; }
    public ClientProfile ClientProfile { get; set; } = null!;
    public Guid TrainerProfileId { get; set; }
    public TrainerProfile TrainerProfile { get; set; } = null!;
    public TrainerRequestStatus Status { get; set; } = TrainerRequestStatus.Pending;
    public string? Message { get; set; }
    public string? ResponseComment { get; set; }
    public DateTimeOffset? RespondedAt { get; set; }
    public Guid? RespondedByUserId { get; set; }
    /// <summary>Optimistic concurrency token (PostgreSQL xmin).</summary>
    public uint Version { get; set; }
}

public enum TrainingSessionStatus { Scheduled, Completed, Cancelled }

public class TrainingSession : Entity
{
    public Guid TrainerProfileId { get; set; }
    public TrainerProfile TrainerProfile { get; set; } = null!;
    public Guid ClientProfileId { get; set; }
    public ClientProfile ClientProfile { get; set; } = null!;
    public DateTimeOffset StartsAt { get; set; }
    public int DurationMinutes { get; set; }
    public TrainingSessionStatus Status { get; set; } = TrainingSessionStatus.Scheduled;
    public string? Notes { get; set; }
}

/// <summary>Stage 1 source is manual entry by staff; turnstile integration comes in stage 2.</summary>
public enum VisitSource { Manual }

public class Visit : Entity
{
    public Guid ClientProfileId { get; set; }
    public ClientProfile ClientProfile { get; set; } = null!;
    public Guid? MembershipId { get; set; }
    public Membership? Membership { get; set; }
    public DateTimeOffset VisitedAt { get; set; }
    public VisitSource Source { get; set; } = VisitSource.Manual;
    public Guid? RecordedByUserId { get; set; }
}

public enum NotificationType { TrainerRequestReceived, TrainerRequestAccepted, TrainerRequestRejected, TrainingSessionScheduled, TrainingSessionCancelled, MembershipAssigned }

/// <summary>In-app notification. Text is localized by the client app from Type and Payload.</summary>
public class Notification : Entity
{
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;
    public NotificationType Type { get; set; }
    public Guid? RelatedEntityId { get; set; }
    /// <summary>Short display value for the template, e.g. trainer name or plan name.</summary>
    public string? Payload { get; set; }
    public DateTimeOffset? ReadAt { get; set; }
}
