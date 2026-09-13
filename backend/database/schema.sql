CREATE TABLE IF NOT EXISTS "__EFMigrationsHistory" (
    "MigrationId" TEXT NOT NULL CONSTRAINT "PK___EFMigrationsHistory" PRIMARY KEY,
    "ProductVersion" TEXT NOT NULL
);

BEGIN TRANSACTION;

CREATE TABLE "Surahs" (
    "Number" INTEGER NOT NULL CONSTRAINT "PK_Surahs" PRIMARY KEY,
    "EnglishName" TEXT NOT NULL,
    "ArabicName" TEXT NOT NULL,
    "JuzLabel" TEXT NOT NULL,
    "AyahCount" INTEGER NOT NULL
);

CREATE TABLE "Users" (
    "Id" TEXT NOT NULL CONSTRAINT "PK_Users" PRIMARY KEY,
    "Provider" INTEGER NOT NULL,
    "ProviderSubject" TEXT NOT NULL,
    "Email" TEXT NOT NULL,
    "DisplayName" TEXT NOT NULL,
    "CreatedAt" INTEGER NOT NULL,
    "LastSignedInAt" INTEGER NOT NULL
);

CREATE TABLE "ActivityDays" (
    "UserId" TEXT NOT NULL,
    "Date" TEXT NOT NULL,
    "RevisionCount" INTEGER NOT NULL,
    "Xp" INTEGER NOT NULL,
    "Score" INTEGER NOT NULL,
    "SurahNumbers" TEXT NOT NULL,
    "DurationSeconds" INTEGER NOT NULL,
    "QuranReadCount" INTEGER NOT NULL,
    CONSTRAINT "PK_ActivityDays" PRIMARY KEY ("UserId", "Date"),
    CONSTRAINT "FK_ActivityDays_Users_UserId" FOREIGN KEY ("UserId") REFERENCES "Users" ("Id") ON DELETE CASCADE
);

CREATE TABLE "RecitationSessions" (
    "Id" TEXT NOT NULL CONSTRAINT "PK_RecitationSessions" PRIMARY KEY,
    "UserId" TEXT NOT NULL,
    "SurahNumber" INTEGER NOT NULL,
    "StartedAt" INTEGER NOT NULL,
    "DurationSeconds" INTEGER NOT NULL,
    "VersesMatched" INTEGER NOT NULL,
    "VersesAttempted" INTEGER NOT NULL,
    "AverageConfidence" REAL NOT NULL,
    "CoveredRefs" TEXT NOT NULL,
    "CreatedAt" INTEGER NOT NULL,
    CONSTRAINT "FK_RecitationSessions_Users_UserId" FOREIGN KEY ("UserId") REFERENCES "Users" ("Id") ON DELETE CASCADE
);

CREATE TABLE "RefreshTokens" (
    "Id" TEXT NOT NULL CONSTRAINT "PK_RefreshTokens" PRIMARY KEY,
    "UserId" TEXT NOT NULL,
    "TokenHash" TEXT NOT NULL,
    "ExpiresAt" INTEGER NOT NULL,
    "CreatedAt" INTEGER NOT NULL,
    "RevokedAt" INTEGER NULL,
    CONSTRAINT "FK_RefreshTokens_Users_UserId" FOREIGN KEY ("UserId") REFERENCES "Users" ("Id") ON DELETE CASCADE
);

CREATE TABLE "RevisionPlans" (
    "Id" TEXT NOT NULL CONSTRAINT "PK_RevisionPlans" PRIMARY KEY,
    "UserId" TEXT NOT NULL,
    "Name" TEXT NOT NULL,
    "SurahNumbers" TEXT NOT NULL,
    "ReminderTime" INTEGER NOT NULL,
    "IsActive" INTEGER NOT NULL,
    "CreatedAt" INTEGER NOT NULL,
    "UpdatedAt" INTEGER NOT NULL,
    CONSTRAINT "FK_RevisionPlans_Users_UserId" FOREIGN KEY ("UserId") REFERENCES "Users" ("Id") ON DELETE CASCADE
);

