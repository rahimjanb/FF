using System.Security.Cryptography;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Auth;

public sealed class AuthService(
    AppDbContext db, TokenService tokens, IPasswordHasher<User> hasher, ISmsSender sms,
    TimeProvider time, ILogger<AuthService> logger, DevLogins? devLogins = null)
{
    public const int MaxFailedAttempts = 5;
    public static readonly TimeSpan LockoutDuration = TimeSpan.FromMinutes(15);
    private static readonly TimeSpan CodeLifetime = TimeSpan.FromMinutes(5);
    private const int MaxCodeAttempts = 5;

    public async Task<AuthResponse> RegisterClientAsync(RegisterRequest req, CancellationToken ct)
    {
        var phone = PhoneNumber.Normalize(req.Phone)!;
        if (await db.Users.AnyAsync(u => u.Phone == phone, ct))
            throw ApiException.Conflict("phone_taken", "A user with this phone number already exists.");

        var user = await CreateUserAsync(phone, req.Password, req.FirstName, req.LastName, RoleNames.Client, ct);
        db.ClientProfiles.Add(new ClientProfile { UserId = user.Id });
        await db.SaveChangesAsync(ct);
        logger.LogInformation("Client {UserId} registered", user.Id);
        return await IssueAsync(user, ct);
    }

    /// <summary>
    /// Creates a user with a hashed password. Caller adds the role-specific profile and saves.
    /// <paramref name="assignedByStaff"/> marks a temporary password the user must change at first sign-in.
    /// </summary>
    public async Task<User> CreateUserAsync(string phone, string password, string firstName, string lastName, string role,
        CancellationToken ct, bool assignedByStaff = false)
    {
        var roleEntity = await db.Roles.SingleAsync(r => r.Name == role, ct);
        var user = new User
        {
            Phone = phone,
            FirstName = firstName.Trim(),
            LastName = lastName.Trim(),
            PasswordHash = "",
            RoleId = roleEntity.Id,
            Role = roleEntity,
            MustChangePassword = assignedByStaff,
        };
        user.PasswordHash = hasher.HashPassword(user, password);
        db.Users.Add(user);
        return user;
    }

    public async Task<AuthResponse> LoginAsync(LoginRequest req, CancellationToken ct)
    {
        var phone = devLogins?.Resolve(req.Phone) ?? PhoneNumber.Normalize(req.Phone)!;
        var now = time.GetUtcNow();
        var user = await db.Users.Include(u => u.Role).SingleOrDefaultAsync(u => u.Phone == phone, ct);

        // Same error for unknown phone and wrong password to avoid account enumeration.
        var invalid = ApiException.Unauthorized("invalid_credentials", "Invalid phone number or password.");
        if (user is null)
        {
            hasher.HashPassword(new User { Phone = "", PasswordHash = "", FirstName = "", LastName = "" }, req.Password); // equalize timing
            throw invalid;
        }
        if (user.LockoutEnd > now)
            throw new ApiException(StatusCodes.Status423Locked, "account_locked", "Too many failed attempts. Try again later.");

        var result = hasher.VerifyHashedPassword(user, user.PasswordHash, req.Password);
        if (result == PasswordVerificationResult.Failed)
        {
            user.AccessFailedCount++;
            if (user.AccessFailedCount >= MaxFailedAttempts)
            {
                user.LockoutEnd = now.Add(LockoutDuration);
                user.AccessFailedCount = 0;
                logger.LogWarning("User {UserId} locked out after failed logins", user.Id);
            }
            await db.SaveChangesAsync(ct);
            throw invalid;
        }
        if (user.Status != UserStatus.Active)
            throw new ApiException(StatusCodes.Status403Forbidden, "account_blocked", "The account is blocked. Contact the club.");

        if (result == PasswordVerificationResult.SuccessRehashNeeded)
            user.PasswordHash = hasher.HashPassword(user, req.Password);
        user.AccessFailedCount = 0;
        user.LockoutEnd = null;
        user.LastLoginAt = now;
        await db.SaveChangesAsync(ct);
        return await IssueAsync(user, ct);
    }

    public async Task<AuthResponse> RefreshAsync(string refreshToken, CancellationToken ct)
    {
        var (user, pair) = await tokens.RotateAsync(refreshToken, ct)
            ?? throw ApiException.Unauthorized("invalid_refresh_token", "The session has expired. Sign in again.");
        return ToResponse(pair, user);
    }

    /// <summary>
    /// Changes the password, clears the "must change" flag, ends all other sessions and returns a fresh token pair
    /// so the current device stays signed in.
    /// </summary>
    public async Task<AuthResponse> ChangePasswordAsync(Guid userId, ChangePasswordRequest req, CancellationToken ct)
    {
        var user = await db.Users.Include(u => u.Role).SingleAsync(u => u.Id == userId, ct);
        if (hasher.VerifyHashedPassword(user, user.PasswordHash, req.CurrentPassword) == PasswordVerificationResult.Failed)
            throw ApiException.BadRequest("invalid_password", "Current password is incorrect.");
        if (req.NewPassword == req.CurrentPassword)
            throw ApiException.BadRequest("password_unchanged", "The new password must differ from the current one.");

        user.PasswordHash = hasher.HashPassword(user, req.NewPassword);
        user.MustChangePassword = false;
        await db.SaveChangesAsync(ct);
        await tokens.RevokeAllAsync(userId, ct);
        logger.LogInformation("User {UserId} changed password", userId);
        return await IssueAsync(user, ct);
    }

    /// <summary>Sets a password chosen by staff. The user must replace it at next sign-in; all sessions end.</summary>
    public async Task ResetByStaffAsync(User user, string newPassword, CancellationToken ct)
    {
        user.PasswordHash = hasher.HashPassword(user, newPassword);
        user.MustChangePassword = true;
        user.AccessFailedCount = 0;
        user.LockoutEnd = null;
        await db.SaveChangesAsync(ct);
        await tokens.RevokeAllAsync(user.Id, ct);
    }

    public async Task<AuthUserDto> GetUserAsync(Guid userId, CancellationToken ct)
    {
        var user = await db.Users.Include(u => u.Role).SingleOrDefaultAsync(u => u.Id == userId, ct)
            ?? throw ApiException.NotFound("User");
        return ToDto(user);
    }

    // ---- Phone confirmation by SMS code (prepared for stage 2) ----

    public async Task RequestPhoneVerificationAsync(Guid userId, CancellationToken ct)
    {
        EnsureSmsAvailable();
        var user = await db.Users.SingleAsync(u => u.Id == userId, ct);
        if (user.PhoneConfirmed) throw ApiException.Conflict("already_confirmed", "Phone number is already confirmed.");

        var now = time.GetUtcNow();
        var recent = await db.PhoneVerificationCodes.CountAsync(
            c => c.Phone == user.Phone && c.CreatedAt > now.AddMinutes(-1), ct);
        if (recent > 0)
            throw new ApiException(StatusCodes.Status429TooManyRequests, "too_many_requests", "Wait a minute before requesting a new code.");

        var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
        db.PhoneVerificationCodes.Add(new PhoneVerificationCode
        {
            Phone = user.Phone,
            Purpose = VerificationPurpose.PhoneConfirmation,
            CodeHash = TokenService.Hash(user.Phone + ":" + code),
            ExpiresAt = now.Add(CodeLifetime),
        });
        await db.SaveChangesAsync(ct);
        await sms.SendAsync(user.Phone, $"Fitness Formulasi: {code}", ct);
    }

    public async Task ConfirmPhoneAsync(Guid userId, string code, CancellationToken ct)
    {
        EnsureSmsAvailable();
        var user = await db.Users.SingleAsync(u => u.Id == userId, ct);
        var now = time.GetUtcNow();
        var entry = await db.PhoneVerificationCodes
            .Where(c => c.Phone == user.Phone && c.Purpose == VerificationPurpose.PhoneConfirmation && c.ConsumedAt == null && c.ExpiresAt > now)
            .OrderByDescending(c => c.CreatedAt).FirstOrDefaultAsync(ct);
        var invalid = ApiException.BadRequest("invalid_code", "The code is invalid or expired.");
        if (entry is null || entry.Attempts >= MaxCodeAttempts) throw invalid;

        if (!CryptographicOperations.FixedTimeEquals(
                System.Text.Encoding.ASCII.GetBytes(entry.CodeHash),
                System.Text.Encoding.ASCII.GetBytes(TokenService.Hash(user.Phone + ":" + code))))
        {
            entry.Attempts++;
            await db.SaveChangesAsync(ct);
            throw invalid;
        }
        entry.ConsumedAt = now;
        user.PhoneConfirmed = true;
        await db.SaveChangesAsync(ct);
    }

    private void EnsureSmsAvailable()
    {
        if (!sms.IsConfigured)
            throw new ApiException(StatusCodes.Status503ServiceUnavailable, "sms_not_configured",
                "SMS verification is not available yet.");
    }

    private async Task<AuthResponse> IssueAsync(User user, CancellationToken ct)
    {
        var pair = await tokens.IssueAsync(user, ct);
        return ToResponse(pair, user);
    }

    private static AuthResponse ToResponse(TokenPair pair, User user) =>
        new(pair.AccessToken, pair.AccessTokenExpiresAt, pair.RefreshToken, pair.RefreshTokenExpiresAt, ToDto(user));

    private static AuthUserDto ToDto(User u) => new(u.Id, u.Phone, u.PhoneConfirmed, u.FirstName, u.LastName, u.Role.Name, u.MustChangePassword,
        u.Role.Name == RoleNames.Admin && u.CanManageIntegrations);
}
