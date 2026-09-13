import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/revision_plan_provider.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';

/// How far through today's revision the reciter is.
///
/// The unit depends on what they have committed to. With an active plan it is
/// surahs — the ones they chose, and how many of those they have actually been
/// through today. Without a plan there is nothing to be a fraction of, so it
/// falls back to the daily minutes goal from settings.
///
/// Keeping both behind one type means the progress widget and the leaving-the-
/// app reminder always quote the same number, rather than each deriving its own.
class DailyProgress {
  const DailyProgress({
    required this.completedUnits,
    required this.totalUnits,
    required this.isPlanBased,
  });

  const DailyProgress.empty()
      : completedUnits = 0,
        totalUnits = 0,
        isPlanBased = false;

  final int completedUnits;
  final int totalUnits;

  /// True when the units are surahs from a plan, false when they are minutes.
  final bool isPlanBased;

  double get ratio =>
      totalUnits == 0 ? 0 : (completedUnits / totalUnits).clamp(0.0, 1.0);

  int get percentComplete => (ratio * 100).round();

  int get percentRemaining => 100 - percentComplete;

  /// Something done, but not finished — the only state worth interrupting
  /// someone about as they leave.
  bool get isPartial => percentComplete > 0 && percentComplete < 100;

  bool get isComplete => totalUnits > 0 && completedUnits >= totalUnits;

  /// Nothing to be a fraction of.
  bool get isEmpty => totalUnits == 0;
}

/// Today's progress, recomputed whenever the plan or the day's activity moves.
final dailyProgressProvider = Provider<DailyProgress>((ref) {
  final summary = ref.watch(progressSummaryProvider).valueOrNull;
  if (summary == null) return const DailyProgress.empty();

  final planned = (ref.watch(revisionPlansProvider).valueOrNull ?? const [])
      .where((plan) => plan.isActive)
      .expand((plan) => plan.surahNumbers)
      .toSet();

  if (planned.isNotEmpty) {
    // The last calendar day is today; its surah set is what has been revised.
    final revisedToday = summary.calendar.isEmpty
        ? const <int>{}
        : summary.calendar.last.surahNumbers;
    return DailyProgress(
      completedUnits: planned.intersection(revisedToday).length,
      totalUnits: planned.length,
      isPlanBased: true,
    );
  }

  final goalMinutes = ref.watch(appSettingsProvider).dailyGoalMinutes;
  if (goalMinutes <= 0) return const DailyProgress.empty();

  // Without per-session timing rolled up by day, minutes are estimated from
  // the number of reviews. Flagged here rather than hidden: it is the reason
  // a plan gives a truer figure.
  const estimatedMinutesPerReview = 5;
  final minutes =
      (summary.reviewedToday * estimatedMinutesPerReview).clamp(0, goalMinutes);
  return DailyProgress(
    completedUnits: minutes,
    totalUnits: goalMinutes,
    isPlanBased: false,
  );
});
