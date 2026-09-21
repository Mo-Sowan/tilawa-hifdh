import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/presentation/providers/quran_providers.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';

/// How much of the Quran the reciter has been through.
///
/// Two figures, because one alone misleads. Counting surahs is what people say
/// — "I've done 57 of them" — but a surah is not a unit of size: Al-Fatiha and
/// Al-Baqarah each move that count by one, though one is 7 ayahs and the other
/// 286. Counting Mushaf pages says how much of the book it actually is.
///
/// Someone who has revised the whole of Juz Amma has done 37 of 114 surahs —
/// a third by count — and about a twentieth of the pages. Both are true, and
/// showing them together is the only honest way to answer "how far am I?".
class QuranCoverage {
  const QuranCoverage({
    required this.surahsRevised,
    required this.totalSurahs,
    required this.pagesRevised,
    required this.totalPages,
  });

  const QuranCoverage.none()
      : surahsRevised = 0,
        totalSurahs = 114,
        pagesRevised = 0,
        totalPages = 604;

  final int surahsRevised;
  final int totalSurahs;

  /// Distinct Mushaf pages touched by at least one revised surah.
  final int pagesRevised;
  final int totalPages;

  double get surahRatio =>
      totalSurahs == 0 ? 0 : (surahsRevised / totalSurahs).clamp(0.0, 1.0);

  double get pageRatio =>
      totalPages == 0 ? 0 : (pagesRevised / totalPages).clamp(0.0, 1.0);

  int get surahPercent => (surahRatio * 100).round();
  int get pagePercent => (pageRatio * 100).round();

  /// Nothing revised yet. The dashboard hides the card entirely in this state
  /// rather than greeting a new reciter with a zero.
  bool get isEmpty => surahsRevised == 0;
}

final quranCoverageProvider = Provider<QuranCoverage>((ref) {
  final surahs = ref.watch(revisionOverviewProvider).valueOrNull ?? const [];
  final revised = surahs.where((surah) => surah.isAssessed).toList();
  if (revised.isEmpty) return const QuranCoverage.none();

  final index = ref.watch(quranTextIndexProvider).valueOrNull;
  var pages = 0;
  if (index != null) {
    // A page can carry the end of one surah and the start of the next, so the
    // pages are collected into a set before being counted.
    final touched = <int>{};
    for (final surah in revised) {
      for (final ayah in index.surahAyahs(surah.number)) {
        if (ayah.page > 0) touched.add(ayah.page);
      }
    }
    pages = touched.length;
  }

  return QuranCoverage(
    surahsRevised: revised.length,
    totalSurahs: surahs.length,
    pagesRevised: pages,
    totalPages: 604,
  );
});
