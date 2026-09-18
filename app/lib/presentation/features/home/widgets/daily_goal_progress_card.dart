import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/daily_progress_provider.dart';
import 'package:tilawa/presentation/features/home/widgets/goal_shell.dart';

// ─── Daily Goal Progress Card (Time-based) ──────────────────────────────────
class DailyGoalProgressCard extends ConsumerWidget {
  const DailyGoalProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final progress = ref.watch(dailyProgressProvider);

    if (progress.isEmpty) {
      return GoalShell(
        title: strings.planProgressTitle,
        child: Text(
          strings.planProgressEmpty,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
        ),
      );
    }

    final done = progress.percentComplete;
    final left = progress.percentRemaining;

    return GoalShell(
      title: progress.isPlanBased
          ? strings.planProgressTitle
          : strings.dailyGoalSetting,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The two halves of the same fact, side by side: what is done reads
          // as the achievement, what is left reads as the ask.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$done%',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                      height: 1,
                    ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  strings
                      .percentCompleted(done)
                      .replaceFirst('$done%', '')
                      .trim(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  strings.percentRemaining(left),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.ratio,
              minHeight: 16,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            progress.isPlanBased
                ? strings.planProgress(
                    progress.completedUnits, progress.totalUnits)
                : strings.goalProgress(
                    progress.completedUnits, progress.totalUnits),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
