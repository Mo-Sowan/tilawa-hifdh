import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/data/quran/quran_text_index.dart';

/// The bundled Quran text, loaded once and shared by every reader surface.
final quranTextIndexProvider = FutureProvider<QuranTextIndex>((ref) async {
  ref.keepAlive();
  return QuranTextIndex.load();
});

/// Every ayah of a surah (1-114).
final quranSurahProvider =
    FutureProvider.family<List<QuranAyah>, int>((ref, surahNumber) async {
  final index = await ref.watch(quranTextIndexProvider.future);
  return index.surahAyahs(surahNumber);
});

/// Metadata for all 114 surahs.
final surahListProvider = FutureProvider<List<QuranSurahMeta>>((ref) async {
  final index = await ref.watch(quranTextIndexProvider.future);
  return index.surahs;
});

/// Text search across the whole Quran.
final quranSearchProvider =
    FutureProvider.family<List<QuranAyah>, String>((ref, query) async {
  if (query.trim().isEmpty) return const [];
  final index = await ref.watch(quranTextIndexProvider.future);
  return index.search(query);
});

/// Whether Mushaf page positions are available. Without the generated index
/// asset the page reader has nothing to lay out.
final hasPageIndexProvider = Provider<bool>((ref) {
  return ref.watch(quranTextIndexProvider).valueOrNull?.hasPageIndex ?? false;
});
