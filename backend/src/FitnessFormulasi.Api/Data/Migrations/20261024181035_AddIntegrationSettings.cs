using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitnessFormulasi.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddIntegrationSettings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "CanManageIntegrations",
                table: "Users",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateTable(
                name: "AuditLog",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: true),
                    Action = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Target = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    Details = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AuditLog", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "IntegrationSecrets",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Provider = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    Mode = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    Name = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Ciphertext = table.Column<string>(type: "character varying(4096)", maxLength: 4096, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_IntegrationSecrets", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "IntegrationSettings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Provider = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    IsEnabled = table.Column<bool>(type: "boolean", nullable: false),
                    Mode = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    TestValuesJson = table.Column<string>(type: "jsonb", nullable: false),
                    ProductionValuesJson = table.Column<string>(type: "jsonb", nullable: false),
                    ConfigChangedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    LastVerifiedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    UpdatedByUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    xmin = table.Column<uint>(type: "xid", rowVersion: true, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_IntegrationSettings", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_AuditLog_Target_CreatedAt",
                table: "AuditLog",
                columns: new[] { "Target", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_IntegrationSecrets_Provider_Mode_Name",
                table: "IntegrationSecrets",
                columns: new[] { "Provider", "Mode", "Name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_IntegrationSettings_Provider",
                table: "IntegrationSettings",
                column: "Provider",
                unique: true);

            // Existing installations: the first administrator (the bootstrap one) keeps access to the new settings.
            migrationBuilder.Sql(@"UPDATE ""Users"" SET ""CanManageIntegrations"" = TRUE
                WHERE ""Id"" = (SELECT u.""Id"" FROM ""Users"" u JOIN ""Roles"" r ON r.""Id"" = u.""RoleId""
                                WHERE r.""Name"" = 'Admin' ORDER BY u.""CreatedAt"" LIMIT 1);");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AuditLog");

            migrationBuilder.DropTable(
                name: "IntegrationSecrets");

            migrationBuilder.DropTable(
                name: "IntegrationSettings");

            migrationBuilder.DropColumn(
                name: "CanManageIntegrations",
                table: "Users");
        }
    }
}
