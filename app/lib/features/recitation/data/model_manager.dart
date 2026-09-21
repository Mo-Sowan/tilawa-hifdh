import 'dart:async';

import 'package:http/http.dart' as http;

import 'package:tilawa/features/recitation/data/model_manager_io.dart'
    if (dart.library.js_interop) 'package:tilawa/features/recitation/data/model_manager_web.dart' as impl;

/// Progress of preparing the on-device model.
enum ModelStage { idle, checking, downloading, verifying, ready, failed }

class ModelStatus {
  const ModelStatus({
    required this.stage,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.message,
  });

  final ModelStage stage;
  final int receivedBytes;
  final int totalBytes;
  final String? message;

  double? get fraction =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : null;

  bool get isReady => stage == ModelStage.ready;
}

/// The model could not be prepared, but the situation is recoverable — a failed
/// download, a checksum mismatch.
class ModelPreparationException implements Exception {
  const ModelPreparationException(this.message);

  final String message;

  @override
  String toString() => 'ModelPreparationException: $message';
}

/// This build has no way to obtain the model at all, so there is nothing to
/// retry. Callers should present [message] rather than an error.
class ModelUnavailableException implements Exception {
  const ModelUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'ModelUnavailableException: $message';
}

/// Resolves a local reference to the recitation model, fetching it if needed.
///
/// On mobile and desktop the ~88 MB file is downloaded once, checksum-verified
/// and cached on disk. In the browser there is nowhere to cache it, so only a
/// bundled asset is used.
abstract class ModelManager {
  factory ModelManager({http.Client? httpClient, String? downloadUrl}) =>
      impl.createModelManager(
        httpClient: httpClient,
        downloadUrl: downloadUrl,
      );

  static const String defaultFileName = 'fastconformer_full_mixed.onnx';
  static const String bundledAsset = 'assets/model/$defaultFileName';

  /// Overridable at build time:
  /// `--dart-define=MODEL_URL=https://your.cdn/fastconformer_full_mixed.onnx`
  static const String defaultDownloadUrl = String.fromEnvironment(
    'MODEL_URL',
    defaultValue:
        'https://github.com/yazinsai/tilawa/releases/download/v0.2.0/fastconformer_full_mixed.onnx',
  );

  Stream<ModelStatus> get status;

  ModelStatus get currentStatus;

  /// A path or asset key the inference session can open.
  ///
  /// [expectedSha256] comes from the bundled `export_metadata.json`; pass an
  /// empty string to skip verification (not recommended).
  Future<String> ensureModel({required String expectedSha256});

  /// True when the model is already available without a download.
  Future<bool> isModelCached();

  /// Removes any cached copy. The next [ensureModel] fetches it again.
  Future<void> clearCache();

  void dispose();
}
