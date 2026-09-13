using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Tilawa.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class InitialSchema : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Surahs",
                columns: table => new
                {
                    Number = table.Column<int>(type: "INTEGER", nullable: false),
                    EnglishName = table.Column<string>(type: "TEXT", nullable: false),
                    ArabicName = table.Column<string>(type: "TEXT", nullable: false),
                    JuzLabel = table.Column<string>(type: "TEXT", nullable: false),
                    AyahCount = table.Column<int>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Surahs", x => x.Number);
                });

            migrationBuilder.CreateTable(
                name: "Users",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    Provider = table.Column<int>(type: "INTEGER", nullable: false),
                    ProviderSubject = table.Column<string>(type: "TEXT", nullable: false),
                    Email = table.Column<string>(type: "TEXT", nullable: false),
                    DisplayName = table.Column<string>(type: "TEXT", nullable: false),
                    CreatedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    LastSignedInAt = table.Column<long>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Users", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "ActivityDays",
                columns: table => new
                {
                    UserId = table.Column<Guid>(type: "TEXT", nullable: false),
                    Date = table.Column<DateOnly>(type: "TEXT", nullable: false),
                    RevisionCount = table.Column<int>(type: "INTEGER", nullable: false),
                    Xp = table.Column<int>(type: "INTEGER", nullable: false),
                    Score = table.Column<int>(type: "INTEGER", nullable: false),
                    SurahNumbers = table.Column<string>(type: "TEXT", nullable: false),
                    DurationSeconds = table.Column<int>(type: "INTEGER", nullable: false),
                    QuranReadCount = table.Column<int>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ActivityDays", x => new { x.UserId, x.Date });
                    table.ForeignKey(
                        name: "FK_ActivityDays_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "RecitationSessions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    UserId = table.Column<Guid>(type: "TEXT", nullable: false),
                    SurahNumber = table.Column<int>(type: "INTEGER", nullable: false),
                    StartedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    DurationSeconds = table.Column<int>(type: "INTEGER", nullable: false),
                    VersesMatched = table.Column<int>(type: "INTEGER", nullable: false),
                    VersesAttempted = table.Column<int>(type: "INTEGER", nullable: false),
                    AverageConfidence = table.Column<double>(type: "REAL", nullable: false),
                    CoveredRefs = table.Column<string>(type: "TEXT", nullable: false),
                    CreatedAt = table.Column<long>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RecitationSessions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RecitationSessions_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "RefreshTokens",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    UserId = table.Column<Guid>(type: "TEXT", nullable: false),
                    TokenHash = table.Column<string>(type: "TEXT", nullable: false),
                    ExpiresAt = table.Column<long>(type: "INTEGER", nullable: false),
                    CreatedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    RevokedAt = table.Column<long>(type: "INTEGER", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RefreshTokens", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RefreshTokens_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "RevisionPlans",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    UserId = table.Column<Guid>(type: "TEXT", nullable: false),
                    Name = table.Column<string>(type: "TEXT", nullable: false),
                    SurahNumbers = table.Column<string>(type: "TEXT", nullable: false),
                    ReminderTime = table.Column<long>(type: "INTEGER", nullable: false),
                    IsActive = table.Column<bool>(type: "INTEGER", nullable: false),
                    CreatedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    UpdatedAt = table.Column<long>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RevisionPlans", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RevisionPlans_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "UserSurahProgress",
                columns: table => new
                {
                    UserId = table.Column<Guid>(type: "TEXT", nullable: false),
                    SurahNumber = table.Column<int>(type: "INTEGER", nullable: false),
                    Mastery = table.Column<double>(type: "REAL", nullable: false),
                    MistakeRate = table.Column<double>(type: "REAL", nullable: false),
                    RevisionCount = table.Column<int>(type: "INTEGER", nullable: false),
                    LastReviewed = table.Column<long>(type: "INTEGER", nullable: true),
                    RevisionIntensity = table.Column<string>(type: "TEXT", nullable: false),
                    LastRevisionDurationSeconds = table.Column<int>(type: "INTEGER", nullable: false),
                    LastRevisionSection = table.Column<string>(type: "TEXT", nullable: true),
                    QuranReadCount = table.Column<int>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserSurahProgress", x => new { x.UserId, x.SurahNumber });
                    table.ForeignKey(
                        name: "FK_UserSurahProgress_Surahs_SurahNumber",
                        column: x => x.SurahNumber,
                        principalTable: "Surahs",
                        principalColumn: "Number",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_UserSurahProgress_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.InsertData(
                table: "Surahs",
                columns: new[] { "Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel" },
                values: new object[,]
                {
                    { 1, "سُورَةُ ٱلْفَاتِحَةِ", 7, "Al-Faatiha", "Juz 1" },
                    { 2, "سُورَةُ البَقَرَةِ", 286, "Al-Baqara", "Juz 1" },
                    { 3, "سُورَةُ آلِ عِمۡرَانَ", 200, "Aal-i-Imraan", "Juz 3" },
                    { 4, "سُورَةُ النِّسَاءِ", 176, "An-Nisaa", "Juz 4" },
                    { 5, "سُورَةُ المَائـِدَةِ", 120, "Al-Maaida", "Juz 6" },
                    { 6, "سُورَةُ الأَنۡعَامِ", 165, "Al-An'aam", "Juz 7" },
                    { 7, "سُورَةُ الأَعۡرَافِ", 206, "Al-A'raaf", "Juz 8" },
                    { 8, "سُورَةُ الأَنفَالِ", 75, "Al-Anfaal", "Juz 9" },
                    { 9, "سُورَةُ التَّوۡبَةِ", 129, "At-Tawba", "Juz 10" },
                    { 10, "سُورَةُ يُونُسَ", 109, "Yunus", "Juz 11" },
                    { 11, "سُورَةُ هُودٍ", 123, "Hud", "Juz 11" },
                    { 12, "سُورَةُ يُوسُفَ", 111, "Yusuf", "Juz 12" },
                    { 13, "سُورَةُ الرَّعۡدِ", 43, "Ar-Ra'd", "Juz 13" },
                    { 14, "سُورَةُ إِبۡرَاهِيمَ", 52, "Ibrahim", "Juz 13" },
                    { 15, "سُورَةُ الحِجۡرِ", 99, "Al-Hijr", "Juz 14" },
                    { 16, "سُورَةُ النَّحۡلِ", 128, "An-Nahl", "Juz 14" },
                    { 17, "سُورَةُ الإِسۡرَاءِ", 111, "Al-Israa", "Juz 15" },
                    { 18, "سُورَةُ الكَهۡفِ", 110, "Al-Kahf", "Juz 15" },
                    { 19, "سُورَةُ مَرۡيَمَ", 98, "Maryam", "Juz 16" },
                    { 20, "سُورَةُ طه", 135, "Taa-Haa", "Juz 16" },
                    { 21, "سُورَةُ الأَنبِيَاءِ", 112, "Al-Anbiyaa", "Juz 17" },
                    { 22, "سُورَةُ الحَجِّ", 78, "Al-Hajj", "Juz 17" },
                    { 23, "سُورَةُ المُؤۡمِنُونَ", 118, "Al-Muminoon", "Juz 18" },
                    { 24, "سُورَةُ النُّورِ", 64, "An-Noor", "Juz 18" },
                    { 25, "سُورَةُ الفُرۡقَانِ", 77, "Al-Furqaan", "Juz 18" },
                    { 26, "سُورَةُ الشُّعَرَاءِ", 227, "Ash-Shu'araa", "Juz 19" },
                    { 27, "سُورَةُ النَّمۡلِ", 93, "An-Naml", "Juz 19" },
                    { 28, "سُورَةُ القَصَصِ", 88, "Al-Qasas", "Juz 20" },
                    { 29, "سُورَةُ العَنكَبُوتِ", 69, "Al-Ankaboot", "Juz 20" },
                    { 30, "سُورَةُ الرُّومِ", 60, "Ar-Room", "Juz 21" },
                    { 31, "سُورَةُ لُقۡمَانَ", 34, "Luqman", "Juz 21" },
                    { 32, "سُورَةُ السَّجۡدَةِ", 30, "As-Sajda", "Juz 21" },
                    { 33, "سُورَةُ الأَحۡزَابِ", 73, "Al-Ahzaab", "Juz 21" },
                    { 34, "سُورَةُ سَبَإٍ", 54, "Saba", "Juz 22" },
                    { 35, "سُورَةُ فَاطِرٍ", 45, "Faatir", "Juz 22" },
                    { 36, "سُورَةُ يسٓ", 83, "Yaseen", "Juz 22" },
                    { 37, "سُورَةُ الصَّافَّاتِ", 182, "As-Saaffaat", "Juz 23" },
                    { 38, "سُورَةُ صٓ", 88, "Saad", "Juz 23" },
                    { 39, "سُورَةُ الزُّمَرِ", 75, "Az-Zumar", "Juz 23" },
                    { 40, "سُورَةُ غَافِرٍ", 85, "Ghafir", "Juz 24" },
                    { 41, "سُورَةُ فُصِّلَتۡ", 54, "Fussilat", "Juz 24" },
                    { 42, "سُورَةُ الشُّورَىٰ", 53, "Ash-Shura", "Juz 25" },
                    { 43, "سُورَةُ الزُّخۡرُفِ", 89, "Az-Zukhruf", "Juz 25" },
                    { 44, "سُورَةُ الدُّخَانِ", 59, "Ad-Dukhaan", "Juz 25" },
                    { 45, "سُورَةُ الجَاثِيَةِ", 37, "Al-Jaathiya", "Juz 25" },
                    { 46, "سُورَةُ الأَحۡقَافِ", 35, "Al-Ahqaf", "Juz 26" },
                    { 47, "سُورَةُ مُحَمَّدٍ", 38, "Muhammad", "Juz 26" },
                    { 48, "سُورَةُ الفَتۡحِ", 29, "Al-Fath", "Juz 26" },
                    { 49, "سُورَةُ الحُجُرَاتِ", 18, "Al-Hujuraat", "Juz 26" },
                    { 50, "سُورَةُ قٓ", 45, "Qaaf", "Juz 26" },
                    { 51, "سُورَةُ الذَّارِيَاتِ", 60, "Adh-Dhaariyat", "Juz 26" },
                    { 52, "سُورَةُ الطُّورِ", 49, "At-Tur", "Juz 27" },
                    { 53, "سُورَةُ النَّجۡمِ", 62, "An-Najm", "Juz 27" },
                    { 54, "سُورَةُ القَمَرِ", 55, "Al-Qamar", "Juz 27" },
                    { 55, "سُورَةُ الرَّحۡمَٰن", 78, "Ar-Rahmaan", "Juz 27" },
                    { 56, "سُورَةُ الوَاقِعَةِ", 96, "Al-Waaqia", "Juz 27" },
                    { 57, "سُورَةُ الحَدِيدِ", 29, "Al-Hadid", "Juz 27" },
                    { 58, "سُورَةُ المُجَادلَةِ", 22, "Al-Mujaadila", "Juz 28" },
                    { 59, "سُورَةُ الحَشۡرِ", 24, "Al-Hashr", "Juz 28" },
                    { 60, "سُورَةُ المُمۡتَحنَةِ", 13, "Al-Mumtahana", "Juz 28" },
                    { 61, "سُورَةُ الصَّفِّ", 14, "As-Saff", "Juz 28" },
                    { 62, "سُورَةُ الجُمُعَةِ", 11, "Al-Jumu'a", "Juz 28" },
                    { 63, "سُورَةُ المُنَافِقُونَ", 11, "Al-Munaafiqoon", "Juz 28" },
                    { 64, "سُورَةُ التَّغَابُنِ", 18, "At-Taghaabun", "Juz 28" },
                    { 65, "سُورَةُ الطَّلَاقِ", 12, "At-Talaaq", "Juz 28" },
                    { 66, "سُورَةُ التَّحۡرِيمِ", 12, "At-Tahrim", "Juz 28" },
                    { 67, "سُورَةُ المُلۡكِ", 30, "Al-Mulk", "Juz Tabarak" },
                    { 68, "سُورَةُ القَلَمِ", 52, "Al-Qalam", "Juz Tabarak" },
                    { 69, "سُورَةُ الحَاقَّةِ", 52, "Al-Haaqqa", "Juz Tabarak" },
                    { 70, "سُورَةُ المَعَارِجِ", 44, "Al-Ma'aarij", "Juz Tabarak" },
                    { 71, "سُورَةُ نُوحٍ", 28, "Nooh", "Juz Tabarak" },
                    { 72, "سُورَةُ الجِنِّ", 28, "Al-Jinn", "Juz Tabarak" },
                    { 73, "سُورَةُ المُزَّمِّلِ", 20, "Al-Muzzammil", "Juz Tabarak" },
                    { 74, "سُورَةُ المُدَّثِّرِ", 56, "Al-Muddaththir", "Juz Tabarak" },
                    { 75, "سُورَةُ القِيَامَةِ", 40, "Al-Qiyaama", "Juz Tabarak" },
                    { 76, "سُورَةُ الإِنسَانِ", 31, "Al-Insaan", "Juz Tabarak" },
                    { 77, "سُورَةُ المُرۡسَلَاتِ", 50, "Al-Mursalaat", "Juz Tabarak" },
                    { 78, "سُورَةُ النَّبَإِ", 40, "An-Naba", "Juz Amma" },
                    { 79, "سُورَةُ النَّازِعَاتِ", 46, "An-Naazi'aat", "Juz Amma" },
                    { 80, "سُورَةُ عَبَسَ", 42, "Abasa", "Juz Amma" },
                    { 81, "سُورَةُ التَّكۡوِيرِ", 29, "At-Takwir", "Juz Amma" },
                    { 82, "سُورَةُ الانفِطَارِ", 19, "Al-Infitaar", "Juz Amma" },
                    { 83, "سُورَةُ المُطَفِّفِينَ", 36, "Al-Mutaffifin", "Juz Amma" },
                    { 84, "سُورَةُ الانشِقَاقِ", 25, "Al-Inshiqaaq", "Juz Amma" },
                    { 85, "سُورَةُ البُرُوجِ", 22, "Al-Burooj", "Juz Amma" },
                    { 86, "سُورَةُ الطَّارِقِ", 17, "At-Taariq", "Juz Amma" },
                    { 87, "سُورَةُ الأَعۡلَىٰ", 19, "Al-A'laa", "Juz Amma" },
                    { 88, "سُورَةُ الغَاشِيَةِ", 26, "Al-Ghaashiya", "Juz Amma" },
                    { 89, "سُورَةُ الفَجۡرِ", 30, "Al-Fajr", "Juz Amma" },
                    { 90, "سُورَةُ البَلَدِ", 20, "Al-Balad", "Juz Amma" },
                    { 91, "سُورَةُ الشَّمۡسِ", 15, "Ash-Shams", "Juz Amma" },
                    { 92, "سُورَةُ اللَّيۡلِ", 21, "Al-Lail", "Juz Amma" },
                    { 93, "سُورَةُ الضُّحَىٰ", 11, "Ad-Dhuhaa", "Juz Amma" },
                    { 94, "سُورَةُ الشَّرۡحِ", 8, "Ash-Sharh", "Juz Amma" },
                    { 95, "سُورَةُ التِّينِ", 8, "At-Tin", "Juz Amma" },
                    { 96, "سُورَةُ العَلَقِ", 19, "Al-Alaq", "Juz Amma" },
                    { 97, "سُورَةُ القَدۡرِ", 5, "Al-Qadr", "Juz Amma" },
                    { 98, "سُورَةُ البَيِّنَةِ", 8, "Al-Bayyina", "Juz Amma" },
                    { 99, "سُورَةُ الزَّلۡزَلَةِ", 8, "Az-Zalzala", "Juz Amma" },
                    { 100, "سُورَةُ العَادِيَاتِ", 11, "Al-Aadiyaat", "Juz Amma" },
                    { 101, "سُورَةُ القَارِعَةِ", 11, "Al-Qaari'a", "Juz Amma" },
                    { 102, "سُورَةُ التَّكَاثُرِ", 8, "At-Takaathur", "Juz Amma" },
                    { 103, "سُورَةُ العَصۡرِ", 3, "Al-Asr", "Juz Amma" },
                    { 104, "سُورَةُ الهُمَزَةِ", 9, "Al-Humaza", "Juz Amma" },
                    { 105, "سُورَةُ الفِيلِ", 5, "Al-Fil", "Juz Amma" },
                    { 106, "سُورَةُ قُرَيۡشٍ", 4, "Quraish", "Juz Amma" },
                    { 107, "سُورَةُ المَاعُونِ", 7, "Al-Maa'un", "Juz Amma" },
                    { 108, "سُورَةُ الكَوۡثَرِ", 3, "Al-Kawthar", "Juz Amma" },
                    { 109, "سُورَةُ الكَافِرُونَ", 6, "Al-Kaafiroon", "Juz Amma" },
                    { 110, "سُورَةُ النَّصۡرِ", 3, "An-Nasr", "Juz Amma" },
                    { 111, "سُورَةُ المَسَدِ", 5, "Al-Masad", "Juz Amma" },
                    { 112, "سُورَةُ الإِخۡلَاصِ", 4, "Al-Ikhlaas", "Juz Amma" },
                    { 113, "سُورَةُ الفَلَقِ", 5, "Al-Falaq", "Juz Amma" },
                    { 114, "سُورَةُ النَّاسِ", 6, "An-Naas", "Juz Amma" }
                });

            migrationBuilder.CreateIndex(
                name: "IX_RecitationSessions_UserId_StartedAt",
                table: "RecitationSessions",
                columns: new[] { "UserId", "StartedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_RefreshTokens_TokenHash",
                table: "RefreshTokens",
                column: "TokenHash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RefreshTokens_UserId",
                table: "RefreshTokens",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_RevisionPlans_UserId",
                table: "RevisionPlans",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_Users_Provider_ProviderSubject",
                table: "Users",
                columns: new[] { "Provider", "ProviderSubject" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserSurahProgress_SurahNumber",
                table: "UserSurahProgress",
                column: "SurahNumber");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ActivityDays");

            migrationBuilder.DropTable(
                name: "RecitationSessions");

            migrationBuilder.DropTable(
                name: "RefreshTokens");

            migrationBuilder.DropTable(
                name: "RevisionPlans");

            migrationBuilder.DropTable(
                name: "UserSurahProgress");

            migrationBuilder.DropTable(
                name: "Surahs");

            migrationBuilder.DropTable(
                name: "Users");
        }
    }
}
