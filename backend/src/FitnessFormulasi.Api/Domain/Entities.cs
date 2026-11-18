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

/// <summary>Deleted: a client erased their account (or the club did on their request); see <c>AccountDeletionService</c>. Final.</summary>
public enum UserStatus { Active, Blocked, Deleted }

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
    /// <summary>Administrator allowed to view and change payment integration settings (Click, Payme).</summary>
    public bool CanManageIntegrations { get; set; }
    public int AccessFailedCount { get; set; }
    public DateTimeOffset? LockoutEnd { get; set; }
    public DateTimeOffset? LastLoginAt { get; set; }
    /// <summary>When the account was deleted; personal data is gone, the record stays for memberships and visits.</summary>
    public DateTimeOffset? DeletedAt { get; set; }

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
    /// <summary>The client chose to train on their own. Cleared when a trainer is assigned.</summary>
    public bool WithoutTrainer { get; set; }
    /// <summary>Person number on the face recognition terminals, assigned with the first face photo (sequence from 1001).</summary>
    public int? AccessNo { get; set; }

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
    /// <summary>Bumped on every photo change; 0 means no photo. Part of the photo URL so clients can cache it.</summary>
    public int PhotoVersion { get; set; }
    /// <summary>Telegram username without "@". A client sees it after sending a request to the trainer.</summary>
    public string? Telegram { get; set; }
    /// <summary>Instagram username without "@". A client sees it after sending a request to the trainer.</summary>
    public string? Instagram { get; set; }

    public ICollection<ClientProfile> Clients { get; set; } = [];
}

/// <summary>Trainer photo bytes, kept apart from the profile so profile queries never load them.</summary>
public class TrainerPhoto
{
    public Guid TrainerProfileId { get; set; }
    public required byte[] Data { get; set; }
    public required string ContentType { get; set; }
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
    public ICollection<MembershipFreeze> Freezes { get; set; } = [];
}

/// <summary>
/// Freeze period set by the client in the app or by staff (club-local dates, inclusive). The membership EndDate is
/// moved forward by its length when it is created and back by the unused days when it is ended early. At most one
/// freeze per membership may be current or upcoming, so the latest one describes the freeze state. Every row counts
/// towards the freeze limit (see MembershipService.FreezesAllowed); a planned freeze cancelled before it started is deleted.
/// </summary>
public class MembershipFreeze : Entity
{
    public Guid MembershipId { get; set; }
    public Membership Membership { get; set; } = null!;
    public DateOnly StartDate { get; set; }
    public DateOnly EndDate { get; set; }
    public Guid? CreatedByUserId { get; set; }
}

/// <summary>New = the client has no membership yet; Renew = the same plan after the current one; Change = another plan.</summary>
public enum MembershipRequestKind { New, Renew, Change }

public enum MembershipRequestStatus { Pending, Completed, Rejected, Cancelled }

/// <summary>
/// A client asks for a membership from the app; staff take the payment at the desk and complete the request,
/// which assigns the membership. Online payment is stage 2.
/// </summary>
public class MembershipRequest : Entity
{
    public Guid ClientProfileId { get; set; }
    public ClientProfile ClientProfile { get; set; } = null!;
    public Guid MembershipPlanId { get; set; }
    public MembershipPlan Plan { get; set; } = null!;
    public MembershipRequestKind Kind { get; set; }
    public MembershipRequestStatus Status { get; set; } = MembershipRequestStatus.Pending;
    public string? ResponseComment { get; set; }
    public DateTimeOffset? RespondedAt { get; set; }
    public Guid? RespondedByUserId { get; set; }
    /// <summary>The membership assigned when the request was completed.</summary>
    public Guid? MembershipId { get; set; }
    /// <summary>Optimistic concurrency token (PostgreSQL xmin).</summary>
    public uint Version { get; set; }
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

/// <summary>Manual entry by staff, the client's QR pass scanned at the desk, or a pass through the face recognition terminal.</summary>
public enum VisitSource { Manual, QrScan, FaceTerminal }

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

public enum NotificationType
{
    TrainerRequestReceived, TrainerRequestAccepted, TrainerRequestRejected, TrainingSessionScheduled, TrainingSessionCancelled,
    MembershipAssigned, MembershipFrozen, MembershipUnfrozen, MembershipRequestRejected,
}

/// <summary>Promo banner at the top of the client app home screen; tapping it opens the title, text and media.</summary>
public class Banner : Entity
{
    public required string Title { get; set; }
    public string? Description { get; set; }
    /// <summary>Hidden banners stay in the admin panel but are not shown in the app.</summary>
    public bool IsActive { get; set; } = true;
    /// <summary>Position in the app carousel, ascending.</summary>
    public int SortOrder { get; set; }

    public ICollection<BannerMedia> Media { get; set; } = [];
}

public enum BannerMediaKind { Image, Video }

/// <summary>
/// Photo or video of a banner, in display order; the first photo is the banner cover. The file itself is kept
/// by <c>MediaStorage</c> under the media id, not in the database.
/// </summary>
public class BannerMedia : Entity
{
    public Guid BannerId { get; set; }
    public Banner Banner { get; set; } = null!;
    public BannerMediaKind Kind { get; set; }
    public required string ContentType { get; set; }
    public long SizeBytes { get; set; }
    public int SortOrder { get; set; }
}

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
