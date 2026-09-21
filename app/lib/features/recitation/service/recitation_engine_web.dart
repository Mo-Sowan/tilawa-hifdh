import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:tilawa/features/recitation/data/model_manager.dart';
import 'package:tilawa/features/recitation/engine/recitation_types.dart';
import 'package:tilawa/features/recitation/service/recitation_engine.dart';
import 'package:tilawa/features/recitation/service/recitation_pipeline.dart';

RecitationEngine createRecitationEngine({ModelManager? modelManager}) =>
    WebRecitationEngine(modelManager: modelManager);

/// Runs the pipeline directly, since the browser has no `dart:isolate`.
///
/// Inference still yields between chunks, so the UI keeps painting, but a long
/// pass is felt more than it is on mobile. Recognition is only available when
/// the model has been bundled into `assets/model/` — see
/// [ModelManager] for why the web build cannot cache an 88 MB download.
class WebRecitationEngine extends RecitationEngineBase {
  WebRecitationEngine({super.modelManager});

  RecitationPipeline? _pipeline;
  Completer<void>? _readyCompleter;

  int? _pendingActiveSurah;
  StreamingConfig? _pendingConfig;

  bool _processing = false;
  final List<Float32List> _queue = [];

  @override
  Future<void> start() async {
    final inFlight = _readyCompleter;
    if (inFlight != null) return inFlight.future;
    if (currentStatus.isReady) return;

    final completer = Completer<void>();
    _readyCompleter = completer;

    try {
      final modelPath = await prepareModel();

      publish(
        const EngineStatus(
          state: EngineState.preparing,
          message: 'Loading the Quran index',
        ),
      );

      final pipeline = await RecitationPipeline.create(modelPath);
      if (_pendingConfig != null) pipeline.setConfig(_pendingConfig!);
      pipeline.setActiveSurah(_pendingActiveSurah);
      _pipeline = pipeline;

      publish(const EngineStatus(state: EngineState.ready));
      completer.complete();
    } on ModelUnavailableException catch (error) {
      // Not a failure to fix — the build simply has no model to load.
      publish(
        EngineStatus(state: EngineState.unsupported, message: error.message),
      );
      completer.completeError(error);
    } catch (error, stackTrace) {
      debugPrint('Recitation engine failed to start: $error\n$stackTrace');
      publish(EngineStatus(state: EngineState.failed, message: '$error'));
      completer.completeError(error, stackTrace);
    } finally {
      _readyCompleter = null;
    }
    return completer.future;
  }

  @override
  void feed(Float32List samples) {
    if (_pipeline == null) return;
    _queue.add(samples);
    unawaited(_drain());
  }

  Future<void> _drain() async {
    final pipeline = _pipeline;
    if (_processing || pipeline == null) return;
    _processing = true;
    try {
      while (_queue.isNotEmpty) {
        for (final event in await pipeline.feed(_queue.removeAt(0))) {
          if (!eventController.isClosed) eventController.add(event);
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Recitation cycle failed: $error\n$stackTrace');
      publish(EngineStatus(state: EngineState.failed, message: '$error'));
    } finally {
      _processing = false;
    }
  }

  @override
  void setActiveSurah(int? surah) {
    _pendingActiveSurah = surah;
    _pipeline?.setActiveSurah(surah);
  }

  @override
  void setConfig(StreamingConfig config) {
    _pendingConfig = config;
    _pipeline?.setConfig(config);
  }

  @override
  void resetSession() {
    _queue.clear();
    _pipeline?.reset();
  }

  @override
  Future<void> dispose() async {
    await _pipeline?.close();
    _pipeline = null;
    _queue.clear();
    modelManager.dispose();
    await closeControllers();
  }
}
