import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/domain/entities/surah_revision.dart';
import 'package:tilawa/recitation/presentation/live_recitation_view.dart';

// ─── Due Today List (Sorted Weakest → Strongest) ────────────────────────────
class DueTodayList extends ConsumerWidget {
  const DueTodayList({super.key, required this.surahs});

  final List<SurahRevision> surahs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    // Only surahs the reciter has actually been through. Everything else has
    // never been claimed as memorised, so calling all 113 of them "due" turned
    // the dashboard into a wall of red on day one and said nothing useful.
    final dueSurahs =
        surahs.where((s) => s.isAssessed && s.isDueToday).toList()
      ..sort((a, b) => a.number.compareTo(b.number)); // ascending order
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              strings.dueSurahs,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: dueSurahs.isEmpty
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: .15)
                    : Theme.of(context)
                        .colorScheme
                        .error
                        .withValues(alpha: .15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${dueSurahs.length} ${strings.dueTodayCount}',
                style: TextStyle(
                  color: dueSurahs.isEmpty
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (dueSurahs.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    color: Theme.of(context).colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    strings.noDueSurahs,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dueSurahs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final surah = dueSurahs[index];
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LiveRecitationView(surah: surah),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 168,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .error
                            .withValues(alpha: .3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          strings.isArabic
                              ? surah.arabicName
                              : surah.englishName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings.surahInfo(surah.number, surah.ayahCount),
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          surah.isAssessed
                              ? strings
                                  .masteryPercent((surah.mastery * 100).round())
                              : strings.masteryUnknown,
                          style: TextStyle(
                            color: surah.isAssessed
                                ? Theme.of(context).colorScheme.error
                                : muted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
