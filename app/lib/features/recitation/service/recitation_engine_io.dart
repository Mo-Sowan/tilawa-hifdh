import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show RootIsolateToken;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show BackgroundIsolateBinaryMessenger;

import 'package:tilawa/features/recitation/data/model_manager.dart';
import 'package:tilawa/features/recitation/engine/recitation_types.dart';
import 'package:tilawa/features/recitation/service/recitation_engine.dart';
import 'package:tilawa/features/recitation/service/recitation_pipeline.dart';

RecitationEngine createRecitationEngine({ModelManager? modelManager}) =>
    IsolateRecitationEngine(modelManager: modelManager);

/// Runs the pipeline on a worker isolate.
class IsolateRecitationEngine extends RecitationEngineBase {
  IsolateRecitationEngine({super.modelManager});

  Isolate? _isolate;
  SendPort? _commands;
  ReceivePort? _fromIsolate;
  Completer<void>? _readyCompleter;

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

      await _spawn(modelPath);
      publish(const EngineStatus(state: EngineState.ready));
      completer.complete();
    } catch (error, stackTrace) {
      debugPrint('Recitation engine failed to start: $error\n$stackTrace');
      publish(EngineStatus(state: EngineState.failed, message: '$error'));
      completer.completeError(error, stackTrace);
    } finally {
      _readyCompleter = null;
    }
    return completer.future;
  }

  Future<void> _spawn(String modelPath) async {
    final receivePort = ReceivePort();
    _fromIsolate = receivePort;

    final token = RootIsolateToken.instance;
    if (token == null) {
      throw StateError('Recitation engine must be started from the UI isolate.');
    }

    final handshake = Completer<SendPort>();
    final startup = Completer<void>();

    receivePort.listen((message) {
      if (message is SendPort) {
        handshake.complete(message);
      } else if (message is _EngineReady) {
        if (!startup.isCompleted) startup.complete();
      } else if (message is _EngineFailure) {
        if (!startup.isCompleted) {
          startup.completeError(StateError(message.message));
        } else {
          publish(
            EngineStatus(state: EngineState.failed, message: message.message),
          );
        }
      } else if (message is RecitationEvent) {
        eventController.add(message);
      }
    });

    _isolate = await Isolate.spawn(
      _engineIsolateEntry,
      _EngineBootstrap(
        replyTo: receivePort.sendPort,
        rootIsolateToken: token,
        modelPath: modelPath,
      ),
      debugName: 'tilawa-recitation',
    );

    _commands = await handshake.future;
    await startup.future;
  }

  @override
  void feed(Float32List samples) => _commands?.send(_AudioChunk(samples));

  @override
  void setActiveSurah(int? surah) => _commands?.send(_SetActiveSurah(surah));

  @override
  void setConfig(StreamingConfig config) => _commands?.send(_SetConfig(config));

  @override
  void resetSession() => _commands?.send(const _ResetSession());

  @override
  Future<void> dispose() async {
    _commands?.send(const _Shutdown());
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    _isolate = null;
    _fromIsolate?.close();
    _fromIsolate = null;
    _commands = null;
    modelManager.dispose();
    await closeControllers();
  }
}

// ---------------------------------------------------------------------------
// Isolate protocol
// ---------------------------------------------------------------------------

class _EngineBootstrap {
  const _EngineBootstrap({
    required this.replyTo,
    required this.rootIsolateToken,
    required this.modelPath,
  });

  final SendPort replyTo;
  final RootIsolateToken rootIsolateToken;
  final String modelPath;
}

class _AudioChunk {
  const _AudioChunk(this.samples);

  final Float32List samples;
}

class _SetActiveSurah {
  const _SetActiveSurah(this.surah);

  final int? surah;
}

class _SetConfig {
  const _SetConfig(this.config);

  final StreamingConfig config;
}

class _ResetSession {
  const _ResetSession();
}

class _Shutdown {
  const _Shutdown();
}

class _EngineReady {
  const _EngineReady();
}

class _EngineFailure {
  const _EngineFailure(this.message);

  final String message;
}

/// Worker isolate: owns the pipeline for its lifetime.
Future<void> _engineIsolateEntry(_EngineBootstrap bootstrap) async {
  // Required before any platform channel (asset loading, ONNX Runtime) is
  // used from a background isolate.
  BackgroundIsolateBinaryMessenger.ensureInitialized(
    bootstrap.rootIsolateToken,
  );

  final commandPort = ReceivePort();
  bootstrap.replyTo.send(commandPort.sendPort);

  late final RecitationPipeline pipeline;
  try {
    pipeline = await RecitationPipeline.create(bootstrap.modelPath);
  } catch (error, stackTrace) {
    debugPrint('Recitation isolate init failed: $error\n$stackTrace');
    bootstrap.replyTo.send(_EngineFailure('$error'));
    commandPort.close();
    return;
  }

  bootstrap.replyTo.send(const _EngineReady());

  // Audio arrives faster than inference completes; queue it, but never run two
  // passes at once.
  var processing = false;
  final pending = <Float32List>[];

  Future<void> drain() async {
    if (processing) return;
    processing = true;
    try {
      while (pending.isNotEmpty) {
        final events = await pipeline.feed(pending.removeAt(0));
        for (final event in events) {
          bootstrap.replyTo.send(event);
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Recitation cycle failed: $error\n$stackTrace');
      bootstrap.replyTo.send(_EngineFailure('$error'));
    } finally {
      processing = false;
    }
  }

  await for (final message in commandPort) {
    switch (message) {
      case _AudioChunk(:final samples):
        pending.add(samples);
        unawaited(drain());
      case _SetActiveSurah(:final surah):
        pipeline.setActiveSurah(surah);
      case _SetConfig(:final config):
        pipeline.setConfig(config);
      case _ResetSession():
        pending.clear();
        pipeline.reset();
      case _Shutdown():
        await pipeline.close();
        commandPort.close();
        return;
    }
  }
}
