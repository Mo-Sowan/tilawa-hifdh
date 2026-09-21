import 'dart:typed_data';

import 'package:tilawa/features/recitation/data/quran_corpus.dart';
import 'package:tilawa/features/recitation/engine/quran_db.dart';
import 'package:tilawa/features/recitation/engine/recitation_tracker.dart';
import 'package:tilawa/features/recitation/engine/recitation_types.dart';
import 'package:tilawa/features/recitation/service/onnx_asr_session.dart';

/// Corpus + inference session + tracker, wired together.
///
/// Deliberately free of isolates and platform channels so the same object can
/// run inside a worker isolate on mobile and desktop, or directly on the main
/// isolate in the browser.
class RecitationPipeline {
  RecitationPipeline._(this._corpus, this._session, this._tracker);

  final QuranCorpus _corpus;
  final OnnxAsrSession _session;
  final RecitationTracker _tracker;

  int? _activeSurah;

  /// Loads the corpus, opens a session against the model at [modelPath] and
  /// builds a tracker over both.
  static Future<RecitationPipeline> create(
    String modelPath, {
    StreamingConfig? config,
    DiagnosticSink? onDiagnostic,
  }) async {
    final corpus = await QuranCorpus.load();
    final session = await OnnxAsrSession.open(modelPath);

    late final RecitationPipeline pipeline;

    Future<TranscribeResult> transcribe(Float32List audio) async {
      final evidence = await session.run(audio, blankId: corpus.blankId);
      final greedy = corpus.decoder.decode(
        evidence.logProbs,
        evidence.timeSteps,
        evidence.vocabSize,
      );
      final champion = corpus.db.bestJointMatch(
        greedy.text,
        surahFilter: pipeline._activeSurah,
      );

      // Only a high-scoring joint match is trusted enough to bypass the
      // tracker's own candidate ranking.
      final trusted =
          (champion != null && champion.score >= 0.8) ? champion : null;

      return TranscribeResult(
        text: greedy.text,
        tokenIds: greedy.tokenIds,
        acoustic: evidence,
        championMatch: trusted,
      );
    }

    final tracker = RecitationTracker(
      corpus.db,
      transcribe,
      config: config ?? StreamingConfig.defaults,
      onDiagnostic: onDiagnostic,
    );

    return pipeline = RecitationPipeline._(corpus, session, tracker);
  }

  QuranDB get db => _corpus.db;

  /// Feeds one chunk of 16 kHz mono audio.
  Future<List<RecitationEvent>> feed(Float32List samples) =>
      _tracker.feed(samples);

  /// Restricts matching to [surah], or the whole Quran when null.
  void setActiveSurah(int? surah) {
    _activeSurah = surah;
    _tracker.setActiveSurah(surah);
  }

  void setConfig(StreamingConfig config) => _tracker.setConfig(config);

  void reset() => _tracker.reset();

  Future<void> close() => _session.close();
}
