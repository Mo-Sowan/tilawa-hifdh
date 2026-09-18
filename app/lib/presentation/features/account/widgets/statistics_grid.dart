import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';
import 'package:tilawa/presentation/features/account/widgets/account_stat_card.dart';

/// The four numbers a reciter actually tracks.
class StatisticsGrid extends ConsumerWidget {
  const StatisticsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final summary = ref.watch(progressSummaryProvider).valueOrNull;
    final surahs = ref.watch(revisionOverviewProvider).valueOrNull ?? const [];

    final started = surahs.where((s) => s.revisionCount > 0).length;
    final revisions =
        surahs.fold<int>(0, (sum, surah) => sum + surah.revisionCount);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        AccountStatCard(
          icon: Icons.bolt_rounded,
          label: strings.totalXpLabel,
          value: '${summary?.totalXp ?? 0}',
        ),
        AccountStatCard(
          icon: Icons.local_fire_department_rounded,
          label: strings.currentStreakLabel,
          value: strings.dayCount(summary?.streak ?? 0),
        ),
        AccountStatCard(
          icon: Icons.menu_book_rounded,
          label: strings.surahsStartedLabel,
          value: '$started',
        ),
        AccountStatCard(
          icon: Icons.repeat_rounded,
          label: strings.revisionsLabel,
          value: '$revisions',
        ),
      ],
    );
  }
}
