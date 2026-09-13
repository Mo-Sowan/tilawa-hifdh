import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/revision_plan_provider.dart';

class RevisionPlanSheet extends ConsumerWidget {
  const RevisionPlanSheet({
    required this.surahs,
    super.key,
  });

  final List<SurahRevision> surahs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final plan = ref.watch(activeRevisionPlanProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan?.name ?? strings.planRevision,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: strings.close,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              strings.planHint,
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 260,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final surah in surahs)
                      FilterChip(
                        selected:
                            plan?.surahNumbers.contains(surah.number) ?? false,
                        onSelected: (_) async {
                          final controller =
                              ref.read(revisionPlansProvider.notifier);
                          if (plan == null) {
                            await controller.createPlan(
                              name: 'Quick Revision',
                              surahNumbers: {surah.number},
                              reminderTime:
                                  DateTime.now().add(const Duration(hours: 1)),
                            );
                            return;
                          }
                          final next = <int>{...plan.surahNumbers};
                          if (!next.add(surah.number)) {
                            next.remove(surah.number);
                          }
                          if (next.isEmpty) {
                            next.add(surah.number);
                          }
                          await controller
                              .updatePlan(plan.copyWith(surahNumbers: next));
                        },
                        label: Text(
                          '${surah.number}. ${strings.isArabic ? surah.arabicName : surah.englishName}',
                        ),
                        selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: .18),
                        checkmarkColor: Theme.of(context).colorScheme.primary,
                        side: BorderSide(
                          color:
                              plan?.surahNumbers.contains(surah.number) ?? false
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
