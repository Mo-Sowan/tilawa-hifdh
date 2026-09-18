import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/features/leaderboard/leaderboard_view.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';
import 'package:tilawa/presentation/features/progress/widgets/session_log_card.dart';
import 'package:tilawa/presentation/features/progress/widgets/activity_heatmap_card.dart';
import 'package:tilawa/presentation/features/progress/widgets/progress_stat_card.dart';
import 'package:tilawa/presentation/features/progress/widgets/mastery_bar.dart';

class ProgressView extends ConsumerWidget {
  const ProgressView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final progress = ref.watch(progressSummaryProvider);

    return SafeArea(
      child: progress.when(
        data: (summary) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.progressTab,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: strings.leaderboardTitle,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LeaderboardView(),
                    ),
                  ),
                  icon: const Icon(Icons.leaderboard_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                ProgressStatCard(
                  title: strings.xp,
                  value: '${summary.totalXp}',
                  icon: Icons.star_rounded,
                  color: Theme.of(context).colorScheme.secondary,
                  onTap: () => _showInfoSheet(
                      context, strings.xp, strings.xpDescription),
                ),
                ProgressStatCard(
                  title: strings.streak,
                  value: '${summary.streak}',
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.rose,
                  onTap: () => _showInfoSheet(
                      context, strings.streak, strings.streakDescription),
                ),
                ProgressStatCard(
                  title: strings.score,
                  value: '${summary.score}',
                  icon: Icons.military_tech_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                ProgressStatCard(
                  title: strings.reviewedToday,
                  value: '${summary.reviewedToday}',
                  icon: Icons.fact_check_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 22),
            ActivityHeatmapCard(days: summary.calendar),
            const SizedBox(height: 22),
            const SessionLogCard(),
            const SizedBox(height: 22),
            Text(
              strings.mastery,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            for (final bucket in summary.masteryBuckets) ...[
              MasteryBar(
                label: _localizedBucket(strings, bucket.label),
                count: bucket.count,
                ratio: bucket.ratio,
                color: _bucketColor(bucket.label, context),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  void _showInfoSheet(BuildContext context, String title, String description) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                      ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _localizedBucket(AppStrings strings, String label) {
    switch (label.toLowerCase()) {
      case 'excellent':
        return strings.excellent;
      case 'good':
        return strings.good;
      case 'shaky':
        return strings.shaky;
      default:
        return strings.weak;
    }
  }

  Color _bucketColor(String label, BuildContext context) {
    switch (label.toLowerCase()) {
      case 'excellent':
        return Theme.of(context).colorScheme.primary;
      case 'good':
        return Theme.of(context).colorScheme.primary;
      case 'shaky':
        return Theme.of(context).colorScheme.secondary;
      default:
        return Theme.of(context).colorScheme.error;
    }
  }
}
