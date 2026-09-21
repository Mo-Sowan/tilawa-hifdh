import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/quran_coverage_provider.dart';

/// How far through the Quran the reciter has been.
///
/// Hidden until the first revision. A brand-new reciter opening the app to a
/// bar reading 0% is being told what they have not done before they have had a
/// chance to do anything; the card only earns its place once there is progress
/// to show, and its first appearance is itself a small reward.
///
/// Two numbers, because either alone misleads — see [QuranCoverage]. Surahs
/// lead, since that is how people describe their own progress, and the share
/// of the Mushaf sits underneath as the truer measure of how much text that
/// actually is.
class QuranCompletionCard extends ConsumerWidget {
  const QuranCompletionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final coverage = ref.watch(quranCoverageProvider);

    if (coverage.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF0D2818),
                  Color(0xFF1A3A2A),
                  Color(0xFF0D2818),
                ]
              : const [
                  Color(0xFFE8F5E9),
                  Color(0xFFC8E6C9),
                  Color(0xFFE8F5E9),
                ],
        ),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.quranCoverageTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Text(
                '${coverage.surahPercent}%',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: coverage.surahRatio,
              minHeight: 14,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            strings.surahsRevisedOf(
              coverage.surahsRevised,
              coverage.totalSurahs,
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface.withValues(alpha: 0.8),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.pagesRevisedOf(
              coverage.pagesRevised,
              coverage.totalPages,
              coverage.pagePercent,
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
          ),
        ],
      ),
    );
  }
}
