import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tilawa/features/recitation/engine/arabic_normalizer.dart';
import 'package:tilawa/features/recitation/engine/ctc_rescore.dart';
import 'package:tilawa/features/recitation/engine/levenshtein.dart';
import 'package:tilawa/features/recitation/engine/quran_db.dart';
import 'package:tilawa/features/recitation/engine/recitation_types.dart';

/// One inference pass: decoded text plus the acoustic evidence behind it.
class TranscribeResult {
  const TranscribeResult({
    required this.text,
    required this.tokenIds,
    this.acoustic,
    this.championMatch,
  });

  final String text;
  final List<int> tokenIds;
  final AcousticEvidence? acoustic;

  /// Match produced by the joint matcher on the decoded text, when it cleared
  /// the trust threshold.
  final QuranMatch? championMatch;
}

typedef TranscribeFn = Future<TranscribeResult> Function(Float32List audio);

typedef DiagnosticSink = void Function(TrackerDiagnostic event);

/// A short verse needs a moment of fresh audio before a queued advance is
/// confirmed, or two back-to-back final-word decodes visibly skip it.
const int _shortPendingConfirmMaxWords = 12;
const int _shortPendingConfirmMinSamples = sampleRate;

// Transition weights for the final-sequence Viterbi path.
const double _surahJumpHighConfidence = -0.35;
const double _surahJump = -1.25;
const double _sameAyah = 0.15;
const double _nextAyah = 0.35;
const double _smallForwardPerAyah = -0.15;
const double _backward = -1.0;
const double _farForward = -0.65;

class _PendingLeader {
  const _PendingLeader(this.key, this.count);

  final String key;
  final int count;
}

class _CommitEvidence {
  const _CommitEvidence({
    required this.confidence,
    required this.acousticMargin,
    required this.strong,
  });

  final double confidence;
  final double acousticMargin;
  final bool strong;
}

class _RankedCandidate {
  const _RankedCandidate({
    required this.candidate,
    required this.acousticScore,
    required this.acousticMargin,
    required this.feasible,
    required this.lengthFit,
    required this.fusionScore,
  });

  final QuranCandidate candidate;
  final double acousticScore;
  final double acousticMargin;
  final bool feasible;
  final double lengthFit;
  final double fusionScore;
}

class _TrackingPrefix {
  const _TrackingPrefix(this.wordIndex, this.ids);

  final int wordIndex;
  final List<int> ids;
}

class _PreAdvanceSnapshot {
  const _PreAdvanceSnapshot({
    required this.emittedRef,
    required this.emittedText,
    required this.prevEmittedRef,
    required this.prevEmittedText,
    required this.commitEvidence,
  });

  final ({int surah, int ayah})? emittedRef;
  final String emittedText;
  final ({int surah, int ayah})? prevEmittedRef;
  final String prevEmittedText;
  final _CommitEvidence? commitEvidence;
}

class _AlignResult {
  const _AlignResult(this.position, this.matchedIndices);

  final int position;
  final List<int> matchedIndices;
}

/// Streaming verse tracker.
///
/// Runs a two-phase state machine over a rolling audio window:
///
/// * **discovery** — no verse is locked in. Every trigger interval the window
///   is transcribed, candidates are retrieved by text and re-ranked by CTC
///   acoustic score, and a verse is committed once it either wins by a clear
///   acoustic margin or leads for enough consecutive cycles.
/// * **tracking** — a verse is locked in. Shorter windows report word-level
///   progress through it; when coverage completes, the next verse is queued
///   and only published after fresh audio confirms it, so a mis-advance rolls
///   back instead of dragging the UI forward.
class RecitationTracker {
  RecitationTracker(
    this._db,
    this._transcribe, {
    StreamingConfig? config,
    DiagnosticSink? onDiagnostic,
  })  : _config = (config ?? StreamingConfig.defaults).normalized(),
        _onDiagnostic = onDiagnostic;

  final QuranDB _db;
  final TranscribeFn _transcribe;
  final DiagnosticSink? _onDiagnostic;

  StreamingConfig _config;

  // Rolling audio window.
  Float32List _utteranceAudio = Float32List(0);
  int _newAudioCount = 0;
  int _silenceSamples = 0;
  bool _utteranceHasSpeech = false;
  bool _didFinalFlush = false;
  int _totalSamplesFed = 0;

  // Commit history.
  ({int surah, int ayah})? _lastEmittedRef;
  String _lastEmittedText = '';
  ({int surah, int ayah})? _prevEmittedRef;
  String _prevEmittedText = '';
  _PendingLeader? _pendingLeader;
  _CommitEvidence? _lastCommitEvidence;
  String? _lastDecodedText;

  // Tracking state.
  QuranVerse? _trackingVerse;
  List<String> _trackingVerseWords = const [];
  List<_TrackingPrefix> _trackingPrefixes = const [];
  int _trackingLastWordIdx = -1;
  bool _trackingProgressEstablished = false;
  int _staleCycles = 0;
  int _cyclesSinceCommit = 1 << 30;
  TranscribeResult? _lastTrackingResult;
  int _consecutiveAutoAdvances = 0;

  // Deferred next-verse emission.
  bool _trackingPendingEmission = false;
  VerseMatchEvent? _pendingEmissionMessage;
  double _pendingEmissionMargin = double.infinity;
  _PreAdvanceSnapshot? _preAdvanceSnapshot;
  int _samplesAtAdvance = 0;

  final _StreamingHypothesis _hypothesis = _StreamingHypothesis();

  int? _activeSurah;

  StreamingConfig get config => _config;

  void setConfig(StreamingConfig config) {
    _config = config.normalized();
  }

  /// Restricts matching to one surah, e.g. when the user opened it to revise.
  /// Pass null to search the whole corpus.
  void setActiveSurah(int? surah) {
    _activeSurah = surah;
    _resetUtterance();
  }

  /// Clears every piece of per-session state.
  void reset() {
    _resetUtterance();
    _exitTracking('reset');
    _lastEmittedRef = null;
    _lastEmittedText = '';
    _prevEmittedRef = null;
    _prevEmittedText = '';
    _lastCommitEvidence = null;
    _cyclesSinceCommit = 1 << 30;
    _consecutiveAutoAdvances = 0;
    _totalSamplesFed = 0;
    _samplesAtAdvance = 0;
  }

  /// Feeds one chunk of 16 kHz mono audio and returns whatever the tracker
  /// concluded from it.
  Future<List<RecitationEvent>> feed(Float32List samples) async {
    final messages = <RecitationEvent>[];

    _totalSamplesFed += samples.length;
    _utteranceAudio = _concat(_utteranceAudio, samples);

    final maxSamples = _trackingVerse != null
        ? _samplesForSeconds(_config.trackingMaxWindowSec)
        : _samplesForSeconds(_config.discoveryMaxWindowSec);
    if (_utteranceAudio.length > maxSamples) {
      _utteranceAudio = _tail(_utteranceAudio, maxSamples);
    }

    _newAudioCount += samples.length;

    if (_isSilence(samples, _config.silenceRmsThreshold)) {
      _silenceSamples += samples.length;
    } else {
      _silenceSamples = 0;
      _utteranceHasSpeech = true;
      _didFinalFlush = false;
    }

    final finalFlush = _utteranceHasSpeech &&
        !_didFinalFlush &&
        _silenceSamples >= _samplesForSeconds(_config.finalSilenceSec);

    if (_trackingVerse != null) {
      messages.addAll(await _handleTracking(finalFlush));
    } else {
      messages.addAll(await _handleDiscovery(finalFlush));
    }

    for (final message in messages) {
      if (message is VerseCandidateEvent) {
        _hypothesis.observeCandidates(message);
      } else if (message is VerseMatchEvent) {
        _hypothesis.observeCommit(message);
      }
    }

    if (finalFlush) {
      final finalSequence = _hypothesis.finalize();
      if (finalSequence != null) messages.add(finalSequence);
      _didFinalFlush = true;
      _emit('flush', {
        'mode': _trackingVerse != null ? 'tracking' : 'discovery',
        'duration_sec': _utteranceAudio.length / sampleRate,
      });
      if (_trackingVerse == null) _resetUtterance();
    }

    return messages;
  }

