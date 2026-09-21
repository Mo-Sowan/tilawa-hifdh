import 'package:flutter_test/flutter_test.dart';
import 'package:tilawa/presentation/providers/quran_coverage_provider.dart';

void main() {
  QuranCoverage coverage({
    int surahs = 0,
    int pages = 0,
  }) =>
      QuranCoverage(
        surahsRevised: surahs,
        totalSurahs: 114,
        pagesRevised: pages,
        totalPages: 604,
      );

  group('the card hides itself until there is something to show', () {
    test('nothing revised is empty', () {
      expect(const QuranCoverage.none().isEmpty, isTrue);
      expect(coverage().isEmpty, isTrue);
    });

    test('one surah is enough to appear', () {
      expect(coverage(surahs: 1, pages: 1).isEmpty, isFalse);
    });
  });

  group('percentages', () {
    test('57 of 114 surahs reads as 50%', () {
      expect(coverage(surahs: 57, pages: 100).surahPercent, 50);
    });

    test('all 114 surahs and 604 pages is 100% both ways', () {
      final done = coverage(surahs: 114, pages: 604);
      expect(done.surahPercent, 100);
      expect(done.pagePercent, 100);
      expect(done.surahRatio, 1.0);
    });

    test('ratios never exceed one, even on inconsistent input', () {
      final over = QuranCoverage(
        surahsRevised: 200,
        totalSurahs: 114,
        pagesRevised: 900,
        totalPages: 604,
      );
      expect(over.surahRatio, 1.0);
      expect(over.pageRatio, 1.0);
    });

    test('a zero total does not divide by zero', () {
      const none = QuranCoverage(
        surahsRevised: 0,
        totalSurahs: 0,
        pagesRevised: 0,
        totalPages: 0,
      );
      expect(none.surahRatio, 0);
      expect(none.pageRatio, 0);
    });
  });

  // This is why both numbers are shown rather than only the one people quote.
  test('counting surahs overstates progress against counting pages', () {
    // Juz Amma is 37 of the 114 surahs but only about 23 of the 604 pages.
    final juzAmma = coverage(surahs: 37, pages: 23);

    expect(juzAmma.surahPercent, 32);
    expect(juzAmma.pagePercent, 4);
    expect(juzAmma.surahPercent, greaterThan(juzAmma.pagePercent * 5));
  });
}
