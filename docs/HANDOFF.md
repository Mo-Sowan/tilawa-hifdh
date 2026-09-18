# Handoff — what is done, what is left

Original baseline (superseded by Verification below): `flutter analyze` clean, **73** Dart tests pass, `dotnet build`
succeeds, **51** backend tests pass. Nothing is half-applied; every feature below
is either finished or not started.

Repo root: `C:\Users\m.sowan\Desktop\Project\TilawaHifdh`
App: `app/` (Flutter) · API: `backend/` (ASP.NET Core 8 + EF Core/SQLite)

Verify with:

```bash
cd app && flutter analyze && flutter test
cd ../backend && dotnet test
```

---

## Done — 6½ of 8 features

### Feature 1 — Progress widget + app-exit reminder ✅

- `app/lib/presentation/providers/daily_progress_provider.dart` — `DailyProgress`
  (`completedUnits`/`totalUnits`/`ratio`/`percentComplete`/`percentRemaining`/
  `isPartial`/`isComplete`). With an active plan the unit is surahs; without one
  it falls back to the daily minutes goal.
- `_DailyGoalProgressCard` in `home_view.dart` — 16px rounded
  `LinearProgressIndicator`, `displaySmall` percentage, "X% Completed" /
  "Y% Remaining".
- `main_view.dart` — `didChangeAppLifecycleState` fires on `paused`/`hidden`,
  **only when `isPartial`**, with `strings.exitReminder(done, left)`.

### Feature 2 — Weighted heatmap ✅

- `ActivityDay.weightedScore = minutes*1.0 + surahs*10.0`, `heatTier` 0–4
  (thresholds 0/15/35/70, absolute not relative) in
  `app/lib/domain/entities/activity_day.dart`.
- `_CalendarCard`/`_HeatCell`/`_HeatLegend` in `progress_view.dart` — 7-column
  grid, 5 opacity tiers `[0, .25, .5, .75, 1]`, `Tooltip` with
  `triggerMode: tap` showing "14 Oct: 35 mins, 3 Surahs", plus a less→more key.

### Feature 3 — Streak celebration modal ✅

- `app/lib/presentation/widgets/particle_burst.dart` — `Particle`,
  `ParticlePainter`, `ParticleMode` **extracted** from `celebration_overlay.dart`
  so both celebrations share one implementation.
- `app/lib/presentation/widgets/streak_celebration_dialog.dart` —
  `showStreakCelebration()`, `showGeneralDialog` + `ScaleTransition` with
  `Curves.elasticOut`, confetti via `ParticleMode.explode`, "🔥 N-Day Streak!",
  Continue button.
- Trigger in `main_view.dart` via `ref.listen(dailyProgressProvider)`; fires once
  per day, guarded by `AppSettings.streakCelebratedOn` (persisted).

### Feature 4 — Wisdom card redesign ✅

- `app/lib/presentation/widgets/octagram_pattern_painter.dart` — procedural
  interlocking Rub el Hizb lattice.
- `_WisdomPage` in `home_view.dart` — gradient `#0F3935 → #1E6B5C` with
  asymmetric stops `[0.35, 1.0]`, octagram at 10% white, amber badge and quote
  mark, white body ≥18sp bold, italic source bottom-trailing.
- The old rotating `_gradients` table and `_IslamicDecorationPainter` are gone.

### Feature 5 — Dynamic mastery decay ✅ (both sides, with parity tests)

- `app/lib/domain/entities/surah_difficulty.dart` and
  `backend/Tilawa.Api/Services/SurahDifficulty.cs` — identical tables.
  - Hard ×1.5: **2, 4, 5, 6**
  - Easy ×0.5: **18, 36, 67**, and **78–114**
  - Everything else ×1.0
- `MasteryModel.halfLifeDays(streak, decayCoefficient:)` **divides** the
  half-life by the coefficient; `MasteryModel.current(...)` takes it too. Same in
  `MasteryModel.cs`. `RevisionService.CurrentMastery` passes
  `SurahDifficulty.CoefficientFor(progress.SurahNumber)`.
- `SurahRevision.decayCoefficient` / `.halfLifeDays`. `isDueToday` now follows
  the decay curve (`mastery < 0.65`, or a full half-life elapsed) instead of a
  fixed day ladder — which is what makes hard surahs resurface sooner.
- Tests: 5 Dart (`test/domain/mastery_test.dart`), 5 C#
  (`MasteryModelTests.cs`).

### Feature 7 — Onboarding questionnaire ✅ (client + API + migration)

- `app/lib/domain/entities/reciter_profile.dart` — `MemorisationExtent`,
  `MemorisationDifficulty`, `FrequentlyRecited` (multi-select),
  `RevisionGoal`, `ReciterProfile` with `toJson`/`fromJson` and
  `frequentlyRecitedSurahs` (expands Juz Amma to 78–114).
- `data/repositories/reciter_profile_repository.dart` — device first, API
  mirrored; a failed mirror never loses the local answer.