  // -------------------------------------------------------------------------
  // Tracking
  // -------------------------------------------------------------------------

  Future<List<RecitationEvent>> _handleTracking(bool finalFlush) async {
    final messages = <RecitationEvent>[];
    final trackingVerse = _trackingVerse;
    if (trackingVerse == null) return messages;

    if (!finalFlush &&
        _newAudioCount < _samplesForSeconds(_config.trackingTriggerSec)) {
      if (_silenceSamples >=
          _samplesForSeconds(_config.trackingSilenceTimeoutSec)) {
        _rollbackWeakCommit('tracking silence timeout');
        _exitTracking('extended silence');
      }
      return messages;
    }
    _newAudioCount = 0;

    final result = await _transcribe(Float32List.fromList(_utteranceAudio));
    _lastTrackingResult = result;
    final text = result.text.trim();
    if (text.isEmpty && !finalFlush) return messages;

    // Silence arrived with an advance still queued: publish it if the acoustic
    // evidence was strong enough to stand without confirmation.
    final pendingMessage = _pendingEmissionMessage;
    if (finalFlush &&
        _trackingPendingEmission &&
        pendingMessage != null &&
        _pendingEmissionMargin < _config.advanceFlushStrictMargin) {
      messages.add(pendingMessage);
      _emitPendingFlush(pendingMessage);
      _clearPendingEmission();
      _exitTracking('final silence flush (pending emitted)');
      return messages;
    }

    final recognizedWords = splitWords(text);
    final resumeFrom = _trackingLastWordIdx < 0 ? 0 : _trackingLastWordIdx;
    var confirmedPendingEmission = false;
    var aligned = _alignPosition(
      recognizedWords,
      _trackingVerseWords,
      startFrom: resumeFrom,
      lookahead: _config.lookaheadWords,
    );
    var matchedIndices = aligned.matchedIndices;
    final primaryMatchCount = matchedIndices.length;

    final freshSamplesSinceAdvance = _totalSamplesFed - _samplesAtAdvance;
    final pendingHasEnoughDwell = !_trackingPendingEmission ||
        _trackingVerseWords.length > _shortPendingConfirmMaxWords ||
        freshSamplesSinceAdvance >= _shortPendingConfirmMinSamples;

    // Confirm a queued advance only from primary word alignment on fresh audio.
    if (_trackingPendingEmission &&
        pendingHasEnoughDwell &&
        _hasStrongPendingPrefixEvidence(
          matchedIndices,
          _trackingVerseWords.length,
        ) &&
        _totalSamplesFed > _samplesAtAdvance) {
      final pending = _pendingEmissionMessage!;
      messages.add(pending);
      _emitPendingConfirmed(pending, matchedIndices);
      _clearPendingEmission();
      confirmedPendingEmission = true;
    }

    int? acousticWord;
    if (matchedIndices.isEmpty) {
      final acousticIdx = _resolveTrackingAcousticWord(result);
      if (acousticIdx > _trackingLastWordIdx) {
        acousticWord = acousticIdx;
        matchedIndices = [acousticIdx];
      }
    }

    int? charWord;
    if (matchedIndices.isEmpty &&
        text.length >= 5 &&
        _trackingVerseWords.length >= 10) {
      final charWordIdx = _charLevelProgress(text);
      if (charWordIdx > _trackingLastWordIdx) {
        charWord = charWordIdx;
        matchedIndices = [charWordIdx];
      }
    }

    final advanced =
        matchedIndices.isNotEmpty && matchedIndices.last > _trackingLastWordIdx;
    final reportedPosition =
        advanced ? matchedIndices.last + 1 : _trackingLastWordIdx + 1;

    _emit('tracking_cycle', {
      'ref': trackingVerse.ref,
      'text_length': text.length,
      'word_matches': primaryMatchCount,
      'acoustic_word': acousticWord,
      'char_word': charWord,
      'advanced': advanced,
      'final_flush': finalFlush,
      'word_position': reportedPosition,
      'total_words': _trackingVerseWords.length,
      'coverage': _round3(reportedPosition / _trackingVerseWords.length),
      'pending': _trackingPendingEmission,
    });

    if (!advanced) {
      _staleCycles++;
      if (_staleCycles >= _config.staleCycleLimit || finalFlush) {
        _emit('stale_exit', {
          'ref': trackingVerse.ref,
          'stale_cycles': _staleCycles,
        });
        final queued = _pendingEmissionMessage;
        if (finalFlush &&
            _trackingPendingEmission &&
            queued != null &&
            _pendingEmissionMargin < _config.advanceFlushStrictMargin) {
          messages.add(queued);
          _emitPendingFlush(queued);
          _clearPendingEmission();
          // No rollback: the queued advance has just been published.
          _exitTracking('final silence flush (pending emitted)');
        } else {
          final reason =
              finalFlush ? 'final silence flush' : 'stale tracking';
          _rollbackWeakCommit(reason);
          _exitTracking(reason);
        }
      }
      return messages;
    }

    final observedWordIdx = matchedIndices.last;
    final observedWordPos = observedWordIdx + 1;
    final totalWords = _trackingVerseWords.length;
    final completionWordCount =
        (totalWords * _config.trackingCompletionCoverage).ceil();
    final observedFinalWordReached = observedWordIdx >= totalWords - 1;

    if (_trackingPendingEmission &&
        _pendingEmissionMessage != null &&
        !pendingHasEnoughDwell) {
      _emitAdvanceDecision(
        fromRef: trackingVerse.ref,
        toRef: null,
        action: 'blocked',
        reason: 'pending confirmation dwell',
        wordPosition: observedWordPos,
        totalWords: totalWords,
        coverage: _round3(observedWordPos / totalWords),
        completionTarget: completionWordCount,
        finalWord: observedFinalWordReached,
        advanceOk: false,
        earlyAdvanceOk: false,
        margin: null,
      );
      return messages;
    }

    _staleCycles = 0;
    _trackingProgressEstablished = true;
    _trackingLastWordIdx = observedWordIdx;
    final wordPos = _trackingLastWordIdx + 1;
    final coverage = _round3(wordPos / totalWords);
    final completedEnough = wordPos >= completionWordCount;
    final finalWordReached = _trackingLastWordIdx >= totalWords - 1;

    if (completedEnough &&
        _trackingPendingEmission &&
        _pendingEmissionMessage != null &&
        pendingHasEnoughDwell) {
      final pending = _pendingEmissionMessage!;
      messages.add(pending);
      _emitPendingConfirmed(pending, matchedIndices);
      _clearPendingEmission();
      confirmedPendingEmission = true;
    }

    if (!_trackingPendingEmission) {
      messages.add(
        WordProgressEvent(
          surah: trackingVerse.surah,
          ayah: trackingVerse.ayah,
          wordIndex: wordPos,
          totalWords: totalWords,
          matchedIndices: matchedIndices,
        ),
      );
    }

    // Confirming an advance and arming the next one in the same cycle would
    // skip a verse, so hold until the reciter reaches the final word.
    if (completedEnough && confirmedPendingEmission && !finalWordReached) {
      _emit('pending_emission', {
        'action': 'cascade_blocked',
        'ref': trackingVerse.ref,
        'fresh_samples': _totalSamplesFed - _samplesAtAdvance,
        'matched_indices': matchedIndices,
      });
      _emitAdvanceDecision(
        fromRef: trackingVerse.ref,
        toRef: null,
        action: 'blocked',
        reason: 'pending confirmed before final word',
        wordPosition: wordPos,
        totalWords: totalWords,
        coverage: coverage,
        completionTarget: completionWordCount,
        finalWord: finalWordReached,
        advanceOk: false,
        earlyAdvanceOk: false,
        margin: null,
      );
    }

    if (completedEnough && (!confirmedPendingEmission || finalWordReached)) {
      if (!(_lastCommitEvidence?.strong ?? false) &&
          !_trackingProgressEstablished) {
        _emitAdvanceDecision(
          fromRef: trackingVerse.ref,
          toRef: null,
          action: 'blocked',
          reason: 'weak commit evidence',
          wordPosition: wordPos,
          totalWords: totalWords,
          coverage: coverage,
          completionTarget: completionWordCount,
          finalWord: finalWordReached,
          advanceOk: false,
          earlyAdvanceOk: false,
          margin: null,
        );
        _exitTracking('weak completion');
        return messages;
      }

      final currentRef = (surah: trackingVerse.surah, ayah: trackingVerse.ayah);
      final currentIds = trackingVerse.phonemeTokenIds;
      final nextVerse = _db.getNextVerse(currentRef.surah, currentRef.ayah);

      // Default to advancing so behaviour is unchanged when no acoustic
      // evidence is available.
      var advanceOk = true;
      var earlyAdvanceOk = completedEnough;
      var advanceMargin = double.infinity;

      final acoustic = _lastTrackingResult?.acoustic;
      final nextIds = nextVerse?.phonemeTokenIds ?? const <int>[];

      if (nextVerse != null &&
          acoustic != null &&
          currentIds.isNotEmpty &&
          nextIds.isNotEmpty) {
        // Does the tail of the window explain the end of this verse better
        // than the start of the next one?
        final n = _config.advancePrefixTokens;
        final suffixIds = currentIds
            .sublist(currentIds.length - math.min(n, currentIds.length));
        final prefixIds = nextIds.sublist(0, math.min(n, nextIds.length));

        final suffixScore = scoreCtcSequence(acoustic, suffixIds);
        final prefixScore = scoreCtcSequence(acoustic, prefixIds);

        if (!suffixScore.isFinite || !prefixScore.isFinite) {
          advanceOk = false;
        } else {
          advanceMargin = prefixScore - suffixScore;
          advanceOk = advanceMargin < _config.advanceRelativeMargin;
          earlyAdvanceOk = earlyAdvanceOk ||
              advanceMargin < _config.advanceFlushStrictMargin;
        }
      }

      if (!finalWordReached && !earlyAdvanceOk) {
        _emitAdvanceDecision(
          fromRef: trackingVerse.ref,
          toRef: nextVerse?.ref,
          action: 'wait',
          reason: 'coverage reached without final word or next-prefix evidence',
          wordPosition: wordPos,
          totalWords: totalWords,
          coverage: coverage,
          completionTarget: completionWordCount,
          finalWord: finalWordReached,
          advanceOk: advanceOk,
          earlyAdvanceOk: earlyAdvanceOk,
          margin: advanceMargin,
        );
        return messages;
      }

      _lastEmittedRef = currentRef;
      _lastEmittedText = trackingVerse.phonemesJoined;
      _exitTracking(
        finalWordReached ? 'verse complete' : 'near-complete with next prefix',
      );

      if (nextVerse != null) {
        if (advanceOk) {
          _preAdvanceSnapshot = _PreAdvanceSnapshot(
            emittedRef: _lastEmittedRef,
            emittedText: _lastEmittedText,
            prevEmittedRef: _prevEmittedRef,
            prevEmittedText: _prevEmittedText,
            commitEvidence: _lastCommitEvidence,
          );

          _pendingEmissionMessage = VerseMatchEvent(
            surah: nextVerse.surah,
            ayah: nextVerse.ayah,
            verseText: nextVerse.textUthmani,
            surahName: nextVerse.surahName,
            confidence: 0.99,
            surroundingVerses:
                _db.surroundingVerses(nextVerse.surah, nextVerse.ayah),
          );
          _trackingPendingEmission = true;
          _samplesAtAdvance = _totalSamplesFed;
          _pendingEmissionMargin = advanceMargin;

          _emitAdvanceDecision(
            fromRef: '${currentRef.surah}:${currentRef.ayah}',
            toRef: nextVerse.ref,
            action: 'armed',
            reason: finalWordReached
                ? 'final word reached'
                : earlyAdvanceOk
                    ? 'completion coverage reached'
                    : 'next-prefix evidence',
            wordPosition: wordPos,
            totalWords: totalWords,
            coverage: coverage,
            completionTarget: completionWordCount,
            finalWord: finalWordReached,
            advanceOk: advanceOk,
            earlyAdvanceOk: earlyAdvanceOk,
            margin: advanceMargin,
          );
          _emit('pending_emission', {
            'action': 'armed',
            'ref': nextVerse.ref,
            'margin': _finiteOrNull(advanceMargin),
            'fresh_samples': 0,
          });

          _prevEmittedRef = currentRef;
          _prevEmittedText = _lastEmittedText;
          _lastEmittedRef = (surah: nextVerse.surah, ayah: nextVerse.ayah);
          _lastEmittedText = nextVerse.phonemesJoined;
          _lastCommitEvidence = const _CommitEvidence(
            confidence: 0.99,
            acousticMargin: 1,
            strong: true,
          );
          _enterTracking(nextVerse);
          _consecutiveAutoAdvances++;

          switch (_config.nextVerseEmitMode) {
            case NextVerseEmitMode.candidateUntilConfirmed:
              messages.add(
                VerseCandidateEvent(
                  candidates: [
                    VerseCandidate(
                      surah: nextVerse.surah,
                      ayah: nextVerse.ayah,
                      ayahEnd: null,
                      confidence: 0.99,
                      rank: 1,
                      source: CandidateSource.tracking,
                    ),
                  ],
                  stable: true,
                  finalFlush: false,
                ),
              );
            case NextVerseEmitMode.immediateOnCompletion:
              messages.add(_pendingEmissionMessage!);
              _clearPendingEmission();
            case NextVerseEmitMode.deferredConfirm:
              break;
          }

          // After a long unbroken run of auto-advances, downgrade the evidence
          // so a stale cycle drops back into discovery instead of coasting.
          if (_consecutiveAutoAdvances >= 5) {
            final evidence = _lastCommitEvidence!;
            _lastCommitEvidence = _CommitEvidence(
              confidence: evidence.confidence,
              acousticMargin: evidence.acousticMargin,
              strong: false,
            );
          }
        } else {
          _emitAdvanceDecision(
            fromRef: '${currentRef.surah}:${currentRef.ayah}',
            toRef: nextVerse.ref,
            action: 'blocked',
            reason: 'advance margin failed',
            wordPosition: wordPos,
            totalWords: totalWords,
            coverage: coverage,
            completionTarget: completionWordCount,
            finalWord: finalWordReached,
            advanceOk: advanceOk,
            earlyAdvanceOk: earlyAdvanceOk,
            margin: advanceMargin,
          );
        }
      }

      _retainTailAfterCommit();
    }

    return messages;
  }

