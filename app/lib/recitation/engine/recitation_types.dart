import 'package:tilawa/recitation/engine/arabic_normalizer.dart';

const int sampleRate = 16000;

// --- Discovery / tracking constants (mirror the reference pipeline) ---------
const double _triggerSeconds = 2.0;
const double _maxWindowSeconds = 30.0;
const double _silenceRmsThreshold = 0.005;
const double _utteranceFinalSilenceSeconds = 1.2;

const double kVerseMatchThreshold = 0.45;
const double kFirstMatchThreshold = 0.75;
const double kRawTranscriptThreshold = 0.25;
const int kSurroundingContext = 2;
const int kDiscoveryRepeatCycles = 2;
const int kDiscoveryTopSingleCandidates = 64;
const int kDiscoveryTopSurahs = 5;
const int kDiscoveryMaxSpan = 4;
const double kAcousticClearMargin = 0.12;
const double kAcousticContinuationMargin = 0.08;
const double kNonContinuationJumpThreshold = 0.65;
const int kDiscoveryExpandedCandidates = 200;
const int kDiscoveryLowConfidenceWords = 4;
const int kDiscoveryLowConfidenceChars = 18;
const double kDiscoveryFusionTextWeight = 0.6;
const double kDiscoveryFusionAcousticWeight = 0.25;
const double kDiscoveryFusionLengthWeight = 0.15;
const double kDiscoveryFusionLowTextWeight = 0.45;
const double kDiscoveryFusionLowAcousticWeight = 0.4;
const double kDiscoveryFusionLowLengthWeight = 0.15;
const double kDiscoveryFusionSelectionGap = 0.08;

const double _trackingTriggerSeconds = 0.5;
const double _trackingSilenceTimeout = 4.0;
const double _trackingMaxWindowSeconds = 30.0;
const int _staleCycleLimit = 4;
const int _lookahead = 5;
const double _trackingPrefixTolerance = 0.12;
const double kTrackingWeakCommitConfidence = 0.6;
const double _trackingCompletionCoverage = 0.95;
const double _advanceRelativeMargin = 3.0;
const int _advancePrefixTokens = 15;

/// Stricter than [_advanceRelativeMargin]. Used at final flush, where there is
/// no chance to wait for fresh audio to confirm the advance.
const double _advanceFlushStrictMargin = 0.5;

/// How the tracker publishes the *next* verse once the current one completes.
enum NextVerseEmitMode {
  /// Hold the match until fresh audio confirms it. Safest.
  deferredConfirm,

  /// Publish as a low-commitment candidate, upgrade on confirmation.
  candidateUntilConfirmed,

  /// Publish immediately when coverage completes.
  immediateOnCompletion,
}

/// Tunables for the streaming state machine.
class StreamingConfig {
  const StreamingConfig({
    required this.audioChunkMs,
    required this.discoveryTriggerSec,
    required this.trackingTriggerSec,
    required this.discoveryMaxWindowSec,
    required this.trackingMaxWindowSec,
    required this.tailAfterCommitSec,
    required this.tailAfterPendingAdvanceSec,
    required this.finalSilenceSec,
    required this.silenceRmsThreshold,
    required this.firstMatchThreshold,
    required this.verseMatchThreshold,
    required this.discoveryRepeatCycles,
    required this.acousticClearMargin,
    required this.acousticContinuationMargin,
    required this.decodeStabilityEnabled,
    required this.decodeStabilityRatio,
    required this.nonContinuationJumpThreshold,
    required this.nextVerseEmitMode,
    required this.trackingCompletionCoverage,
    required this.trackingPrefixTolerance,
    required this.lookaheadWords,
    required this.staleCycleLimit,
    required this.trackingSilenceTimeoutSec,
    required this.advanceRelativeMargin,
    required this.advancePrefixTokens,
    required this.advanceFlushStrictMargin,
  });

