using System.ComponentModel.DataAnnotations;
using FitnessFormulasi.Api.Common;

namespace FitnessFormulasi.Api.Auth;

public class RegisterRequest
{
    [Required, PhoneE164] public string Phone { get; set; } = "";
    [Required, StrongPassword] public string Password { get; set; } = "";
    [Required, StringLength(64, MinimumLength = 1)] public string FirstName { get; set; } = "";
    [Required, StringLength(64, MinimumLength = 1)] public string LastName { get; set; } = "";
}

public class LoginRequest
{
    [Required, LoginPhone] public string Phone { get; set; } = "";
    [Required, StringLength(128)] public string Password { get; set; } = "";
}

public class RefreshRequest
{
    [Required, StringLength(256)] public string RefreshToken { get; set; } = "";
}

public class ChangePasswordRequest
{
    [Required, StringLength(128)] public string CurrentPassword { get; set; } = "";
    [Required, StrongPassword] public string NewPassword { get; set; } = "";
}

public class PhoneVerificationConfirmRequest
{
    [Required, RegularExpression(@"^\d{6}$")] public string Code { get; set; } = "";
}

public record AuthUserDto(
    Guid Id, string Phone, bool PhoneConfirmed, string FirstName, string LastName, string Role, bool MustChangePassword,
    bool CanManageIntegrations);

public record AuthResponse(string AccessToken, DateTimeOffset AccessTokenExpiresAt, string RefreshToken, DateTimeOffset RefreshTokenExpiresAt, AuthUserDto User);
