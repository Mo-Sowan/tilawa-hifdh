import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// One verse as the UI needs it: script, normalized text and its position in
/// the printed Mushaf.
@immutable
class QuranAyah {
  const QuranAyah({
    required this.surah,
    required this.ayah,
    required this.textUthmani,
    required this.textClean,
    required this.surahName,
    required this.surahNameEn,
    required this.page,
    required this.juz,
    required this.hizbQuarter,
  });

  final int surah;
  final int ayah;
  final String textUthmani;
  final String textClean;
  final String surahName;
  final String surahNameEn;
  final int page;
  final int juz;
  final int hizbQuarter;

  String get ref => '$surah:$ayah';
}

/// Metadata for one surah, derived from the corpus itself.
@immutable
class QuranSurahMeta {
  const QuranSurahMeta({
    required this.number,
    required this.arabicName,
    required this.englishName,
    required this.ayahCount,
    required this.startPage,
  });

  final int number;
  final String arabicName;
  final String englishName;
  final int ayahCount;
  final int startPage;
}

/// What the parse produces, before the lookup tables are built.
@immutable
class _ParsedCorpus {
  const _ParsedCorpus(this.ayahs, this.surahs);

  final List<QuranAyah> ayahs;
  final List<QuranSurahMeta> surahs;
}

/// Read-only Quran text for display.
///
/// Deliberately separate from the recogniser's corpus: this holds only what the
/// UI renders, while the recogniser additionally carries per-verse CTC token
/// ids and span tables and lives in its own isolate.
///
/// Backed by `quran_display.json`, a generated file that packs verse text and
/// Mushaf position into positional rows with the surah names stored once. The
/// two sources it derives from repeat every surah name and field name on all
/// 6,236 rows, which was most of their bytes and all of the load time.
class QuranTextIndex {
  QuranTextIndex._(this._ayahs, this._surahs) {
    for (final ayah in _ayahs) {
      _byRef[ayah.ref] = ayah;
      (_bySurah[ayah.surah] ??= <QuranAyah>[]).add(ayah);
      if (ayah.page > 0) (_byPage[ayah.page] ??= <QuranAyah>[]).add(ayah);
    }
    for (final meta in _surahs) {
      _metaByNumber[meta.number] = meta;
    }
  }

  static const String displayAsset = 'assets/quran/quran_display.json';

  final List<QuranAyah> _ayahs;
  final List<QuranSurahMeta> _surahs;
  final Map<String, QuranAyah> _byRef = {};
  final Map<int, List<QuranAyah>> _bySurah = {};
  final Map<int, List<QuranAyah>> _byPage = {};
  final Map<int, QuranSurahMeta> _metaByNumber = {};

  List<QuranSurahMeta> get surahs => List.unmodifiable(_surahs);

  int get totalAyahs => _ayahs.length;

  bool get hasPageIndex => _byPage.isNotEmpty;

  QuranAyah? ayah(int surah, int ayah) => _byRef['$surah:$ayah'];

  List<QuranAyah> surahAyahs(int surah) => _bySurah[surah] ?? const [];

  List<QuranAyah> pageAyahs(int page) => _byPage[page] ?? const [];

  QuranSurahMeta? surahMeta(int surah) => _metaByNumber[surah];

  /// Substring search over the normalized text.
  List<QuranAyah> search(String query, {int limit = 50}) {
    final needle = query.trim();
    if (needle.isEmpty) return const [];
    final results = <QuranAyah>[];
    for (final ayah in _ayahs) {
      if (ayah.textClean.contains(needle) || ayah.textUthmani.contains(needle)) {
        results.add(ayah);
        if (results.length >= limit) break;
      }
    }
    return results;
  }

  /// Loads the index, parsing on a background isolate so opening the reader
  /// does not stall a frame.
  ///
  /// `compute` runs inline on the web, which has no isolates; there the saving
  /// is the smaller file rather than the offloading.
  static Future<QuranTextIndex> load() async {
    final String source;
    try {
      source = await rootBundle.loadString(displayAsset);
    } catch (error) {
      throw StateError(
        'Could not read $displayAsset ($error). It is generated — run '
        'tools/build_display_index.py after changing the corpus or the '
        'position index.',
      );
    }

    final parsed = await compute(_parseCorpus, source);
    return QuranTextIndex._(parsed.ayahs, parsed.surahs);
  }

  /// Runs on a background isolate: decode, then build the rows.
  static _ParsedCorpus _parseCorpus(String source) {
    final document = jsonDecode(source) as Map<String, dynamic>;

    final surahs = [
      for (final row in (document['surahs'] as List).cast<Map<String, dynamic>>())
        QuranSurahMeta(
          number: (row['n'] as num).toInt(),
          arabicName: row['ar'] as String,
          englishName: row['en'] as String,
          ayahCount: (row['c'] as num).toInt(),
          startPage: (row['p'] as num).toInt(),
        ),
    ];

    final namesByNumber = {
      for (final meta in surahs) meta.number: meta,
    };

    // Positional rows: surah, ayah, page, juz, hizb, uthmani, clean.
    final ayahs = [
      for (final row in (document['verses'] as List).cast<List<dynamic>>())
        () {
          final surah = (row[0] as num).toInt();
          final meta = namesByNumber[surah];
          return QuranAyah(
            surah: surah,
            ayah: (row[1] as num).toInt(),
            page: (row[2] as num).toInt(),
            juz: (row[3] as num).toInt(),
            hizbQuarter: (row[4] as num).toInt(),
            textUthmani: row[5] as String,
            textClean: row[6] as String,
            surahName: meta?.arabicName ?? '',
            surahNameEn: meta?.englishName ?? '',
          );
        }(),
    ];

    return _ParsedCorpus(ayahs, surahs);
  }
}