  final int audioChunkMs;
  final double discoveryTriggerSec;
  final double trackingTriggerSec;
  final double discoveryMaxWindowSec;
  final double trackingMaxWindowSec;
  final double tailAfterCommitSec;
  final double tailAfterPendingAdvanceSec;
  final double finalSilenceSec;
  final double silenceRmsThreshold;
  final double firstMatchThreshold;
  final double verseMatchThreshold;
  final int discoveryRepeatCycles;
  final double acousticClearMargin;
  final double acousticContinuationMargin;
  final bool decodeStabilityEnabled;
  final double decodeStabilityRatio;
  final double nonContinuationJumpThreshold;
  final NextVerseEmitMode nextVerseEmitMode;
  final double trackingCompletionCoverage;
  final double trackingPrefixTolerance;
  final int lookaheadWords;
  final int staleCycleLimit;
  final double trackingSilenceTimeoutSec;
  final double advanceRelativeMargin;
  final int advancePrefixTokens;
  final double advanceFlushStrictMargin;

  StreamingConfig copyWith({
    int? audioChunkMs,
    double? discoveryTriggerSec,
    double? trackingTriggerSec,
    double? discoveryMaxWindowSec,
    double? trackingMaxWindowSec,
    double? tailAfterCommitSec,
    double? tailAfterPendingAdvanceSec,
    double? finalSilenceSec,
    double? silenceRmsThreshold,
    double? firstMatchThreshold,
    double? verseMatchThreshold,
    int? discoveryRepeatCycles,
    double? acousticClearMargin,
    double? acousticContinuationMargin,
    bool? decodeStabilityEnabled,
    double? decodeStabilityRatio,
    double? nonContinuationJumpThreshold,
    NextVerseEmitMode? nextVerseEmitMode,
    double? trackingCompletionCoverage,
    double? trackingPrefixTolerance,
    int? lookaheadWords,
    int? staleCycleLimit,
    double? trackingSilenceTimeoutSec,
    double? advanceRelativeMargin,
    int? advancePrefixTokens,
    double? advanceFlushStrictMargin,
  }) {
    return StreamingConfig(
      audioChunkMs: audioChunkMs ?? this.audioChunkMs,
      discoveryTriggerSec: discoveryTriggerSec ?? this.discoveryTriggerSec,
      trackingTriggerSec: trackingTriggerSec ?? this.trackingTriggerSec,
      discoveryMaxWindowSec:
          discoveryMaxWindowSec ?? this.discoveryMaxWindowSec,
      trackingMaxWindowSec: trackingMaxWindowSec ?? this.trackingMaxWindowSec,
      tailAfterCommitSec: tailAfterCommitSec ?? this.tailAfterCommitSec,
      tailAfterPendingAdvanceSec:
          tailAfterPendingAdvanceSec ?? this.tailAfterPendingAdvanceSec,
      finalSilenceSec: finalSilenceSec ?? this.finalSilenceSec,
      silenceRmsThreshold: silenceRmsThreshold ?? this.silenceRmsThreshold,
      firstMatchThreshold: firstMatchThreshold ?? this.firstMatchThreshold,
      verseMatchThreshold: verseMatchThreshold ?? this.verseMatchThreshold,
      discoveryRepeatCycles:
          discoveryRepeatCycles ?? this.discoveryRepeatCycles,
      acousticClearMargin: acousticClearMargin ?? this.acousticClearMargin,
      acousticContinuationMargin:
          acousticContinuationMargin ?? this.acousticContinuationMargin,
      decodeStabilityEnabled:
          decodeStabilityEnabled ?? this.decodeStabilityEnabled,
      decodeStabilityRatio: decodeStabilityRatio ?? this.decodeStabilityRatio,
      nonContinuationJumpThreshold:
          nonContinuationJumpThreshold ?? this.nonContinuationJumpThreshold,
      nextVerseEmitMode: nextVerseEmitMode ?? this.nextVerseEmitMode,
      trackingCompletionCoverage:
          trackingCompletionCoverage ?? this.trackingCompletionCoverage,
      trackingPrefixTolerance:
          trackingPrefixTolerance ?? this.trackingPrefixTolerance,
      lookaheadWords: lookaheadWords ?? this.lookaheadWords,
      staleCycleLimit: staleCycleLimit ?? this.staleCycleLimit,
      trackingSilenceTimeoutSec:
          trackingSilenceTimeoutSec ?? this.trackingSilenceTimeoutSec,
      advanceRelativeMargin:
          advanceRelativeMargin ?? this.advanceRelativeMargin,
      advancePrefixTokens: advancePrefixTokens ?? this.advancePrefixTokens,
      advanceFlushStrictMargin:
          advanceFlushStrictMargin ?? this.advanceFlushStrictMargin,
    );
  }