  // -------------------------------------------------------------------------
  // Discovery
  // -------------------------------------------------------------------------

  Future<List<RecitationEvent>> _handleDiscovery(bool finalFlush) async {
    final messages = <RecitationEvent>[];

    if (!_utteranceHasSpeech) {
      _emit('silence_skip',
          {'mode': 'discovery', 'reason': 'no speech detected'});
      return messages;
    }

    if (!finalFlush &&
        _newAudioCount < _samplesForSeconds(_config.discoveryTriggerSec)) {
      return messages;
    }
    _newAudioCount = 0;
    _cyclesSinceCommit++;

    final result = await _transcribe(Float32List.fromList(_utteranceAudio));
    final text = result.text.trim();

    if (text.length < 5) {
      final rescued = _shortUtteranceRescue(result, messages);
      if (rescued) return messages;
      _emit('silence_skip',
          {'mode': 'discovery', 'reason': 'transcript too short'});
      return messages;
    }

    // Ignore a window that is still dominated by the verse just committed.
    if (_lastEmittedText.isNotEmpty &&
        (_lastCommitEvidence?.strong ?? false)) {
      final residual = partialRatio(text, _lastEmittedText);
      final textChars = text.replaceAll(RegExp(r'\s+'), '').length;
      final emittedChars =
          _lastEmittedText.replaceAll(RegExp(r'\s+'), '').length;
      final looksLikeLeftover = textChars <= (emittedChars * 1.15).ceil();
      if (residual > 0.7 && looksLikeLeftover && !finalFlush) {
        _emit('silence_skip', {
          'mode': 'discovery',
          'reason': 'residual=${residual.toStringAsFixed(3)}',
        });
        return messages;
      }
    }

    final championMatch = result.championMatch;
    final match = championMatch ??
        _db.matchVerse(
          text,
          threshold: kRawTranscriptThreshold,
          maxSpan: kDiscoveryMaxSpan,
          hint: _lastEmittedRef,
          surahFilter: _activeSurah,
        );

    // Widen the candidate set when the text match looks unreliable.
    final textConfidenceLow =
        match == null || match.score < _config.verseMatchThreshold + 0.10;
    final retrieved = _db.retrieveCandidates(
      text,
      maxSpan: kDiscoveryMaxSpan,
      hint: _lastEmittedRef,
      singleLimit: textConfidenceLow
          ? kDiscoveryExpandedCandidates
          : kDiscoveryTopSingleCandidates,
      topSurahs: textConfidenceLow ? 10 : kDiscoveryTopSurahs,
      spanLimit: kDiscoveryTopSingleCandidates,
      surahFilter: _activeSurah,
    );

    final ranked = _rankCandidates(retrieved.combined, result);

    _emit('discovery_cycle', {
      'text': text,
      'final_flush': finalFlush,
      'candidates': [
        for (final entry in ranked.take(8))
          {
            'ref': entry.candidate.refKey,
            'kind': entry.candidate.kind.name,
            'stageA': _round3(entry.candidate.stageAScore),
            'acoustic': _round3(entry.acousticScore),
            'acousticMargin': _round3(entry.acousticMargin),
            'lengthFit': _round3(entry.lengthFit),
            'fusion': _round3(entry.fusionScore),
            'feasible': entry.feasible,
          },
      ],
    });

    var acousticMargin = 0.0;
    var lengthFit = 1.0;
    var effectiveMatch = match;
    var effectiveScore = match?.score ?? 0.0;
    final fusionBest = ranked.isEmpty ? null : ranked.first;

    if (fusionBest != null) {
      acousticMargin = fusionBest.acousticMargin;
      lengthFit = fusionBest.lengthFit;
    }

    if (match != null && fusionBest != null) {
      final fusionGap = fusionBest.fusionScore - match.score;
      if (fusionBest.candidate.refKey == match.refKey) {
        effectiveScore = math.max(
          effectiveScore,
          math.max(fusionBest.fusionScore, fusionBest.candidate.stageAScore),
        );
      }
      final shouldOverride = championMatch == null &&
          fusionBest.candidate.refKey != match.refKey &&
          (match.score < _config.verseMatchThreshold + 0.10 ||
              textConfidenceLow ||
              fusionGap >= kDiscoveryFusionSelectionGap ||
              (fusionBest.candidate.kind == CandidateKind.span &&
                  fusionBest.lengthFit >= 0.7));

      if (shouldOverride) {
        effectiveMatch = _matchFromCandidate(
          fusionBest.candidate,
          math.max(
            math.max(match.score, fusionBest.fusionScore),
            math.max(fusionBest.candidate.stageAScore, 0.5),
          ),
        );
        effectiveScore = effectiveMatch.score;
        acousticMargin = fusionBest.acousticMargin;
        lengthFit = fusionBest.lengthFit;
      }
    } else if (match == null && fusionBest != null) {
      effectiveMatch = _matchFromCandidate(
        fusionBest.candidate,
        math.max(fusionBest.fusionScore, fusionBest.candidate.stageAScore),
      );
      effectiveScore = effectiveMatch.score;
    }

    // A broad span that swallows the next ayah hides genuine forward progress.
    final lastRef = _lastEmittedRef;
    if (effectiveMatch != null &&
        fusionBest != null &&
        lastRef != null &&
        !finalFlush) {
      final nextAyah = lastRef.ayah + 1;
      final effectiveEnd = _spanEnd(effectiveMatch);
      final top = fusionBest.candidate;
      final broadMatchCoversNext = effectiveMatch.surah == lastRef.surah &&
          effectiveMatch.ayah < nextAyah &&
          effectiveEnd >= nextAyah;
      final topIsNearbyForwardContinuation = top.surah == lastRef.surah &&
          top.ayah > nextAyah &&
          top.ayah <= lastRef.ayah + 3;
      final topClearlyBetter =
          (fusionBest.feasible || result.acoustic == null) &&
              fusionBest.lengthFit >= 0.6 &&
              fusionBest.fusionScore >= effectiveScore + 0.05;

      if (broadMatchCoversNext &&
          topIsNearbyForwardContinuation &&
          topClearlyBetter) {
        effectiveMatch = _matchFromCandidate(
          top,
          math.max(fusionBest.fusionScore, top.stageAScore),
        );
        effectiveScore = effectiveMatch.score;
        acousticMargin = fusionBest.acousticMargin;
        lengthFit = fusionBest.lengthFit;
      }
    }

    if (effectiveMatch != null) {
      final selectedKey = effectiveMatch.refKey;
      for (final entry in ranked) {
        if (entry.candidate.refKey == selectedKey) {
          acousticMargin = entry.acousticMargin;
          lengthFit = entry.lengthFit;
          break;
        }
      }
    }

    // Live spans that start before the expected next ayah are rebased onto it.
    if (effectiveMatch != null && lastRef != null && !finalFlush) {
      final nextAyah = lastRef.ayah + 1;
      final effectiveEnd = _spanEnd(effectiveMatch);
      final shouldRebaseToNext = effectiveMatch.surah == lastRef.surah &&
          effectiveMatch.ayah != nextAyah &&
          effectiveMatch.ayah <= nextAyah &&
          effectiveEnd >= nextAyah;
      final nextVerse = _db.getVerse(effectiveMatch.surah, nextAyah);
      if (shouldRebaseToNext && nextVerse != null) {
        _emitAdvanceDecision(
          fromRef: effectiveMatch.refKey,
          toRef: nextVerse.ref,
          action: 'blocked',
          reason: 'live span rebased to next ayah',
          wordPosition: 0,
          totalWords: 0,
          coverage: 0,
          completionTarget: 0,
          finalWord: false,
          advanceOk: false,
          earlyAdvanceOk: false,
          margin: null,
        );
        effectiveMatch = QuranMatch(
          surah: nextVerse.surah,
          ayah: nextVerse.ayah,
          ayahEnd: null,
          text: nextVerse.textUthmani,
          phonemesJoined: nextVerse.phonemesJoined,
          score: effectiveScore,
          rawScore: effectiveScore,
          bonus: 0,
        );
      }
    }

    final threshold = _lastEmittedRef != null
        ? _config.verseMatchThreshold
        : _config.firstMatchThreshold;

    if (effectiveMatch == null || effectiveScore < threshold) {
      messages.add(
        RawTranscriptEvent(
          text: text,
          confidence: effectiveMatch != null ? _round2(effectiveScore) : 0,
        ),
      );
      _lastDecodedText = result.text;
      return messages;
    }

    messages.addAll(
      _tryCommit(
        text: text,
        result: result,
        effectiveMatch: effectiveMatch,
        effectiveScore: effectiveScore,
        threshold: threshold,
        acousticMargin: acousticMargin,
        lengthFit: lengthFit,
        ranked: ranked,
        finalFlush: finalFlush,
      ),
    );

    _lastDecodedText = result.text;
    return messages;
  }

