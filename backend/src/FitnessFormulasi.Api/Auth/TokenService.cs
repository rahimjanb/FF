using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace FitnessFormulasi.Api.Auth;

public record TokenPair(string AccessToken, DateTimeOffset AccessTokenExpiresAt, string RefreshToken, DateTimeOffset RefreshTokenExpiresAt);

public sealed class TokenService(AppDbContext db, IOptions<JwtOptions> options, TimeProvider time)
{
    private readonly JwtOptions _opt = options.Value;

    public async Task<TokenPair> IssueAsync(User user, CancellationToken ct)
    {
        var pair = Create(user, time.GetUtcNow(), out _);
        await db.SaveChangesAsync(ct);
        return pair;
    }

    /// <summary>
    /// Rotates a refresh token: the presented token is revoked atomically and a new pair is issued.
    /// Presenting an already rotated token revokes all of the user's sessions, since that indicates theft.
    /// </summary>
    public async Task<(User User, TokenPair Pair)?> RotateAsync(string rawToken, CancellationToken ct)
    {
        var hash = Hash(rawToken);
        var now = time.GetUtcNow();
        var token = await db.RefreshTokens.AsNoTracking().Include(t => t.User).ThenInclude(u => u.Role)
            .SingleOrDefaultAsync(t => t.TokenHash == hash, ct);
        if (token is null) return null;
        if (token.RevokedAt is not null)
        {
            if (token.ReplacedByTokenId is not null) await RevokeAllAsync(token.UserId, ct);
            return null;
        }
        if (token.ExpiresAt <= now || token.User.Status != UserStatus.Active) return null;

        var pair = Create(token.User, now, out var replacement);
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        // Conditional update guards against two concurrent refreshes with the same token.
        var revoked = await db.RefreshTokens.Where(t => t.Id == token.Id && t.RevokedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAt, now).SetProperty(t => t.ReplacedByTokenId, replacement.Id), ct);
        if (revoked == 0)
        {
            await tx.RollbackAsync(ct);
            db.ChangeTracker.Clear();
            await RevokeAllAsync(token.UserId, ct);
            return null;
        }
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return (token.User, pair);
    }

    public async Task RevokeAsync(string rawToken, Guid userId, CancellationToken ct)
    {
        var hash = Hash(rawToken);
        var now = time.GetUtcNow();
        await db.RefreshTokens.Where(t => t.TokenHash == hash && t.UserId == userId && t.RevokedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAt, now), ct);
    }

    public async Task RevokeAllAsync(Guid userId, CancellationToken ct)
    {
        var now = time.GetUtcNow();
        await db.RefreshTokens.Where(t => t.UserId == userId && t.RevokedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAt, now), ct);
    }

    public static SymmetricSecurityKey SigningKey(JwtOptions o) => new(Encoding.UTF8.GetBytes(o.SigningKey));

    public static string Hash(string value) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value)));

    private TokenPair Create(User user, DateTimeOffset now, out RefreshToken refresh)
    {
        var accessExpires = now.AddMinutes(_opt.AccessTokenMinutes);
        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new Claim(ClaimTypes.Role, user.Role.Name),
            new Claim(ClaimTypes.Name, user.FullName),
        };
        var jwt = new JwtSecurityToken(
            _opt.Issuer, _opt.Audience, claims,
            notBefore: now.UtcDateTime, expires: accessExpires.UtcDateTime,
            signingCredentials: new SigningCredentials(SigningKey(_opt), SecurityAlgorithms.HmacSha256));

        var raw = Convert.ToBase64String(RandomNumberGenerator.GetBytes(48));
        refresh = new RefreshToken { UserId = user.Id, TokenHash = Hash(raw), ExpiresAt = now.AddDays(_opt.RefreshTokenDays) };
        db.RefreshTokens.Add(refresh);
        return new TokenPair(new JwtSecurityTokenHandler().WriteToken(jwt), accessExpires, raw, refresh.ExpiresAt);
    }
}
