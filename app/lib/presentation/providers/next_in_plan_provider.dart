import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/domain/entities/revision_plan.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';
import 'package:tilawa/presentation/providers/revision_plan_provider.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';

/// What the reciter should recite next out of their plan.
///
/// One rule, in one place, because three screens ask the same question and
/// would otherwise each answer it differently: the button after finishing a
/// surah, the button after creating a plan, and the plan card on the
/// dashboard. If they disagreed, "next" would mean something different
/// depending on where you tapped.
///
/// The rule is weakest first, skipping anything already revised today.
/// Weakest is mastery *after* decay, so a surah left alone for a month ranks
/// above one revised last week even if it was recalled perfectly at the time.
/// Skipping today's work stops "next" from sending the reciter back over
/// ground they have just covered.
class NextInPlan {
  const NextInPlan({required this.surah, required this.remaining});

  /// The surah to offer, or null when the plan is finished for today.
  final SurahRevision? surah;

  /// How many plan surahs still want revising today, including [surah].
  final int remaining;

  bool get hasSurah => surah != null;

  /// Every surah in the plan has been revised today.
  bool get isDoneForToday => surah == null && remaining == 0;
}

/// The next surah from a specific plan.
final nextInPlanProvider =
    Provider.family<NextInPlan, RevisionPlan?>((ref, plan) {
  if (plan == null || plan.surahNumbers.isEmpty) {
    return const NextInPlan(surah: null, remaining: 0);
  }

  final all = ref.watch(revisionOverviewProvider).valueOrNull ?? const [];
  if (all.isEmpty) return const NextInPlan(surah: null, remaining: 0);

  // The last calendar day is today; its surah set is what has been revised.
  final summary = ref.watch(progressSummaryProvider).valueOrNull;
  final revisedToday = (summary == null || summary.calendar.isEmpty)
      ? const <int>{}
      : summary.calendar.last.surahNumbers;

  final outstanding = [
    for (final surah in all)
      if (plan.surahNumbers.contains(surah.number) &&
          !revisedToday.contains(surah.number))
        surah,
  ]..sort((a, b) {
      // Never reviewed sorts before anything with a history: there is more to
      // gain from a first pass than from topping up something already known.
      if (a.isAssessed != b.isAssessed) return a.isAssessed ? 1 : -1;
      final byMastery = a.mastery.compareTo(b.mastery);
      if (byMastery != 0) return byMastery;
      // Stable, so the same plan always offers the same order.
      return a.number.compareTo(b.number);
    });

  return NextInPlan(
    surah: outstanding.isEmpty ? null : outstanding.first,
    remaining: outstanding.length,
  );
});

/// The next surah from whichever plan is active.
final nextInActivePlanProvider = Provider<NextInPlan>((ref) {
  return ref.watch(nextInPlanProvider(ref.watch(activeRevisionPlanProvider)));
});
