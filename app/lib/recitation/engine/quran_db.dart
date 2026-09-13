import 'dart:typed_data';

import 'package:tilawa/recitation/engine/arabic_normalizer.dart';
import 'package:tilawa/recitation/engine/levenshtein.dart';
import 'package:tilawa/recitation/engine/recitation_types.dart';

/// Basmala words as they appear after [normalizeArabic].
const List<String> _basmalaWords = ['بسم', 'الله', 'الرحمن', 'الرحيم'];

// --- Joint matcher tuning (mirrors the reference implementation) -----------
const int _jointTopK = 18;
const int _jointTopSurahs = 32;
const int _jointMaxSpan = 6;
const double _jointFragmentBlend = 0.82;
const int _jointPrefixMaxSpan = 7;
const int _jointPrefixMinChars = 34;
const double _jointPrefixMinScore = 0.50;
const double _jointPrefixMargin = -0.02;
const int _jointGlobalSpanMinChars = 80;
const double _jointGlobalSpanMinScore = 0.54;
const double _jointGlobalSpanMargin = -0.015;
const int _jointGlobalSpanShortlist = 320;
const int _jointOpeningCollapseMinChars = 34;
const int _jointOpeningCollapseMaxChars = 115;
const double _jointOpeningCollapseMinScore = 0.50;
const int _jointShortOpeningMaxChars = 10;
const int _jointShortOpeningMinQueryChars = 8;
const double _jointShortOpeningMinScore = 0.48;
const double _jointShortOpeningMargin = -0.18;

enum CandidateKind { single, span }

/// A retrieval candidate: one verse, or a run of consecutive verses.
class QuranCandidate {
  const QuranCandidate({
    required this.surah,
    required this.ayah,
    required this.ayahEnd,
    required this.text,
    required this.phonemesJoined,
    required this.phonemeTokenIds,
    required this.stageAScore,
    required this.rawScore,
    required this.bonus,
    required this.kind,
    this.surahRank,
  });

  final int surah;
  final int ayah;
  final int? ayahEnd;
  final String text;
  final String phonemesJoined;
  final List<int> phonemeTokenIds;

  /// Text-only retrieval score, continuation bonus included.
  final double stageAScore;
  final double rawScore;
  final double bonus;
  final CandidateKind kind;
  final int? surahRank;

  String get refKey => refKeyFor(surah, ayah, ayahEnd);
}

/// The matcher's pick for a transcript.
class QuranMatch {
  const QuranMatch({
    required this.surah,
    required this.ayah,
    required this.ayahEnd,
    required this.text,
    required this.phonemesJoined,
    required this.score,
    required this.rawScore,
    required this.bonus,
    this.prefixRescue = false,
    this.globalSpanRescue = false,
  });

  final int surah;
  final int ayah;
  final int? ayahEnd;
  final String text;
  final String phonemesJoined;
  final double score;
  final double rawScore;
  final double bonus;

  /// Came from the surah-opening rescue table.
  final bool prefixRescue;

  /// Came from the whole-corpus span rescue table.
  final bool globalSpanRescue;

  QuranMatch copyWith({
    int? surah,
    int? ayah,
    int? ayahEnd,
    bool clearAyahEnd = false,
    String? text,
    String? phonemesJoined,
    double? score,
    double? rawScore,
    double? bonus,
  }) {
    return QuranMatch(
      surah: surah ?? this.surah,
      ayah: ayah ?? this.ayah,
      ayahEnd: clearAyahEnd ? null : (ayahEnd ?? this.ayahEnd),
      text: text ?? this.text,
      phonemesJoined: phonemesJoined ?? this.phonemesJoined,
      score: score ?? this.score,
      rawScore: rawScore ?? this.rawScore,
      bonus: bonus ?? this.bonus,
      prefixRescue: prefixRescue,
      globalSpanRescue: globalSpanRescue,
    );
  }

  String get refKey => refKeyFor(surah, ayah, ayahEnd);
}

class CandidateRetrieval {
  const CandidateRetrieval({
    required this.singles,
    required this.spans,
    required this.combined,
  });

  final List<QuranCandidate> singles;
  final List<QuranCandidate> spans;
  final List<QuranCandidate> combined;

  static const CandidateRetrieval empty = CandidateRetrieval(
    singles: [],
    spans: [],
    combined: [],
  );
}

/// `surah:ayah` for a single verse, `surah:ayah-ayahEnd` for a span.
String refKeyFor(int surah, int ayah, [int? ayahEnd]) {
  return (ayahEnd != null && ayahEnd != ayah)
      ? '$surah:$ayah-$ayahEnd'
      : '$surah:$ayah';
}

/// A whole-corpus span, stored by index so the 37k-row rescue table costs
/// kilobytes instead of tens of megabytes. Text is materialized only for the
/// few hundred rows that survive the rough n-gram pass.
class _GlobalSpanRow {
  const _GlobalSpanRow({
    required this.surah,
    required this.startIndex,
    required this.span,
    required this.ayah,
    required this.ayahEnd,
  });

