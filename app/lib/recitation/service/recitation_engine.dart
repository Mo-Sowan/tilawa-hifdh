import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'package:tilawa/recitation/data/model_manager.dart';
import 'package:tilawa/recitation/data/quran_corpus.dart';
import 'package:tilawa/recitation/engine/recitation_types.dart';
import 'package:tilawa/recitation/service/recitation_engine_io.dart'
    if (dart.library.js_interop) 'package:tilawa/recitation/service/recitation_engine_web.dart' as impl;

/// Lifecycle of the offline recogniser.
enum EngineState { idle, preparing, ready, listening, failed, unsupported }

class EngineStatus {
  const EngineStatus({required this.state, this.message, this.progress});

  final EngineState state;
  final String? message;
  final double? progress;

  bool get isReady =>
      state == EngineState.ready || state == EngineState.listening;
}

/// Runs the offline recitation pipeline and surfaces its events.
///
/// Mobile and desktop run it on a worker isolate — inference is CPU-bound for
/// hundreds of milliseconds at a time and would otherwise stutter the
/// follow-along highlight. The web build runs the same pipeline directly.
abstract class RecitationEngine {
  factory RecitationEngine({ModelManager? modelManager}) =>
      impl.createRecitationEngine(modelManager: modelManager);

  Stream<RecitationEvent> get events;

  Stream<EngineStatus> get status;

  EngineStatus get currentStatus;

  ModelManager get modelManager;

  bool get isReady;

  /// Loads the corpus and model and gets the pipeline running.
  /// Safe to call repeatedly; concurrent callers await the same startup.
  Future<void> start();

  /// Feeds one chunk of 16 kHz mono audio.
  void feed(Float32List samples);

  /// Restricts matching to [surah], or the whole Quran when null.
  void setActiveSurah(int? surah);

  void setConfig(StreamingConfig config);

  /// Clears session state so the next audio starts a fresh utterance.
  void resetSession();

  void markListening(bool listening);

  Future<void> dispose();
}

/// Status plumbing and model preparation shared by both implementations.
abstract class RecitationEngineBase implements RecitationEngine {
  RecitationEngineBase({ModelManager? modelManager})
      : modelManager = modelManager ?? ModelManager();

  @override
  final ModelManager modelManager;

  final StreamController<RecitationEvent> eventController =
      StreamController<RecitationEvent>.broadcast();
  final StreamController<EngineStatus> statusController =
      StreamController<EngineStatus>.broadcast();

  EngineStatus _currentStatus = const EngineStatus(state: EngineState.idle);

  @override
  Stream<RecitationEvent> get events => eventController.stream;

  @override
  Stream<EngineStatus> get status => statusController.stream;

  @override
  EngineStatus get currentStatus => _currentStatus;

  @override
  bool get isReady => _currentStatus.isReady;

  @override
  void markListening(bool listening) {
    if (!_currentStatus.isReady) return;
    publish(
      EngineStatus(
        state: listening ? EngineState.listening : EngineState.ready,
      ),
    );
  }

  void publish(EngineStatus status) {
    _currentStatus = status;
    if (!statusController.isClosed) statusController.add(status);
  }

  /// Downloads and verifies the model, reporting progress as it goes.
  Future<String> prepareModel() async {
    publish(
      const EngineStatus(
        state: EngineState.preparing,
        message: 'Preparing the recitation model',
      ),
    );

    final expectedSha = await readExpectedModelSha();
    final subscription = modelManager.status.listen((status) {
      if (status.stage == ModelStage.downloading) {
        publish(
          EngineStatus(
            state: EngineState.preparing,
            message: 'Downloading the recitation model',
            progress: status.fraction,
          ),
        );
      } else if (status.stage == ModelStage.verifying) {
        publish(
          const EngineStatus(
            state: EngineState.preparing,
            message: 'Verifying the recitation model',
          ),
        );
      }
    });

    try {
      return await modelManager.ensureModel(expectedSha256: expectedSha);
    } finally {
      await subscription.cancel();
    }
  }

  /// Reads only the export manifest — parsing the whole corpus here would
  /// duplicate work the pipeline is about to do anyway.
  static Future<String> readExpectedModelSha() async {
    final metadata = jsonDecode(
      await rootBundle.loadString(CorpusAssets.metadata),
    ) as Map<String, dynamic>;
    return (metadata['onnx_sha256'] as String?) ?? '';
  }

  Future<void> closeControllers() async {
    await eventController.close();
    await statusController.close();
  }
}
