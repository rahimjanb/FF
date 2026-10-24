using System.ComponentModel.DataAnnotations;

namespace FitnessFormulasi.Api.Auth;

public class JwtOptions
{
    public const string Section = "Jwt";

    [Required] public string Issuer { get; set; } = "fitness-formulasi";
    [Required] public string Audience { get; set; } = "fitness-formulasi-clients";

    /// <summary>HMAC-SHA256 key, at least 32 characters. Must come from secure configuration (env / user-secrets).</summary>
    [Required, MinLength(32)] public string SigningKey { get; set; } = "";

    [Range(1, 120)] public int AccessTokenMinutes { get; set; } = 15;
    [Range(1, 365)] public int RefreshTokenDays { get; set; } = 30;
}