  List<RecitationEvent> _tryCommit({
    required String text,
    required TranscribeResult result,
    required QuranMatch effectiveMatch,
    required double effectiveScore,
    required double threshold,
    required double acousticMargin,
    required double lengthFit,
    required List<_RankedCandidate> ranked,
    required bool finalFlush,
  }) {
    final messages = <RecitationEvent>[];
    final key = effectiveMatch.refKey;

    _pendingLeader = _pendingLeader?.key == key
        ? _PendingLeader(key, _pendingLeader!.count + 1)
        : _PendingLeader(key, 1);

    final isContinuation =
        _isContinuation(effectiveMatch.surah, effectiveMatch.ayah);
    final clearMargin = lengthFit >= 0.6 &&
        acousticMargin >=
            (isContinuation
                ? _config.acousticContinuationMargin
                : _config.acousticClearMargin);
    final repeatedLeader =
        (_pendingLeader?.count ?? 0) >= _config.discoveryRepeatCycles;

    final candidateMessage = _candidateMessage(
      effectiveMatch,
      effectiveScore,
      ranked,
      stable: repeatedLeader || finalFlush,
      finalFlush: finalFlush,
    );
    if (candidateMessage != null) messages.add(candidateMessage);

    // Anti-cascade: during live recitation, never jump off the committed verse
    // to something that is not a plausible continuation.
    var blocked = false;
    if (_lastEmittedRef != null && !isContinuation && !finalFlush) {
      blocked = true;
      _emitAdvanceDecision(
        fromRef: '${_lastEmittedRef!.surah}:${_lastEmittedRef!.ayah}',
        toRef: key,
        action: 'blocked',
        reason: 'live non-continuation discovery blocked',
        wordPosition: 0,
        totalWords: 0,
        coverage: 0,
        completionTarget: 0,
        finalWord: false,
        advanceOk: false,
        earlyAdvanceOk: false,
        margin: null,
      );
    }
    if (!isContinuation && _lastEmittedRef != null && _cyclesSinceCommit <= 2) {
      if (effectiveScore < _config.nonContinuationJumpThreshold &&
          !repeatedLeader) {
        blocked = true;
      }
    }

    // The caller already gated on `effectiveScore >= threshold`, so on a final
    // flush the score alone is enough — no repeat cycle needed.
    final finalFlushCommit = finalFlush;

    // Decode-stability gate: a single-cycle margin commit must be backed by a
    // decode that has stopped changing between cycles. Repeated-leader and
    // final-flush commits carry their own protection and are exempt.
    var clearMarginAllowed = clearMargin;
    if (_config.decodeStabilityEnabled && clearMargin && !isContinuation) {
      final previous = _lastDecodedText;
      final stable = previous != null &&
          previous.isNotEmpty &&
          similarityRatio(previous, result.text) >= _config.decodeStabilityRatio;
      if (!stable) clearMarginAllowed = false;
    }

    if (blocked || !(clearMarginAllowed || repeatedLeader || finalFlushCommit)) {
      messages.add(
        RawTranscriptEvent(text: text, confidence: _round2(effectiveScore)),
      );
      return messages;
    }

    final ref = (surah: effectiveMatch.surah, ayah: effectiveMatch.ayah);
    if (_lastEmittedRef == ref) return messages;

    final verse = _db.getVerse(effectiveMatch.surah, effectiveMatch.ayah);
    final confidence = math.max(
      effectiveScore,
      math.min(0.99, 0.45 + acousticMargin + lengthFit * 0.2),
    );

    var selectedRank = -1;
    for (var i = 0; i < ranked.length; i++) {
      if (ranked[i].candidate.refKey == key) {
        selectedRank = i;
        break;
      }
    }

    messages.add(
      VerseMatchEvent(
        surah: effectiveMatch.surah,
        ayah: effectiveMatch.ayah,
        verseText: verse?.textUthmani ?? effectiveMatch.text,
        surahName: verse?.surahName ?? '',
        confidence: _round2(confidence),
        surroundingVerses:
            _db.surroundingVerses(effectiveMatch.surah, effectiveMatch.ayah),
      ),
    );

    // Only a final flush commits every ayah of a span. Committing the whole
    // span live would jump the UI past the ayah the reciter just started.
    final ayahEnd = effectiveMatch.ayahEnd;
    final liveSpanCollapsed =
        ayahEnd != null && ayahEnd > effectiveMatch.ayah && !finalFlush;
    final committedAyahEnd =
        (ayahEnd != null && ayahEnd > effectiveMatch.ayah && finalFlush)
            ? ayahEnd
            : effectiveMatch.ayah;

    if (liveSpanCollapsed) {
      _emitAdvanceDecision(
        fromRef: refKeyFor(effectiveMatch.surah, effectiveMatch.ayah, ayahEnd),
        toRef: '${effectiveMatch.surah}:${effectiveMatch.ayah}',
        action: 'blocked',
        reason: 'live span collapsed to first ayah',
        wordPosition: 0,
        totalWords: 0,
        coverage: 0,
        completionTarget: 0,
        finalWord: false,
        advanceOk: false,
        earlyAdvanceOk: false,
        margin: null,
      );
    }

    for (var a = effectiveMatch.ayah + 1; a <= committedAyahEnd; a++) {
      final spanVerse = _db.getVerse(effectiveMatch.surah, a);
      if (spanVerse == null) continue;
      messages.add(
        VerseMatchEvent(
          surah: spanVerse.surah,
          ayah: spanVerse.ayah,
          verseText: spanVerse.textUthmani,
          surahName: spanVerse.surahName,
          confidence: _round2(confidence),
          surroundingVerses:
              _db.surroundingVerses(spanVerse.surah, spanVerse.ayah),
        ),
      );
    }

    _prevEmittedRef = _lastEmittedRef;
    _prevEmittedText = _lastEmittedText;
    _lastEmittedRef = (surah: effectiveMatch.surah, ayah: committedAyahEnd);

    final lastSpanVerse = committedAyahEnd > effectiveMatch.ayah
        ? _db.getVerse(effectiveMatch.surah, committedAyahEnd)
        : verse;
    _lastEmittedText = lastSpanVerse?.phonemesJoined ??
        (effectiveMatch.phonemesJoined.isNotEmpty
            ? effectiveMatch.phonemesJoined
            : (verse?.phonemesJoined ?? ''));
    _lastCommitEvidence = _CommitEvidence(
      confidence: confidence,
      acousticMargin: acousticMargin,
      strong: confidence >= kTrackingWeakCommitConfidence &&
          lengthFit >= 0.8 &&
          clearMargin,
    );
    _pendingLeader = null;
    _cyclesSinceCommit = 0;
    _consecutiveAutoAdvances = 0;

    _emit('commit', {
      'ref': liveSpanCollapsed
          ? '${effectiveMatch.surah}:${effectiveMatch.ayah}'
          : key,
      'reason': liveSpanCollapsed
          ? 'live_span_collapsed'
          : clearMargin
              ? 'acoustic_margin'
              : 'repeat_leader',
      'confidence': _round3(confidence),
      'origin': 'discovery',
      'selected_rank': selectedRank >= 0 ? selectedRank + 1 : null,
      'effective_score': _round3(effectiveScore),
      'threshold': threshold,
      'acoustic_margin': _round3(acousticMargin),
      'length_fit': _round3(lengthFit),
      'clear_margin': clearMarginAllowed,
      'repeated_leader': repeatedLeader,
      'final_flush_commit': finalFlushCommit,
      'is_continuation': isContinuation,
    });

    // Live spans track their first ayah; final-flush spans track the last.
    final trackVerse = lastSpanVerse ?? verse;
    if (trackVerse != null) {
      _enterTracking(trackVerse);
    } else {
      _retainTailAfterCommit();
    }
    return messages;
  }

