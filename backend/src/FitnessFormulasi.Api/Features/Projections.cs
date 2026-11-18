using System.Linq.Expressions;
using FitnessFormulasi.Api.Domain;

namespace FitnessFormulasi.Api.Features;

/// <summary>EF-translatable projections shared by all controllers, so DTO shapes stay consistent.</summary>
public static class Projections
{
    /// <summary>Raw membership row with its latest freeze; effective status is computed in memory against the club date.</summary>
    public record MembershipRow(
        Guid Id, Guid ClientId, string ClientFirstName, string ClientLastName, Guid PlanId, string PlanName,
        MembershipPlanType PlanType, DateOnly StartDate, DateOnly EndDate, MembershipStatus Status,
        int? VisitLimit, int VisitsUsed, DateTimeOffset CreatedAt, DateOnly? FreezeStart, DateOnly? FreezeEnd,
        int PlanDurationDays, int FreezesUsed)
    {
        public MembershipDto ToDto(DateOnly today)
        {
            var frozenToday = FreezeStart <= today && today <= FreezeEnd;
            var effective = MembershipStatusCalculator.Compute(Status, StartDate, EndDate, today, VisitLimit, VisitsUsed, frozenToday);
            var daysLeft = effective is MembershipEffectiveStatus.Active or MembershipEffectiveStatus.Frozen or MembershipEffectiveStatus.Upcoming
                ? EndDate.DayNumber - Math.Max(today.DayNumber, StartDate.DayNumber) + 1
                : 0;
            // Only a current or upcoming freeze is shown; past ones are already part of the end date.
            var showFreeze = FreezeEnd >= today && Status != MembershipStatus.Cancelled;
            return new MembershipDto(Id, ClientId, $"{ClientFirstName} {ClientLastName}".Trim(), PlanId, PlanName, PlanType,
                StartDate, EndDate, Status, effective, VisitLimit, VisitsUsed, daysLeft, CreatedAt,
                showFreeze ? FreezeStart : null, showFreeze ? FreezeEnd : null,
                MembershipService.FreezesAllowed(PlanDurationDays), FreezesUsed);
        }
    }

    public static readonly Expression<Func<Membership, MembershipRow>> MembershipRowExpr = m => new MembershipRow(
        m.Id, m.ClientProfileId, m.ClientProfile.User.FirstName, m.ClientProfile.User.LastName, m.MembershipPlanId,
        m.Plan.Name, m.Plan.Type, m.StartDate, m.EndDate, m.Status, m.VisitLimit, m.Visits.Count(), m.CreatedAt,
        m.Freezes.OrderByDescending(f => f.StartDate).Select(f => (DateOnly?)f.StartDate).FirstOrDefault(),
        m.Freezes.OrderByDescending(f => f.StartDate).Select(f => (DateOnly?)f.EndDate).FirstOrDefault(),
        m.Plan.DurationDays, m.Freezes.Count());

    public static readonly Expression<Func<MembershipRequest, MembershipRequestDto>> MembershipRequestExpr = r => new MembershipRequestDto(
        r.Id, r.Kind, r.Status, r.ResponseComment, r.CreatedAt, r.RespondedAt, r.MembershipId,
        new MembershipPlanDto(r.Plan.Id, r.Plan.Name, r.Plan.Description, r.Plan.Type, r.Plan.DurationDays, r.Plan.VisitLimit, r.Plan.Price, r.Plan.IsActive),
        new PersonRef(r.ClientProfileId, r.ClientProfile.User.FirstName, r.ClientProfile.User.LastName),
        r.ClientProfile.User.Phone);

    public static readonly Expression<Func<MembershipPlan, MembershipPlanDto>> Plan = p => new MembershipPlanDto(
        p.Id, p.Name, p.Description, p.Type, p.DurationDays, p.VisitLimit, p.Price, p.IsActive);

    public static readonly Expression<Func<TrainerProfile, TrainerPublicDto>> TrainerPublic = t => new TrainerPublicDto(
        t.Id, t.User.FirstName, t.User.LastName, t.Specialization, t.Bio, t.ExperienceYears, t.IsAcceptingClients, t.PhotoVersion);

    /// <summary>The client's own trainer, with Telegram and Instagram.</summary>
    public static readonly Expression<Func<TrainerProfile, TrainerPublicDto>> TrainerWithContacts = t => new TrainerPublicDto(
        t.Id, t.User.FirstName, t.User.LastName, t.Specialization, t.Bio, t.ExperienceYears, t.IsAcceptingClients, t.PhotoVersion,
        t.Telegram, t.Instagram);

    public static readonly Expression<Func<TrainerProfile, TrainerAdminDto>> TrainerAdmin = t => new TrainerAdminDto(
        t.Id, t.UserId, t.User.Phone, t.User.FirstName, t.User.LastName, t.Specialization, t.Bio, t.ExperienceYears,
        t.IsAcceptingClients, t.IsActive, t.User.Status, t.Clients.Count(), t.CreatedAt, t.PhotoVersion, t.Telegram, t.Instagram);

    public static readonly Expression<Func<TrainerRequest, TrainerRequestDto>> Request = r => new TrainerRequestDto(
        r.Id, r.Status, r.Message, r.ResponseComment, r.CreatedAt, r.RespondedAt,
        new PersonRef(r.TrainerProfileId, r.TrainerProfile.User.FirstName, r.TrainerProfile.User.LastName),
        new PersonRef(r.ClientProfileId, r.ClientProfile.User.FirstName, r.ClientProfile.User.LastName),
        r.TrainerProfile.Telegram, r.TrainerProfile.Instagram);

    public static readonly Expression<Func<TrainingSession, TrainingSessionDto>> Session = s => new TrainingSessionDto(
        s.Id, s.StartsAt, s.DurationMinutes, s.Status, s.Notes,
        new PersonRef(s.TrainerProfileId, s.TrainerProfile.User.FirstName, s.TrainerProfile.User.LastName),
        new PersonRef(s.ClientProfileId, s.ClientProfile.User.FirstName, s.ClientProfile.User.LastName));

    public static readonly Expression<Func<Visit, VisitDto>> VisitExpr = v => new VisitDto(
        v.Id, v.VisitedAt, v.Source, v.ClientProfileId, v.ClientProfile.User.FirstName + " " + v.ClientProfile.User.LastName, v.MembershipId);

    public static readonly Expression<Func<Notification, NotificationDto>> NotificationExpr = n => new NotificationDto(
        n.Id, n.Type, n.RelatedEntityId, n.Payload, n.ReadAt != null, n.CreatedAt);
}
