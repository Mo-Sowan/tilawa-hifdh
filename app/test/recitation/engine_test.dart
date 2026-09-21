import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tilawa/features/recitation/engine/arabic_normalizer.dart';
import 'package:tilawa/features/recitation/engine/ctc_decoder.dart';
import 'package:tilawa/features/recitation/engine/ctc_rescore.dart';
import 'package:tilawa/features/recitation/engine/levenshtein.dart';
import 'package:tilawa/features/recitation/engine/quran_db.dart';
import 'package:tilawa/features/recitation/engine/recitation_tracker.dart';
import 'package:tilawa/features/recitation/engine/recitation_types.dart';

void main() {
  group('normalizeArabic', () {
    test('strips diacritics and the byte-order mark', () {
      expect(
        normalizeArabic('﻿بِسْمِ ٱللَّهِ'),
        'بسم الله',
      );
    });

    test('folds hamza, alif-wasla, ta-marbuta and alif-maqsura', () {
      expect(normalizeArabic('أإآٱ'), 'اااا');
      expect(normalizeArabic('صلاة'), 'صلاه');
      expect(normalizeArabic('موسى'), 'موسي');
    });

    test('collapses runs of whitespace', () {
      expect(normalizeArabic('  الحمد    لله  '), 'الحمد لله');
    });

    // The reader relies on this to tell a word from a mark: the Uthmani text
    // carries standalone pause and hizb signs, which are printed but never
    // recited, and so must never be covered or counted as words.
    test('a standalone pause or hizb mark normalizes away to nothing', () {
      expect(normalizeArabic('ۛ'), isEmpty); // ۛ
      expect(normalizeArabic('ۖ'), isEmpty); // ۖ
      expect(normalizeArabic('۞'), isEmpty); // ۞
      expect(normalizeArabic('الله'), isNotEmpty);
    });
  });

  group('levenshtein', () {
    test('distance is symmetric and zero for equal strings', () {
      expect(editDistance('kitten', 'kitten'), 0);
      expect(editDistance('kitten', 'sitting'), 3);
      expect(editDistance('sitting', 'kitten'), 3);
    });

    test('ratio matches the python-Levenshtein formula', () {
      // (6 + 7 - 3) / (6 + 7)
      expect(similarityRatio('kitten', 'sitting'), closeTo(10 / 13, 1e-9));
      expect(similarityRatio('', ''), 1.0);
    });

    test('fragmentScore is 1.0 for an exact substring', () {
      expect(fragmentScore('حمد', 'الحمدلله'), 1.0);
      expect(fragmentScore('', 'anything'), 1.0);
    });

    test('fragmentScore degrades with mismatch', () {
      expect(fragmentScore('xyz', 'الحمدلله'), lessThan(0.5));
    });

    test('partialRatio finds the best window regardless of argument order', () {
      expect(partialRatio('bcd', 'abcde'), 1.0);
      expect(partialRatio('abcde', 'bcd'), 1.0);
      expect(partialRatio('', 'abc'), 0.0);
    });
  });

  group('CtcDecoder', () {
    late CtcDecoder decoder;

    // 0..3 are pieces, 4 is a bare word boundary, 5 is blank.
    final vocab = <String, dynamic>{
      '0': 'ا',
      '1': 'ل',
      '2': '▁ب',
      '3': 'ت',
      '4': '▁',
      '5': '<blank>',
    };

    setUp(() => decoder = CtcDecoder(vocab, blankId: 5));

    test('collapses repeats and drops blanks', () {
      final logProbs = _argmaxFrames(
        const [0, 0, 5, 0, 1, 1, 5, 2],
        vocabSize: 6,
      );
      final result = decoder.decode(logProbs, 8, 6);
      expect(result.tokenIds, [0, 0, 1, 2]);
    });

    test('renders the word-boundary marker as a space', () {
      expect(decoder.tokenIdsToText([0, 1, 2, 0]), 'ال با');
    });

    test('word ends mark each token boundary', () {
      // ا ل ▁ب ا  ->  "ال" then "با": ends after index 2 and at the end.
      expect(decoder.tokenIdsToWordEnds([0, 1, 2, 0]), [2, 4]);
    });

    test('blank id defaults to the highest vocabulary id', () {
      expect(CtcDecoder(vocab).blankId, 5);
    });
  });

  group('scoreCtcSequence', () {
    test('rejects sequences that cannot fit in the available frames', () {
      final evidence = _flatEvidence(timeSteps: 2, vocabSize: 4, blankId: 3);
      // Needs 2*2+1 = 5 frames but only 2 are available.
      expect(scoreCtcSequence(evidence, [0, 1]), 1e9);
    });

    test('scores the sequence the frames actually support best', () {
      final evidence = _peakedEvidence(
        frames: const [0, 1, 2],
        vocabSize: 4,
        blankId: 3,
      );
      final matching = scoreCtcSequence(evidence, [0, 1, 2]);
      final mismatched = scoreCtcSequence(evidence, [2, 1, 0]);
      expect(matching, lessThan(mismatched));
    });

    test('empty targets are impossible', () {
      final evidence = _flatEvidence(timeSteps: 8, vocabSize: 4, blankId: 3);
      expect(scoreCtcSequence(evidence, const []), 1e9);
    });
  });

  group('chooseLongestStablePrefix', () {
    test('prefers the longest candidate within tolerance of the best', () {
      final scored = [
        const ScoredCtcCandidate<String>(
          ids: [1],
          meta: 'short',
          priorScore: 0,
          acousticScore: 1.00,
          feasible: true,
          minFrames: 3,
        ),
        const ScoredCtcCandidate<String>(
          ids: [1, 2, 3],
          meta: 'long',
          priorScore: 0,
          acousticScore: 1.05,
          feasible: true,
          minFrames: 7,
        ),
        const ScoredCtcCandidate<String>(
          ids: [1, 2, 3, 4, 5],
          meta: 'too far',
          priorScore: 0,
          acousticScore: 1.90,
          feasible: true,
          minFrames: 11,
        ),
      ];

      expect(chooseLongestStablePrefix(scored, tolerance: 0.12)?.meta, 'long');
    });

    test('returns null when nothing is feasible', () {
      final scored = [
        const ScoredCtcCandidate<String>(
          ids: [1],
          meta: 'x',
          priorScore: 0,
          acousticScore: 1e9,
          feasible: false,
          minFrames: 3,
        ),
      ];
      expect(chooseLongestStablePrefix(scored), isNull);
    });
  });

  group('QuranDB', () {
    late QuranDB db;

    setUp(() => db = QuranDB(_fixtureVerses()));

    test('indexes verses by reference and surah', () {
      expect(db.totalVerses, 7);
      expect(db.surahCount, 2);
      expect(db.getVerse(1, 2)?.phonemesJoined, 'الحمد لله رب العلمين');
      expect(db.getSurah(2).length, 3);
    });

    test('getNextVerse rolls over into the following surah', () {
      expect(db.getNextVerse(1, 1)?.ayah, 2);
      expect(db.getNextVerse(1, 4)?.surah, 2);
      expect(db.getNextVerse(1, 4)?.ayah, 1);
      expect(db.getNextVerse(2, 3), isNull);
    });

    test('strips the basmala from an opening verse outside Al-Fatiha', () {
      final opening = db.getVerse(2, 1)!;
      expect(opening.phonemesJoinedNoBsm, 'الم');
      expect(opening.phonemesJoinedNoBsmNs, 'الم');

      // Al-Fatiha's own first verse is the basmala; it must stay intact.
      expect(db.getVerse(1, 1)!.phonemesJoinedNoBsm, isNull);
    });

    test('surroundingVerses returns the neighbourhood with a current flag', () {
      final around = db.surroundingVerses(1, 2);
      expect(around.map((v) => v.ayah), [1, 2, 3, 4]);
      expect(around.where((v) => v.isCurrent).single.ayah, 2);
    });

    test('matchVerse finds the verse a transcript came from', () {
      final match = db.matchVerse('الحمد لله رب العلمين', threshold: 0.3);
      expect(match, isNotNull);
      expect(match!.surah, 1);
      expect(match.ayah, 2);
      expect(match.score, greaterThan(0.9));
    });

    test('matchVerse returns null below the threshold', () {
      expect(db.matchVerse('zzz qqq', threshold: 0.9), isNull);
    });

    test('a surah filter confines retrieval to that surah', () {
      final retrieved = db.retrieveCandidates(
        'الحمد لله رب العلمين',
        surahFilter: 2,
      );
      expect(retrieved.singles, isNotEmpty);
      expect(retrieved.singles.every((c) => c.surah == 2), isTrue);
    });

    test('continuation hints lift the following verse', () {
      final withoutHint = db.retrieveCandidates('رب العلمين');
      final withHint =
          db.retrieveCandidates('رب العلمين', hint: (surah: 1, ayah: 1));

      double scoreOf(List<QuranCandidate> candidates) => candidates
          .firstWhere((c) => c.surah == 1 && c.ayah == 2)
          .stageAScore;

      expect(scoreOf(withHint.singles), greaterThan(scoreOf(withoutHint.singles)));
    });

    test('short verse candidates are limited by token count', () {
      final short = db.getShortVerseCandidates(maxTokens: 4);
      expect(short, isNotEmpty);
      expect(short.every((c) => c.phonemeTokenIds.length <= 4), isTrue);
    });

    test('bestJointMatch recovers the verse from a clean transcript', () {
      final match = db.bestJointMatch('اياك نعبد واياك نستعين');
      expect(match, isNotNull);
      expect(match!.surah, 1);
      expect(match.ayah, 4);
    });

    test('search ranks the closest verse first', () {
      final results = db.search('مالك يوم الدين', topK: 2);
      expect(results.first.verse.ayah, 3);
    });
  });

  group('RecitationTracker', () {
    late QuranDB db;

    setUp(() => db = QuranDB(_fixtureVerses()));

    test('silence alone never produces a match', () async {
      final tracker = RecitationTracker(
        db,
        (_) async => throw StateError('should not transcribe silence'),
      );
      final events = await tracker.feed(_silence(seconds: 3));
      expect(events, isEmpty);
    });

    test('commits a verse once the same leader repeats', () async {
      final tracker = RecitationTracker(
        db,
        (_) async => const TranscribeResult(
          text: 'الحمد لله رب العلمين',
          tokenIds: [10, 11, 12, 13],
        ),
        config: StreamingConfig.balanced,
      );

      final matches = <VerseMatchEvent>[];
      for (var cycle = 0; cycle < 6; cycle++) {
        final events = await tracker.feed(_speech(seconds: 1));
        matches.addAll(events.whereType<VerseMatchEvent>());
      }

      expect(matches, isNotEmpty);
      expect(matches.first.surah, 1);
      expect(matches.first.ayah, 2);
    });

    test('reports word progress while tracking a committed verse', () async {
      var transcript = 'الحمد لله رب العلمين';
      final tracker = RecitationTracker(
        db,
        (_) async => TranscribeResult(text: transcript, tokenIds: const [1, 2]),
        config: StreamingConfig.balanced,
      );

      for (var cycle = 0; cycle < 4; cycle++) {
        await tracker.feed(_speech(seconds: 1));
      }

      transcript = 'رب العلمين';
      final progress = <WordProgressEvent>[];
      for (var cycle = 0; cycle < 4; cycle++) {
        progress.addAll(
          (await tracker.feed(_speech(seconds: 1)))
              .whereType<WordProgressEvent>(),
        );
      }

      expect(progress, isNotEmpty);
      for (final event in progress) {
        // Whichever verse the tracker settled on, the reported position must
        // stay inside it and match that verse's real word count.
        final verse = db.getVerse(event.surah, event.ayah);
        expect(verse, isNotNull);
        expect(event.totalWords, verse!.phonemeWords.length);
        expect(event.wordIndex, inInclusiveRange(1, event.totalWords));
        expect(event.matchedIndices.last, lessThan(event.totalWords));
      }
    });

    test('reset clears committed state', () async {
      final tracker = RecitationTracker(
        db,
        (_) async => const TranscribeResult(
          text: 'الحمد لله رب العلمين',
          tokenIds: [1, 2],
        ),
      );
      for (var cycle = 0; cycle < 4; cycle++) {
        await tracker.feed(_speech(seconds: 1));
      }
      tracker.reset();

      // After a reset the first match must clear the stricter first-match
      // threshold again rather than the continuation threshold.
      final events = await tracker.feed(_silence(seconds: 1));
      expect(events.whereType<VerseMatchEvent>(), isEmpty);
    });

    test('an unrecognised transcript surfaces as raw text', () async {
      final tracker = RecitationTracker(
        db,
        (_) async => const TranscribeResult(
          text: 'كلمات غير معروفه هنا',
          tokenIds: [1, 2, 3],
        ),
      );

      final events = <RecitationEvent>[];
      for (var cycle = 0; cycle < 3; cycle++) {
        events.addAll(await tracker.feed(_speech(seconds: 1)));
      }
      expect(events.whereType<RawTranscriptEvent>(), isNotEmpty);
      expect(events.whereType<VerseMatchEvent>(), isEmpty);
    });
  });

  group('StreamingConfig', () {
    test('normalize clamps out-of-range values', () {
      final config = StreamingConfig.balanced
          .copyWith(
            audioChunkMs: 5,
            discoveryTriggerSec: 99,
            lookaheadWords: 99,
            decodeStabilityRatio: -3,
          )
          .normalized();

      expect(config.audioChunkMs, 100);
      expect(config.discoveryTriggerSec, 6);
      expect(config.lookaheadWords, 15);
      expect(config.decodeStabilityRatio, 0);
    });

    test('presets are distinct and all normalize cleanly', () {
      for (final preset in StreamingConfig.presets.values) {
        expect(preset.normalized().audioChunkMs, preset.audioChunkMs);
      }
      expect(
        StreamingConfig.conservative.nextVerseEmitMode,
        NextVerseEmitMode.deferredConfirm,
      );
      expect(
        StreamingConfig.balanced.nextVerseEmitMode,
        NextVerseEmitMode.candidateUntilConfirmed,
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// Al-Fatiha 1-4 and Al-Baqara 1-3, enough to exercise surah rollover, basmala
/// stripping and continuation bonuses without loading the real corpus.
List<QuranVerse> _fixtureVerses() {
  final rows = <({int surah, int ayah, String text})>[
    (surah: 1, ayah: 1, text: 'بسم الله الرحمن الرحيم'),
    (surah: 1, ayah: 2, text: 'الحمد لله رب العلمين'),
    (surah: 1, ayah: 3, text: 'مالك يوم الدين'),
    (surah: 1, ayah: 4, text: 'اياك نعبد واياك نستعين'),
    (surah: 2, ayah: 1, text: 'بسم الله الرحمن الرحيم الم'),
    (surah: 2, ayah: 2, text: 'ذلك الكتاب لا ريب فيه'),
    (surah: 2, ayah: 3, text: 'الذين يؤمنون بالغيب'),
  ];

  var nextTokenId = 1;
  final tokenIdOf = <String, int>{};

  return [
    for (final row in rows)
      () {
        final words = splitWords(row.text);
        final ids = <int>[];
        final ends = <int>[];
        for (final word in words) {
          ids.add(tokenIdOf.putIfAbsent(word, () => nextTokenId++));
          ends.add(ids.length);
        }
        return QuranVerse(
          surah: row.surah,
          ayah: row.ayah,
          textUthmani: row.text,
          textClean: row.text,
          surahName: row.surah == 1 ? 'الفاتحة' : 'البقرة',
          surahNameEn: row.surah == 1 ? 'Al-Faatiha' : 'Al-Baqara',
          phonemesJoined: row.text,
          phonemeTokens: words,
          phonemeTokenIds: ids,
          wordTokenEnds: ends,
          phonemeWords: words,
        );
      }(),
  ];
}

Float32List _silence({required double seconds}) =>
    Float32List((sampleRate * seconds).round());

/// White-ish noise loud enough to clear the silence gate.
Float32List _speech({required double seconds}) {
  final random = math.Random(7);
  final samples = Float32List((sampleRate * seconds).round());
  for (var i = 0; i < samples.length; i++) {
    samples[i] = (random.nextDouble() - 0.5) * 0.6;
  }
  return samples;
}

/// Log-probs whose argmax follows [frames] exactly.
Float32List _argmaxFrames(List<int> frames, {required int vocabSize}) {
  final logProbs = Float32List(frames.length * vocabSize);
  for (var t = 0; t < frames.length; t++) {
    for (var v = 0; v < vocabSize; v++) {
      logProbs[t * vocabSize + v] = v == frames[t] ? -0.1 : -10.0;
    }
  }
  return logProbs;
}

AcousticEvidence _flatEvidence({
  required int timeSteps,
  required int vocabSize,
  required int blankId,
}) {
  final logProbs = Float32List(timeSteps * vocabSize);
  final uniform = math.log(1 / vocabSize);
  for (var i = 0; i < logProbs.length; i++) {
    logProbs[i] = uniform;
  }
  return AcousticEvidence(
    logProbs: logProbs,
    timeSteps: timeSteps,
    vocabSize: vocabSize,
    blankId: blankId,
  );
}

/// Frames that strongly favour the given token ids, blank-separated, so a
/// matching sequence scores far better than a shuffled one.
AcousticEvidence _peakedEvidence({
  required List<int> frames,
  required int vocabSize,
  required int blankId,
}) {
  final expanded = <int>[blankId];
  for (final id in frames) {
    expanded
      ..add(id)
      ..add(id)
      ..add(blankId);
  }
  final logProbs = Float32List(expanded.length * vocabSize);
  for (var t = 0; t < expanded.length; t++) {
    for (var v = 0; v < vocabSize; v++) {
      logProbs[t * vocabSize + v] = v == expanded[t] ? -0.05 : -8.0;
    }
  }
  return AcousticEvidence(
    logProbs: logProbs,
    timeSteps: expanded.length,
    vocabSize: vocabSize,
    blankId: blankId,
  );
}
