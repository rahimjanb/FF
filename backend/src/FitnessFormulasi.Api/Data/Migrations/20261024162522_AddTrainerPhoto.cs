using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FitnessFormulasi.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddTrainerPhoto : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "PhotoVersion",
                table: "TrainerProfiles",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateTable(
                name: "TrainerPhotos",
                columns: table => new
                {
                    TrainerProfileId = table.Column<Guid>(type: "uuid", nullable: false),
                    Data = table.Column<byte[]>(type: "bytea", nullable: false),
                    ContentType = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TrainerPhotos", x => x.TrainerProfileId);
                    table.ForeignKey(
                        name: "FK_TrainerPhotos_TrainerProfiles_TrainerProfileId",
                        column: x => x.TrainerProfileId,
                        principalTable: "TrainerProfiles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "TrainerPhotos");

            migrationBuilder.DropColumn(
                name: "PhotoVersion",
                table: "TrainerProfiles");
        }
    }
}
