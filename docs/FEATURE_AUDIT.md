# Audit of the attached eight-feature brief

Checked against the implementation on 2026-09-12. This is an audit of the
requested behavior, not an assumption that the earlier handoff proves completion.

| Feature | Status | Evidence and differences |
| --- | --- | --- |
| 1. Progress and exit reminder | Partial | `daily_progress_provider.dart`, `home_view.dart`, `main_view.dart`, `notification_service.dart`: plan completion uses revised surahs; the large rounded progress UI and lifecycle reminder exist. Without a plan, progress still estimates five minutes per review instead of using recorded duration. Local notifications are disabled on web and depend on native permissions. |
| 2. Weighted heatmap | Implemented | `activity_day.dart` computes minutes + 10 × surahs. `progress_view.dart` has the seven-column grid, five opacity tiers and tap tooltips. |
| 3. Daily-target celebration | Implemented | `main_view.dart` listens for completed daily progress, with a once-per-day guard; `streak_celebration_dialog.dart` uses elastic scale and shared canvas particles. The redundant second streak overlay from the assessment screen was removed in this follow-up. |
| 4. Wisdom card | Implemented | `home_view.dart` and `octagram_pattern_painter.dart`: specified emerald gradient, low-opacity octagram geometry, amber accents, white body text and source styling. |
| 5. Variable mastery decay | Behavior implemented; architecture differs | Mirrored `SurahDifficulty` and `MasteryModel` rules use the requested coefficients, with personal-habit overrides. `SurahRevision.decayCoefficient` feeds decay on reads. There is no `SurahStats` type or daily cron job; elapsed-time evaluation avoids stale stored scores. |
| 6. Leaderboard | Implemented with limits | Global/Friends tabs, rank/name/initial avatar, three metrics, and current-user row outside the displayed leaders. Uses initials rather than uploaded profile photos. Requires the authenticated API; there are no invented offline rankings. |
| 7. Profiling | Functional; animation approach differs | Four questions, page transitions, progress animation, haptics and local/API persistence exist. Uses Flutter animations, not Lottie/Rive assets. Extent, long-surah difficulty and frequent-recitation habits affect plans/mastery. The goal answer remains stored but does not yet change recommendations. |
| 8. Utilities | Partial | Utilities, tasbeeh, sensor compass and actual-letter Hasanat calculation exist. Adhkar text/UI is intentionally absent pending the user's choice of a verified source. Compass hardware needs device QA; web displays a numeric location-based bearing because the plugin has no web sensor implementation. Hasanat uses matched checked-in verse text, not estimated verse lengths; manual sessions without matched references cannot produce a letter total. |

## Duplicate-submit fix and design changes

- Save is locked synchronously before any asynchronous work. Repeated taps use
  one write; history and previous confidence are updated only after it succeeds.
  A failure shows feedback and allows retry. Successful writes remain locked if
  a later UI step fails. Finish-recitation navigation is also guarded.
- This prevents rapid duplicate clicks within one session. It is not an API-wide
  idempotency guarantee for network retries or requests from separate devices.
  Existing duplicate records are left intact; no historical data is guessed away.
- Calmer emerald tones, contrast-aware button foregrounds, consistent larger
  controls and field styling, softer card/divider borders, responsive desktop
  navigation, paired dashboard cards, utility cards and quieter session rows.
- Quran datasets and Quran text typography are preserved. No religious text is
  generated. No Flutter `/design` skill was installed; changes were made directly
  in the Flutter code after inspecting the current interface.

## Still requires a decision or device check

Choose the Adhkar dataset before its generator or text UI is implemented.
Verify native location permissions, sensor calibration and haptics on devices.
Android's plugin reports magnetic heading, so its arrow is approximate relative
to the true-north great-circle bearing.