  /// A one- or two-word utterance carries too little text to match, but its
  /// CTC score against the pool of very short verses can still be decisive.
  bool _shortUtteranceRescue(
    TranscribeResult result,
    List<RecitationEvent> messages,
  ) {
    final acoustic = result.acoustic;
    if (acoustic == null ||
        result.tokenIds.length < 2 ||
        _cyclesSinceCommit <= 1) {
      return false;
    }

    final shortCandidates = _db.getShortVerseCandidates();
    if (shortCandidates.isEmpty) return false;

    final scored = scoreCtcCandidates<QuranCandidate>(
      acoustic,
      [
        for (final candidate in shortCandidates)
          CtcCandidate(ids: candidate.phonemeTokenIds, meta: candidate),
      ],
    );
    final feasible = scored.where((s) => s.feasible).toList();
    if (feasible.length < 2) return false;

    final margin = feasible[1].acousticScore - feasible[0].acousticScore;
    if (margin < _config.acousticClearMargin) return false;

    final best = feasible.first.meta;
    final verse = _db.getVerse(best.surah, best.ayah);
    if (verse == null) return false;

    final ref = (surah: best.surah, ayah: best.ayah);
    if (_lastEmittedRef == ref) return false;

    final confidence = math.min(0.85, 0.5 + margin);
    messages.add(
      VerseMatchEvent(
        surah: best.surah,
        ayah: best.ayah,
        verseText: verse.textUthmani,
        surahName: verse.surahName,
        confidence: _round2(confidence),
        surroundingVerses: _db.surroundingVerses(best.surah, best.ayah),
      ),
    );

    _prevEmittedRef = _lastEmittedRef;
    _prevEmittedText = _lastEmittedText;
    _lastEmittedRef = ref;
    _lastEmittedText = verse.phonemesJoined;
    _lastCommitEvidence = _CommitEvidence(
      confidence: confidence,
      acousticMargin: margin,
      strong: margin >= 0.3,
    );
    _pendingLeader = null;
    _cyclesSinceCommit = 0;
    _consecutiveAutoAdvances = 0;

    _emit('commit', {
      'ref': refKeyFor(best.surah, best.ayah),
      'reason': 'short_rescue',
      'confidence': _round3(confidence),
      'origin': 'short_rescue',
      'acoustic_margin': _round3(margin),
    });
    _enterTracking(verse);
    return true;
  }

