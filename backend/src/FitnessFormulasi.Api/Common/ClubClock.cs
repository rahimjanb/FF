namespace FitnessFormulasi.Api.Common;

public class ClubOptions
{
    public const string Section = "Club";
    /// <summary>IANA time zone of the club. All membership dates are club-local dates.</summary>
    public string TimeZoneId { get; set; } = "Asia/Tashkent";
}

/// <summary>Single source of "now" and "today" in the club's time zone.</summary>
public interface IClubClock
{
    DateTimeOffset UtcNow { get; }
    DateOnly Today { get; }
    TimeZoneInfo TimeZone { get; }
    DateOnly ToClubDate(DateTimeOffset instant);
    /// <summary>UTC instant at which the given club-local date starts.</summary>
    DateTimeOffset StartOfDayUtc(DateOnly date);
}

public sealed class ClubClock(TimeProvider timeProvider, Microsoft.Extensions.Options.IOptions<ClubOptions> options) : IClubClock
{
    public TimeZoneInfo TimeZone { get; } = TimeZoneInfo.FindSystemTimeZoneById(options.Value.TimeZoneId);
    public DateTimeOffset UtcNow => timeProvider.GetUtcNow();
    public DateOnly Today => ToClubDate(UtcNow);
    public DateOnly ToClubDate(DateTimeOffset instant) => DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(instant, TimeZone).DateTime);

    public DateTimeOffset StartOfDayUtc(DateOnly date)
    {
        var local = date.ToDateTime(TimeOnly.MinValue, DateTimeKind.Unspecified);
        return new DateTimeOffset(local, TimeZone.GetUtcOffset(local)).ToUniversalTime();
    }
}
