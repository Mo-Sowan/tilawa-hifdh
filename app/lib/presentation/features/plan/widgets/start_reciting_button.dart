import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/domain/entities/revision_plan.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/next_in_plan_provider.dart';
import 'package:tilawa/features/recitation/presentation/live_recitation_view.dart';

/// The one button that turns a plan into a recitation.
///
/// A plan the reciter has to navigate out of before they can act on it is a
/// list, not a plan. This names the surah it will open — weakest first,
/// skipping anything already done today — so pressing it is a decision rather
/// than a leap, and the same rule answers "what next?" on every screen that
/// asks. See [nextInPlanProvider].
class StartRecitingButton extends ConsumerWidget {
  const StartRecitingButton({required this.plan, super.key});

  final RevisionPlan? plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final next = ref.watch(nextInPlanProvider(plan));

    // Everything in the plan has been through today. Saying so is better than
    // offering a button that would send them round again.
    if (next.isDoneForToday) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                strings.planDoneForToday,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final surah = next.surah;
    if (surah == null) return const SizedBox.shrink();

    return FilledButton.icon(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LiveRecitationView(surah: surah),
        ),
      ),
      icon: const Icon(Icons.play_arrow_rounded),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            strings.startReciting,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          Text(
            strings.isArabic ? surah.arabicName : surah.englishName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
