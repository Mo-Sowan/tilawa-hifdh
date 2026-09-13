import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/domain/entities/revision_intensity.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';
import 'package:tilawa/presentation/widgets/glass_panel.dart';

class ActiveRevisionCard extends ConsumerWidget {
  const ActiveRevisionCard({
    required this.onStart,
    super.key,
  });

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weakest = ref.watch(weakestSurahProvider);
    final strings = ref.watch(appStringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final text =
        isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;

    return GlassPanel(
      onTap: onStart,
      padding: const EdgeInsets.all(22),
      child: weakest.when(
        data: (surah) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: .35),
                    ),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.startWeakestSurah,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        strings.oneTapRevision,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              strings.isArabic ? surah.arabicName : surah.englishName,
              textAlign: TextAlign.right,
              style: strings.isArabic 
                  ? AppTheme.arabicText(size: 42, color: text)
                  : Theme.of(context).textTheme.headlineLarge?.copyWith(color: text, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              strings.isArabic
                  ? 'سورة ${surah.number} - ${surah.revisionIntensity.label}'
                  : 'Surah ${surah.number} - ${surah.revisionIntensity.label}',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: surah.masteryOrNull ?? 0,
                backgroundColor: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: .08),
                valueColor:
                    AlwaysStoppedAnimation<Color>(!surah.isAssessed ? (isDark ? AppColors.textMuted : AppColors.lightTextMuted) : (surah.mastery < 0.5 ? AppColors.rose : (surah.mastery < 0.8 ? AppColors.amber : AppColors.emerald))),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              !surah.isAssessed
                  ? strings.masteryUnknown
                  : '${(surah.mastery * 100).round()}% ${strings.mastery} - ${(surah.mistakeRate * 100).round()}% ${strings.mistakes}',
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
        loading: () => const SizedBox(
          height: 210,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Text('Unable to load revision target: $error'),
      ),
    );
  }
}
