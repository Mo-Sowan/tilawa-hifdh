import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tilawa/core/theme/app_theme.dart';
import 'package:tilawa/data/quran/quran_text_index.dart';
import 'package:tilawa/presentation/providers/app_settings_provider.dart';

class SearchResultsList extends ConsumerWidget {
  const SearchResultsList({super.key, 
    required this.results,
    required this.loading,
    required this.onAyahTap,
  });

  final List<QuranAyah> results;
  final bool loading;
  final ValueChanged<QuranAyah> onAyahTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final ayah = results[index];
        return Card(
          child: InkWell(
            onTap: () => onAyahTap(ayah),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Surah info
                  Row(
                    children: [
                      Icon(Icons.menu_book_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${strings.isArabic ? ayah.surahName : ayah.surahNameEn} - ${strings.ayahLabel} ${ayah.ayah}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        '${strings.pageLabel} ${ayah.page}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Ayah text
                  Text(
                    ayah.textUthmani,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontFamily: AppTheme.quranFontFamily,
                      fontSize: 20,
                      height: 2.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
