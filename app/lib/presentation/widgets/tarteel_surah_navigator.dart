import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/localization/app_strings.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/domain/entities/revision_intensity.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/revision_plan_provider.dart';

class TarteelSurahNavigator extends ConsumerWidget {
  const TarteelSurahNavigator({
    required this.surahs,
    required this.onOpenSurah,
    this.shrinkWrap = false,
    this.physics,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 32),
    super.key,
  });

  final List<SurahRevision> surahs;
  final ValueChanged<SurahRevision> onOpenSurah;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(activeRevisionPlanProvider);
    final strings = ref.watch(appStringsProvider);

    return ListView.separated(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: surahs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final surah = surahs[index];
        final planned = plan?.surahNumbers.contains(surah.number) ?? false;
        return _SurahNavigationTile(
          surah: surah,
          planned: planned,
          strings: strings,
          onTap: () => onOpenSurah(surah),
          onPlanTap: () async {
            final controller = ref.read(revisionPlansProvider.notifier);
            if (plan == null) {
              await controller.createPlan(
                name: 'Quick Revision',
                surahNumbers: {surah.number},
                reminderTime: DateTime.now().add(const Duration(hours: 1)),
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
            await controller.updatePlan(plan.copyWith(surahNumbers: next));
          },
        );
      },
    );
  }
}

class _SurahNavigationTile extends StatelessWidget {
  const _SurahNavigationTile({
    required this.surah,
    required this.planned,
    required this.strings,
    required this.onTap,
    required this.onPlanTap,
  });

  final SurahRevision surah;
  final bool planned;
  final AppStrings strings;
  final VoidCallback onTap;
  final VoidCallback onPlanTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;
    final muted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final text =
        isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    // A surah nobody has revised yet is not weak — nothing is known about it —
    // so it stays neutral rather than joining a wall of red.
    final accent = !surah.isAssessed
        ? (isDark ? AppColors.textMuted : AppColors.lightTextMuted)
        : (surah.mastery < 0.5
            ? AppColors.rose
            : (surah.mastery < 0.8 ? AppColors.amber : AppColors.emerald));

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: planned
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: .55)
                  : accent.withValues(alpha: .18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? .16 : .045),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              _SurahNumberBadge(
                number: surah.number,
                mastery: surah.masteryOrNull ?? 0,
                color: accent,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            strings.isArabic
                                ? surah.arabicName
                                : surah.englishName,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: text,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          surah.isAssessed
                              ? '${(surah.mastery * 100).round()}%'
                              : strings.masteryUnknownShort,
                                  style:
                                      Theme.of(context).textTheme.labelLarge?.copyWith(
                                            color: accent,
                                            fontWeight: FontWeight.w900,
                                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.isArabic
                          ? 'سورة ${surah.number} - ${surah.ayahCount} ${strings.ayat} - ${surah.revisionIntensity.label}'
                          : 'Surah ${surah.number} - ${surah.ayahCount} ${strings.ayat} - ${surah.revisionIntensity.label}',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: surah.masteryOrNull ?? 0,
                        backgroundColor: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: isDark ? .08 : .06),
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: planned ? strings.removeFromPlan : strings.addToPlan,
                onPressed: onPlanTap,
                icon: Icon(
                  planned
                      ? Icons.bookmark_added_rounded
                      : Icons.bookmark_add_outlined,
                  color: planned ? Theme.of(context).colorScheme.primary : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurahNumberBadge extends StatelessWidget {
  const _SurahNumberBadge({
    required this.number,
    required this.mastery,
    required this.color,
  });

  final int number;
  final double mastery;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 58,
          height: 58,
          child: CircularProgressIndicator(
            value: mastery,
            strokeWidth: 5,
            backgroundColor: bg,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$number',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
      ],
    );
  }
}