  final int surah;
  final int startIndex;
  final int span;
  final int ayah;
  final int ayahEnd;
}

/// Offline verse index and text matcher.
///
/// Owns candidate retrieval (Levenshtein + fragment scoring over the whole
/// corpus, plus multi-verse spans) and the joint rescue paths used when the
/// leading single-verse guess looks unreliable.
class QuranDB {
  QuranDB(List<QuranVerse> data, {Map<String, List<int>>? ctcTokenTable})
      : verses = data,
        _ctcTokenTable = ctcTokenTable {
    for (final verse in data) {
      _byRef[verse.ref] = verse;
      (_bySurah[verse.surah] ??= <QuranVerse>[]).add(verse);
      _applyBasmalaStripping(verse);
    }
  }

  final List<QuranVerse> verses;
  final Map<String, List<int>>? _ctcTokenTable;

  final Map<String, QuranVerse> _byRef = {};
  final Map<int, List<QuranVerse>> _bySurah = {};

  List<QuranMatch>? _jointPrefixSpans;
  List<_GlobalSpanRow>? _jointGlobalSpans;

  int get totalVerses => verses.length;

  int get surahCount => _bySurah.length;

  List<int> get surahNumbers => _bySurah.keys.toList()..sort();

  QuranVerse? getVerse(int surah, int ayah) => _byRef['$surah:$ayah'];

  List<QuranVerse> getSurah(int surah) => _bySurah[surah] ?? const [];

  /// Next verse in the same surah, rolling over to the first verse of the
  /// following surah at the end.
  QuranVerse? getNextVerse(int surah, int ayah) {
    final surahVerses = _bySurah[surah];
    if (surahVerses == null) return null;
    for (var i = 0; i < surahVerses.length; i++) {
      if (surahVerses[i].ayah != ayah) continue;
      if (i + 1 < surahVerses.length) return surahVerses[i + 1];
      final next = _bySurah[surah + 1];
      return (next == null || next.isEmpty) ? null : next.first;
    }
    return null;
  }

  /// Verses within [kSurroundingContext] ayahs of the given reference.
  List<SurroundingVerse> surroundingVerses(int surah, int ayah) {
    return [
      for (final verse in getSurah(surah))
        if ((verse.ayah - ayah).abs() <= kSurroundingContext)
          SurroundingVerse(
            surah: verse.surah,
            ayah: verse.ayah,
            text: verse.textUthmani,
            isCurrent: verse.ayah == ayah,
          ),
    ];
  }

  /// Verses whose token sequence is short enough to be recognised from a
  /// fragment of audio — the short-utterance rescue pool.
  List<QuranCandidate> getShortVerseCandidates({int maxTokens = 15}) {
    final result = <QuranCandidate>[];
    for (final verse in verses) {
      final ids = verse.phonemeTokenIdsNoBsm ?? verse.phonemeTokenIds;
      if (ids.isEmpty || ids.length > maxTokens) continue;
      result.add(
        QuranCandidate(
          surah: verse.surah,
          ayah: verse.ayah,
          ayahEnd: verse.ayah,
          text: verse.phonemesJoined,
          phonemesJoined: verse.phonemesJoined,
          phonemeTokenIds: ids,
          stageAScore: 0,
          rawScore: 0,
          bonus: 0,
          kind: CandidateKind.single,
        ),
      );
    }
    return result;
  }

