using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitnessFormulasi.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddFaceAccess : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateSequence<int>(
                name: "ClientAccessNumbers",
                startValue: 1001L);

            migrationBuilder.AddColumn<int>(
                name: "AccessNo",
                table: "ClientProfiles",
                type: "integer",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "AccessDevices",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    BaseUrl = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Username = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    PasswordCiphertext = table.Column<string>(type: "character varying(512)", maxLength: 512, nullable: true),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    RecordsVisits = table.Column<bool>(type: "boolean", nullable: false),
                    DoorNo = table.Column<int>(type: "integer", nullable: false),
                    EventToken = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Model = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    SerialNumber = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    Firmware = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    LastContactAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    LastEventAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    LastError = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    LastErrorAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AccessDevices", x => x.Id);
                    table.CheckConstraint("CK_AccessDevices_DoorNo", "\"DoorNo\" BETWEEN 1 AND 8");
                });

            migrationBuilder.CreateTable(
                name: "ClientFaces",
                columns: table => new
                {
                    ClientProfileId = table.Column<Guid>(type: "uuid", nullable: false),
                    Data = table.Column<byte[]>(type: "bytea", nullable: false),
                    Version = table.Column<int>(type: "integer", nullable: false),
                    UploadedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UploadedByUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    ConsentAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ClientFaces", x => x.ClientProfileId);
                    table.ForeignKey(
                        name: "FK_ClientFaces_ClientProfiles_ClientProfileId",
                        column: x => x.ClientProfileId,
                        principalTable: "ClientProfiles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "AccessDeviceUsers",
                columns: table => new
                {
                    AccessDeviceId = table.Column<Guid>(type: "uuid", nullable: false),
                    ClientProfileId = table.Column<Guid>(type: "uuid", nullable: false),
                    EmployeeNo = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    AccessKey = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    FaceVersion = table.Column<int>(type: "integer", nullable: false),
                    RejectedFaceVersion = table.Column<int>(type: "integer", nullable: true),
                    State = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    LastError = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    FailedAttempts = table.Column<int>(type: "integer", nullable: false),
                    RetryAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    SyncedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AccessDeviceUsers", x => new { x.AccessDeviceId, x.ClientProfileId });
                    table.ForeignKey(
                        name: "FK_AccessDeviceUsers_AccessDevices_AccessDeviceId",
                        column: x => x.AccessDeviceId,
                        principalTable: "AccessDevices",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_AccessDeviceUsers_ClientProfiles_ClientProfileId",
                        column: x => x.ClientProfileId,
                        principalTable: "ClientProfiles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "AccessEvents",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    AccessDeviceId = table.Column<Guid>(type: "uuid", nullable: true),
                    DeviceName = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    SerialNo = table.Column<long>(type: "bigint", nullable: true),
                    OccurredAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    Major = table.Column<int>(type: "integer", nullable: false),
                    Minor = table.Column<int>(type: "integer", nullable: false),
                    Granted = table.Column<bool>(type: "boolean", nullable: false),
                    EmployeeNo = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: true),
                    ClientProfileId = table.Column<Guid>(type: "uuid", nullable: true),
                    VisitId = table.Column<Guid>(type: "uuid", nullable: true),
                    Note = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AccessEvents", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AccessEvents_AccessDevices_AccessDeviceId",
                        column: x => x.AccessDeviceId,
                        principalTable: "AccessDevices",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_AccessEvents_ClientProfiles_ClientProfileId",
                        column: x => x.ClientProfileId,
                        principalTable: "ClientProfiles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ClientProfiles_AccessNo",
                table: "ClientProfiles",
                column: "AccessNo",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_AccessDevices_EventToken",
                table: "AccessDevices",
                column: "EventToken",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_AccessDeviceUsers_ClientProfileId",
                table: "AccessDeviceUsers",
                column: "ClientProfileId");

            migrationBuilder.CreateIndex(
                name: "IX_AccessEvents_AccessDeviceId_SerialNo",
                table: "AccessEvents",
                columns: new[] { "AccessDeviceId", "SerialNo" },
                unique: true,
                filter: "\"SerialNo\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_AccessEvents_ClientProfileId_OccurredAt",
                table: "AccessEvents",
                columns: new[] { "ClientProfileId", "OccurredAt" });

            migrationBuilder.CreateIndex(
                name: "IX_AccessEvents_OccurredAt",
                table: "AccessEvents",
                column: "OccurredAt");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AccessDeviceUsers");

            migrationBuilder.DropTable(
                name: "AccessEvents");

            migrationBuilder.DropTable(
                name: "ClientFaces");

            migrationBuilder.DropTable(
                name: "AccessDevices");

            migrationBuilder.DropIndex(
                name: "IX_ClientProfiles_AccessNo",
                table: "ClientProfiles");

            migrationBuilder.DropColumn(
                name: "AccessNo",
                table: "ClientProfiles");

            migrationBuilder.DropSequence(
                name: "ClientAccessNumbers");
        }
    }
}