  /// Clamps every field into its supported range.
  StreamingConfig normalized() {
    return StreamingConfig(
      audioChunkMs: _clamp(audioChunkMs.toDouble(), 100, 1000).round(),
      discoveryTriggerSec: _clamp(discoveryTriggerSec, 0.5, 6),
      trackingTriggerSec: _clamp(trackingTriggerSec, 0.15, 3),
      discoveryMaxWindowSec: _clamp(discoveryMaxWindowSec, 3, 45),
      trackingMaxWindowSec: _clamp(trackingMaxWindowSec, 3, 45),
      tailAfterCommitSec: _clamp(tailAfterCommitSec, 0, 6),
      tailAfterPendingAdvanceSec: _clamp(tailAfterPendingAdvanceSec, 0, 3),
      finalSilenceSec: _clamp(finalSilenceSec, 0.3, 5),
      silenceRmsThreshold: _clamp(silenceRmsThreshold, 0.001, 0.05),
      firstMatchThreshold: _clamp(firstMatchThreshold, 0.1, 0.99),
      verseMatchThreshold: _clamp(verseMatchThreshold, 0.1, 0.99),
      discoveryRepeatCycles:
          _clamp(discoveryRepeatCycles.toDouble(), 1, 5).round(),
      acousticClearMargin: _clamp(acousticClearMargin, 0, 1),
      acousticContinuationMargin: _clamp(acousticContinuationMargin, 0, 1),
      decodeStabilityEnabled: decodeStabilityEnabled,
      decodeStabilityRatio: _clamp(decodeStabilityRatio, 0, 1),
      nonContinuationJumpThreshold:
          _clamp(nonContinuationJumpThreshold, 0.1, 0.99),
      nextVerseEmitMode: nextVerseEmitMode,
      trackingCompletionCoverage: _clamp(trackingCompletionCoverage, 0.5, 1),
      trackingPrefixTolerance: _clamp(trackingPrefixTolerance, 0, 1),
      lookaheadWords: _clamp(lookaheadWords.toDouble(), 1, 15).round(),
      staleCycleLimit: _clamp(staleCycleLimit.toDouble(), 1, 12).round(),
      trackingSilenceTimeoutSec: _clamp(trackingSilenceTimeoutSec, 0.5, 10),
      advanceRelativeMargin: _clamp(advanceRelativeMargin, -2, 8),
      advancePrefixTokens: _clamp(advancePrefixTokens.toDouble(), 3, 60).round(),
      advanceFlushStrictMargin: _clamp(advanceFlushStrictMargin, -2, 8),
    );
  }

  static double _clamp(double value, double min, double max) {
    if (value.isNaN || value.isInfinite) return min;
    return value < min ? min : (value > max ? max : value);
  }

  /// Slowest to commit, least likely to jump to the wrong verse.
  static const StreamingConfig conservative = StreamingConfig(
    audioChunkMs: 300,
    discoveryTriggerSec: _triggerSeconds,
    trackingTriggerSec: _trackingTriggerSeconds,
    discoveryMaxWindowSec: _maxWindowSeconds,
    trackingMaxWindowSec: _trackingMaxWindowSeconds,
    tailAfterCommitSec: _triggerSeconds,
    tailAfterPendingAdvanceSec: _trackingTriggerSeconds,
    finalSilenceSec: _utteranceFinalSilenceSeconds,
    silenceRmsThreshold: _silenceRmsThreshold,
    firstMatchThreshold: kFirstMatchThreshold,
    verseMatchThreshold: kVerseMatchThreshold,
    discoveryRepeatCycles: kDiscoveryRepeatCycles,
    acousticClearMargin: kAcousticClearMargin,
    acousticContinuationMargin: kAcousticContinuationMargin,
    decodeStabilityEnabled: true,
    decodeStabilityRatio: 0.70,
    nonContinuationJumpThreshold: kNonContinuationJumpThreshold,
    nextVerseEmitMode: NextVerseEmitMode.deferredConfirm,
    trackingCompletionCoverage: _trackingCompletionCoverage,
    trackingPrefixTolerance: _trackingPrefixTolerance,
    lookaheadWords: _lookahead,
    staleCycleLimit: _staleCycleLimit,
    trackingSilenceTimeoutSec: _trackingSilenceTimeout,
    advanceRelativeMargin: _advanceRelativeMargin,
    advancePrefixTokens: _advancePrefixTokens,
    advanceFlushStrictMargin: _advanceFlushStrictMargin,
  );