  /// Plain text search over the corpus, ranked by similarity.
  List<({QuranVerse verse, double score})> search(String text, {int topK = 5}) {
    final scored = [
      for (final verse in verses)
        (verse: verse, score: similarityRatio(text, verse.phonemesJoined)),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return scored.take(topK).toList();
  }

  // -------------------------------------------------------------------------
  // Stage A retrieval
  // -------------------------------------------------------------------------

  /// Text-only candidate retrieval: every verse scored by similarity, then
  /// multi-verse spans built from the strongest surahs.
  CandidateRetrieval retrieveCandidates(
    String text, {
    int maxSpan = 4,
    ({int surah, int ayah})? hint,
    int singleLimit = 32,
    int topSurahs = 3,
    int spanLimit = 32,
    int? surahFilter,
  }) {
    if (text.trim().isEmpty) return CandidateRetrieval.empty;

    final bonuses = _continuationBonuses(hint);
    final textWords = splitWords(text);
    final noSpaceText = text.replaceAll(' ', '');

    final pool = surahFilter != null ? getSurah(surahFilter) : verses;
    final scored = <_ScoredVerse>[];

    for (final verse in pool) {
      var raw = similarityRatio(text, verse.phonemesJoined);

      final verseWordList = verse.phonemeWords;
      final sharedWordCount = textWords.length < verseWordList.length
          ? textWords.length
          : verseWordList.length;
      if (sharedWordCount > 0) {
        final textPrefix = textWords.take(sharedWordCount).join(' ');
        final versePrefix = verseWordList.take(sharedWordCount).join(' ');
        raw = _max(raw, similarityRatio(textPrefix, versePrefix));
      }
      if (noSpaceText.length <= 10) {
        raw = _max(raw, _shortQueryBoost(noSpaceText, verse));
      }
      final noBsm = verse.phonemesJoinedNoBsm;
      if (noBsm != null) {
        raw = _max(raw, similarityRatio(text, noBsm));
        if (noSpaceText.length <= 10) {
          raw = _max(raw, _shortQueryBoost(noSpaceText, verse, useNoBsm: true));
        }
      }

      final bonus = bonuses[verse.ref] ?? 0.0;
      if (bonus > 0) {
        raw = _max(raw, _suffixPrefixScore(text, verse.phonemesJoined));
      }
      scored.add(
        _ScoredVerse(verse, raw, bonus, _min(raw + bonus, 1.0)),
      );
    }
    scored.sort((a, b) => b.total.compareTo(a.total));

    final pass2Surahs = <int>[];
    for (final entry in scored) {
      if (pass2Surahs.length >= topSurahs) break;
      if (!pass2Surahs.contains(entry.verse.surah)) {
        pass2Surahs.add(entry.verse.surah);
      }
    }

    // Fragment rescue: a short transcript may be a slice of a long verse, in
    // which case whole-string similarity understates the fit.
    if (noSpaceText.length >= 8) {
      var resorted = false;
      for (var i = 0; i < scored.length; i++) {
        final entry = scored[i];
        if (noSpaceText.length >= entry.verse.phonemesJoinedNs.length * 0.8) {
          continue;
        }
        var frag = fragmentScore(noSpaceText, entry.verse.phonemesJoinedNs);
        final noBsmNs = entry.verse.phonemesJoinedNoBsmNs;
        if (noBsmNs != null) {
          frag = _max(frag, fragmentScore(noSpaceText, noBsmNs));
        }
        if (frag > entry.raw) {
          final boosted = entry.raw + (frag - entry.raw) * 0.7;
          scored[i] = _ScoredVerse(
            entry.verse,
            boosted,
            entry.bonus,
            _min(boosted + entry.bonus, 1.0),
          );
          resorted = true;
        }
      }
      if (resorted) scored.sort((a, b) => b.total.compareTo(a.total));
    }

    final singles = [
      for (final entry in scored.take(singleLimit))
        _candidateFromVerse(entry.verse, entry.raw, entry.bonus, entry.total),
    ];

    final spans = <QuranCandidate>[];
    for (var surahRank = 0; surahRank < pass2Surahs.length; surahRank++) {
      final surahVerses = getSurah(pass2Surahs[surahRank]);
      for (var i = 0; i < surahVerses.length; i++) {
        for (var span = 2; span <= maxSpan; span++) {
          if (i + span > surahVerses.length) break;
          final chunk = surahVerses.sublist(i, i + span);
          final spanText = _joinedSpanPhonemes(chunk);
          var raw = similarityRatio(text, spanText);
          final spanWords = splitWords(spanText);
          final sharedWordCount = textWords.length < spanWords.length
              ? textWords.length
              : spanWords.length;
          if (sharedWordCount > 0) {
            final textPrefix = textWords.take(sharedWordCount).join(' ');
            final spanPrefix = spanWords.take(sharedWordCount).join(' ');
            raw = _max(raw, similarityRatio(textPrefix, spanPrefix));
          }
          final bonus = bonuses[chunk.first.ref] ?? 0.0;
          spans.add(
            _candidateFromSpan(chunk, raw, bonus, _min(raw + bonus, 1.0),
                surahRank),
          );
        }
      }
    }
    spans.sort((a, b) => b.stageAScore.compareTo(a.stageAScore));

    final topSpans = spans.take(spanLimit).toList();
    return CandidateRetrieval(
      singles: singles,
      spans: topSpans,
      combined: [...singles, ...topSpans],
    );
  }

  /// Highest-scoring candidate above [threshold], or null.
  QuranMatch? matchVerse(
    String text, {
    double threshold = 0.3,
    int maxSpan = 3,
    ({int surah, int ayah})? hint,
    int? surahFilter,
  }) {
    final retrieved = retrieveCandidates(
      text,
      maxSpan: maxSpan,
      hint: hint,
      singleLimit: 5,
      topSurahs: 20,
      spanLimit: 64,
      surahFilter: surahFilter,
    );

    final ranked = [...retrieved.combined]
      ..sort((a, b) => b.stageAScore.compareTo(a.stageAScore));
    if (ranked.isEmpty || ranked.first.stageAScore < threshold) return null;

    final best = ranked.first;
    return QuranMatch(
      surah: best.surah,
      ayah: best.ayah,
      ayahEnd: best.ayahEnd,
      text: best.text,
      phonemesJoined: best.phonemesJoined,
      score: best.stageAScore,
      rawScore: best.rawScore,
      bonus: best.bonus,
    );
  }

  // -------------------------------------------------------------------------
  // Joint matcher (the "champion" path)
  // -------------------------------------------------------------------------

  /// Best joint match for a decoded transcript, applying the opening and
  /// whole-corpus span rescues when the leading guess is weak or is a span
  /// that starts mid-surah.
  QuranMatch? bestJointMatch(String text, {int? surahFilter}) {
    final top = _jointMatch(text, topK: _jointTopK, surahFilter: surahFilter);
    if (top.isEmpty) return null;

    final best = top.first;
    final bestScore = best.score;

    final shortOpening = _jointShortOpeningSpanCandidate(text, bestScore);
    if (shortOpening != null) return shortOpening;

    final bestIsLateSpan = best.ayahEnd != null && best.ayah > 1;
    final lowConfidence = bestScore < 0.62;
    if (!bestIsLateSpan && !lowConfidence) return best;

    final noSpaceLen = text.replaceAll(' ', '').length;
    final prefix = _jointSurahPrefixCandidates(text);
    final globalSpan = _jointGlobalSpanCandidates(text);

    final candidates = <QuranMatch>[
      best,
      ...prefix.where((p) => p.score >= bestScore + _jointPrefixMargin),
      ...globalSpan
          .where((g) => g.score >= bestScore + _jointGlobalSpanMargin),
    ]..sort((a, b) => b.score.compareTo(a.score));
    final chosen = candidates.first;

    // A mid-surah span over a medium-length transcript usually means the
    // reciter started at the top of the surah and the span drifted; prefer an
    // opening span from the same surah when one scores well.
    if (noSpaceLen >= _jointOpeningCollapseMinChars &&
        noSpaceLen <= _jointOpeningCollapseMaxChars &&
        best.ayahEnd != null &&
        best.ayah > 1) {
      final sameSurahPrefix = prefix
          .where(
            (p) =>
                p.surah == best.surah &&
                p.score >= _jointOpeningCollapseMinScore &&
                (p.ayahEnd == null ||
                    best.ayahEnd == null ||
                    p.ayahEnd! >= best.ayahEnd!),
          )
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      if (sameSurahPrefix.isNotEmpty) return sameSurahPrefix.first;
    }

    return chosen;
  }

  List<QuranMatch> _jointMatch(
    String phonemeText, {
    int topK = _jointTopK,
    int? surahFilter,
  }) {
    if (phonemeText.trim().isEmpty) return const [];

    final noSpaceText = phonemeText.replaceAll(' ', '');
    final candidatePool = surahFilter != null
        ? getSurah(surahFilter)
        : _jointCandidateVerses(noSpaceText);

    final scored = <_ScoredVerse>[];
    for (final verse in candidatePool) {
      final reference = verse.phonemesJoined;
      if (reference.isEmpty) continue;

      var raw = similarityRatio(phonemeText, reference);
      if (noSpaceText.length <= 10) {
        raw = _max(raw, _shortQueryBoost(noSpaceText, verse));
      }
      final noBsm = verse.phonemesJoinedNoBsm;
      if (noBsm != null) {
        raw = _max(raw, similarityRatio(phonemeText, noBsm));
        if (noSpaceText.length <= 10) {
          raw = _max(raw, _shortQueryBoost(noSpaceText, verse, useNoBsm: true));
        }
      }
      scored.add(_ScoredVerse(verse, raw, 0, raw));
    }
    scored.sort((a, b) => b.total.compareTo(a.total));

    final pass2Surahs = <int>[];
    for (final entry in scored) {
      if (!pass2Surahs.contains(entry.verse.surah)) {
        pass2Surahs.add(entry.verse.surah);
      }
      if (pass2Surahs.length >= _jointTopSurahs) break;
    }

    if (noSpaceText.length >= 8) {
      var resorted = false;
      for (var i = 0; i < scored.length; i++) {
        final entry = scored[i];
        final referenceNs = entry.verse.phonemesJoinedNs;
        if (referenceNs.isEmpty ||
            noSpaceText.length >= referenceNs.length * 0.8) {
          continue;
        }
        var frag = fragmentScore(noSpaceText, referenceNs);
        final noBsmNs = entry.verse.phonemesJoinedNoBsmNs;
        if (noBsmNs != null) {
          frag = _max(frag, fragmentScore(noSpaceText, noBsmNs));
        }
        if (frag > entry.raw) {
          final boosted = entry.raw + (frag - entry.raw) * _jointFragmentBlend;
          scored[i] = _ScoredVerse(entry.verse, boosted, 0, boosted);
          resorted = true;
        }
      }
      if (resorted) scored.sort((a, b) => b.total.compareTo(a.total));
    }

    final spanResults = <QuranMatch>[];
    final spanSurahs = surahFilter != null
        ? (pass2Surahs.contains(surahFilter) ? [surahFilter] : const <int>[])
        : pass2Surahs;
    for (final surahNumber in spanSurahs) {
      final surahVerses = getSurah(surahNumber);
      for (var i = 0; i < surahVerses.length; i++) {
        for (var span = 2; span <= _jointMaxSpan; span++) {
          if (i + span > surahVerses.length) break;
          final chunk = surahVerses.sublist(i, i + span);
          final spanPhonemes = _joinedSpanPhonemes(chunk);
          final score = _round4(similarityRatio(phonemeText, spanPhonemes));
          spanResults.add(
            QuranMatch(
              surah: surahNumber,
              ayah: chunk.first.ayah,
              ayahEnd: chunk.last.ayah,
              text: chunk.map((v) => v.textUthmani).join(' '),
              phonemesJoined: spanPhonemes,
              score: score,
              rawScore: score,
              bonus: 0,
            ),
          );
        }
      }
    }

    final singles = [
      for (final entry in scored.take(topK > 32 ? topK : 32))
        QuranMatch(
          surah: entry.verse.surah,
          ayah: entry.verse.ayah,
          ayahEnd: null,
          text: entry.verse.textUthmani,
          phonemesJoined: entry.verse.phonemesJoined,
          score: _round4(entry.total),
          rawScore: _round4(entry.raw),
          bonus: 0,
        ),
    ];

    return ([...singles, ...spanResults]
          ..sort((a, b) => b.score.compareTo(a.score)))
        .take(topK)
        .toList();
  }

  /// Opening spans (ayah 1..n) of every surah — rescues a reciter who started
  /// at the top of a surah but whose transcript best-matched something later.
  List<QuranMatch> _jointSurahPrefixCandidates(String phonemeText) {
    if (phonemeText.trim().isEmpty) return const [];
    final noSpaceText = phonemeText.replaceAll(' ', '');
    if (noSpaceText.length < _jointPrefixMinChars) return const [];

    final out = <QuranMatch>[];
    for (final row in _prefixSpanTable()) {
      final raw = similarityRatio(phonemeText, row.phonemesJoined);
      final frag = fragmentScore(
        noSpaceText,
        row.phonemesJoined.replaceAll(' ', ''),
      );
      final score = _max(raw, raw + (frag - raw) * _jointFragmentBlend);
      if (score < _jointPrefixMinScore) continue;
      out.add(
        QuranMatch(
          surah: row.surah,
          ayah: row.ayah,
          ayahEnd: row.ayahEnd,
          text: row.text,
          phonemesJoined: row.phonemesJoined,
          score: _round4(score),
          rawScore: _round4(raw),
          bonus: 0,
          prefixRescue: true,
        ),
      );
    }
    return (out..sort((a, b) => b.score.compareTo(a.score))).take(12).toList();
  }

  /// Whole-corpus multi-verse spans, shortlisted by character n-gram coverage
  /// before the expensive edit-distance pass.
  List<QuranMatch> _jointGlobalSpanCandidates(String phonemeText) {
    if (phonemeText.trim().isEmpty) return const [];
    final noSpaceText = phonemeText.replaceAll(' ', '');
    if (noSpaceText.length < _jointGlobalSpanMinChars) return const [];

    final coverage = _NgramCoverage(noSpaceText);
    if (coverage.isEmpty) return const [];

    final verseMasks = coverage.maskPerVerse(verses);
    final rows = _globalSpanTable();

    final rough = <({double overlap, _GlobalSpanRow row})>[];
    final scratch = Uint32List(coverage.wordCount);
    for (final row in rows) {
      scratch.fillRange(0, scratch.length, 0);
      for (var i = 0; i < row.span; i++) {
        final mask = verseMasks[row.startIndex + i];
        for (var w = 0; w < scratch.length; w++) {
          scratch[w] |= mask[w];
        }
      }
      final overlap = coverage.weightedPopcount(scratch);
      if (overlap > 0) rough.add((overlap: overlap, row: row));
    }
    rough.sort((a, b) => b.overlap.compareTo(a.overlap));

    final out = <QuranMatch>[];
    for (final entry in rough.take(_jointGlobalSpanShortlist)) {
      final chunk = _spanChunk(entry.row);
      final phonemes = _joinedSpanPhonemes(chunk);
      final raw = similarityRatio(phonemeText, phonemes);
      final frag = fragmentScore(noSpaceText, phonemes.replaceAll(' ', ''));
      final score = _max(raw, raw + (frag - raw) * _jointFragmentBlend);
      if (score < _jointGlobalSpanMinScore) continue;
      out.add(
        QuranMatch(
          surah: entry.row.surah,
          ayah: entry.row.ayah,
          ayahEnd: entry.row.ayahEnd,
          text: chunk.map((v) => v.textUthmani).join(' '),
          phonemesJoined: phonemes,
          score: _round4(score),
          rawScore: _round4(raw),
          bonus: 0,
          globalSpanRescue: true,
        ),
      );
    }
    return (out..sort((a, b) => b.score.compareTo(a.score))).take(12).toList();
  }

  /// Handles surahs whose first ayah is only a word or two: the transcript
  /// starts with that verse verbatim and continues into the second one.
  QuranMatch? _jointShortOpeningSpanCandidate(
    String phonemeText,
    double bestScore,
  ) {
    final noSpaceText = phonemeText.replaceAll(' ', '');
    if (noSpaceText.length < _jointShortOpeningMinQueryChars) return null;

    QuranMatch? best;
    for (final row in _prefixSpanTable()) {
      final first = getVerse(row.surah, 1);
      final second = getVerse(row.surah, 2);
      if (first == null || second == null) continue;

      final firstNs = first.phonemesJoinedNoBsmNs ?? first.phonemesJoinedNs;
      if (firstNs.isEmpty || firstNs.length > _jointShortOpeningMaxChars) {
        continue;
      }
      if (!noSpaceText.startsWith(firstNs)) continue;

      final remainder = noSpaceText.substring(firstNs.length);
      final secondNs = second.phonemesJoinedNs;
      var compareLen = secondNs.length;
      if (remainder.length < compareLen) compareLen = remainder.length;
      if (compareLen > 12) compareLen = 12;
      if (compareLen >= 4 &&
          similarityRatio(
                remainder.substring(0, compareLen),
                secondNs.substring(0, compareLen),
              ) <
              0.72) {
        continue;
      }

      final raw = similarityRatio(phonemeText, row.phonemesJoined);
      final frag = fragmentScore(
        noSpaceText,
        row.phonemesJoined.replaceAll(' ', ''),
      );
      final score = _max(raw, raw + (frag - raw) * _jointFragmentBlend);
      if (score >= _jointShortOpeningMinScore &&
          score >= bestScore + _jointShortOpeningMargin &&
          (best == null || score > best.score)) {
        best = QuranMatch(
          surah: row.surah,
          ayah: row.ayah,
          ayahEnd: row.ayahEnd,
          text: row.text,
          phonemesJoined: row.phonemesJoined,
          score: _round4(score),
          rawScore: _round4(raw),
          bonus: 0,
          prefixRescue: true,
        );
      }
    }
    return best;
  }

  /// Narrows the joint pass to verses that share character n-grams with the
  /// query. Falls back to the whole corpus when the shortlist would be too
  /// small to be trustworthy.
  List<QuranVerse> _jointCandidateVerses(
    String noSpaceText, {
    int maxCandidates = 950,
  }) {
    if (noSpaceText.length < 4) return verses;

    final coverage = _NgramCoverage(noSpaceText);
    if (coverage.isEmpty) return verses;

    final scored = <({double overlap, int index})>[];
    for (var i = 0; i < verses.length; i++) {
      final referenceNs = verses[i].phonemesJoinedNs;
      if (referenceNs.length < 2) continue;
      final overlap = coverage.overlapWith(referenceNs);
      if (overlap > 0) scored.add((overlap: overlap, index: i));
    }
    if (scored.length < 80) return verses;
    scored.sort((a, b) => b.overlap.compareTo(a.overlap));
    return [
      for (final entry in scored.take(maxCandidates)) verses[entry.index],
    ];
  }

  List<QuranMatch> _prefixSpanTable() {
    final cached = _jointPrefixSpans;
    if (cached != null) return cached;

    final spans = <QuranMatch>[];
    for (final entry in _bySurah.entries) {
      final surahVerses = entry.value;
      if (surahVerses.isEmpty || surahVerses.first.ayah != 1) continue;
      final maxSpan = surahVerses.length < _jointPrefixMaxSpan
          ? surahVerses.length
          : _jointPrefixMaxSpan;
      for (var span = 2; span <= maxSpan; span++) {
        final chunk = surahVerses.sublist(0, span);
        spans.add(
          QuranMatch(
            surah: entry.key,
            ayah: 1,
            ayahEnd: chunk.last.ayah,
            text: chunk.map((v) => v.textUthmani).join(' '),
            phonemesJoined: _joinedSpanPhonemes(chunk),
            score: 0,
            rawScore: 0,
            bonus: 0,
          ),
        );
      }
    }
    return _jointPrefixSpans = spans;
  }

  List<_GlobalSpanRow> _globalSpanTable() {
    final cached = _jointGlobalSpans;
    if (cached != null) return cached;

    // Index into `verses`, which is in canonical order, so a span's members
    // are contiguous there as well.
    final indexOfVerse = <String, int>{};
    for (var i = 0; i < verses.length; i++) {
      indexOfVerse[verses[i].ref] = i;
    }

    final spans = <_GlobalSpanRow>[];
    for (final entry in _bySurah.entries) {
      final surahVerses = entry.value;
      for (var i = 0; i < surahVerses.length; i++) {
        final remaining = surahVerses.length - i;
        final maxSpan =
            remaining < _jointPrefixMaxSpan ? remaining : _jointPrefixMaxSpan;
        for (var span = 2; span <= maxSpan; span++) {
          final chunk = surahVerses.sublist(i, i + span);
          spans.add(
            _GlobalSpanRow(
              surah: entry.key,
              startIndex: indexOfVerse[chunk.first.ref]!,
              span: span,
              ayah: chunk.first.ayah,
              ayahEnd: chunk.last.ayah,
            ),
          );
        }
      }
    }
    return _jointGlobalSpans = spans;
  }

  List<QuranVerse> _spanChunk(_GlobalSpanRow row) =>
      verses.sublist(row.startIndex, row.startIndex + row.span);

  // -------------------------------------------------------------------------
  // Derivation helpers
  // -------------------------------------------------------------------------

  /// Every surah except Al-Fatiha and At-Tawba opens with the basmala, which
  /// a reciter may or may not say. Cache the stripped variants so both
  /// readings match.
  void _applyBasmalaStripping(QuranVerse verse) {
    if (verse.ayah != 1 || verse.surah == 1 || verse.surah == 9) return;
    if (!_startsWithBasmala(verse.phonemeWords)) return;

    final strippedWords = verse.phonemeWords.sublist(_basmalaWords.length);
    verse.phonemesJoinedNoBsm =
        strippedWords.isEmpty ? null : strippedWords.join(' ');
    verse.phonemesJoinedNoBsmNs =
        verse.phonemesJoinedNoBsm?.replaceAll(' ', '');

    final basmalaTokenEnd = verse.wordTokenEnds.length >= _basmalaWords.length
        ? verse.wordTokenEnds[_basmalaWords.length - 1]
        : 0;
    verse.phonemeTokensNoBsm =
        basmalaTokenEnd > 0 && verse.phonemeTokens.length > basmalaTokenEnd
            ? verse.phonemeTokens.sublist(basmalaTokenEnd)
            : null;
    verse.phonemeTokenIdsNoBsm =
        basmalaTokenEnd > 0 && verse.phonemeTokenIds.length > basmalaTokenEnd
            ? verse.phonemeTokenIds.sublist(basmalaTokenEnd)
            : null;
  }

  static bool _startsWithBasmala(List<String> words) {
    if (words.length <= _basmalaWords.length) return false;
    for (var i = 0; i < _basmalaWords.length; i++) {
      if (words[i] != _basmalaWords[i]) return false;
    }
    return true;
  }

  QuranCandidate _candidateFromVerse(
    QuranVerse verse,
    double raw,
    double bonus,
    double total,
  ) {
    return QuranCandidate(
      surah: verse.surah,
      ayah: verse.ayah,
      ayahEnd: verse.ayah,
      text: verse.textUthmani,
      phonemesJoined: verse.phonemesJoined,
      phonemeTokenIds: verse.phonemeTokenIdsNoBsm ?? verse.phonemeTokenIds,
      stageAScore: total,
      rawScore: raw,
      bonus: bonus,
      kind: CandidateKind.single,
    );
  }

  QuranCandidate _candidateFromSpan(
    List<QuranVerse> chunk,
    double raw,
    double bonus,
    double total,
    int surahRank,
  ) {
    final first = chunk.first;
    final spanKey = '${first.surah}:${first.ayah}:${chunk.last.ayah}';
    final tokenIds =
        _ctcTokenTable?[spanKey] ?? _concatenatedSpanTokenIds(chunk);

    return QuranCandidate(
      surah: first.surah,
      ayah: first.ayah,
      ayahEnd: chunk.last.ayah,
      text: chunk.map((v) => v.textUthmani).join(' '),
      phonemesJoined: _joinedSpanPhonemes(chunk),
      phonemeTokenIds: tokenIds,
      stageAScore: total,
      rawScore: raw,
      bonus: bonus,
      kind: CandidateKind.span,
      surahRank: surahRank,
    );
  }

  /// The span's comparison text. The leading verse drops its basmala so a
  /// reciter who skips it still matches.
  String _joinedSpanPhonemes(List<QuranVerse> chunk) {
    final firstText = chunk.first.phonemesJoinedNoBsm ?? chunk.first.phonemesJoined;
    return [
      firstText,
      for (final verse in chunk.skip(1)) verse.phonemesJoined,
    ].join(' ');
  }

  List<int> _concatenatedSpanTokenIds(List<QuranVerse> chunk) {
    return [
      ...(chunk.first.phonemeTokenIdsNoBsm ?? chunk.first.phonemeTokenIds),
      for (final verse in chunk.skip(1)) ...verse.phonemeTokenIds,
    ];
  }

  /// For very short transcripts, compare against the verse opening and its
  /// first word rather than the whole verse.
  double _shortQueryBoost(
    String noSpaceText,
    QuranVerse verse, {
    bool useNoBsm = false,
  }) {
    final candidate = useNoBsm
        ? (verse.phonemesJoinedNoBsmNs ?? verse.phonemesJoinedNs)
        : verse.phonemesJoinedNs;
    if (candidate.isEmpty) return 0;

    final prefixWindow = candidate.length < noSpaceText.length + 6
        ? candidate.length
        : noSpaceText.length + 6;
    final prefix =
        similarityRatio(noSpaceText, candidate.substring(0, prefixWindow));

    final firstWord = useNoBsm
        ? (splitWords(verse.phonemesJoinedNoBsm ?? '').firstOrNull ?? '')
        : (verse.phonemeWords.firstOrNull ?? '');
    final firstWordScore =
        firstWord.isEmpty ? 0.0 : similarityRatio(noSpaceText, firstWord);
    return _max(prefix, firstWordScore);
  }

  /// Verses that would naturally follow the last committed one get a score
  /// bump, so ordinary sequential recitation stays locked on.
  Map<String, double> _continuationBonuses(({int surah, int ayah})? hint) {
    final bonuses = <String, double>{};
    if (hint == null) return bonuses;

    final next = _byRef['${hint.surah}:${hint.ayah + 1}'];
    if (next != null) {
      bonuses['${hint.surah}:${hint.ayah + 1}'] = 0.22;
      if (_byRef.containsKey('${hint.surah}:${hint.ayah + 2}')) {
        bonuses['${hint.surah}:${hint.ayah + 2}'] = 0.12;
      }
      if (_byRef.containsKey('${hint.surah}:${hint.ayah + 3}')) {
        bonuses['${hint.surah}:${hint.ayah + 3}'] = 0.06;
      }
    } else {
      // End of surah: the continuation is the opening of the next one.
      final nextSurah = _bySurah[hint.surah + 1] ?? const <QuranVerse>[];
      const values = [0.22, 0.12, 0.06];
      final limit = nextSurah.length < 3 ? nextSurah.length : 3;
      for (var i = 0; i < limit; i++) {
        bonuses[nextSurah[i].ref] = values[i];
      }
    }
    return bonuses;
  }

  /// Best alignment of a trailing slice of [text] against the head of
  /// [verseText] — catches the case where the audio window still contains the
  /// tail of the previous verse.
  static double _suffixPrefixScore(String text, String verseText) {
    final textWords = text.split(' ');
    final verseWordList = verseText.split(' ');
    if (textWords.length < 2 || verseWordList.length < 2) return 0.0;

    var best = 0.0;
    final halfWords = textWords.length ~/ 2;
    final maxTrim = halfWords < 4 ? halfWords : 4;
    for (var trim = 1; trim <= maxTrim; trim++) {
      final suffix = textWords.sublist(trim).join(' ');
      final n = textWords.length - trim;
      final prefix = verseWordList
          .sublist(0, n < verseWordList.length ? n : verseWordList.length)
          .join(' ');
      best = _max(best, similarityRatio(suffix, prefix));
    }
    return best;
  }

  static double _round4(double value) => (value * 10000).round() / 10000;
}

class _ScoredVerse {
  const _ScoredVerse(this.verse, this.raw, this.bonus, this.total);

