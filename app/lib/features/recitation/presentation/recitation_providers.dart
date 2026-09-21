import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tilawa/data/repositories/recitation_session_repository.dart';
import 'package:tilawa/presentation/providers/revision_providers.dart';
import 'package:tilawa/features/recitation/engine/recitation_types.dart';
import 'package:tilawa/features/recitation/service/audio_capture.dart';
import 'package:tilawa/features/recitation/service/recitation_engine.dart';

/// The offline recogniser. One instance for the life of the app: starting it
/// loads ~90 MB of model and index.
final recitationEngineProvider = Provider<RecitationEngine>((ref) {
  final engine = RecitationEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

final recitationEngineStatusProvider = StreamProvider<EngineStatus>((ref) {
  final engine = ref.watch(recitationEngineProvider);
  return engine.status;
});

/// Stores completed sessions locally and mirrors them to the API.
final recitationSessionRepositoryProvider =
    Provider<RecitationSessionRepository>((ref) {
  return RecitationSessionRepository(ref.watch(apiClientProvider));
});

final audioCaptureProvider = Provider<AudioCapture>((ref) {
  final capture = AudioCapture(
    chunkMs: StreamingConfig.defaults.audioChunkMs,
  );
  ref.onDispose(capture.dispose);
  return capture;
});

/// One verse the reciter has been matched on.
class RecitedVerse {
  const RecitedVerse({
    required this.surah,
    required this.ayah,
    required this.text,
    required this.surahName,
    required this.confidence,
  });

  final int surah;
  final int ayah;
  final String text;
  final String surahName;
  final double confidence;

  String get ref => '$surah:$ayah';
}

/// Live state of a follow-along session.
class RecitationSessionState {
  const RecitationSessionState({
    this.isListening = false,
    this.activeSurah,
    this.current,
    this.covered = const [],
    this.candidates = const [],
    this.wordIndex = 0,
    this.totalWords = 0,
    this.matchedWordIndices = const [],
    this.lastTranscript = '',
    this.startedAt,
    this.error,
  });

  final bool isListening;
  final int? activeSurah;

  /// Verse the tracker currently believes is being recited.
  final RecitedVerse? current;

  /// Every verse committed this session, in order.
  final List<RecitedVerse> covered;

  /// Ranked alternatives while the tracker is still deciding.
  final List<VerseCandidate> candidates;

  final int wordIndex;
  final int totalWords;
  final List<int> matchedWordIndices;

  /// Decoded text that did not clear the match threshold. Useful feedback when
  /// nothing is matching.
  final String lastTranscript;

  final DateTime? startedAt;
  final String? error;

  double get verseProgress =>
      totalWords == 0 ? 0 : (wordIndex / totalWords).clamp(0.0, 1.0);

  Duration get elapsed => startedAt == null
      ? Duration.zero
      : DateTime.now().difference(startedAt!);

  double get averageConfidence => covered.isEmpty
      ? 0
      : covered.fold<double>(0, (sum, v) => sum + v.confidence) / covered.length;

  RecitationSessionState copyWith({
    bool? isListening,
    int? activeSurah,
    bool clearActiveSurah = false,
    RecitedVerse? current,
    List<RecitedVerse>? covered,
    List<VerseCandidate>? candidates,
    int? wordIndex,
    int? totalWords,
    List<int>? matchedWordIndices,
    String? lastTranscript,
    DateTime? startedAt,
    String? error,
    bool clearError = false,
  }) {
    return RecitationSessionState(
      isListening: isListening ?? this.isListening,
      activeSurah: clearActiveSurah ? null : (activeSurah ?? this.activeSurah),
      current: current ?? this.current,
      covered: covered ?? this.covered,
      candidates: candidates ?? this.candidates,
      wordIndex: wordIndex ?? this.wordIndex,
      totalWords: totalWords ?? this.totalWords,
      matchedWordIndices: matchedWordIndices ?? this.matchedWordIndices,
      lastTranscript: lastTranscript ?? this.lastTranscript,
      startedAt: startedAt ?? this.startedAt,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Drives a follow-along session: microphone in, tracker events out.
class RecitationSessionNotifier extends StateNotifier<RecitationSessionState> {
  RecitationSessionNotifier(this._engine, this._capture)
      : super(const RecitationSessionState()) {
    _eventSubscription = _engine.events.listen(_onEvent);
  }

  final RecitationEngine _engine;
  final AudioCapture _capture;

  StreamSubscription<RecitationEvent>? _eventSubscription;
  StreamSubscription? _audioSubscription;

  /// Prepares the model and index without starting the microphone, so the
  /// download happens before the user taps record.
  Future<void> prepare() => _engine.start();

  /// Limits matching to one surah. Null follows the whole Quran.
  void setActiveSurah(int? surah) {
    state = surah == null
        ? state.copyWith(clearActiveSurah: true)
        : state.copyWith(activeSurah: surah);
    _engine.setActiveSurah(surah);
  }

  Future<void> start() async {
    if (state.isListening) return;
    state = state.copyWith(clearError: true);

    try {
      await _engine.start();
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return;
    }

    if (!await _capture.start()) {
      state = state.copyWith(
        error: 'Microphone permission is required to follow your recitation.',
      );
      return;
    }

    _engine.resetSession();
    _engine.setActiveSurah(state.activeSurah);
    _engine.markListening(true);
    _audioSubscription = _capture.chunks.listen(_engine.feed);

    state = RecitationSessionState(
      isListening: true,
      activeSurah: state.activeSurah,
      startedAt: DateTime.now(),
    );
  }

  Future<void> stop() async {
    if (!state.isListening) return;
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _capture.stop();
    _engine.markListening(false);
    state = state.copyWith(isListening: false);
  }

  /// Clears the session but keeps the loaded model.
  Future<void> reset() async {
    await stop();
    _engine.resetSession();
    state = RecitationSessionState(activeSurah: state.activeSurah);
  }

  void _onEvent(RecitationEvent event) {
    switch (event) {
      case VerseMatchEvent():
        final verse = RecitedVerse(
          surah: event.surah,
          ayah: event.ayah,
          text: event.verseText,
          surahName: event.surahName,
          confidence: event.confidence,
        );
        final covered = state.covered.any((v) => v.ref == verse.ref)
            ? state.covered
            : [...state.covered, verse];
        state = state.copyWith(
          current: verse,
          covered: covered,
          candidates: const [],
          wordIndex: 0,
          totalWords: 0,
          matchedWordIndices: const [],
          lastTranscript: '',
        );

      case WordProgressEvent():
        // Ignore progress for a verse the UI has already moved past.
        if (state.current?.ref != '${event.surah}:${event.ayah}') return;
        state = state.copyWith(
          wordIndex: event.wordIndex,
          totalWords: event.totalWords,
          matchedWordIndices: event.matchedIndices,
        );

      case VerseCandidateEvent():
        state = state.copyWith(candidates: event.candidates);

      case RawTranscriptEvent():
        state = state.copyWith(lastTranscript: event.text);

      case FinalSequenceEvent():
        // The committed list already holds these; nothing further to show.
        break;

      case TrackerDiagnostic():
        break;
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _audioSubscription?.cancel();
    super.dispose();
  }
}

final recitationSessionProvider =
    StateNotifierProvider<RecitationSessionNotifier, RecitationSessionState>(
  (ref) {
    return RecitationSessionNotifier(
      ref.watch(recitationEngineProvider),
      ref.watch(audioCaptureProvider),
    );
  },
);
