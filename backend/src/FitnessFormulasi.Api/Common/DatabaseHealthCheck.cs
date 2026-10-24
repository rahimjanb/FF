using FitnessFormulasi.Api.Data;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace FitnessFormulasi.Api.Common;

public sealed class DatabaseHealthCheck(AppDbContext db) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken ct = default) =>
        await db.Database.CanConnectAsync(ct)
            ? HealthCheckResult.Healthy("PostgreSQL reachable")
            : HealthCheckResult.Unhealthy("PostgreSQL unreachable");
}
