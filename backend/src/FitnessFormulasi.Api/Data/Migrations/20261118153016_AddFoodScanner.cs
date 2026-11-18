using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitnessFormulasi.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddFoodScanner : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "AiUsage",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ClientProfileId = table.Column<Guid>(type: "uuid", nullable: true),
                    Feature = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    Provider = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    Model = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    InputTokens = table.Column<int>(type: "integer", nullable: false),
                    OutputTokens = table.Column<int>(type: "integer", nullable: false),
                    CacheReadTokens = table.Column<int>(type: "integer", nullable: false),
                    CacheWriteTokens = table.Column<int>(type: "integer", nullable: false),
                    CostUsd = table.Column<decimal>(type: "numeric(12,6)", precision: 12, scale: 6, nullable: false),
                    DurationMs = table.Column<int>(type: "integer", nullable: false),
                    Success = table.Column<bool>(type: "boolean", nullable: false),
                    ErrorCode = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AiUsage", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AiUsage_ClientProfiles_ClientProfileId",
                        column: x => x.ClientProfileId,
                        principalTable: "ClientProfiles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "FoodProducts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Key = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    Name = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: false),
                    NameUz = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: true),
                    NameEn = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    Brand = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: true),
                    Aliases = table.Column<List<string>>(type: "text[]", nullable: false),
                    SearchText = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: false),
                    Category = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    Kcal = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Protein = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Fat = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Carbs = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Fiber = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    Sugar = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    SaturatedFat = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    SodiumMg = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    Per100Ml = table.Column<bool>(type: "boolean", nullable: false),
                    Source = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    SourceRef = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    ServingGrams = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    PackageGrams = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    Allergens = table.Column<string[]>(type: "character varying(16)[]", nullable: false),
                    IngredientsText = table.Column<string>(type: "character varying(4000)", maxLength: 4000, nullable: true),
                    OwnerClientId = table.Column<Guid>(type: "uuid", nullable: true),
                    FetchedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_FoodProducts", x => x.Id);
                    table.CheckConstraint("CK_FoodProducts_Values", "\"Kcal\" BETWEEN 0 AND 950 AND \"Protein\" BETWEEN 0 AND 100 AND \"Fat\" BETWEEN 0 AND 100 AND \"Carbs\" BETWEEN 0 AND 100");
                    table.ForeignKey(
                        name: "FK_FoodProducts_ClientProfiles_OwnerClientId",
                        column: x => x.OwnerClientId,
                        principalTable: "ClientProfiles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "FoodRecipes",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Key = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    Name = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: false),
                    NameUz = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: true),
                    NameEn = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    Aliases = table.Column<List<string>>(type: "text[]", nullable: false),
                    SearchText = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: false),
                    Category = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    DishKey = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: true),
                    IsTraditional = table.Column<bool>(type: "boolean", nullable: false),
                    Description = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    PortionGrams = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    YieldGrams = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    OwnerClientId = table.Column<Guid>(type: "uuid", nullable: true),
                    Kcal = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Protein = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Fat = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Carbs = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Fiber = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    Sugar = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    SaturatedFat = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    SodiumMg = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_FoodRecipes", x => x.Id);
                    table.ForeignKey(
                        name: "FK_FoodRecipes_ClientProfiles_OwnerClientId",
                        column: x => x.OwnerClientId,
                        principalTable: "ClientProfiles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "NutritionDailySummaries",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ClientProfileId = table.Column<Guid>(type: "uuid", nullable: false),
                    Date = table.Column<DateOnly>(type: "date", nullable: false),
                    Entries = table.Column<int>(type: "integer", nullable: false),
                    Kcal = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Protein = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Fat = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Carbs = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Fiber = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Sugar = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    SaturatedFat = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    SodiumMg = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Incomplete = table.Column<bool>(type: "boolean", nullable: false),
                    TargetKcal = table.Column<int>(type: "integer", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NutritionDailySummaries", x => x.Id);
                    table.ForeignKey(
                        name: "FK_NutritionDailySummaries_ClientProfiles_ClientProfileId",
                        column: x => x.ClientProfileId,
                        principalTable: "ClientProfiles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "NutritionProfiles",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ClientProfileId = table.Column<Guid>(type: "uuid", nullable: false),
                    Goal = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: true),
                    WeightKg = table.Column<decimal>(type: "numeric(5,1)", precision: 5, scale: 1, nullable: true),
                    HeightCm = table.Column<decimal>(type: "numeric(5,1)", precision: 5, scale: 1, nullable: true),
                    Activity = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: true),
                    CustomKcalTarget = table.Column<int>(type: "integer", nullable: true),
                    Restrictions = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    Allergies = table.Column<string[]>(type: "character varying(16)[]", nullable: false),
                    AiConsentAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NutritionProfiles", x => x.Id);
                    table.CheckConstraint("CK_NutritionProfiles_Height", "\"HeightCm\" IS NULL OR \"HeightCm\" BETWEEN 100 AND 250");
                    table.CheckConstraint("CK_NutritionProfiles_Target", "\"CustomKcalTarget\" IS NULL OR \"CustomKcalTarget\" BETWEEN 800 AND 6000");
                    table.CheckConstraint("CK_NutritionProfiles_Weight", "\"WeightKg\" IS NULL OR \"WeightKg\" BETWEEN 25 AND 350");
                    table.ForeignKey(
                        name: "FK_NutritionProfiles_ClientProfiles_ClientProfileId",
                        column: x => x.ClientProfileId,
                        principalTable: "ClientProfiles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "NutritionReports",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ClientProfileId = table.Column<Guid>(type: "uuid", nullable: false),
                    Period = table.Column<string>(type: "character varying(8)", maxLength: 8, nullable: false),
                    FromDate = table.Column<DateOnly>(type: "date", nullable: false),
                    ToDate = table.Column<DateOnly>(type: "date", nullable: false),
                    Locale = table.Column<string>(type: "character varying(8)", maxLength: 8, nullable: false),
                    InputHash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Text = table.Column<string>(type: "character varying(8000)", maxLength: 8000, nullable: false),
                    AiModel = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NutritionReports", x => x.Id);
                    table.ForeignKey(
                        name: "FK_NutritionReports_ClientProfiles_ClientProfileId",
                        column: x => x.ClientProfileId,
                        principalTable: "ClientProfiles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "FoodBarcodes",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Code = table.Column<string>(type: "character varying(14)", maxLength: 14, nullable: false),
                    FoodProductId = table.Column<Guid>(type: "uuid", nullable: true),
                    NotFound = table.Column<bool>(type: "boolean", nullable: false),
                    CheckedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    OwnerClientId = table.Column<Guid>(type: "uuid", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_FoodBarcodes", x => x.Id);
                    table.ForeignKey(
                        name: "FK_FoodBarcodes_ClientProfiles_OwnerClientId",
                        column: x => x.OwnerClientId,
                        principalTable: "ClientProfiles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_FoodBarcodes_FoodProducts_FoodProductId",
                        column: x => x.FoodProductId,
                        principalTable: "FoodProducts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "FoodScans",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ClientProfileId = table.Column<Guid>(type: "uuid", nullable: false),
                    Kind = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    Status = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    PhotoId = table.Column<Guid>(type: "uuid", nullable: true),
                    ImageHash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    Hint = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    Barcode = table.Column<string>(type: "character varying(14)", maxLength: 14, nullable: true),
                    FoodProductId = table.Column<Guid>(type: "uuid", nullable: true),
                    ImageQuality = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: true),
                    ClarificationQuestion = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    ErrorCode = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    AiModel = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    AiResponseJson = table.Column<string>(type: "jsonb", nullable: true),
                    AddedToDiaryAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_FoodScans", x => x.Id);
                    table.ForeignKey(
                        name: "FK_FoodScans_ClientProfiles_ClientProfileId",
                        column: x => x.ClientProfileId,
                        principalTable: "ClientProfiles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_FoodScans_FoodProducts_FoodProductId",
                        column: x => x.FoodProductId,
                        principalTable: "FoodProducts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "FoodRecipeIngredients",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    FoodRecipeId = table.Column<Guid>(type: "uuid", nullable: false),
                    FoodProductId = table.Column<Guid>(type: "uuid", nullable: false),
                    Grams = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Role = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    SortOrder = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_FoodRecipeIngredients", x => x.Id);
                    table.CheckConstraint("CK_FoodRecipeIngredients_Grams", "\"Grams\" > 0");
                    table.ForeignKey(
                        name: "FK_FoodRecipeIngredients_FoodProducts_FoodProductId",
                        column: x => x.FoodProductId,
                        principalTable: "FoodProducts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_FoodRecipeIngredients_FoodRecipes_FoodRecipeId",
                        column: x => x.FoodRecipeId,
                        principalTable: "FoodRecipes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "FoodDiaryEntries",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ClientProfileId = table.Column<Guid>(type: "uuid", nullable: false),
                    Date = table.Column<DateOnly>(type: "date", nullable: false),
                    MealType = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    EatenAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    Name = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: false),
                    FoodScanId = table.Column<Guid>(type: "uuid", nullable: true),
                    Grams = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Kcal = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    KcalMin = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    KcalMax = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Protein = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Fat = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Carbs = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Fiber = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    Sugar = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    SaturatedFat = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    SodiumMg = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    NutritionIncomplete = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_FoodDiaryEntries", x => x.Id);
                    table.ForeignKey(
                        name: "FK_FoodDiaryEntries_ClientProfiles_ClientProfileId",
                        column: x => x.ClientProfileId,
                        principalTable: "ClientProfiles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_FoodDiaryEntries_FoodScans_FoodScanId",
                        column: x => x.FoodScanId,
                        principalTable: "FoodScans",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "FoodRecognitionResults",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    FoodScanId = table.Column<Guid>(type: "uuid", nullable: false),
                    DishIndex = table.Column<int>(type: "integer", nullable: false),
                    Name = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: false),
                    NameUz = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: true),
                    NameEn = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: true),
                    Category = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    TraditionalDishKey = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: true),
                    Confidence = table.Column<decimal>(type: "numeric(3,2)", precision: 3, scale: 2, nullable: false),
                    EstimatedWeightGrams = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    WeightConfidence = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    PreparationMethod = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    PreparationNote = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    PossibleAllergens = table.Column<string[]>(type: "character varying(16)[]", nullable: false),
                    NeedsConfirmation = table.Column<bool>(type: "boolean", nullable: false),
                    Notes = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    UserEdited = table.Column<bool>(type: "boolean", nullable: false),
                    Grams = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Kcal = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    KcalMin = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    KcalMax = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Protein = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Fat = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Carbs = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Fiber = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    Sugar = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    SaturatedFat = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    SodiumMg = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    NutritionIncomplete = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_FoodRecognitionResults", x => x.Id);
                    table.CheckConstraint("CK_FoodRecognitionResults_Confidence", "\"Confidence\" BETWEEN 0 AND 1");
                    table.ForeignKey(
                        name: "FK_FoodRecognitionResults_FoodScans_FoodScanId",
                        column: x => x.FoodScanId,
                        principalTable: "FoodScans",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "FoodDiaryItems",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    FoodDiaryEntryId = table.Column<Guid>(type: "uuid", nullable: false),
                    SortOrder = table.Column<int>(type: "integer", nullable: false),
                    Name = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    FoodProductId = table.Column<Guid>(type: "uuid", nullable: true),
                    FoodRecipeId = table.Column<Guid>(type: "uuid", nullable: true),
                    Grams = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Role = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    Uncertainty = table.Column<decimal>(type: "numeric(4,2)", precision: 4, scale: 2, nullable: false),
                    Kcal = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    Protein = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    Fat = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    Carbs = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    Fiber = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    Sugar = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    SaturatedFat = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    SodiumMg = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    Source = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: true),
                    SourceRef = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_FoodDiaryItems", x => x.Id);
                    table.CheckConstraint("CK_FoodDiaryItems_Grams", "\"Grams\" > 0");
                    table.ForeignKey(
                        name: "FK_FoodDiaryItems_FoodDiaryEntries_FoodDiaryEntryId",
                        column: x => x.FoodDiaryEntryId,
                        principalTable: "FoodDiaryEntries",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_FoodDiaryItems_FoodProducts_FoodProductId",
                        column: x => x.FoodProductId,
                        principalTable: "FoodProducts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_FoodDiaryItems_FoodRecipes_FoodRecipeId",
                        column: x => x.FoodRecipeId,
                        principalTable: "FoodRecipes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "FoodRecognitionIngredients",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    FoodRecognitionResultId = table.Column<Guid>(type: "uuid", nullable: false),
                    SortOrder = table.Column<int>(type: "integer", nullable: false),
                    Name = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    FoodProductId = table.Column<Guid>(type: "uuid", nullable: true),
                    Grams = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Role = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    Match = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    Uncertainty = table.Column<decimal>(type: "numeric(4,2)", precision: 4, scale: 2, nullable: false),
                    Kcal = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    Protein = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    Fat = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    Carbs = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    Fiber = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    Sugar = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    SaturatedFat = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    SodiumMg = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    Source = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: true),
                    SourceRef = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_FoodRecognitionIngredients", x => x.Id);
                    table.CheckConstraint("CK_FoodRecognitionIngredients_Grams", "\"Grams\" > 0");
                    table.ForeignKey(
                        name: "FK_FoodRecognitionIngredients_FoodProducts_FoodProductId",
                        column: x => x.FoodProductId,
                        principalTable: "FoodProducts",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_FoodRecognitionIngredients_FoodRecognitionResults_FoodRecog~",
                        column: x => x.FoodRecognitionResultId,
                        principalTable: "FoodRecognitionResults",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_AiUsage_ClientProfileId_Feature_CreatedAt",
                table: "AiUsage",
                columns: new[] { "ClientProfileId", "Feature", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_AiUsage_CreatedAt",
                table: "AiUsage",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_FoodBarcodes_FoodProductId",
                table: "FoodBarcodes",
                column: "FoodProductId");

            migrationBuilder.CreateIndex(
                name: "IX_FoodBarcodes_OwnCode",
                table: "FoodBarcodes",
                columns: new[] { "OwnerClientId", "Code" },
                unique: true,
                filter: "\"OwnerClientId\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_FoodBarcodes_SharedCode",
                table: "FoodBarcodes",
                column: "Code",
                unique: true,
                filter: "\"OwnerClientId\" IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_FoodDiaryEntries_ClientProfileId_CreatedAt",
                table: "FoodDiaryEntries",
                columns: new[] { "ClientProfileId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_FoodDiaryEntries_ClientProfileId_Date_MealType",
                table: "FoodDiaryEntries",
                columns: new[] { "ClientProfileId", "Date", "MealType" });

            migrationBuilder.CreateIndex(
                name: "IX_FoodDiaryEntries_FoodScanId",
                table: "FoodDiaryEntries",
                column: "FoodScanId");

            migrationBuilder.CreateIndex(
                name: "IX_FoodDiaryItems_FoodDiaryEntryId_SortOrder",
                table: "FoodDiaryItems",
                columns: new[] { "FoodDiaryEntryId", "SortOrder" });

            migrationBuilder.CreateIndex(
                name: "IX_FoodDiaryItems_FoodProductId",
                table: "FoodDiaryItems",
                column: "FoodProductId");

            migrationBuilder.CreateIndex(
                name: "IX_FoodDiaryItems_FoodRecipeId",
                table: "FoodDiaryItems",
                column: "FoodRecipeId");

            migrationBuilder.CreateIndex(
                name: "IX_FoodProducts_Key",
                table: "FoodProducts",
                column: "Key",
                unique: true,
                filter: "\"Key\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_FoodProducts_OwnerClientId",
                table: "FoodProducts",
                column: "OwnerClientId");

            migrationBuilder.CreateIndex(
                name: "IX_FoodProducts_Source_SourceRef",
                table: "FoodProducts",
                columns: new[] { "Source", "SourceRef" });

            migrationBuilder.CreateIndex(
                name: "IX_FoodRecipeIngredients_FoodProductId",
                table: "FoodRecipeIngredients",
                column: "FoodProductId");

            migrationBuilder.CreateIndex(
                name: "IX_FoodRecipeIngredients_FoodRecipeId_SortOrder",
                table: "FoodRecipeIngredients",
                columns: new[] { "FoodRecipeId", "SortOrder" });

            migrationBuilder.CreateIndex(
                name: "IX_FoodRecipes_DishKey",
                table: "FoodRecipes",
                column: "DishKey");

            migrationBuilder.CreateIndex(
                name: "IX_FoodRecipes_Key",
                table: "FoodRecipes",
                column: "Key",
                unique: true,
                filter: "\"Key\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_FoodRecipes_OwnerClientId",
                table: "FoodRecipes",
                column: "OwnerClientId");

            migrationBuilder.CreateIndex(
                name: "IX_FoodRecognitionIngredients_FoodProductId",
                table: "FoodRecognitionIngredients",
                column: "FoodProductId");

            migrationBuilder.CreateIndex(
                name: "IX_FoodRecognitionIngredients_FoodRecognitionResultId_SortOrder",
                table: "FoodRecognitionIngredients",
                columns: new[] { "FoodRecognitionResultId", "SortOrder" });

            migrationBuilder.CreateIndex(
                name: "IX_FoodRecognitionResults_FoodScanId_DishIndex",
                table: "FoodRecognitionResults",
                columns: new[] { "FoodScanId", "DishIndex" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_FoodScans_ClientProfileId_CreatedAt",
                table: "FoodScans",
                columns: new[] { "ClientProfileId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_FoodScans_ClientProfileId_ImageHash",
                table: "FoodScans",
                columns: new[] { "ClientProfileId", "ImageHash" });

            migrationBuilder.CreateIndex(
                name: "IX_FoodScans_FoodProductId",
                table: "FoodScans",
                column: "FoodProductId");

            migrationBuilder.CreateIndex(
                name: "IX_NutritionDailySummaries_ClientProfileId_Date",
                table: "NutritionDailySummaries",
                columns: new[] { "ClientProfileId", "Date" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_NutritionProfiles_ClientProfileId",
                table: "NutritionProfiles",
                column: "ClientProfileId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_NutritionReports_ClientProfileId_Period_FromDate_Locale",
                table: "NutritionReports",
                columns: new[] { "ClientProfileId", "Period", "FromDate", "Locale" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AiUsage");

            migrationBuilder.DropTable(
                name: "FoodBarcodes");

            migrationBuilder.DropTable(
                name: "FoodDiaryItems");

            migrationBuilder.DropTable(
                name: "FoodRecipeIngredients");

            migrationBuilder.DropTable(
                name: "FoodRecognitionIngredients");

            migrationBuilder.DropTable(
                name: "NutritionDailySummaries");

            migrationBuilder.DropTable(
                name: "NutritionProfiles");

            migrationBuilder.DropTable(
                name: "NutritionReports");

            migrationBuilder.DropTable(
                name: "FoodDiaryEntries");

            migrationBuilder.DropTable(
                name: "FoodRecipes");

            migrationBuilder.DropTable(
                name: "FoodRecognitionResults");

            migrationBuilder.DropTable(
                name: "FoodScans");

            migrationBuilder.DropTable(
                name: "FoodProducts");
        }
    }
}