- `presentation/views/profiling_view.dart` — `PageView` with
  `BouncingScrollPhysics`, animated top progress bar, `HapticFeedback
  .selectionClick()` on every selection, staggered option entry, skip.
- `root_navigator.dart` — order is onboarding → auth → questionnaire → main, and
  it **waits** for the stored profile so returning users are not re-asked.
- Backend: `ReciterProfile` entity, `ReciterProfileDto`, `ProfileController`
  (GET/PUT `/api/v1/profile`), migration `AddReciterProfile`.

### Feature 6 — Leaderboard ✅ (client + API + migration)

- Backend: `Friendship` entity (one-directional, unique pair),
  `LeaderboardService` (ranks by total XP, streak computed per user from
  `ActivityDays`, stable tiebreak), `LeaderboardController` — `GET
  /api/v1/leaderboard?scope=global|friends&limit=`, `POST
  /leaderboard/friends` (by email; same 404 for unknown and self so it cannot
  enumerate accounts), `DELETE /leaderboard/friends/{id}`. Migration
  `AddFriendships`. Registered in `Program.cs`.
- Client: `domain/entities/leaderboard_entry.dart`,
  `providers/leaderboard_provider.dart`, `views/leaderboard_view.dart` —
  `TabBar` Global/Friends, rank + avatar + name, metrics row
  `🔥 streak · 🏆 XP · 📖 reviewed today`, gold/silver/bronze top three,
  current user pinned at the bottom **only when not already listed**
  (`Leaderboard.currentUserIsListed`). Entry point: leaderboard icon on the
  Progress tab header.
- **No offline fallback, deliberately** — a leaderboard of one is not a
  leaderboard, so it says so instead of inventing a ranking.

### Feature 8.3 — Hasanat ✅

- `app/lib/domain/entities/hasanat.dart` — `isArabicLetter`, `letters`,
  `countLetters`, `countLettersIn`, `forText`, `forTexts`, `perLetter = 10`.
  Ranges are enumerated explicitly. **U+0670 (superscript alef) is deliberately
  excluded** — Unicode calls it a letter, it is a vowel mark, and including it
  added a letter to every dagger-alif word. A test catches this.
- `_HasanatCard` in `surah_detail_view.dart`, fed by `recitedRefs` threaded from
  `live_recitation_view.dart`, reading real verse text from `QuranTextIndex` —
  never a verse count times an average.
- Tests: `app/test/domain/hasanat_test.dart`, 11 tests including a sweep over all
  6,236 verses. "بسم الله الرحمن الرحيم" = 19 letters = 190 hasanat.

---

## Follow-up completed — 2026-09-12

The requested five items are implemented. Do not redo them.

- **Utilities:** `UtilitiesView`, reachable from Settings, with working Tasbeeh
  and Qibla tiles. No Adhkar tile or religious text was added.
- **Digital tasbeeh:** target choices 33/99/100/1000, one haptic per tap with a
  stronger completion haptic, capped counter, progress indicator, reset. Changing
  the target starts a new round. The counter is session-local.
- **Qibla:** pure `qiblaBearing` in `domain/entities/qibla.dart`; Cairo/London,
  normalization, invalid-coordinate and wraparound tests. Circular low-pass
  filtering accepts Android's signed heading angles. The animated dial uses a
  cancellable compass subscription and retries location on resume. Denied,
  permanently denied, services-off and sensor-unavailable states are explicit.
  Android fine/coarse location permissions and iOS usage description are added.
  On the web, location can provide a numeric bearing; the compass plugin has no
  web sensor implementation, so the view explains the fallback. The numeric
  bearing is relative to true north; the sensor arrow is approximate (Android
  supplies magnetic heading). Calibration and physical-device validation remain.
- **Controller tests:** `ProfileLeaderboardTests.cs` covers authentication,
  profile round-trip/replacement/account isolation, real-activity ranks and stable
  ties, current-user rank outside the first page, directional friend filtering,
  duplicate follows/removals, invalid requests and streak boundaries.
  `InternalsVisibleTo` exposes internal helpers only to the test assembly.
- **Profile wiring:** personal frequent-recitation choices replace the static
  habit assumptions; otherwise-hard surahs can receive the easy coefficient if
  explicitly present in the personal set. Empty/unknown choices retain default
  behavior. Juz Amma expands to 78–114. Local storage, remote DTO decoding,
  API mastery/priority/progress and subsequent reviews use this policy.
- **Plan preferences:** extent caps are 3 / 10 / 20 / 40 surahs for just-starting /
  up-to-five-juz / half / entire. Skipped extent retains the existing API limit
  of 40. Limits are enforced for creation and updates in local/remote repositories
  and the API. The composer suggests known surahs first; long-surah difficulty
  prefers shorter surahs within those groups. Beginners also start with shorter
  surahs. The full catalogue stays available, since extent does not identify
  which surahs someone knows. Defaults apply once and never overwrite manual
  selection. The goal answer remains stored for future recommendations.
