using System.ComponentModel.DataAnnotations;
using System.Text.RegularExpressions;

namespace FitnessFormulasi.Api.Common;

public static partial class PhoneNumber
{
    /// <summary>
    /// Normalizes to E.164. Accepts "+998 90 123-45-67", "998901234567" or a 9-digit local Uzbek number.
    /// Returns null if the input is not a valid phone number.
    /// </summary>
    public static string? Normalize(string? input)
    {
        if (string.IsNullOrWhiteSpace(input)) return null;
        var trimmed = input.Trim();
        var hasPlus = trimmed.StartsWith('+');
        var digits = NonDigits().Replace(trimmed, "");
        if (!hasPlus)
        {
            if (digits.Length == 9) digits = "998" + digits;
            else if (!(digits.Length == 12 && digits.StartsWith("998"))) return null;
        }
        if (digits.StartsWith("998") && digits.Length != 12) return null;
        return digits.Length is >= 10 and <= 15 ? "+" + digits : null;
    }

    [GeneratedRegex(@"\D")]
    private static partial Regex NonDigits();
}

[AttributeUsage(AttributeTargets.Property)]
public sealed class PhoneE164Attribute : ValidationAttribute
{
    protected override ValidationResult? IsValid(object? value, ValidationContext context) =>
        value is null || PhoneNumber.Normalize(value as string) is not null
            ? ValidationResult.Success
            : new ValidationResult("Invalid phone number.", [context.MemberName!]);
}

[AttributeUsage(AttributeTargets.Property)]
public sealed class StrongPasswordAttribute : ValidationAttribute
{
    protected override ValidationResult? IsValid(object? value, ValidationContext context)
    {
        if (value is not string s) return ValidationResult.Success;
        var ok = s.Length is >= 8 and <= 128 && s.Any(char.IsLetter) && s.Any(char.IsDigit);
        return ok
            ? ValidationResult.Success
            : new ValidationResult("Password must be 8-128 characters and contain letters and digits.", [context.MemberName!]);
    }
}

[AttributeUsage(AttributeTargets.Property)]
public sealed class PastDateAttribute : ValidationAttribute
{
    protected override ValidationResult? IsValid(object? value, ValidationContext context) =>
        value is not DateOnly d || (d < DateOnly.FromDateTime(DateTime.UtcNow) && d.Year >= 1900)
            ? ValidationResult.Success
            : new ValidationResult("Date must be in the past.", [context.MemberName!]);
}
