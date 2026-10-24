using FitnessFormulasi.Api.Auth;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Data;

public class BootstrapOptions
{
    public const string Section = "Bootstrap";
    /// <summary>Phone of the first administrator. Used only when no administrator exists yet.</summary>
    public string? AdminPhone { get; set; }
    /// <summary>Initial admin password. Supply via environment/secret store and change after first login.</summary>
    public string? AdminPassword { get; set; }
    public string AdminFirstName { get; set; } = "Admin";
    public string AdminLastName { get; set; } = "";
}

public static class DbInitializer
{
    public static async Task InitializeAsync(IServiceProvider services, CancellationToken ct = default)
    {
        using var scope = services.CreateScope();
        var sp = scope.ServiceProvider;
        var config = sp.GetRequiredService<IConfiguration>();
        var logger = sp.GetRequiredService<ILoggerFactory>().CreateLogger("DbInitializer");
        var db = sp.GetRequiredService<AppDbContext>();

        if (config.GetValue("Database:MigrateOnStartup", false))
        {
            logger.LogInformation("Applying database migrations");
            await db.Database.MigrateAsync(ct);
        }

        await CreateBootstrapAdminAsync(sp, config, db, logger, ct);
        if (sp.GetService<DevLogins>() is not null)
            await DevLogins.SeedAsync(sp, logger, ct);
    }

    private static async Task CreateBootstrapAdminAsync(IServiceProvider sp, IConfiguration config, AppDbContext db, ILogger logger,
        CancellationToken ct)
    {
        var opt = config.GetSection(BootstrapOptions.Section).Get<BootstrapOptions>() ?? new BootstrapOptions();
        if (await db.Users.AnyAsync(u => u.Role.Name == RoleNames.Admin, ct)) return;
        if (string.IsNullOrWhiteSpace(opt.AdminPhone) || string.IsNullOrWhiteSpace(opt.AdminPassword))
        {
            logger.LogWarning("No administrator exists. Set Bootstrap__AdminPhone and Bootstrap__AdminPassword to create one");
            return;
        }
        var phone = PhoneNumber.Normalize(opt.AdminPhone)
                    ?? throw new InvalidOperationException("Bootstrap:AdminPhone is not a valid phone number.");
        if (await db.Users.AnyAsync(u => u.Phone == phone, ct))
            throw new InvalidOperationException("Bootstrap:AdminPhone belongs to an existing non-admin user.");

        var auth = sp.GetRequiredService<AuthService>();
        // The bootstrap password comes from configuration, so it is treated as temporary.
        var admin = await auth.CreateUserAsync(phone, opt.AdminPassword, opt.AdminFirstName, opt.AdminLastName, RoleNames.Admin, ct,
            assignedByStaff: true);
        await db.SaveChangesAsync(ct);
        logger.LogInformation("Bootstrap administrator {UserId} created", admin.Id);
    }
}
