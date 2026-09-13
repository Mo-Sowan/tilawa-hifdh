import 'package:flutter/material.dart';

import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/domain/entities/revision_intensity.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';

class SurahPathNode extends StatelessWidget {
  const SurahPathNode({
    required this.surah,
    required this.index,
    super.key,
  });

  final SurahRevision surah;
  final int index;

  @override
  Widget build(BuildContext context) {
    final alignment =
        index.isEven ? Alignment.centerLeft : Alignment.centerRight;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = !surah.isAssessed
        ? (isDark ? AppColors.textMuted : AppColors.lightTextMuted)
        : (surah.mastery < 0.5 
            ? AppColors.rose 
            : (surah.mastery < 0.8 ? AppColors.amber : AppColors.emerald));
    final locked = !surah.isUnlocked;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Opacity(
          opacity: locked ? .45 : 1,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: .22)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: .08),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 62,
                      height: 62,
                      child: CircularProgressIndicator(
                        value: surah.masteryOrNull ?? 0,
                        strokeWidth: 6,
                        backgroundColor: Colors.white.withValues(alpha: .08),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            locked ? AppColors.textMuted : color),
                      ),
                    ),
                    Text(
                      '${surah.number}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: locked
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        surah.englishName,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      Text(
                        surah.arabicName,
                        textAlign: TextAlign.right,
                        style: AppTheme.arabicText(
                          size: 22,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${surah.ayahCount} ayat · ${surah.revisionIntensity.label}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  locked ? Icons.lock_rounded : Icons.check_circle_rounded,
                  color: locked ? AppColors.textMuted : color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
