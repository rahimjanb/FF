using FitnessFormulasi.Api.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace FitnessFormulasi.Api.Auth;

[ApiController]
[Route("api/auth")]
[Produces("application/json")]
public class AuthController(AuthService auth, TokenService tokens, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Registers a new club client by phone number and password.</summary>
    [HttpPost("register")]
    [AllowAnonymous, EnableRateLimiting(RateLimits.Auth)]
    public Task<AuthResponse> Register(RegisterRequest req, CancellationToken ct) => auth.RegisterClientAsync(req, ct);

    /// <summary>Signs in any role (client, trainer, admin) by phone number and password.</summary>
    [HttpPost("login")]
    [AllowAnonymous, EnableRateLimiting(RateLimits.Auth)]
    public Task<AuthResponse> Login(LoginRequest req, CancellationToken ct) => auth.LoginAsync(req, ct);

    /// <summary>Exchanges a refresh token for a new token pair (rotation).</summary>
    [HttpPost("refresh")]
    [AllowAnonymous, EnableRateLimiting(RateLimits.Auth)]
    public Task<AuthResponse> Refresh(RefreshRequest req, CancellationToken ct) => auth.RefreshAsync(req.RefreshToken, ct);

    [HttpPost("logout")]
    [Authorize, AllowWithPendingPasswordChange]
    public async Task<IActionResult> Logout(RefreshRequest req, CancellationToken ct)
    {
        await tokens.RevokeAsync(req.RefreshToken, currentUser.Id, ct);
        return NoContent();
    }

    [HttpGet("me")]
    [Authorize, AllowWithPendingPasswordChange]
    public Task<AuthUserDto> Me(CancellationToken ct) => auth.GetUserAsync(currentUser.Id, ct);

    /// <summary>Changes the password and returns a new token pair; other sessions are signed out.</summary>
    [HttpPost("change-password")]
    [Authorize, EnableRateLimiting(RateLimits.Auth), AllowWithPendingPasswordChange]
    public Task<AuthResponse> ChangePassword(ChangePasswordRequest req, CancellationToken ct) =>
        auth.ChangePasswordAsync(currentUser.Id, req, ct);

    /// <summary>Sends a confirmation code by SMS. Returns 503 until an SMS provider is connected (stage 2).</summary>
    [HttpPost("phone-verification/request")]
    [Authorize, EnableRateLimiting(RateLimits.Auth)]
    public async Task<IActionResult> RequestPhoneVerification(CancellationToken ct)
    {
        await auth.RequestPhoneVerificationAsync(currentUser.Id, ct);
        return Accepted();
    }

    [HttpPost("phone-verification/confirm")]
    [Authorize, EnableRateLimiting(RateLimits.Auth)]
    public async Task<IActionResult> ConfirmPhone(PhoneVerificationConfirmRequest req, CancellationToken ct)
    {
        await auth.ConfirmPhoneAsync(currentUser.Id, req.Code, ct);
        return NoContent();
    }
}

public static class RateLimits
{
    public const string Auth = "auth";
}
