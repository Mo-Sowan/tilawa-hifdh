import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/domain/entities/revision_plan.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';
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

          if (planSurahs.isEmpty) {
            return Center(
              child: Text(
                strings.noPlanYet,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            );
          }

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    strings.revisionPathSubtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textMuted
                              : AppColors.lightTextMuted,
                        ),
                  ),
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
