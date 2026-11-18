using System.Buffers.Binary;
using System.Security.Cryptography;
using System.Text;
using FitnessFormulasi.Api.Auth;
using Microsoft.Extensions.Options;

namespace FitnessFormulasi.Api.Features;

public record PassToken(string Code, DateTimeOffset ExpiresAt, DateTimeOffset RefreshAt);

public enum PassTokenError { None, Invalid, Expired }

/// <summary>
/// Short-lived QR pass: "FF1" + Base32(client id, expiry, truncated HMAC). A new code every 30 seconds, each valid
/// for 60, so a screenshot or a forwarded code stops working within a minute. Only digits and capital letters are used:
/// QR alphanumeric mode, and a USB scanner types it the same in any keyboard layout once mapped by key position.
/// The key is derived from the JWT signing key, so no extra secret has to be configured.
/// </summary>
public sealed class PassTokenService(IOptions<JwtOptions> jwt)
{
    public const int WindowSeconds = 30;
    public const int LifetimeSeconds = 60;
    private const string Prefix = "FF1";
    private const int SignatureBytes = 10;
    private const int ClockSkewSeconds = 5;
    private const string Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

    private readonly byte[] _key = HMACSHA256.HashData(Encoding.UTF8.GetBytes(jwt.Value.SigningKey), "ff-qr-pass-v1"u8);

    /// <summary>The same code is returned for the whole 30-second window, so polling does not change the QR.</summary>
    public PassToken Issue(Guid clientId, DateTimeOffset now)
    {
        var window = now.ToUnixTimeSeconds() / WindowSeconds * WindowSeconds;
        var expires = window + LifetimeSeconds;
        var data = new byte[16 + 4 + SignatureBytes];
        clientId.TryWriteBytes(data.AsSpan(0, 16));
        BinaryPrimitives.WriteUInt32BigEndian(data.AsSpan(16, 4), (uint)expires);
        Sign(data.AsSpan(0, 20)).CopyTo(data.AsSpan(20));
        return new PassToken(Prefix + ToBase32(data), DateTimeOffset.FromUnixTimeSeconds(expires),
            DateTimeOffset.FromUnixTimeSeconds(window + WindowSeconds));
    }

    public (PassTokenError Error, Guid ClientId) Validate(string? code, DateTimeOffset now)
    {
        var normalized = new string((code ?? "").Where(c => !char.IsWhiteSpace(c)).ToArray()).ToUpperInvariant();
        if (!normalized.StartsWith(Prefix, StringComparison.Ordinal) || FromBase32(normalized[Prefix.Length..]) is not { Length: 30 } data)
            return (PassTokenError.Invalid, Guid.Empty);
        if (!CryptographicOperations.FixedTimeEquals(Sign(data.AsSpan(0, 20)), data.AsSpan(20)))
            return (PassTokenError.Invalid, Guid.Empty);

        var expires = BinaryPrimitives.ReadUInt32BigEndian(data.AsSpan(16, 4));
        var unixNow = now.ToUnixTimeSeconds();
        if (expires > unixNow + LifetimeSeconds + ClockSkewSeconds) return (PassTokenError.Invalid, Guid.Empty);
        if (unixNow > expires + ClockSkewSeconds) return (PassTokenError.Expired, Guid.Empty);
        return (PassTokenError.None, new Guid(data.AsSpan(0, 16)));
    }

    private byte[] Sign(ReadOnlySpan<byte> payload) => HMACSHA256.HashData(_key, payload)[..SignatureBytes];

    private static string ToBase32(byte[] data)
    {
        var sb = new StringBuilder((data.Length * 8 + 4) / 5);
        int buffer = 0, bits = 0;
        foreach (var b in data)
        {
            buffer = (buffer << 8) | b;
            bits += 8;
            while (bits >= 5)
            {
                sb.Append(Alphabet[(buffer >> (bits - 5)) & 31]);
                bits -= 5;
            }
        }
        if (bits > 0) sb.Append(Alphabet[(buffer << (5 - bits)) & 31]);
        return sb.ToString();
    }

    private static byte[]? FromBase32(string text)
    {
        var result = new List<byte>(text.Length * 5 / 8);
        int buffer = 0, bits = 0;
        foreach (var c in text)
        {
            var value = Alphabet.IndexOf(c);
            if (value < 0) return null;
            buffer = (buffer << 5) | value;
            bits += 5;
            if (bits >= 8)
            {
                result.Add((byte)(buffer >> (bits - 8)));
                bits -= 8;
            }
        }
        return result.ToArray();
    }
}