  /// Default. Responsive enough to follow a live reciter.
  static const StreamingConfig balanced = StreamingConfig(
    audioChunkMs: 150,
    discoveryTriggerSec: _triggerSeconds,
    trackingTriggerSec: 0.25,
    discoveryMaxWindowSec: _maxWindowSeconds,
    trackingMaxWindowSec: 12,
    tailAfterCommitSec: 0.75,
    tailAfterPendingAdvanceSec: _trackingTriggerSeconds,
    finalSilenceSec: _utteranceFinalSilenceSeconds,
    silenceRmsThreshold: _silenceRmsThreshold,
    firstMatchThreshold: kFirstMatchThreshold,
    verseMatchThreshold: kVerseMatchThreshold,
    discoveryRepeatCycles: kDiscoveryRepeatCycles,
    acousticClearMargin: kAcousticClearMargin,
    acousticContinuationMargin: 0.06,
    decodeStabilityEnabled: true,
    decodeStabilityRatio: 0.70,
    nonContinuationJumpThreshold: kNonContinuationJumpThreshold,
    nextVerseEmitMode: NextVerseEmitMode.candidateUntilConfirmed,
    trackingCompletionCoverage: 0.82,
    trackingPrefixTolerance: _trackingPrefixTolerance,
    lookaheadWords: _lookahead,
    staleCycleLimit: _staleCycleLimit,
    trackingSilenceTimeoutSec: _trackingSilenceTimeout,
    advanceRelativeMargin: 3.5,
    advancePrefixTokens: _advancePrefixTokens,
    advanceFlushStrictMargin: _advanceFlushStrictMargin,
  );

  /// Advances on weaker evidence. Best for fast reciters.
  static const StreamingConfig aggressiveAdvance = StreamingConfig(
    audioChunkMs: 150,
    discoveryTriggerSec: 1.5,
    trackingTriggerSec: 0.25,
    discoveryMaxWindowSec: _maxWindowSeconds,
    trackingMaxWindowSec: 12,
    tailAfterCommitSec: 0.75,
    tailAfterPendingAdvanceSec: _trackingTriggerSeconds,
    finalSilenceSec: _utteranceFinalSilenceSeconds,
    silenceRmsThreshold: _silenceRmsThreshold,
    firstMatchThreshold: kFirstMatchThreshold,
    verseMatchThreshold: kVerseMatchThreshold,
    discoveryRepeatCycles: 1,
    acousticClearMargin: kAcousticClearMargin,
    acousticContinuationMargin: 0.04,
    decodeStabilityEnabled: true,
    decodeStabilityRatio: 0.70,
    nonContinuationJumpThreshold: kNonContinuationJumpThreshold,
    nextVerseEmitMode: NextVerseEmitMode.candidateUntilConfirmed,
    trackingCompletionCoverage: 0.85,
    trackingPrefixTolerance: _trackingPrefixTolerance,
    lookaheadWords: _lookahead,
    staleCycleLimit: _staleCycleLimit,
    trackingSilenceTimeoutSec: _trackingSilenceTimeout,
    advanceRelativeMargin: 4.0,
    advancePrefixTokens: _advancePrefixTokens,
    advanceFlushStrictMargin: 1.0,
  );

  static const StreamingConfig defaults = balanced;

  static const Map<String, StreamingConfig> presets = {
    'conservative': conservative,
    'balanced': balanced,
    'aggressiveAdvance': aggressiveAdvance,
  };
}

/// One verse of the offline corpus plus everything the matcher precomputes.
///
/// The `phoneme*` names are inherited from the original phoneme-based pipeline.
/// Under the current text-CTC model they hold normalized Arabic text and BPE
/// token ids; the names are kept so the corpus files stay interchangeable.
class QuranVerse {
  QuranVerse({
    required this.surah,
    required this.ayah,
    required this.textUthmani,
    required this.textClean,
    required this.surahName,
    required this.surahNameEn,
    required this.phonemesJoined,
    required this.phonemeTokens,
    required this.phonemeTokenIds,
    required this.wordTokenEnds,
    required this.phonemeWords,
  }) : phonemesJoinedNs = phonemesJoined.replaceAll(' ', '');