  // -------------------------------------------------------------------------
  // Ranking helpers
  // -------------------------------------------------------------------------

  VerseCandidateEvent? _candidateMessage(
    QuranMatch? effectiveMatch,
    double effectiveScore,
    List<_RankedCandidate> ranked, {
    required bool stable,
    required bool finalFlush,
  }) {
    final candidates = <VerseCandidate>[];
    final seen = <String>{};

    void add(int surah, int ayah, int? ayahEnd, double confidence) {
      final key = refKeyFor(surah, ayah, ayahEnd);
      if (!seen.add(key)) return;
      candidates.add(
        VerseCandidate(
          surah: surah,
          ayah: ayah,
          ayahEnd: ayahEnd,
          confidence: _round2(confidence.clamp(0.0, 1.0)),
          rank: candidates.length + 1,
          source: CandidateSource.discovery,
        ),
      );
    }

    if (effectiveMatch != null) {
      add(effectiveMatch.surah, effectiveMatch.ayah, effectiveMatch.ayahEnd,
          effectiveScore);
    }
    for (final entry in ranked.take(4)) {
      add(entry.candidate.surah, entry.candidate.ayah, entry.candidate.ayahEnd,
          entry.fusionScore);
    }

    if (candidates.isEmpty) return null;
    return VerseCandidateEvent(
      candidates: candidates,
      stable: stable,
      finalFlush: finalFlush,
    );
  }

  /// How far into the tracked verse the audio reaches, judged purely
  /// acoustically by scoring each word-prefix of the verse.
  int _resolveTrackingAcousticWord(TranscribeResult result) {
    final acoustic = result.acoustic;
    if (acoustic == null || _trackingPrefixes.isEmpty) return -1;

    final start = _trackingLastWordIdx < 0 ? 0 : _trackingLastWordIdx;
    if (start >= _trackingPrefixes.length) return -1;

    final scored = scoreCtcCandidates<_TrackingPrefix>(
      acoustic,
      [
        for (final prefix in _trackingPrefixes.sublist(start))
          CtcCandidate(
            ids: prefix.ids,
            meta: prefix,
            priorScore: (prefix.wordIndex + 1).toDouble(),
          ),
      ],
    );
    final stable = chooseLongestStablePrefix(
      scored,
      tolerance: _config.trackingPrefixTolerance,
    );
    return stable?.meta.wordIndex ?? -1;
  }

  /// Fuses text similarity, acoustic fit and length agreement into one score.
  List<_RankedCandidate> _rankCandidates(
    List<QuranCandidate> candidates,
    TranscribeResult result,
  ) {
    final acoustic = result.acoustic;
    if (acoustic == null || candidates.isEmpty) {
      return [
        for (final candidate in candidates)
          _RankedCandidate(
            candidate: candidate,
            acousticScore: 0,
            acousticMargin: 0,
            feasible: false,
            lengthFit: 1,
            fusionScore: candidate.stageAScore,
          ),
      ]..sort(
          (a, b) =>
              b.candidate.stageAScore.compareTo(a.candidate.stageAScore),
        );
    }

    final observedLength = math.max(result.tokenIds.length, 1);
    final observedWords = splitWords(result.text.trim()).length;
    final observedChars = result.text.replaceAll(RegExp(r'\s+'), '').length;

    // With very little text to go on, lean harder on the acoustics.
    final textWeak = observedWords <= kDiscoveryLowConfidenceWords ||
        observedChars <= kDiscoveryLowConfidenceChars;
    final textWeight =
        textWeak ? kDiscoveryFusionLowTextWeight : kDiscoveryFusionTextWeight;
    final acousticWeight = textWeak
        ? kDiscoveryFusionLowAcousticWeight
        : kDiscoveryFusionAcousticWeight;
    final lengthWeight = textWeak
        ? kDiscoveryFusionLowLengthWeight
        : kDiscoveryFusionLengthWeight;

    final scored = scoreCtcCandidates<QuranCandidate>(
      acoustic,
      [
        for (final candidate in candidates)
          CtcCandidate(
            ids: candidate.phonemeTokenIds,
            meta: candidate,
            priorScore: candidate.stageAScore,
          ),
      ],
    );

    final feasibleScores = [
      for (final entry in scored)
        if (entry.feasible) entry.acousticScore,
    ];
    final minAcoustic =
        feasibleScores.isEmpty ? 0.0 : feasibleScores.reduce(math.min);
    final maxAcoustic =
        feasibleScores.isEmpty ? 1.0 : feasibleScores.reduce(math.max);
    final acousticRange = math.max(maxAcoustic - minAcoustic, 1e-6);

    final ranked = <_RankedCandidate>[];
    for (var i = 0; i < scored.length; i++) {
      final entry = scored[i];
      final candidateLength = math.max(entry.meta.phonemeTokenIds.length, 1);
      final lengthFit = math.min(candidateLength, observedLength) /
          math.max(candidateLength, observedLength);
      final acousticFit = entry.feasible
          ? 1 - (entry.acousticScore - minAcoustic) / acousticRange
          : 0.0;
      final fusionScore = math.min(
        1.0,
        entry.meta.stageAScore * textWeight +
            acousticFit * acousticWeight +
            lengthFit * lengthWeight,
      );
      final nextScore = i + 1 < scored.length
          ? scored[i + 1].acousticScore
          : entry.acousticScore;

      ranked.add(
        _RankedCandidate(
          candidate: entry.meta,
          acousticScore: entry.acousticScore,
          acousticMargin: nextScore - entry.acousticScore,
          feasible: entry.feasible,
          lengthFit: lengthFit,
          fusionScore: fusionScore,
        ),
      );
    }

    ranked.sort((a, b) {
      if (b.fusionScore != a.fusionScore) {
        return b.fusionScore.compareTo(a.fusionScore);
      }
      if (b.candidate.stageAScore != a.candidate.stageAScore) {
        return b.candidate.stageAScore.compareTo(a.candidate.stageAScore);
      }
      return a.acousticScore.compareTo(b.acousticScore);
    });
    return ranked;
  }