  final QuranVerse verse;
  final double raw;
  final double bonus;
  final double total;
}

/// Character bigram/trigram coverage of a query string.
///
/// The reference implementation caches an n-gram `Set` per span, which on a
/// phone would cost hundreds of megabytes for the 37k-row whole-corpus table.
/// Instead the query's n-grams are indexed once per call and each verse is
/// reduced to a bitmask over them, so a span's coverage is the OR of its
/// members' masks. Scores match the original except that the handful of
/// n-grams straddling a verse join are not counted — immaterial for a rough
/// shortlist that is re-scored by edit distance afterwards.
class _NgramCoverage {
  _NgramCoverage(String query) {
    _index(query, 2, 1.0);
    _index(query, 3, 0.48);
    wordCount = (_weights.length + 31) >> 5;
  }

  final Map<int, int> _bigramBits = {};
  final Map<int, int> _trigramBits = {};
  final List<double> _weights = [];
  late final int wordCount;

  bool get isEmpty => _weights.isEmpty;

  void _index(String query, int n, double weight) {
    if (query.length < n) return;
    final target = n == 2 ? _bigramBits : _trigramBits;
    for (var i = 0; i <= query.length - n; i++) {
      final key = _key(query, i, n);
      if (target.containsKey(key)) continue;
      target[key] = _weights.length;
      _weights.add(weight);
    }
  }

