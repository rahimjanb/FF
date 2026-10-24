using FitnessFormulasi.Api.Domain;

namespace FitnessFormulasi.Api.Tests;

public class MembershipStatusCalculatorTests
{
    private static readonly DateOnly Start = new(2026, 6, 1);
    private static readonly DateOnly End = new(2026, 6, 30);

    [Theory]
    [InlineData("2026-05-31", MembershipStatus.Active, MembershipEffectiveStatus.Upcoming)]
    [InlineData("2026-06-01", MembershipStatus.Active, MembershipEffectiveStatus.Active)]
    [InlineData("2026-06-30", MembershipStatus.Active, MembershipEffectiveStatus.Active)] // end date is inclusive
    [InlineData("2026-07-01", MembershipStatus.Active, MembershipEffectiveStatus.Expired)]
    [InlineData("2026-06-15", MembershipStatus.Frozen, MembershipEffectiveStatus.Frozen)]
    [InlineData("2026-07-01", MembershipStatus.Frozen, MembershipEffectiveStatus.Expired)]
    [InlineData("2026-06-15", MembershipStatus.Cancelled, MembershipEffectiveStatus.Cancelled)]
    [InlineData("2026-07-01", MembershipStatus.Cancelled, MembershipEffectiveStatus.Cancelled)]
    public void Computes_status_from_dates(string today, MembershipStatus stored, MembershipEffectiveStatus expected) =>
        Assert.Equal(expected, MembershipStatusCalculator.Compute(stored, Start, End, DateOnly.Parse(today)));

    [Fact]
    public void Visit_limit_reached_is_exhausted_not_active()
    {
        var today = new DateOnly(2026, 6, 10);
        Assert.Equal(MembershipEffectiveStatus.Active, MembershipStatusCalculator.Compute(MembershipStatus.Active, Start, End, today, 8, 7));
        Assert.Equal(MembershipEffectiveStatus.Exhausted, MembershipStatusCalculator.Compute(MembershipStatus.Active, Start, End, today, 8, 8));
    }

    [Fact]
    public void Expired_is_never_active_even_with_active_stored_status() =>
        Assert.NotEqual(MembershipEffectiveStatus.Active,
            MembershipStatusCalculator.Compute(MembershipStatus.Active, Start, End, End.AddDays(1)));
}
