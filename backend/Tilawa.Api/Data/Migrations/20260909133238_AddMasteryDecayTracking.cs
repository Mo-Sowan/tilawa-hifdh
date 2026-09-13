using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tilawa.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddMasteryDecayTracking : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "ConsecutiveGoodReviews",
                table: "UserSurahProgress",
                type: "INTEGER",
                nullable: false,
                defaultValue: 0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ConsecutiveGoodReviews",
                table: "UserSurahProgress");
        }
    }
}