  static int _key(String source, int offset, int n) {
    var key = 0;
    for (var i = 0; i < n; i++) {
      key = (key << 16) | source.codeUnitAt(offset + i);
    }
    return key;
  }

  /// Weighted count of distinct query n-grams occurring in [reference].
  double overlapWith(String reference) {
    final mask = maskFor(reference);
    return weightedPopcount(mask);
  }

  Uint32List maskFor(String reference) {
    final mask = Uint32List(wordCount);
    _fill(mask, reference, 2, _bigramBits);
    _fill(mask, reference, 3, _trigramBits);
    return mask;
  }

  List<Uint32List> maskPerVerse(List<QuranVerse> verses) =>
      [for (final verse in verses) maskFor(verse.phonemesJoinedNs)];

  void _fill(Uint32List mask, String reference, int n, Map<int, int> bits) {
    if (bits.isEmpty || reference.length < n) return;
    for (var i = 0; i <= reference.length - n; i++) {
      final bit = bits[_key(reference, i, n)];
      if (bit == null) continue;
      mask[bit >> 5] |= 1 << (bit & 31);
    }
  }

  double weightedPopcount(Uint32List mask) {
    var total = 0.0;
    for (var bit = 0; bit < _weights.length; bit++) {
      if ((mask[bit >> 5] & (1 << (bit & 31))) != 0) total += _weights[bit];
    }
    return total;
  }
}

double _max(double a, double b) => a > b ? a : b;

double _min(double a, double b) => a < b ? a : b;
