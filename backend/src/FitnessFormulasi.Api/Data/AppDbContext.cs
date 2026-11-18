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
    public DbSet<TrainerPhoto> TrainerPhotos => Set<TrainerPhoto>();
    public DbSet<MembershipPlan> MembershipPlans => Set<MembershipPlan>();
    public DbSet<Membership> Memberships => Set<Membership>();
    public DbSet<MembershipFreeze> MembershipFreezes => Set<MembershipFreeze>();
    public DbSet<MembershipRequest> MembershipRequests => Set<MembershipRequest>();
    public DbSet<TrainerRequest> TrainerRequests => Set<TrainerRequest>();
    public DbSet<TrainingSession> TrainingSessions => Set<TrainingSession>();
    public DbSet<Visit> Visits => Set<Visit>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<Banner> Banners => Set<Banner>();
    public DbSet<BannerMedia> BannerMedia => Set<BannerMedia>();
    public DbSet<IntegrationSetting> IntegrationSettings => Set<IntegrationSetting>();
    public DbSet<IntegrationSecret> IntegrationSecrets => Set<IntegrationSecret>();
    public DbSet<AuditLogEntry> AuditLog => Set<AuditLogEntry>();
    public DbSet<ClientFace> ClientFaces => Set<ClientFace>();
    public DbSet<AccessDevice> AccessDevices => Set<AccessDevice>();
    public DbSet<AccessDeviceUser> AccessDeviceUsers => Set<AccessDeviceUser>();
    public DbSet<AccessEvent> AccessEvents => Set<AccessEvent>();
    public DbSet<FoodProduct> FoodProducts => Set<FoodProduct>();
    public DbSet<FoodBarcode> FoodBarcodes => Set<FoodBarcode>();
    public DbSet<FoodRecipe> FoodRecipes => Set<FoodRecipe>();
    public DbSet<FoodRecipeIngredient> FoodRecipeIngredients => Set<FoodRecipeIngredient>();
    public DbSet<FoodScan> FoodScans => Set<FoodScan>();
    public DbSet<FoodRecognitionResult> FoodRecognitionResults => Set<FoodRecognitionResult>();
    public DbSet<FoodRecognitionIngredient> FoodRecognitionIngredients => Set<FoodRecognitionIngredient>();
    public DbSet<FoodDiaryEntry> FoodDiaryEntries => Set<FoodDiaryEntry>();
    public DbSet<FoodDiaryItem> FoodDiaryItems => Set<FoodDiaryItem>();
    public DbSet<NutritionProfile> NutritionProfiles => Set<NutritionProfile>();
    public DbSet<NutritionDailySummary> NutritionDailySummaries => Set<NutritionDailySummary>();
    public DbSet<NutritionReport> NutritionReports => Set<NutritionReport>();
    public DbSet<AiUsageRecord> AiUsage => Set<AiUsageRecord>();
    public DbSet<AiProviderSettings> AiProviderSettings => Set<AiProviderSettings>();

    /// <summary>Source of <see cref="ClientProfile.AccessNo"/>.</summary>
    public const string AccessNumberSequence = "ClientAccessNumbers";

    protected override void ConfigureConventions(ModelConfigurationBuilder builder)
    {
        // Enums are stored as readable strings.
        builder.Properties<UserStatus>().HaveConversion<string>().HaveMaxLength(32);
        builder.Properties<VerificationPurpose>().HaveConversion<string>().HaveMaxLength(32);
        builder.Properties<Gender>().HaveConversion<string>().HaveMaxLength(16);
        builder.Properties<MembershipPlanType>().HaveConversion<string>().HaveMaxLength(32);
        builder.Properties<MembershipStatus>().HaveConversion<string>().HaveMaxLength(32);
        builder.Properties<MembershipRequestKind>().HaveConversion<string>().HaveMaxLength(16);
        builder.Properties<MembershipRequestStatus>().HaveConversion<string>().HaveMaxLength(32);
        builder.Properties<TrainerRequestStatus>().HaveConversion<string>().HaveMaxLength(32);
        builder.Properties<TrainingSessionStatus>().HaveConversion<string>().HaveMaxLength(32);
        builder.Properties<VisitSource>().HaveConversion<string>().HaveMaxLength(32);
        builder.Properties<NotificationType>().HaveConversion<string>().HaveMaxLength(64);
        builder.Properties<IntegrationProvider>().HaveConversion<string>().HaveMaxLength(32);
        builder.Properties<IntegrationMode>().HaveConversion<string>().HaveMaxLength(16);
        builder.Properties<BannerMediaKind>().HaveConversion<string>().HaveMaxLength(16);
        builder.Properties<AccessSyncState>().HaveConversion<string>().HaveMaxLength(16);
        builder.Properties<MealType>().HaveConversion<string>().HaveMaxLength(16);
        builder.Properties<FoodCategory>().HaveConversion<string>().HaveMaxLength(32);
        builder.Properties<NutritionSource>().HaveConversion<string>().HaveMaxLength(16);
        builder.Properties<IngredientRole>().HaveConversion<string>().HaveMaxLength(16);
        builder.Properties<PreparationMethod>().HaveConversion<string>().HaveMaxLength(16);
        builder.Properties<WeightConfidence>().HaveConversion<string>().HaveMaxLength(16);
        builder.Properties<FoodScanKind>().HaveConversion<string>().HaveMaxLength(16);
        builder.Properties<FoodScanStatus>().HaveConversion<string>().HaveMaxLength(32);
        builder.Properties<IngredientMatch>().HaveConversion<string>().HaveMaxLength(16);
        builder.Properties<NutritionGoal>().HaveConversion<string>().HaveMaxLength(16);
        builder.Properties<ActivityLevel>().HaveConversion<string>().HaveMaxLength(16);
        builder.Properties<AiFeature>().HaveConversion<string>().HaveMaxLength(16);
        builder.Properties<NutritionReportPeriod>().HaveConversion<string>().HaveMaxLength(8);
        // Nutrition values and weights: grams, kcal and mg with two decimals.
        builder.Properties<decimal>().HavePrecision(10, 2);
    }

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.HasSequence<int>(AccessNumberSequence).StartsAt(1001);

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
            e.HasIndex(x => x.AccessNo).IsUnique();
            e.HasOne(x => x.User).WithOne(u => u.ClientProfile).HasForeignKey<ClientProfile>(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.AssignedTrainer).WithMany(t => t.Clients).HasForeignKey(x => x.AssignedTrainerId).OnDelete(DeleteBehavior.SetNull);
        });

        b.Entity<TrainerProfile>(e =>
        {
            e.Property(x => x.Specialization).HasMaxLength(128);
            e.Property(x => x.Bio).HasMaxLength(2000);
            e.Property(x => x.Telegram).HasMaxLength(32);
            e.Property(x => x.Instagram).HasMaxLength(30);
            e.HasIndex(x => x.UserId).IsUnique();
            e.HasOne(x => x.User).WithOne(u => u.TrainerProfile).HasForeignKey<TrainerProfile>(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
            e.ToTable(t => t.HasCheckConstraint("CK_TrainerProfiles_ExperienceYears", "\"ExperienceYears\" IS NULL OR \"ExperienceYears\" BETWEEN 0 AND 80"));
        });

        b.Entity<TrainerPhoto>(e =>
        {
            e.HasKey(x => x.TrainerProfileId);
            e.Property(x => x.ContentType).HasMaxLength(32);
            e.HasOne<TrainerProfile>().WithOne().HasForeignKey<TrainerPhoto>(x => x.TrainerProfileId).OnDelete(DeleteBehavior.Cascade);
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

        b.Entity<MembershipFreeze>(e =>
        {
            e.HasIndex(x => new { x.MembershipId, x.StartDate });
            e.HasOne(x => x.Membership).WithMany(m => m.Freezes).HasForeignKey(x => x.MembershipId).OnDelete(DeleteBehavior.Cascade);
            e.ToTable(t => t.HasCheckConstraint("CK_MembershipFreezes_Dates", "\"EndDate\" >= \"StartDate\""));
        });

        b.Entity<MembershipRequest>(e =>
        {
            e.Property(x => x.Version).IsRowVersion();
            e.Property(x => x.ResponseComment).HasMaxLength(500);
            // At most one pending request per client; enforced by the database.
            e.HasIndex(x => x.ClientProfileId).IsUnique()
                .HasFilter("\"Status\" = 'Pending'").HasDatabaseName("IX_MembershipRequests_OnePendingPerClient");
            e.HasIndex(x => new { x.Status, x.CreatedAt });
            e.HasOne(x => x.ClientProfile).WithMany().HasForeignKey(x => x.ClientProfileId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Plan).WithMany().HasForeignKey(x => x.MembershipPlanId).OnDelete(DeleteBehavior.Restrict);
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

        b.Entity<IntegrationSetting>(e =>
        {
            e.Property(x => x.Version).IsRowVersion();
            e.Property(x => x.TestValuesJson).HasColumnType("jsonb");
            e.Property(x => x.ProductionValuesJson).HasColumnType("jsonb");
            e.HasIndex(x => x.Provider).IsUnique();
        });

        b.Entity<IntegrationSecret>(e =>
        {
            e.Property(x => x.Name).HasMaxLength(64);
            e.Property(x => x.Ciphertext).HasMaxLength(4096);
            e.HasIndex(x => new { x.Provider, x.Mode, x.Name }).IsUnique();
        });

        b.Entity<AuditLogEntry>(e =>
        {
            e.Property(x => x.Action).HasMaxLength(64);
            e.Property(x => x.Target).HasMaxLength(128);
            e.Property(x => x.Details).HasMaxLength(2000);
            e.HasIndex(x => new { x.Target, x.CreatedAt });
        });

        b.Entity<Banner>(e =>
        {
            e.Property(x => x.Title).HasMaxLength(120);
            e.Property(x => x.Description).HasMaxLength(4000);
            e.HasIndex(x => new { x.IsActive, x.SortOrder });
        });

        b.Entity<BannerMedia>(e =>
        {
            e.Property(x => x.ContentType).HasMaxLength(32);
            e.HasIndex(x => new { x.BannerId, x.SortOrder });
            e.HasOne(x => x.Banner).WithMany(x => x.Media).HasForeignKey(x => x.BannerId).OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<ClientFace>(e =>
        {
            e.HasKey(x => x.ClientProfileId);
            e.HasOne(x => x.ClientProfile).WithOne().HasForeignKey<ClientFace>(x => x.ClientProfileId).OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<AccessDevice>(e =>
        {
            e.Property(x => x.Name).HasMaxLength(64);
            e.Property(x => x.BaseUrl).HasMaxLength(200);
            e.Property(x => x.Username).HasMaxLength(32);
            e.Property(x => x.PasswordCiphertext).HasMaxLength(512);
            e.Property(x => x.EventToken).HasMaxLength(64);
            e.Property(x => x.Model).HasMaxLength(64);
            e.Property(x => x.SerialNumber).HasMaxLength(64);
            e.Property(x => x.Firmware).HasMaxLength(64);
            e.Property(x => x.LastError).HasMaxLength(500);
            e.HasIndex(x => x.EventToken).IsUnique();
            e.ToTable(t => t.HasCheckConstraint("CK_AccessDevices_DoorNo", "\"DoorNo\" BETWEEN 1 AND 8"));
        });

        b.Entity<AccessDeviceUser>(e =>
        {
            e.HasKey(x => new { x.AccessDeviceId, x.ClientProfileId });
            e.Property(x => x.EmployeeNo).HasMaxLength(32);
            e.Property(x => x.AccessKey).HasMaxLength(200);
            e.Property(x => x.LastError).HasMaxLength(500);
            e.HasIndex(x => x.ClientProfileId);
            e.HasOne(x => x.Device).WithMany().HasForeignKey(x => x.AccessDeviceId).OnDelete(DeleteBehavior.Cascade);
            e.HasOne(x => x.ClientProfile).WithMany().HasForeignKey(x => x.ClientProfileId).OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<AccessEvent>(e =>
        {
            e.Property(x => x.DeviceName).HasMaxLength(64);
            e.Property(x => x.EmployeeNo).HasMaxLength(32);
            e.Property(x => x.Note).HasMaxLength(64);
            e.HasIndex(x => new { x.AccessDeviceId, x.SerialNo }).IsUnique().HasFilter("\"SerialNo\" IS NOT NULL");
            e.HasIndex(x => x.OccurredAt);
            e.HasIndex(x => new { x.ClientProfileId, x.OccurredAt });
            e.HasOne(x => x.Device).WithMany().HasForeignKey(x => x.AccessDeviceId).OnDelete(DeleteBehavior.SetNull);
            e.HasOne(x => x.ClientProfile).WithMany().HasForeignKey(x => x.ClientProfileId).OnDelete(DeleteBehavior.SetNull);
        });

        b.Entity<Notification>(e =>
        {
            e.Property(x => x.Payload).HasMaxLength(256);
            e.HasIndex(x => new { x.UserId, x.CreatedAt });
            e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        });

        // ---- Nutrition (AI Food Scanner, diary, analytics) ----
        b.Entity<FoodProduct>(e =>
        {
            e.Property(x => x.Key).HasMaxLength(64);
            e.Property(x => x.Name).HasMaxLength(160);
            e.Property(x => x.NameUz).HasMaxLength(160);
            e.Property(x => x.NameEn).HasMaxLength(200);
            e.Property(x => x.Brand).HasMaxLength(120);
            e.Property(x => x.SearchText).HasMaxLength(2000);
            e.Property(x => x.SourceRef).HasMaxLength(64);
            e.Property(x => x.IngredientsText).HasMaxLength(4000);
            e.PrimitiveCollection(x => x.Allergens).ElementType(t => t.HasConversion<string>().HasMaxLength(16));
            e.HasIndex(x => x.Key).IsUnique().HasFilter("\"Key\" IS NOT NULL");
            e.HasIndex(x => x.OwnerClientId);
            e.HasIndex(x => new { x.Source, x.SourceRef });
            e.HasOne<ClientProfile>().WithMany().HasForeignKey(x => x.OwnerClientId).OnDelete(DeleteBehavior.Restrict);
            e.ToTable(t =>
            {
                t.HasCheckConstraint("CK_FoodProducts_Values",
                    "\"Kcal\" BETWEEN 0 AND 950 AND \"Protein\" BETWEEN 0 AND 100 AND \"Fat\" BETWEEN 0 AND 100 AND \"Carbs\" BETWEEN 0 AND 100");
            });
        });

        b.Entity<FoodBarcode>(e =>
        {
            e.Property(x => x.Code).HasMaxLength(14);
            e.HasIndex(x => x.Code).IsUnique().HasFilter("\"OwnerClientId\" IS NULL").HasDatabaseName("IX_FoodBarcodes_SharedCode");
            e.HasIndex(x => new { x.OwnerClientId, x.Code }).IsUnique().HasFilter("\"OwnerClientId\" IS NOT NULL")
                .HasDatabaseName("IX_FoodBarcodes_OwnCode");
            e.HasOne(x => x.Product).WithMany().HasForeignKey(x => x.FoodProductId).OnDelete(DeleteBehavior.Cascade);
            e.HasOne<ClientProfile>().WithMany().HasForeignKey(x => x.OwnerClientId).OnDelete(DeleteBehavior.Restrict);
        });

        b.Entity<FoodRecipe>(e =>
        {
            e.Property(x => x.Key).HasMaxLength(64);
            e.Property(x => x.Name).HasMaxLength(160);
            e.Property(x => x.NameUz).HasMaxLength(160);
            e.Property(x => x.NameEn).HasMaxLength(200);
            e.Property(x => x.SearchText).HasMaxLength(2000);
            e.Property(x => x.DishKey).HasMaxLength(32);
            e.Property(x => x.Description).HasMaxLength(1000);
            e.HasIndex(x => x.Key).IsUnique().HasFilter("\"Key\" IS NOT NULL");
            e.HasIndex(x => x.OwnerClientId);
            e.HasIndex(x => x.DishKey);
            e.HasOne<ClientProfile>().WithMany().HasForeignKey(x => x.OwnerClientId).OnDelete(DeleteBehavior.Restrict);
        });

        b.Entity<FoodRecipeIngredient>(e =>
        {
            e.HasIndex(x => new { x.FoodRecipeId, x.SortOrder });
            e.HasIndex(x => x.FoodProductId);
            e.HasOne<FoodRecipe>().WithMany(r => r.Ingredients).HasForeignKey(x => x.FoodRecipeId).OnDelete(DeleteBehavior.Cascade);
            e.HasOne(x => x.Product).WithMany().HasForeignKey(x => x.FoodProductId).OnDelete(DeleteBehavior.Restrict);
            e.ToTable(t => t.HasCheckConstraint("CK_FoodRecipeIngredients_Grams", "\"Grams\" > 0"));
        });

        b.Entity<FoodScan>(e =>
        {
            e.Property(x => x.ImageHash).HasMaxLength(64);
            e.Property(x => x.Hint).HasMaxLength(200);
            e.Property(x => x.Barcode).HasMaxLength(14);
            e.Property(x => x.ImageQuality).HasMaxLength(16);
            e.Property(x => x.ClarificationQuestion).HasMaxLength(500);
            e.Property(x => x.ErrorCode).HasMaxLength(64);
            e.Property(x => x.AiModel).HasMaxLength(64);
            e.Property(x => x.AiResponseJson).HasColumnType("jsonb");
            e.HasIndex(x => new { x.ClientProfileId, x.CreatedAt });
            e.HasIndex(x => new { x.ClientProfileId, x.ImageHash });
            e.HasOne<ClientProfile>().WithMany().HasForeignKey(x => x.ClientProfileId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Product).WithMany().HasForeignKey(x => x.FoodProductId).OnDelete(DeleteBehavior.SetNull);
        });

        b.Entity<FoodRecognitionResult>(e =>
        {
            e.Property(x => x.Name).HasMaxLength(160);
            e.Property(x => x.NameUz).HasMaxLength(160);
            e.Property(x => x.NameEn).HasMaxLength(160);
            e.Property(x => x.TraditionalDishKey).HasMaxLength(32);
            e.Property(x => x.PreparationNote).HasMaxLength(200);
            e.Property(x => x.Notes).HasMaxLength(500);
            e.Property(x => x.Confidence).HasPrecision(3, 2);
            e.PrimitiveCollection(x => x.PossibleAllergens).ElementType(t => t.HasConversion<string>().HasMaxLength(16));
            e.HasIndex(x => new { x.FoodScanId, x.DishIndex }).IsUnique();
            e.HasOne(x => x.Scan).WithMany(s => s.Results).HasForeignKey(x => x.FoodScanId).OnDelete(DeleteBehavior.Cascade);
            e.ToTable(t => t.HasCheckConstraint("CK_FoodRecognitionResults_Confidence", "\"Confidence\" BETWEEN 0 AND 1"));
        });

        b.Entity<FoodRecognitionIngredient>(e =>
        {
            e.Property(x => x.Name).HasMaxLength(120);
            e.Property(x => x.SourceRef).HasMaxLength(64);
            e.Property(x => x.Uncertainty).HasPrecision(4, 2);
            e.HasIndex(x => new { x.FoodRecognitionResultId, x.SortOrder });
            e.HasIndex(x => x.FoodProductId);
            e.HasOne<FoodRecognitionResult>().WithMany(r => r.Ingredients).HasForeignKey(x => x.FoodRecognitionResultId)
                .OnDelete(DeleteBehavior.Cascade);
            e.HasOne(x => x.Product).WithMany().HasForeignKey(x => x.FoodProductId).OnDelete(DeleteBehavior.SetNull);
            e.ToTable(t => t.HasCheckConstraint("CK_FoodRecognitionIngredients_Grams", "\"Grams\" > 0"));
        });

        b.Entity<FoodDiaryEntry>(e =>
        {
            e.Property(x => x.Name).HasMaxLength(160);
            e.HasIndex(x => new { x.ClientProfileId, x.Date, x.MealType });
            e.HasIndex(x => new { x.ClientProfileId, x.CreatedAt });
            e.HasIndex(x => x.FoodScanId);
            e.HasOne<ClientProfile>().WithMany().HasForeignKey(x => x.ClientProfileId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Scan).WithMany().HasForeignKey(x => x.FoodScanId).OnDelete(DeleteBehavior.SetNull);
        });

        b.Entity<FoodDiaryItem>(e =>
        {
            e.Property(x => x.Name).HasMaxLength(120);
            e.Property(x => x.SourceRef).HasMaxLength(64);
            e.Property(x => x.Uncertainty).HasPrecision(4, 2);
            e.HasIndex(x => new { x.FoodDiaryEntryId, x.SortOrder });
            e.HasIndex(x => x.FoodProductId);
            e.HasIndex(x => x.FoodRecipeId);
            e.HasOne<FoodDiaryEntry>().WithMany(d => d.Items).HasForeignKey(x => x.FoodDiaryEntryId).OnDelete(DeleteBehavior.Cascade);
            e.HasOne<FoodProduct>().WithMany().HasForeignKey(x => x.FoodProductId).OnDelete(DeleteBehavior.SetNull);
            e.HasOne<FoodRecipe>().WithMany().HasForeignKey(x => x.FoodRecipeId).OnDelete(DeleteBehavior.SetNull);
            e.ToTable(t => t.HasCheckConstraint("CK_FoodDiaryItems_Grams", "\"Grams\" > 0"));
        });

        b.Entity<NutritionProfile>(e =>
        {
            e.Property(x => x.Restrictions).HasMaxLength(500);
            e.Property(x => x.AiConsentProvider).HasMaxLength(16);
            e.Property(x => x.WeightKg).HasPrecision(5, 1);
            e.Property(x => x.HeightCm).HasPrecision(5, 1);
            e.PrimitiveCollection(x => x.Allergies).ElementType(t => t.HasConversion<string>().HasMaxLength(16));
            e.HasIndex(x => x.ClientProfileId).IsUnique();
            e.HasOne<ClientProfile>().WithOne().HasForeignKey<NutritionProfile>(x => x.ClientProfileId).OnDelete(DeleteBehavior.Restrict);
            e.ToTable(t =>
            {
                t.HasCheckConstraint("CK_NutritionProfiles_Weight", "\"WeightKg\" IS NULL OR \"WeightKg\" BETWEEN 25 AND 350");
                t.HasCheckConstraint("CK_NutritionProfiles_Height", "\"HeightCm\" IS NULL OR \"HeightCm\" BETWEEN 100 AND 250");
                t.HasCheckConstraint("CK_NutritionProfiles_Target", "\"CustomKcalTarget\" IS NULL OR \"CustomKcalTarget\" BETWEEN 800 AND 6000");
            });
        });

        b.Entity<NutritionDailySummary>(e =>
        {
            e.HasIndex(x => new { x.ClientProfileId, x.Date }).IsUnique();
            e.HasOne<ClientProfile>().WithMany().HasForeignKey(x => x.ClientProfileId).OnDelete(DeleteBehavior.Restrict);
        });

        b.Entity<NutritionReport>(e =>
        {
            e.Property(x => x.Locale).HasMaxLength(8);
            e.Property(x => x.InputHash).HasMaxLength(64);
            e.Property(x => x.Text).HasMaxLength(8000);
            e.Property(x => x.AiModel).HasMaxLength(64);
            e.HasIndex(x => new { x.ClientProfileId, x.Period, x.FromDate, x.Locale });
            e.HasOne<ClientProfile>().WithMany().HasForeignKey(x => x.ClientProfileId).OnDelete(DeleteBehavior.Restrict);
        });

        b.Entity<AiProviderSettings>(e =>
        {
            e.Property(x => x.Version).IsRowVersion();
            e.Property(x => x.Provider).HasMaxLength(16);
            e.Property(x => x.OpenAiKeyCiphertext).HasMaxLength(4096);
            e.Property(x => x.AnthropicKeyCiphertext).HasMaxLength(4096);
            e.Property(x => x.VisionModel).HasMaxLength(64);
            e.Property(x => x.ChatModel).HasMaxLength(64);
            e.Property(x => x.MonthlyBudgetUsd).HasPrecision(10, 2);
            e.Property(x => x.LastCheckJson).HasColumnType("jsonb");
        });

        b.Entity<AiUsageRecord>(e =>
        {
            e.ToTable("AiUsage");
            e.Property(x => x.Provider).HasMaxLength(32);
            e.Property(x => x.Model).HasMaxLength(64);
            e.Property(x => x.ErrorCode).HasMaxLength(64);
            e.Property(x => x.CostUsd).HasPrecision(12, 6);
            e.HasIndex(x => new { x.ClientProfileId, x.Feature, x.CreatedAt });
            e.HasIndex(x => x.CreatedAt);
            // Usage stays after an account is deleted (spending history), without the link to the person.
            e.HasOne<ClientProfile>().WithMany().HasForeignKey(x => x.ClientProfileId).OnDelete(DeleteBehavior.SetNull);
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
