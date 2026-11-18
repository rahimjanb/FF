using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitnessFormulasi.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddBannersFreezeRulesTrainerContacts : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Instagram",
                table: "TrainerProfiles",
                type: "character varying(30)",
                maxLength: 30,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Telegram",
                table: "TrainerProfiles",
                type: "character varying(32)",
                maxLength: 32,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "WithoutTrainer",
                table: "ClientProfiles",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateTable(
                name: "Banners",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Title = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    Description = table.Column<string>(type: "character varying(4000)", maxLength: 4000, nullable: true),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    SortOrder = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Banners", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "BannerMedia",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    BannerId = table.Column<Guid>(type: "uuid", nullable: false),
                    Kind = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    ContentType = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    SizeBytes = table.Column<long>(type: "bigint", nullable: false),
                    SortOrder = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BannerMedia", x => x.Id);
                    table.ForeignKey(
                        name: "FK_BannerMedia_Banners_BannerId",
                        column: x => x.BannerId,
                        principalTable: "Banners",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_BannerMedia_BannerId_SortOrder",
                table: "BannerMedia",
                columns: new[] { "BannerId", "SortOrder" });

            migrationBuilder.CreateIndex(
                name: "IX_Banners_IsActive_SortOrder",
                table: "Banners",
                columns: new[] { "IsActive", "SortOrder" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "BannerMedia");

            migrationBuilder.DropTable(
                name: "Banners");

            migrationBuilder.DropColumn(
                name: "Instagram",
                table: "TrainerProfiles");

            migrationBuilder.DropColumn(
                name: "Telegram",
                table: "TrainerProfiles");

            migrationBuilder.DropColumn(
                name: "WithoutTrainer",
                table: "ClientProfiles");
        }
    }
}
