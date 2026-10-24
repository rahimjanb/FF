namespace FitnessFormulasi.Api.Domain;

public static class MembershipStatusCalculator
{
    /// <summary>
    /// Effective status for a given club-local date. A membership past its EndDate is never Active,
    /// regardless of the stored status.
    /// </summary>
    public static MembershipEffectiveStatus Compute(
        MembershipStatus status, DateOnly startDate, DateOnly endDate, DateOnly today,
        int? visitLimit = null, int visitsUsed = 0)
    {
        if (status == MembershipStatus.Cancelled) return MembershipEffectiveStatus.Cancelled;
        if (today > endDate) return MembershipEffectiveStatus.Expired;
        if (status == MembershipStatus.Frozen) return MembershipEffectiveStatus.Frozen;
        if (today < startDate) return MembershipEffectiveStatus.Upcoming;
        if (visitLimit.HasValue && visitsUsed >= visitLimit.Value) return MembershipEffectiveStatus.Exhausted;
        return MembershipEffectiveStatus.Active;
    }
}
