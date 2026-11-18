using FitnessFormulasi.Api.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Options;

namespace FitnessFormulasi.Api.Features.Access;

public sealed class AccessOptions
{
    public const string Section = "Access";

    /// <summary>Runs the synchronisation in the background. Switched off in tests, which start it explicitly.</summary>
    public bool BackgroundSync { get; set; } = true;
    /// <summary>Full pass over all terminals at least this often, even without changes (dates move on by themselves).</summary>
    public int SyncIntervalSeconds { get; set; } = 60;
}

/// <summary>Wakes the background synchronisation early after a change that may affect who may enter.</summary>
public sealed class AccessSyncSignal
{
    private readonly SemaphoreSlim _signal = new(0, 1);

    public void Request()
    {
        try
        {
            if (_signal.CurrentCount == 0) _signal.Release();
        }
        catch (SemaphoreFullException) { }
    }

    /// <summary>Returns when a change was signalled or the timeout passed.</summary>
    public Task WaitAsync(TimeSpan timeout, CancellationToken ct) => _signal.WaitAsync(timeout, ct);
}

/// <summary>
/// Signals the synchronisation after saving anything that changes the terminal plan: face photos, memberships,
/// freezes, visits (visit limits), and the client's name or blocking. Covers every code path that saves these.
/// </summary>
public sealed class AccessChangeInterceptor(AccessSyncSignal signal) : SaveChangesInterceptor
{
    public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData eventData, InterceptionResult<int> result, CancellationToken ct = default)
    {
        if (eventData.Context is { } context && Affects(context)) signal.Request();
        return base.SavingChangesAsync(eventData, result, ct);
    }

    private static bool Affects(DbContext context) =>
        context.ChangeTracker.Entries().Any(e => (e.State is EntityState.Added or EntityState.Modified or EntityState.Deleted) && e.Entity switch
        {
            ClientFace or Membership or MembershipFreeze or Visit => true,
            // A new terminal, or one moved to another address, is filled at once. Status fields written by the
            // synchronisation itself do not count, or every pass would trigger the next one.
            AccessDevice => e.State != EntityState.Modified
                            || e.Property(nameof(AccessDevice.BaseUrl)).IsModified || e.Property(nameof(AccessDevice.IsActive)).IsModified
                            || e.Property(nameof(AccessDevice.PasswordCiphertext)).IsModified || e.Property(nameof(AccessDevice.DoorNo)).IsModified,
            User => e.State != EntityState.Modified
                    || e.Property(nameof(User.Status)).IsModified || e.Property(nameof(User.FirstName)).IsModified
                    || e.Property(nameof(User.LastName)).IsModified,
            _ => false,
        });
}

/// <summary>
/// Keeps the terminals in step: a pass right after a change (after a short pause, so the change is committed and a
/// burst of changes is handled at once) and at least every <see cref="AccessOptions.SyncIntervalSeconds"/>.
/// </summary>
public sealed class AccessSyncWorker(
    IServiceScopeFactory scopes, AccessSyncSignal signal, IOptions<AccessOptions> options, ILogger<AccessSyncWorker> logger)
    : BackgroundService
{
    private static readonly TimeSpan Debounce = TimeSpan.FromSeconds(2);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!options.Value.BackgroundSync) return;
        var interval = TimeSpan.FromSeconds(Math.Max(10, options.Value.SyncIntervalSeconds));
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await using var scope = scopes.CreateAsyncScope();
                await scope.ServiceProvider.GetRequiredService<AccessSyncService>().SyncAllAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { return; }
            catch (Exception e)
            {
                logger.LogError(e, "Access synchronisation pass failed");
            }

            try
            {
                await signal.WaitAsync(interval, stoppingToken);
                await Task.Delay(Debounce, stoppingToken);
            }
            catch (OperationCanceledException) { return; }
        }
    }
}