  /// Last resort for long verses: slide the transcript along the verse's
  /// character stream and convert the best offset into a word index.
  int _charLevelProgress(String text) {
    final verse = _trackingVerse;
    if (verse == null) return -1;
    final joined = verse.phonemesJoined;
    final words = _trackingVerseWords;
    if (joined.isEmpty || words.isEmpty) return -1;

    final noSpaceText = text.replaceAll(' ', '');
    final noSpaceJoined = joined.replaceAll(' ', '');
    final textLen = noSpaceText.length;
    if (textLen < 3 || textLen >= noSpaceJoined.length) return -1;

    var bestScore = 0.0;
    var bestEnd = 0;
    final step = math.max(1, textLen ~/ 5);
    for (var i = 0; i <= noSpaceJoined.length - textLen; i += step) {
      final score =
          similarityRatio(noSpaceText, noSpaceJoined.substring(i, i + textLen));
      if (score > bestScore) {
        bestScore = score;
        bestEnd = i + textLen;
      }
    }
    if (step > 1) {
      final refineStart = math.max(0, bestEnd - textLen - step);
      final refineEnd = math.min(
        noSpaceJoined.length - textLen,
        bestEnd - textLen + step,
      );
      for (var i = refineStart; i <= refineEnd; i++) {
        final score = similarityRatio(
          noSpaceText,
          noSpaceJoined.substring(i, i + textLen),
        );
        if (score > bestScore) {
          bestScore = score;
          bestEnd = i + textLen;
        }
      }
    }

    if (bestScore < 0.55) return -1;

    var charCount = 0;
    for (var w = 0; w < words.length; w++) {
      charCount += words[w].length;
      if (charCount >= bestEnd) return w;
    }
    return words.length - 1;
  }

  // -------------------------------------------------------------------------
  // State transitions
  // -------------------------------------------------------------------------

  void _enterTracking(QuranVerse verse) {
    _trackingVerse = verse;
    _trackingVerseWords = verse.phonemeWords;
    _trackingLastWordIdx = -1;
    _trackingProgressEstablished = false;
    _staleCycles = 0;

    final tokenIds = verse.phonemeTokenIds;
    _trackingPrefixes = [
      for (var idx = 0; idx < verse.wordTokenEnds.length; idx++)
        if (verse.wordTokenEnds[idx] > 0 &&
            verse.wordTokenEnds[idx] <= tokenIds.length)
          _TrackingPrefix(idx, tokenIds.sublist(0, verse.wordTokenEnds[idx])),
    ];
    _retainTailAfterCommit();
  }

  void _exitTracking(String reason) {
    // An advance that was never confirmed must not leave its optimistic state
    // behind, or discovery restarts from a verse the reciter never reached.
    final snapshot = _preAdvanceSnapshot;
    if (_trackingPendingEmission && snapshot != null) {
      _lastEmittedRef = snapshot.emittedRef;
      _lastEmittedText = snapshot.emittedText;
      _prevEmittedRef = snapshot.prevEmittedRef;
      _prevEmittedText = snapshot.prevEmittedText;
      _lastCommitEvidence = snapshot.commitEvidence;
      _consecutiveAutoAdvances = 0;
    }
    _clearPendingEmission();

    _trackingVerse = null;
    _trackingVerseWords = const [];
    _trackingPrefixes = const [];
    _trackingLastWordIdx = -1;
    _trackingProgressEstablished = false;
    _staleCycles = 0;
    _lastTrackingResult = null;
  }

  void _rollbackWeakCommit(String reason) {
    if ((_lastCommitEvidence?.strong ?? false) || _trackingProgressEstablished) {
      return;
    }
    _lastEmittedRef = _prevEmittedRef;
    _lastEmittedText = _prevEmittedText;
    _lastCommitEvidence = null;
    _emit('rollback', {
      'reason': reason,
      'restored_ref': _prevEmittedRef == null
          ? null
          : '${_prevEmittedRef!.surah}:${_prevEmittedRef!.ayah}',
    });
  }

  /// Keeps a short tail of audio after a confident commit so the next cycle
  /// starts from the reciter's current position rather than re-reading the
  /// verse just matched.
  void _retainTailAfterCommit() {
    if (_lastCommitEvidence?.strong ?? false) {
      final keepSeconds = _trackingPendingEmission
          ? _config.tailAfterPendingAdvanceSec
          : _config.tailAfterCommitSec;
      final keepSamples =
          math.min(_utteranceAudio.length, _samplesForSeconds(keepSeconds));
      _utteranceAudio = _tail(_utteranceAudio, keepSamples);
    }
    _newAudioCount = 0;
    _silenceSamples = 0;
    _utteranceHasSpeech = _utteranceAudio.isNotEmpty;
    _didFinalFlush = false;
  }

  void _resetUtterance() {
    _utteranceAudio = Float32List(0);
    _newAudioCount = 0;
    _silenceSamples = 0;
    _utteranceHasSpeech = false;
    _didFinalFlush = false;
    _pendingLeader = null;
    _lastDecodedText = null;
    _hypothesis.reset();
  }

  bool _isContinuation(int surah, int ayah) {
    final last = _lastEmittedRef;
    if (last == null) return false;
    return surah == last.surah &&
        ayah >= last.ayah + 1 &&
        ayah <= last.ayah + 3;
  }

  void _clearPendingEmission() {
    _trackingPendingEmission = false;
    _pendingEmissionMessage = null;
    _pendingEmissionMargin = double.infinity;
    _preAdvanceSnapshot = null;
  }

  QuranMatch _matchFromCandidate(QuranCandidate candidate, double score) {
    return QuranMatch(
      surah: candidate.surah,
      ayah: candidate.ayah,
      ayahEnd: candidate.ayahEnd,
      text: candidate.text,
      phonemesJoined: candidate.phonemesJoined,
      score: score,
      rawScore: candidate.rawScore,
      bonus: candidate.bonus,
    );
  }

  static int _spanEnd(QuranMatch match) {
    final end = match.ayahEnd;
    return (end != null && end > match.ayah) ? end : match.ayah;
  }

  int _samplesForSeconds(double seconds) =>
      math.max(1, (sampleRate * seconds).round());

  // -------------------------------------------------------------------------
  // Diagnostics
  // -------------------------------------------------------------------------

  void _emit(String type, Map<String, Object?> data) {
    _onDiagnostic?.call(TrackerDiagnostic(type, data));
  }

  void _emitPendingConfirmed(VerseMatchEvent pending, List<int> matched) {
    _emit('pending_emission', {
      'action': 'confirmed',
      'ref': pending.ref,
      'margin': _finiteOrNull(_pendingEmissionMargin),
      'fresh_samples': _totalSamplesFed - _samplesAtAdvance,
      'matched_indices': matched,
    });
  }

  void _emitPendingFlush(VerseMatchEvent pending) {
    _emit('commit', {
      'ref': pending.ref,
      'reason': 'final_flush_pending_emit',
      'confidence': pending.confidence,
    });
    _emit('pending_emission', {
      'action': 'final_flush_emit',
      'ref': pending.ref,
      'margin': _finiteOrNull(_pendingEmissionMargin),
      'fresh_samples': _totalSamplesFed - _samplesAtAdvance,
    });
  }

