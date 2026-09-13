import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'package:tilawa/recitation/engine/ctc_rescore.dart';

/// Thin wrapper over the ONNX Runtime session for the recitation model.
///
/// The exported graph takes raw 16 kHz mono audio — feature extraction is
/// baked into the model — and returns CTC log-probabilities shaped
/// `[1, timeSteps, vocabSize]`.
class OnnxAsrSession {
  OnnxAsrSession._(this._session, this._audioInputName, this._lengthInputName,
      this._outputName);

  final OrtSession _session;
  final String _audioInputName;
  final String _lengthInputName;
  final String _outputName;

  static const String _defaultAudioInput = 'audio_signal';
  static const String _defaultLengthInput = 'length';
  static const String _assetPrefix = 'assets/';

  /// Opens a session against a model bundled as a Flutter asset.
  ///
  /// The web implementation of the plugin hands the asset key straight to ONNX
  /// Runtime as a URL, but Flutter serves bundled assets under an extra
  /// `assets/` segment — so the key has to be turned into a real URL first, or
  /// the fetch 404s and surfaces as a misleading "failed to load external data
  /// file" error. Native platforms extract the asset to a temp file instead and
  /// want the key as-is.
  static Future<OrtSession> _openBundled(OnnxRuntime runtime, String assetKey) {
    return kIsWeb
        ? runtime.createSession('$_assetPrefix$assetKey')
        : runtime.createSessionFromAsset(assetKey);
  }

  /// Opens a session against the model.
  ///
  /// [modelPath] is either a file on disk (mobile and desktop, where the model
  /// is downloaded and cached) or an `assets/` key (the web build, which can
  /// only use a bundled model).
  static Future<OnnxAsrSession> open(String modelPath) async {
    final runtime = OnnxRuntime();
    final session = modelPath.startsWith(_assetPrefix)
        ? await _openBundled(runtime, modelPath)
        : await runtime.createSession(modelPath);

    final inputs = session.inputNames;
    if (inputs.isEmpty) {
      throw StateError('Recitation model exposes no inputs.');
    }
    final audioInput =
        inputs.contains(_defaultAudioInput) ? _defaultAudioInput : inputs.first;
    final lengthInput = inputs.contains(_defaultLengthInput)
        ? _defaultLengthInput
        : (inputs.length > 1 ? inputs[1] : _defaultLengthInput);

    final outputs = session.outputNames;
    if (outputs.isEmpty) {
      throw StateError('Recitation model exposes no outputs.');
    }

    return OnnxAsrSession._(session, audioInput, lengthInput, outputs.first);
  }

  /// Runs one forward pass over [audio] and returns the raw CTC evidence.
  Future<AcousticEvidence> run(Float32List audio, {required int blankId}) async {
    final audioTensor = await OrtValue.fromList(audio, [1, audio.length]);
    final lengthTensor = await OrtValue.fromList(
      Int64List.fromList([audio.length]),
      [1],
    );

    Map<String, OrtValue>? outputs;
    try {
      outputs = await _session.run({
        _audioInputName: audioTensor,
        _lengthInputName: lengthTensor,
      });

      final output = outputs[_outputName];
      if (output == null) {
        throw StateError('Model produced no "$_outputName" output.');
      }

      final dims = output.shape;
      if (dims.length != 3) {
        throw StateError(
          'Expected [batch, time, vocab] logits, got shape $dims.',
        );
      }
      final timeSteps = dims[1];
      final vocabSize = dims[2];

      final flat = await output.asFlattenedList();
      final logProbs = Float32List(flat.length);
      for (var i = 0; i < flat.length; i++) {
        logProbs[i] = (flat[i] as num).toDouble();
      }

      return AcousticEvidence(
        logProbs: logProbs,
        timeSteps: timeSteps,
        vocabSize: vocabSize,
        blankId: blankId,
      );
    } finally {
      await audioTensor.dispose();
      await lengthTensor.dispose();
      if (outputs != null) {
        for (final value in outputs.values) {
          await value.dispose();
        }
      }
    }
  }

  Future<void> close() => _session.close();
}
