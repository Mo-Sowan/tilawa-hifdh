import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/domain/entities/revision_plan.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';
import 'package:tilawa/presentation/features/plan/widgets/start_reciting_button.dart';
import 'package:tilawa/presentation/widgets/tarteel_surah_navigator.dart';
import 'package:tilawa/recitation/presentation/live_recitation_view.dart';

class PlanDetailView extends ConsumerWidget {
  const PlanDetailView({required this.plan, super.key});

  final RevisionPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final overviewAsync = ref.watch(revisionOverviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(plan.name),
      ),
      body: overviewAsync.when(
        data: (surahs) {
          final planSurahs = surahs
              .where((s) => plan.surahNumbers.contains(s.number))
              .toList();
          final now = DateTime.now();
          bool completedToday(SurahRevision surah) {
            final reviewed = surah.lastReviewed?.toLocal();
            return reviewed != null &&
                reviewed.year == now.year &&
                reviewed.month == now.month &&
                reviewed.day == now.day;
          }

          // Keep the next useful action at the top while retaining the
          // repository's priority order inside each group.
          planSurahs.sort((a, b) {
            final aDone = completedToday(a);
            final bDone = completedToday(b);
            if (aDone == bDone) return 0;
            return aDone ? 1 : -1;
          });

          if (planSurahs.isEmpty) {
            return Center(
              child: Text(
                strings.noPlanYet,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _PlanTodayCard(
                    completed: planSurahs.where(completedToday).length,
                    total: planSurahs.length,
                    strings: strings,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: StartRecitingButton(plan: plan),
                ),
                const SizedBox(height: 20),
                TarteelSurahNavigator(
                  surahs: planSurahs,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onOpenSurah: (surah) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LiveRecitationView(surah: surah),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _PlanTodayCard extends StatelessWidget {
  const _PlanTodayCard({
    required this.completed,
    required this.total,
    required this.strings,
  });

  final int completed;
  final int total;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final progress = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.route_rounded, color: primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings.todayPlan,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '$completed / $total',
                style: TextStyle(color: primary, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: primary.withValues(alpha: .12),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            strings.planTodayExplanation,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
