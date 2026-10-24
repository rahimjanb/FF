using FitnessFormulasi.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace FitnessFormulasi.Api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options, TimeProvider timeProvider) : DbContext(options)
{
    public DbSet<Role> Roles => Set<Role>();
    public DbSet<User> Users => Set<User>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<PhoneVerificationCode> PhoneVerificationCodes => Set<PhoneVerificationCode>();
    public DbSet<ClientProfile> ClientProfiles => Set<ClientProfile>();
    public DbSet<TrainerProfile> TrainerProfiles => Set<TrainerProfile>();
    public DbSet<MembershipPlan> MembershipPlans => Set<MembershipPlan>();
    public DbSet<Membership> Memberships => Set<Membership>();
    public DbSet<TrainerRequest> TrainerRequests => Set<TrainerRequest>();
    public DbSet<TrainingSession> TrainingSessions => Set<TrainingSession>();
    public DbSet<Visit> Visits => Set<Visit>();
    public DbSet<Notification> Notifications => Set<Notification>();

    protected override void ConfigureConventions(ModelConfigurationBuilder builder)
    {
        // Enums are stored as readable strings.
        builder.Properties<UserStatus>().HaveConversion<string>().HaveMaxLength(32);
        builder.Properties<VerificationPurpose>().HaveConversion<string>().HaveMaxLength(32);
        builder.Properties<Gender>().HaveConversion<string>().HaveMaxLength(16);
        builder.Properties<MembershipPlanType>().HaveConversion<string>().HaveMaxLength(32);
        builder.Properties<MembershipStatus>().HaveConversion<string>().HaveMaxLength(32);
        builder.Properties<TrainerRequestStatus>().HaveConversion<string>().HaveMaxLength(32);
        builder.Properties<TrainingSessionStatus>().HaveConversion<string>().HaveMaxLength(32);
        builder.Properties<VisitSource>().HaveConversion<string>().HaveMaxLength(32);
        builder.Properties<NotificationType>().HaveConversion<string>().HaveMaxLength(64);
    }

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<Role>(e =>
        {
            e.Property(x => x.Name).HasMaxLength(32);
            e.Property(x => x.Description).HasMaxLength(256);
            e.HasIndex(x => x.Name).IsUnique();
            e.HasData(
                new Role { Id = 1, Name = RoleNames.Admin, Description = "Club administrator: full access to the admin panel" },
                new Role { Id = 2, Name = RoleNames.Trainer, Description = "Trainer: own profile, assigned clients, requests and sessions" },
                new Role { Id = 3, Name = RoleNames.Client, Description = "Club client: own profile, memberships, trainer requests" });
        });

        b.Entity<User>(e =>
        {
            e.Property(x => x.Phone).HasMaxLength(16);
            e.Property(x => x.PasswordHash).HasMaxLength(256);
            e.Property(x => x.FirstName).HasMaxLength(64);
            e.Property(x => x.LastName).HasMaxLength(64);
            e.Property(x => x.Email).HasMaxLength(256);
            e.Ignore(x => x.FullName);
            e.HasIndex(x => x.Phone).IsUnique();
            e.HasIndex(x => x.RoleId);
            e.HasOne(x => x.Role).WithMany(r => r.Users).HasForeignKey(x => x.RoleId).OnDelete(DeleteBehavior.Restrict);
        });

        b.Entity<RefreshToken>(e =>
        {
            e.Property(x => x.TokenHash).HasMaxLength(64);
            e.HasIndex(x => x.TokenHash).IsUnique();
            e.HasIndex(x => x.UserId);
            e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<PhoneVerificationCode>(e =>
        {
            e.Property(x => x.Phone).HasMaxLength(16);
            e.Property(x => x.CodeHash).HasMaxLength(64);
            e.HasIndex(x => new { x.Phone, x.Purpose, x.CreatedAt });
        });

        b.Entity<ClientProfile>(e =>
        {
            e.Property(x => x.Notes).HasMaxLength(2000);
            e.HasIndex(x => x.UserId).IsUnique();
            e.HasIndex(x => x.AssignedTrainerId);
            e.HasOne(x => x.User).WithOne(u => u.ClientProfile).HasForeignKey<ClientProfile>(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.AssignedTrainer).WithMany(t => t.Clients).HasForeignKey(x => x.AssignedTrainerId).OnDelete(DeleteBehavior.SetNull);
        });

        b.Entity<TrainerProfile>(e =>
        {
            e.Property(x => x.Specialization).HasMaxLength(128);
            e.Property(x => x.Bio).HasMaxLength(2000);
            e.HasIndex(x => x.UserId).IsUnique();
            e.HasOne(x => x.User).WithOne(u => u.TrainerProfile).HasForeignKey<TrainerProfile>(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
            e.ToTable(t => t.HasCheckConstraint("CK_TrainerProfiles_ExperienceYears", "\"ExperienceYears\" IS NULL OR \"ExperienceYears\" BETWEEN 0 AND 80"));
        });

        b.Entity<MembershipPlan>(e =>
        {
            e.Property(x => x.Name).HasMaxLength(128);
            e.Property(x => x.Description).HasMaxLength(1000);
            e.Property(x => x.Price).HasPrecision(14, 2);
            e.HasIndex(x => x.Name).IsUnique();
            e.ToTable(t =>
            {
                t.HasCheckConstraint("CK_MembershipPlans_DurationDays", "\"DurationDays\" BETWEEN 1 AND 3660");
                t.HasCheckConstraint("CK_MembershipPlans_Price", "\"Price\" >= 0");
                t.HasCheckConstraint("CK_MembershipPlans_VisitLimit",
                    "(\"Type\" = 'LimitedVisits' AND \"VisitLimit\" > 0) OR (\"Type\" = 'Unlimited' AND \"VisitLimit\" IS NULL)");
            });
        });

        b.Entity<Membership>(e =>
        {
            e.Property(x => x.Version).IsRowVersion();
            e.HasIndex(x => new { x.ClientProfileId, x.EndDate });
            e.HasIndex(x => new { x.Status, x.EndDate });
            e.HasOne(x => x.ClientProfile).WithMany(c => c.Memberships).HasForeignKey(x => x.ClientProfileId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Plan).WithMany().HasForeignKey(x => x.MembershipPlanId).OnDelete(DeleteBehavior.Restrict);
            e.ToTable(t => t.HasCheckConstraint("CK_Memberships_Dates", "\"EndDate\" >= \"StartDate\""));
        });

        b.Entity<TrainerRequest>(e =>
        {
            e.Property(x => x.Version).IsRowVersion();
            e.Property(x => x.Message).HasMaxLength(500);
            e.Property(x => x.ResponseComment).HasMaxLength(500);
            // At most one pending request per client/trainer pair; enforced by the database.
            e.HasIndex(x => new { x.ClientProfileId, x.TrainerProfileId }).IsUnique()
                .HasFilter("\"Status\" = 'Pending'").HasDatabaseName("IX_TrainerRequests_OnePendingPerPair");
            e.HasIndex(x => new { x.TrainerProfileId, x.Status });
            e.HasIndex(x => x.Status);
            e.HasOne(x => x.ClientProfile).WithMany().HasForeignKey(x => x.ClientProfileId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.TrainerProfile).WithMany().HasForeignKey(x => x.TrainerProfileId).OnDelete(DeleteBehavior.Restrict);
        });

        b.Entity<TrainingSession>(e =>
        {
            e.Property(x => x.Notes).HasMaxLength(1000);
            e.HasIndex(x => new { x.TrainerProfileId, x.StartsAt });
            e.HasIndex(x => new { x.ClientProfileId, x.StartsAt });
            e.HasOne(x => x.TrainerProfile).WithMany().HasForeignKey(x => x.TrainerProfileId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.ClientProfile).WithMany().HasForeignKey(x => x.ClientProfileId).OnDelete(DeleteBehavior.Restrict);
            e.ToTable(t => t.HasCheckConstraint("CK_TrainingSessions_Duration", "\"DurationMinutes\" BETWEEN 15 AND 480"));
        });

        b.Entity<Visit>(e =>
        {
            e.HasIndex(x => new { x.ClientProfileId, x.VisitedAt });
            e.HasIndex(x => x.VisitedAt);
            e.HasIndex(x => x.MembershipId);
            e.HasOne(x => x.ClientProfile).WithMany(c => c.Visits).HasForeignKey(x => x.ClientProfileId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Membership).WithMany(m => m.Visits).HasForeignKey(x => x.MembershipId).OnDelete(DeleteBehavior.Restrict);
        });

        b.Entity<Notification>(e =>
        {
            e.Property(x => x.Payload).HasMaxLength(256);
            e.HasIndex(x => new { x.UserId, x.CreatedAt });
            e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        });
    }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        var now = timeProvider.GetUtcNow();
        foreach (var entry in ChangeTracker.Entries<Entity>())
        {
            if (entry.State == EntityState.Added)
            {
                entry.Entity.CreatedAt = now;
                entry.Entity.UpdatedAt = now;
            }
            else if (entry.State == EntityState.Modified)
            {
                entry.Entity.UpdatedAt = now;
            }
        }
        return base.SaveChangesAsync(cancellationToken);
    }
}