  final int surah;
  final int ayah;
  final String textUthmani;
  final String textClean;
  final String surahName;
  final String surahNameEn;

  /// Normalized comparison text for this verse.
  final String phonemesJoined;
  final List<String> phonemeTokens;
  final List<int> phonemeTokenIds;
  final List<int> wordTokenEnds;
  final List<String> phonemeWords;

  /// [phonemesJoined] without spaces, for fragment scoring.
  String phonemesJoinedNs;

  /// Basmala-stripped variants. Populated for `ayah == 1` outside Al-Fatiha
  /// and At-Tawba; null when the verse has no leading basmala.
  String? phonemesJoinedNoBsm;
  String? phonemesJoinedNoBsmNs;
  List<String>? phonemeTokensNoBsm;
  List<int>? phonemeTokenIdsNoBsm;

  String get ref => '$surah:$ayah';
}

/// A verse shown around the currently matched one, for context in the UI.
class SurroundingVerse {
  const SurroundingVerse({
    required this.surah,
    required this.ayah,
    required this.text,
    required this.isCurrent,
  });

  final int surah;
  final int ayah;
  final String text;
  final bool isCurrent;
}

/// Where a candidate came from.
enum CandidateSource { discovery, tracking }

class VerseCandidate {
  const VerseCandidate({
    required this.surah,
    required this.ayah,
    required this.ayahEnd,
    required this.confidence,
    required this.rank,
    required this.source,
  });

  final int surah;
  final int ayah;
  final int? ayahEnd;
  final double confidence;
  final int rank;
  final CandidateSource source;
}

class FinalSequenceVerse {
  const FinalSequenceVerse({
    required this.surah,
    required this.ayah,
    required this.confidence,
  });

  final int surah;
  final int ayah;
  final double confidence;
}

/// Everything the tracker can publish while listening.
sealed class RecitationEvent {
  const RecitationEvent();
}

/// A verse the tracker is confident the reciter is on.
class VerseMatchEvent extends RecitationEvent {
  const VerseMatchEvent({
    required this.surah,
    required this.ayah,
    required this.verseText,
    required this.surahName,
    required this.confidence,
    required this.surroundingVerses,
  });

  final int surah;
  final int ayah;
  final String verseText;
  final String surahName;
  final double confidence;
  final List<SurroundingVerse> surroundingVerses;

  String get ref => '$surah:$ayah';
}

/// Ranked possibilities while the tracker is still deciding.
class VerseCandidateEvent extends RecitationEvent {
  const VerseCandidateEvent({
    required this.candidates,
    required this.stable,
    required this.finalFlush,
  });

  final List<VerseCandidate> candidates;
  final bool stable;
  final bool finalFlush;
}

/// Best full path through the utterance, emitted when the reciter stops.
class FinalSequenceEvent extends RecitationEvent {
  const FinalSequenceEvent({required this.verses, required this.confidence});

  final List<FinalSequenceVerse> verses;
  final double confidence;
}

/// Word-level position inside the verse being tracked.
class WordProgressEvent extends RecitationEvent {
  const WordProgressEvent({
    required this.surah,
    required this.ayah,
    required this.wordIndex,
    required this.totalWords,
    required this.matchedIndices,
  });

  final int surah;
  final int ayah;
  final int wordIndex;
  final int totalWords;
  final List<int> matchedIndices;
}

/// Decoded text that did not clear the match threshold.
class RawTranscriptEvent extends RecitationEvent {
  const RawTranscriptEvent({required this.text, required this.confidence});

  final String text;
  final double confidence;
}

/// Structured trace of a tracker decision. Only produced when diagnostics are
/// switched on; never surfaced in the product UI.
class TrackerDiagnostic extends RecitationEvent {
  const TrackerDiagnostic(this.type, this.data);

  final String type;
  final Map<String, Object?> data;
}

/// Word list for a normalized verse string.
List<String> verseWords(String text) => splitWords(text);
