using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitnessFormulasi.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddAiProviderSettings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "AiConsentProvider",
                table: "NutritionProfiles",
                type: "character varying(16)",
                maxLength: 16,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "AiProviderSettings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    IsEnabled = table.Column<bool>(type: "boolean", nullable: false),
                    Provider = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    OpenAiKeyCiphertext = table.Column<string>(type: "character varying(4096)", maxLength: 4096, nullable: true),
                    OpenAiKeySetAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    AnthropicKeyCiphertext = table.Column<string>(type: "character varying(4096)", maxLength: 4096, nullable: true),
                    AnthropicKeySetAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    VisionModel = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    ChatModel = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    MonthlyBudgetUsd = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    ConfigChangedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    UpdatedByUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    LastCheckAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    LastCheckOk = table.Column<bool>(type: "boolean", nullable: true),
                    LastCheckJson = table.Column<string>(type: "jsonb", nullable: true),
                    xmin = table.Column<uint>(type: "xid", rowVersion: true, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AiProviderSettings", x => x.Id);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AiProviderSettings");

            migrationBuilder.DropColumn(
                name: "AiConsentProvider",
                table: "NutritionProfiles");
        }
    }
}
