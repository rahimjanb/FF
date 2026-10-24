namespace FitnessFormulasi.Api.Auth;

/// <summary>
/// Abstraction over an SMS provider. A real provider (e.g. Eskiz, Play Mobile) is connected in stage 2
/// under a separate agreement; stage 1 ships without a production implementation.
/// </summary>
public interface ISmsSender
{
    bool IsConfigured { get; }
    Task SendAsync(string phoneE164, string message, CancellationToken ct);
}

/// <summary>
/// Production default until a provider is connected: SMS-dependent endpoints answer 503.
/// </summary>
public sealed class NotConfiguredSmsSender : ISmsSender
{
    public bool IsConfigured => false;
    public Task SendAsync(string phoneE164, string message, CancellationToken ct) =>
        throw new InvalidOperationException("SMS provider is not configured.");
}

/// <summary>
/// DEVELOPMENT ONLY. Writes the message to the application log instead of sending an SMS.
/// Registered only when ASPNETCORE_ENVIRONMENT=Development; never use in Production.
/// </summary>
public sealed class DevelopmentSmsSender(ILogger<DevelopmentSmsSender> logger, IHostEnvironment env) : ISmsSender
{
    public bool IsConfigured => true;

    public Task SendAsync(string phoneE164, string message, CancellationToken ct)
    {
        if (!env.IsDevelopment())
            throw new InvalidOperationException("DevelopmentSmsSender must not be used outside Development.");
        logger.LogWarning("[DEV SMS — not sent] To {Phone}: {Message}", phoneE164, message);
        return Task.CompletedTask;
    }
}
