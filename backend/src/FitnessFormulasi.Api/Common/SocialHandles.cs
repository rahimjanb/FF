using System.Text.RegularExpressions;

namespace FitnessFormulasi.Api.Common;

/// <summary>
/// Telegram and Instagram usernames. Staff may paste "@name", "name" or a profile link; only the username is stored,
/// and the apps build the links (https://t.me/name, https://instagram.com/name).
/// </summary>
public static partial class SocialHandles
{
    [GeneratedRegex("^[A-Za-z][A-Za-z0-9_]{4,31}$")]
    private static partial Regex TelegramRx();

    [GeneratedRegex(@"^(?!.*\.\.)(?!\.)(?!.*\.$)[A-Za-z0-9._]{1,30}$")]
    private static partial Regex InstagramRx();

    /// <summary>Username or null for an empty value; throws <c>invalid_telegram</c> for anything else.</summary>
    public static string? Telegram(string? raw) =>
        Normalize(raw, ["t.me/", "telegram.me/", "telegram.dog/"], TelegramRx(), "invalid_telegram",
            "Telegram: 5–32 Latin letters, digits or underscores, e.g. @coach_aziz.");

    /// <summary>Username or null for an empty value; throws <c>invalid_instagram</c> for anything else.</summary>
    public static string? Instagram(string? raw) =>
        Normalize(raw, ["instagram.com/", "instagr.am/"], InstagramRx(), "invalid_instagram",
            "Instagram: up to 30 Latin letters, digits, dots or underscores, e.g. @coach.aziz.");

    private static string? Normalize(string? raw, string[] hosts, Regex valid, string code, string message)
    {
        var s = raw?.Trim();
        if (string.IsNullOrEmpty(s)) return null;
        foreach (var scheme in new[] { "https://", "http://" })
            if (s.StartsWith(scheme, StringComparison.OrdinalIgnoreCase)) s = s[scheme.Length..];
        if (s.StartsWith("www.", StringComparison.OrdinalIgnoreCase)) s = s[4..];
        foreach (var host in hosts)
            if (s.StartsWith(host, StringComparison.OrdinalIgnoreCase)) s = s[host.Length..];
        s = s.Split('?', '#')[0].TrimEnd('/').TrimStart('@');
        return valid.IsMatch(s) ? s : throw ApiException.BadRequest(code, message);
    }
}