- **Tests:** shared habit, Juz expansion and plan-cap rules have mirrored Dart/C#
  assertions. Widget tests cover utility navigation, counter/target/haptics,
  Qibla errors and sensor cleanup. Local repository tests verify personal decay
  is used before recording a review and oversized plans are rejected before writes.

## Verification

Latest checks: `flutter analyze` **0 issues**, `flutter test` **97 passed**,
`dotnet test -c Release` **81 passed**. The accepted starting baseline was
73 Dart / 64 C#; the extra 13 C# tests over the original handoff were the Mushaf
cache tests added earlier. Release avoids file locks from the running Debug API.
The existing app boot smoke test still logs the SQLite factory initialization
warning while passing; it was present at baseline.

The earlier Mushaf cache refactor is also complete; see `docs/mushaf-cache.md`.

## UI and submission follow-up

Rapid repeated Save clicks now accept one submission per assessment screen.
The UI locks before awaiting persistence; history is added after success, and
failure allows a deliberate retry. Finish-recitation navigation is guarded too.
Tests cover two callbacks in the same frame, one history entry, and failed-save retry.

The design refresh includes a calmer emerald palette, contrast-aware button text,
consistent controls and fields, desktop navigation rail, paired dashboard cards,
responsive utility cards/settings controls, and softer session-log rows.
Arabic layouts at 320px and 1024px with enlarged text are tested.

See `docs/FEATURE_AUDIT.md` for the verified comparison with the eight-feature
brief. Earlier "done" labels describe implemented behavior; the audit identifies
remaining differences (estimated non-plan minutes, native-only notifications,
no Lottie/Rive assets, on-read decay rather than cron, and Adhkar still absent).

## Mushaf, plan and AI follow-up (2026-09-15)

- The reader now has one canonical presentation: scanned pages from the Libyan
  Qaloon Mushaf. The electronic-text switch and electronic search destination
  were removed. Search results open the matching scanned page. No Quran dataset
  or Quran character was generated or edited.
- Native page downloads use a persistent 604-object cache with a one-year stale
  period. A phone build skips development-only API hosts (`localhost`,
  `127.0.0.1`, and `10.0.2.2`) and downloads directly from the archive instead
  of waiting for an unreachable emulator proxy. Reader prefetch waits for the
  visible page and then fetches only its immediate neighbours, sequentially.
- The plan screen explains the three-step workflow, separates existing plans
  from creation, labels each creation step, shows the selected count beside the
  final action, and prevents repeated create requests while one is in flight.
  Existing-plan cards and the detail view show today's completed/total progress
  and identify the next action.
- Web recognition is enabled again with ONNX Runtime Web 1.26's WASM provider.
  The older 1.21/1.23 runtimes rejected the model's `ConvInteger` nodes; current
  ONNX Runtime documentation states that its WASM provider supports all ONNX
  operators. The web manager now opens Flutter's bundled model instead of
  rejecting the platform before session creation. The model and native ONNX
  Runtime libraries remain present in Android builds.
- Exact model session creation still needs live browser QA. The local browser
  smoke-test navigation was blocked when the automatic approval reviewer was at
  capacity, and no Android device was connected for native inference validation.
- Direct Dart analysis passes with zero issues. Full Flutter test/build
  validation remains pending because the automatic approval reviewer was at
  capacity when the Flutter SDK needed access outside the workspace sandbox.
## Remaining / intentionally excluded

- **Adhkar text and UI:** blocked until the user chooses a source. Never generate
  Quran or hadith from memory. After approval, add a generator in `tools/` that
  imports and checksums the selected dataset. Resolve Quran portions from the
  existing corpus by surah/ayah references, keeping one canonical text.
- **Device QA:** check compass accuracy/calibration and real location permission
  transitions on Android/iOS; verify physical haptics. Unit/widget tests use fake
  sensors and cannot establish hardware accuracy. Native release builds have not
  been verified in this follow-up.

---
## Environment notes that will save time

- **Flutter is not on PATH.** It lives at
  `C:\Users\m.sowan\develop\flutter\bin`.
- **Gradle will fail** with `java.io.IOException: Unable to establish loopback
  connection` unless `TEMP`/`TMP` are moved off the default. AF_UNIX `connect`
  is broken specifically inside `C:\Users\m.sowan\AppData\Local\Temp` on this
  machine — reproduced in both Java and .NET. Java system properties do not help;
  only the environment variables do:

  ```bash
  export TEMP='C:\Users\m.sowan\build-tmp' TMP='C:\Users\m.sowan\build-tmp'
  flutter build apk --release --dart-define=ALLOW_GUEST=true
  ```

- `ALLOW_GUEST=true` is what puts the "continue without an account" button on the
  auth screen; without it and without a configured OAuth client the app cannot be
  entered.
- The ONNX model (84 MB) **is** bundled at
  `app/assets/model/fastconformer_full_mixed.onnx`, so the APK is ~186 MB and the
  recogniser works offline from first launch. It is gitignored.
- The recogniser **cannot run on the web** — ORT Web does not implement
  `ConvInteger`. Test the AI on Android.


