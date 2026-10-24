using System.Security.Cryptography;
using System.Text;

namespace FitnessFormulasi.Api.Features.Integrations;

public class IntegrationsOptions
{
    public const string Section = "Integrations";

    /// <summary>
    /// Base64 of 32 random bytes (AES-256). Comes from the environment (<c>Integrations__EncryptionKey</c>) like the
    /// JWT key, never from the repository. Without it integration secrets cannot be saved.
    /// Generate with: <c>openssl rand -base64 32</c>.
    /// </summary>
    public string? EncryptionKey { get; set; }
}

/// <summary>
/// Encrypts integration secrets with AES-256-GCM before they reach PostgreSQL. The secret's identity
/// (provider/mode/field) is bound as associated data, so a ciphertext copied to another field fails to decrypt.
/// </summary>
public sealed class SecretProtector
{
    private const string Prefix = "v1:";
    private const int NonceSize = 12, TagSize = 16;
    private readonly byte[]? _key;

    public SecretProtector(Microsoft.Extensions.Options.IOptions<IntegrationsOptions> options)
    {
        var configured = options.Value.EncryptionKey;
        if (string.IsNullOrWhiteSpace(configured)) return;
        byte[] key;
        try { key = Convert.FromBase64String(configured.Trim()); }
        catch (FormatException) { throw new InvalidOperationException("Integrations:EncryptionKey must be base64."); }
        if (key.Length != 32) throw new InvalidOperationException("Integrations:EncryptionKey must be 32 bytes (openssl rand -base64 32).");
        _key = key;
    }

    public bool IsConfigured => _key is not null;

    public string Protect(string plaintext, string context)
    {
        var key = _key ?? throw new InvalidOperationException("Encryption key is not configured.");
        var nonce = RandomNumberGenerator.GetBytes(NonceSize);
        var data = Encoding.UTF8.GetBytes(plaintext);
        var cipher = new byte[data.Length];
        var tag = new byte[TagSize];
        using (var aes = new AesGcm(key, TagSize))
            aes.Encrypt(nonce, data, cipher, tag, Encoding.UTF8.GetBytes(context));
        return Prefix + Convert.ToBase64String([.. nonce, .. cipher, .. tag]);
    }

    /// <summary>Returns the plaintext, or null when the key is missing or the ciphertext does not belong to <paramref name="context"/>.</summary>
    public string? Unprotect(string ciphertext, string context)
    {
        if (_key is null || !ciphertext.StartsWith(Prefix)) return null;
        try
        {
            var raw = Convert.FromBase64String(ciphertext[Prefix.Length..]);
            if (raw.Length < NonceSize + TagSize) return null;
            var nonce = raw[..NonceSize];
            var tag = raw[^TagSize..];
            var cipher = raw[NonceSize..^TagSize];
            var data = new byte[cipher.Length];
            using var aes = new AesGcm(_key, TagSize);
            aes.Decrypt(nonce, cipher, tag, data, Encoding.UTF8.GetBytes(context));
            return Encoding.UTF8.GetString(data);
        }
        catch (Exception e) when (e is CryptographicException or FormatException)
        {
            return null; // wrong key (rotated) or tampered value: treated as "not set" by callers
        }
    }
}