  void _emitAdvanceDecision({
    required String fromRef,
    required String? toRef,
    required String action,
    required String reason,
    required int wordPosition,
    required int totalWords,
    required double coverage,
    required int completionTarget,
    required bool finalWord,
    required bool advanceOk,
    required bool earlyAdvanceOk,
    required double? margin,
  }) {
    _emit('advance_decision', {
      'from_ref': fromRef,
      'to_ref': toRef,
      'action': action,
      'reason': reason,
      'word_position': wordPosition,
      'total_words': totalWords,
      'coverage': coverage,
      'completion_target': completionTarget,
      'final_word': finalWord,
      'advance_ok': advanceOk,
      'early_advance_ok': earlyAdvanceOk,
      'margin': margin == null ? null : _finiteOrNull(margin),
      'normal_margin': _config.advanceRelativeMargin,
      'strict_margin': _config.advanceFlushStrictMargin,
    });
  }

  static double? _finiteOrNull(double value) =>
      value.isFinite ? _round3(value) : null;

  static double _round2(double value) => (value * 100).round() / 100;

  static double _round3(double value) => (value * 1000).round() / 1000;
}

// ---------------------------------------------------------------------------
// Free functions
// ---------------------------------------------------------------------------

Float32List _concat(Float32List a, Float32List b) {
  final result = Float32List(a.length + b.length);
  result.setRange(0, a.length, a);
  result.setRange(a.length, result.length, b);
  return result;
}

Float32List _tail(Float32List source, int keep) {
  if (keep >= source.length) return source;
  // Copy rather than view: a view would keep the whole 30 s buffer alive.
  final result = Float32List(keep);
  result.setRange(0, keep, source, source.length - keep);
  return result;
}

bool _isSilence(Float32List audio, double threshold) {
  if (audio.isEmpty) return true;
  var sumSq = 0.0;
  for (var i = 0; i < audio.length; i++) {
    sumSq += audio[i] * audio[i];
  }
  return math.sqrt(sumSq / audio.length) < threshold;
}

bool _wordsMatch(String a, String b, {double threshold = 0.7}) {
  if (a == b) return true;
  if (a.length <= 2 || b.length <= 2) return false;
  return similarityRatio(a, b) >= threshold;
}

/// Greedily walks the recognized words along the verse, allowing each match to
/// skip up to [lookahead] verse words so a missed or slurred word does not
/// derail the alignment.
_AlignResult _alignPosition(
  List<String> recognizedWords,
  List<String> verseWordList, {
  int startFrom = 0,
  int lookahead = 5,
}) {
  if (recognizedWords.isEmpty || verseWordList.isEmpty) {
    return const _AlignResult(0, []);
  }

  final matchedIndices = <int>[];
  var versePtr = startFrom;

  for (final recognized in recognizedWords) {
    if (versePtr >= verseWordList.length) break;
    final limit = math.min(versePtr + lookahead, verseWordList.length);
    for (var j = versePtr; j < limit; j++) {
      if (_wordsMatch(recognized, verseWordList[j])) {
        matchedIndices.add(j);
        versePtr = j + 1;
        break;
      }
    }
  }

  if (matchedIndices.isNotEmpty) {
    return _AlignResult(matchedIndices.last + 1, matchedIndices);
  }
  return _AlignResult(startFrom, const []);
}

/// A queued advance is only confirmed when the fresh audio genuinely looks
/// like the *start* of the next verse, not an echo of its middle.
bool _hasStrongPendingPrefixEvidence(List<int> matchedIndices, int totalWords) {
  if (matchedIndices.isEmpty) return false;
  final first = matchedIndices.first;
  final last = matchedIndices.last;
  if (totalWords <= 3) return first == 0;
  return first <= 1 && (matchedIndices.length >= 2 || last >= 2);
}

/// Accumulates per-cycle candidates and resolves the most coherent verse path
/// through the whole utterance once the reciter stops.
class _StreamingHypothesis {
  final List<List<VerseCandidate>> _cycles = [];
  final List<FinalSequenceVerse> _committed = [];

  void observeCandidates(VerseCandidateEvent event) {
    if (event.candidates.isEmpty) return;
    _cycles.add(event.candidates.take(5).toList());
    if (_cycles.length > 80) _cycles.removeAt(0);
  }

  void observeCommit(VerseMatchEvent event) {
    final verse = FinalSequenceVerse(
      surah: event.surah,
      ayah: event.ayah,
      confidence: event.confidence,
    );
    if (!_committed.any((e) => _isSameRef(e, verse))) _committed.add(verse);
  }

  FinalSequenceEvent? finalize() {
    final path = _bestPath();
    final verses = path.isNotEmpty ? path : _committed;
    if (verses.isEmpty) return null;

    final deduped = <FinalSequenceVerse>[];
    for (final verse in verses) {
      if (!deduped.any((e) => _isSameRef(e, verse))) deduped.add(verse);
    }

    final confidence =
        deduped.fold<double>(0, (sum, v) => sum + v.confidence) / deduped.length;
    return FinalSequenceEvent(
      verses: deduped,
      confidence: (confidence * 100).round() / 100,
    );
  }

  void reset() {
    _cycles.clear();
    _committed.clear();
  }

  /// Viterbi over the per-cycle candidate lattice, scoring transitions so
  /// sequential recitation beats a chain of unrelated high-confidence hits.
  List<FinalSequenceVerse> _bestPath() {
    if (_cycles.isEmpty) return const [];

    var previous = <({
      VerseCandidate candidate,
      double score,
      List<FinalSequenceVerse> verses
    })>[];

    for (final cycle in _cycles) {
      final current = <({
        VerseCandidate candidate,
        double score,
        List<FinalSequenceVerse> verses
      })>[];

      for (final candidate in cycle) {
        final expanded = _expandCandidate(candidate);
        if (previous.isEmpty) {
          current.add(
            (candidate: candidate, score: candidate.confidence, verses: expanded),
          );
          continue;
        }

        var bestPrev = 0;
        var bestScore = double.negativeInfinity;
        for (var i = 0; i < previous.length; i++) {
          final score = previous[i].score +
              candidate.confidence +
              _transitionScore(previous[i].candidate, candidate);
          if (score > bestScore) {
            bestScore = score;
            bestPrev = i;
          }
        }
        current.add((
          candidate: candidate,
          score: bestScore,
          verses: [...previous[bestPrev].verses, ...expanded],
        ));
      }
      previous = current;
    }

    if (previous.isEmpty) return const [];
    return previous.reduce((a, b) => b.score > a.score ? b : a).verses;
  }

  static List<FinalSequenceVerse> _expandCandidate(VerseCandidate candidate) {
    final end = (candidate.ayahEnd != null && candidate.ayahEnd! > candidate.ayah)
        ? candidate.ayahEnd!
        : candidate.ayah;
    return [
      for (var ayah = candidate.ayah; ayah <= end; ayah++)
        FinalSequenceVerse(
          surah: candidate.surah,
          ayah: ayah,
          confidence: candidate.confidence,
        ),
    ];
  }

  static double _transitionScore(VerseCandidate prev, VerseCandidate next) {
    if (prev.surah != next.surah) {
      return next.confidence >= 0.85 ? _surahJumpHighConfidence : _surahJump;
    }
    final prevEnd = (prev.ayahEnd != null && prev.ayahEnd! > prev.ayah)
        ? prev.ayahEnd!
        : prev.ayah;
    final delta = next.ayah - prevEnd;
    if (delta == 0) return _sameAyah;
    if (delta == 1) return _nextAyah;
    if (delta > 1 && delta <= 3) return _smallForwardPerAyah * delta;
    if (delta < 0) return _backward;
    return _farForward;
  }

  static bool _isSameRef(FinalSequenceVerse a, FinalSequenceVerse b) =>
      a.surah == b.surah && a.ayah == b.ayah;
}