CREATE TABLE "UserSurahProgress" (
    "UserId" TEXT NOT NULL,
    "SurahNumber" INTEGER NOT NULL,
    "Mastery" REAL NOT NULL,
    "MistakeRate" REAL NOT NULL,
    "RevisionCount" INTEGER NOT NULL,
    "LastReviewed" INTEGER NULL,
    "RevisionIntensity" TEXT NOT NULL,
    "LastRevisionDurationSeconds" INTEGER NOT NULL,
    "LastRevisionSection" TEXT NULL,
    "QuranReadCount" INTEGER NOT NULL,
    CONSTRAINT "PK_UserSurahProgress" PRIMARY KEY ("UserId", "SurahNumber"),
    CONSTRAINT "FK_UserSurahProgress_Surahs_SurahNumber" FOREIGN KEY ("SurahNumber") REFERENCES "Surahs" ("Number") ON DELETE RESTRICT,
    CONSTRAINT "FK_UserSurahProgress_Users_UserId" FOREIGN KEY ("UserId") REFERENCES "Users" ("Id") ON DELETE CASCADE
);

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (1, 'سُورَةُ ٱلْفَاتِحَةِ', 7, 'Al-Faatiha', 'Juz 1');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (2, 'سُورَةُ البَقَرَةِ', 286, 'Al-Baqara', 'Juz 1');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (3, 'سُورَةُ آلِ عِمۡرَانَ', 200, 'Aal-i-Imraan', 'Juz 3');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (4, 'سُورَةُ النِّسَاءِ', 176, 'An-Nisaa', 'Juz 4');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (5, 'سُورَةُ المَائـِدَةِ', 120, 'Al-Maaida', 'Juz 6');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (6, 'سُورَةُ الأَنۡعَامِ', 165, 'Al-An''aam', 'Juz 7');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (7, 'سُورَةُ الأَعۡرَافِ', 206, 'Al-A''raaf', 'Juz 8');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (8, 'سُورَةُ الأَنفَالِ', 75, 'Al-Anfaal', 'Juz 9');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (9, 'سُورَةُ التَّوۡبَةِ', 129, 'At-Tawba', 'Juz 10');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (10, 'سُورَةُ يُونُسَ', 109, 'Yunus', 'Juz 11');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (11, 'سُورَةُ هُودٍ', 123, 'Hud', 'Juz 11');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (12, 'سُورَةُ يُوسُفَ', 111, 'Yusuf', 'Juz 12');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (13, 'سُورَةُ الرَّعۡدِ', 43, 'Ar-Ra''d', 'Juz 13');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (14, 'سُورَةُ إِبۡرَاهِيمَ', 52, 'Ibrahim', 'Juz 13');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (15, 'سُورَةُ الحِجۡرِ', 99, 'Al-Hijr', 'Juz 14');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (16, 'سُورَةُ النَّحۡلِ', 128, 'An-Nahl', 'Juz 14');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (17, 'سُورَةُ الإِسۡرَاءِ', 111, 'Al-Israa', 'Juz 15');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (18, 'سُورَةُ الكَهۡفِ', 110, 'Al-Kahf', 'Juz 15');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (19, 'سُورَةُ مَرۡيَمَ', 98, 'Maryam', 'Juz 16');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (20, 'سُورَةُ طه', 135, 'Taa-Haa', 'Juz 16');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (21, 'سُورَةُ الأَنبِيَاءِ', 112, 'Al-Anbiyaa', 'Juz 17');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (22, 'سُورَةُ الحَجِّ', 78, 'Al-Hajj', 'Juz 17');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (23, 'سُورَةُ المُؤۡمِنُونَ', 118, 'Al-Muminoon', 'Juz 18');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (24, 'سُورَةُ النُّورِ', 64, 'An-Noor', 'Juz 18');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (25, 'سُورَةُ الفُرۡقَانِ', 77, 'Al-Furqaan', 'Juz 18');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (26, 'سُورَةُ الشُّعَرَاءِ', 227, 'Ash-Shu''araa', 'Juz 19');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (27, 'سُورَةُ النَّمۡلِ', 93, 'An-Naml', 'Juz 19');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (28, 'سُورَةُ القَصَصِ', 88, 'Al-Qasas', 'Juz 20');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (29, 'سُورَةُ العَنكَبُوتِ', 69, 'Al-Ankaboot', 'Juz 20');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (30, 'سُورَةُ الرُّومِ', 60, 'Ar-Room', 'Juz 21');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (31, 'سُورَةُ لُقۡمَانَ', 34, 'Luqman', 'Juz 21');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (32, 'سُورَةُ السَّجۡدَةِ', 30, 'As-Sajda', 'Juz 21');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (33, 'سُورَةُ الأَحۡزَابِ', 73, 'Al-Ahzaab', 'Juz 21');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (34, 'سُورَةُ سَبَإٍ', 54, 'Saba', 'Juz 22');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (35, 'سُورَةُ فَاطِرٍ', 45, 'Faatir', 'Juz 22');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (36, 'سُورَةُ يسٓ', 83, 'Yaseen', 'Juz 22');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (37, 'سُورَةُ الصَّافَّاتِ', 182, 'As-Saaffaat', 'Juz 23');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (38, 'سُورَةُ صٓ', 88, 'Saad', 'Juz 23');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (39, 'سُورَةُ الزُّمَرِ', 75, 'Az-Zumar', 'Juz 23');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (40, 'سُورَةُ غَافِرٍ', 85, 'Ghafir', 'Juz 24');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (41, 'سُورَةُ فُصِّلَتۡ', 54, 'Fussilat', 'Juz 24');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (42, 'سُورَةُ الشُّورَىٰ', 53, 'Ash-Shura', 'Juz 25');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (43, 'سُورَةُ الزُّخۡرُفِ', 89, 'Az-Zukhruf', 'Juz 25');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (44, 'سُورَةُ الدُّخَانِ', 59, 'Ad-Dukhaan', 'Juz 25');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (45, 'سُورَةُ الجَاثِيَةِ', 37, 'Al-Jaathiya', 'Juz 25');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (46, 'سُورَةُ الأَحۡقَافِ', 35, 'Al-Ahqaf', 'Juz 26');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (47, 'سُورَةُ مُحَمَّدٍ', 38, 'Muhammad', 'Juz 26');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (48, 'سُورَةُ الفَتۡحِ', 29, 'Al-Fath', 'Juz 26');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (49, 'سُورَةُ الحُجُرَاتِ', 18, 'Al-Hujuraat', 'Juz 26');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (50, 'سُورَةُ قٓ', 45, 'Qaaf', 'Juz 26');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (51, 'سُورَةُ الذَّارِيَاتِ', 60, 'Adh-Dhaariyat', 'Juz 26');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (52, 'سُورَةُ الطُّورِ', 49, 'At-Tur', 'Juz 27');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (53, 'سُورَةُ النَّجۡمِ', 62, 'An-Najm', 'Juz 27');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (54, 'سُورَةُ القَمَرِ', 55, 'Al-Qamar', 'Juz 27');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (55, 'سُورَةُ الرَّحۡمَٰن', 78, 'Ar-Rahmaan', 'Juz 27');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (56, 'سُورَةُ الوَاقِعَةِ', 96, 'Al-Waaqia', 'Juz 27');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (57, 'سُورَةُ الحَدِيدِ', 29, 'Al-Hadid', 'Juz 27');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (58, 'سُورَةُ المُجَادلَةِ', 22, 'Al-Mujaadila', 'Juz 28');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (59, 'سُورَةُ الحَشۡرِ', 24, 'Al-Hashr', 'Juz 28');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (60, 'سُورَةُ المُمۡتَحنَةِ', 13, 'Al-Mumtahana', 'Juz 28');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (61, 'سُورَةُ الصَّفِّ', 14, 'As-Saff', 'Juz 28');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (62, 'سُورَةُ الجُمُعَةِ', 11, 'Al-Jumu''a', 'Juz 28');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (63, 'سُورَةُ المُنَافِقُونَ', 11, 'Al-Munaafiqoon', 'Juz 28');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (64, 'سُورَةُ التَّغَابُنِ', 18, 'At-Taghaabun', 'Juz 28');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (65, 'سُورَةُ الطَّلَاقِ', 12, 'At-Talaaq', 'Juz 28');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (66, 'سُورَةُ التَّحۡرِيمِ', 12, 'At-Tahrim', 'Juz 28');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (67, 'سُورَةُ المُلۡكِ', 30, 'Al-Mulk', 'Juz Tabarak');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (68, 'سُورَةُ القَلَمِ', 52, 'Al-Qalam', 'Juz Tabarak');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (69, 'سُورَةُ الحَاقَّةِ', 52, 'Al-Haaqqa', 'Juz Tabarak');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (70, 'سُورَةُ المَعَارِجِ', 44, 'Al-Ma''aarij', 'Juz Tabarak');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (71, 'سُورَةُ نُوحٍ', 28, 'Nooh', 'Juz Tabarak');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (72, 'سُورَةُ الجِنِّ', 28, 'Al-Jinn', 'Juz Tabarak');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (73, 'سُورَةُ المُزَّمِّلِ', 20, 'Al-Muzzammil', 'Juz Tabarak');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (74, 'سُورَةُ المُدَّثِّرِ', 56, 'Al-Muddaththir', 'Juz Tabarak');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (75, 'سُورَةُ القِيَامَةِ', 40, 'Al-Qiyaama', 'Juz Tabarak');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (76, 'سُورَةُ الإِنسَانِ', 31, 'Al-Insaan', 'Juz Tabarak');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (77, 'سُورَةُ المُرۡسَلَاتِ', 50, 'Al-Mursalaat', 'Juz Tabarak');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (78, 'سُورَةُ النَّبَإِ', 40, 'An-Naba', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (79, 'سُورَةُ النَّازِعَاتِ', 46, 'An-Naazi''aat', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (80, 'سُورَةُ عَبَسَ', 42, 'Abasa', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (81, 'سُورَةُ التَّكۡوِيرِ', 29, 'At-Takwir', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (82, 'سُورَةُ الانفِطَارِ', 19, 'Al-Infitaar', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (83, 'سُورَةُ المُطَفِّفِينَ', 36, 'Al-Mutaffifin', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (84, 'سُورَةُ الانشِقَاقِ', 25, 'Al-Inshiqaaq', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (85, 'سُورَةُ البُرُوجِ', 22, 'Al-Burooj', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (86, 'سُورَةُ الطَّارِقِ', 17, 'At-Taariq', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (87, 'سُورَةُ الأَعۡلَىٰ', 19, 'Al-A''laa', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (88, 'سُورَةُ الغَاشِيَةِ', 26, 'Al-Ghaashiya', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (89, 'سُورَةُ الفَجۡرِ', 30, 'Al-Fajr', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (90, 'سُورَةُ البَلَدِ', 20, 'Al-Balad', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (91, 'سُورَةُ الشَّمۡسِ', 15, 'Ash-Shams', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (92, 'سُورَةُ اللَّيۡلِ', 21, 'Al-Lail', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (93, 'سُورَةُ الضُّحَىٰ', 11, 'Ad-Dhuhaa', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (94, 'سُورَةُ الشَّرۡحِ', 8, 'Ash-Sharh', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (95, 'سُورَةُ التِّينِ', 8, 'At-Tin', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (96, 'سُورَةُ العَلَقِ', 19, 'Al-Alaq', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (97, 'سُورَةُ القَدۡرِ', 5, 'Al-Qadr', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (98, 'سُورَةُ البَيِّنَةِ', 8, 'Al-Bayyina', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (99, 'سُورَةُ الزَّلۡزَلَةِ', 8, 'Az-Zalzala', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (100, 'سُورَةُ العَادِيَاتِ', 11, 'Al-Aadiyaat', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (101, 'سُورَةُ القَارِعَةِ', 11, 'Al-Qaari''a', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (102, 'سُورَةُ التَّكَاثُرِ', 8, 'At-Takaathur', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (103, 'سُورَةُ العَصۡرِ', 3, 'Al-Asr', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (104, 'سُورَةُ الهُمَزَةِ', 9, 'Al-Humaza', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (105, 'سُورَةُ الفِيلِ', 5, 'Al-Fil', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (106, 'سُورَةُ قُرَيۡشٍ', 4, 'Quraish', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (107, 'سُورَةُ المَاعُونِ', 7, 'Al-Maa''un', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (108, 'سُورَةُ الكَوۡثَرِ', 3, 'Al-Kawthar', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (109, 'سُورَةُ الكَافِرُونَ', 6, 'Al-Kaafiroon', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (110, 'سُورَةُ النَّصۡرِ', 3, 'An-Nasr', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (111, 'سُورَةُ المَسَدِ', 5, 'Al-Masad', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (112, 'سُورَةُ الإِخۡلَاصِ', 4, 'Al-Ikhlaas', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (113, 'سُورَةُ الفَلَقِ', 5, 'Al-Falaq', 'Juz Amma');
SELECT changes();

INSERT INTO "Surahs" ("Number", "ArabicName", "AyahCount", "EnglishName", "JuzLabel")
VALUES (114, 'سُورَةُ النَّاسِ', 6, 'An-Naas', 'Juz Amma');
SELECT changes();


CREATE INDEX "IX_RecitationSessions_UserId_StartedAt" ON "RecitationSessions" ("UserId", "StartedAt");

CREATE UNIQUE INDEX "IX_RefreshTokens_TokenHash" ON "RefreshTokens" ("TokenHash");

CREATE INDEX "IX_RefreshTokens_UserId" ON "RefreshTokens" ("UserId");

CREATE INDEX "IX_RevisionPlans_UserId" ON "RevisionPlans" ("UserId");

CREATE UNIQUE INDEX "IX_Users_Provider_ProviderSubject" ON "Users" ("Provider", "ProviderSubject");

CREATE INDEX "IX_UserSurahProgress_SurahNumber" ON "UserSurahProgress" ("SurahNumber");

INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20260908105613_InitialSchema', '8.0.11');

COMMIT;

BEGIN TRANSACTION;

ALTER TABLE "UserSurahProgress" ADD "ConsecutiveGoodReviews" INTEGER NOT NULL DEFAULT 0;

INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20260909133238_AddMasteryDecayTracking', '8.0.11');

COMMIT;

