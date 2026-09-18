import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/domain/entities/hasanat.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';
import 'package:tilawa/presentation/providers/quran_providers.dart';

/// Reward for what was recited this session.
///
/// The letters are counted from the verses the recogniser actually matched,
/// read out of the bundled corpus — never from a verse count multiplied by an
/// average, which would be a number the app made up.
class HasanatCard extends ConsumerWidget {
  const HasanatCard({super.key, required this.refs});

  final List<String> refs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final index = ref.watch(quranTextIndexProvider).valueOrNull;
    if (index == null) return const SizedBox.shrink();

    final texts = <String>[];
    for (final reference in refs) {
      final parts = reference.split(':');
      if (parts.length != 2) continue;
      final surah = int.tryParse(parts[0]);
      final ayah = int.tryParse(parts[1]);
      if (surah == null || ayah == null) continue;
      final verse = index.ayah(surah, ayah);
      if (verse != null) texts.add(verse.textUthmani);
    }
    if (texts.isEmpty) return const SizedBox.shrink();

    final letters = Hasanat.countLettersIn(texts);
    final reward = letters * Hasanat.perLetter;
    final format = NumberFormat.decimalPattern(strings.isArabic ? 'ar' : 'en');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.amber),
              const SizedBox(width: 8),
              Text(
                strings.hasanatTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.amber,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            strings.hasanatEarned(format.format(reward)),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.hasanatLetters(format.format(letters)),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.hasanatNote,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}
