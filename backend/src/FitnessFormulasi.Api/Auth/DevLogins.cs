using System.ComponentModel.DataAnnotations;
using FitnessFormulasi.Api.Common;
using FitnessFormulasi.Api.Data;
using FitnessFormulasi.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Auth;

/// <summary>
/// Short development logins ("1"/"1", "2"/"2", "3"/"3") for manual testing.
/// Registered only in the Development environment; elsewhere the service is absent and logins require a phone.
/// </summary>
public sealed class DevLogins
{
    public sealed record Account(string Login, string Phone, string Role, string FirstName, string LastName);

    public static readonly IReadOnlyList<Account> Accounts =
    [
        new("1", "+998000000001", RoleNames.Admin, "Dev", "Admin"),
        new("2", "+998000000002", RoleNames.Trainer, "Dev", "Trainer"),
        new("3", "+998000000003", RoleNames.Client, "Dev", "Client"),
    ];

    /// <summary>Maps a short login to its phone, or null if the input is not a dev login.</summary>
    public string? Resolve(string? login) => Accounts.FirstOrDefault(a => a.Login == login?.Trim())?.Phone;

    /// <summary>Creates missing dev accounts (password = login). Existing accounts are left untouched.</summary>
    public static async Task SeedAsync(IServiceProvider sp, ILogger logger, CancellationToken ct)
    {
        var db = sp.GetRequiredService<AppDbContext>();
        var auth = sp.GetRequiredService<AuthService>();
        foreach (var a in Accounts)
        {
            if (await db.Users.AnyAsync(u => u.Phone == a.Phone, ct)) continue;
            var user = await auth.CreateUserAsync(a.Phone, a.Login, a.FirstName, a.LastName, a.Role, ct);
            if (a.Role == RoleNames.Trainer) db.TrainerProfiles.Add(new TrainerProfile { UserId = user.Id });
            if (a.Role == RoleNames.Client) db.ClientProfiles.Add(new ClientProfile { UserId = user.Id });
            await db.SaveChangesAsync(ct);
            logger.LogInformation("Dev account {Login} ({Role}) created", a.Login, a.Role);
        }
        // The dev administrator manages integrations so the settings screen can be tried locally.
        await db.Users.Where(u => u.Phone == Accounts[0].Phone && !u.CanManageIntegrations)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.CanManageIntegrations, true), ct);
    }
}

/// <summary>Login identifier: a phone number, or a short dev login when <see cref="DevLogins"/> is registered.</summary>
[AttributeUsage(AttributeTargets.Property)]
public sealed class LoginPhoneAttribute : ValidationAttribute
{
    protected override ValidationResult? IsValid(object? value, ValidationContext context) =>
        value is null || PhoneNumber.Normalize(value as string) is not null
                      || context.GetService<DevLogins>()?.Resolve(value as string) is not null
            ? ValidationResult.Success
            : new ValidationResult("Invalid phone number.", [context.MemberName!]);
}
