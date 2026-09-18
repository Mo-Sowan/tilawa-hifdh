import 'dart:async';

import 'package:http/http.dart' as http;

import 'package:tilawa/recitation/data/model_manager.dart';

ModelManager createModelManager({
  http.Client? httpClient,
  String? downloadUrl,
}) {
  return BundledModelManager();
}

/// Resolves the model already emitted by Flutter's web asset bundler.
///
/// Downloading and hashing the 88 MB file in Dart would duplicate the browser's
/// asset request and hold another full copy in memory. The build manifest owns
/// the asset integrity here; ONNX Runtime streams the same URL into WASM.
class BundledModelManager implements ModelManager {
  final StreamController<ModelStatus> _statusController =
      StreamController<ModelStatus>.broadcast();

  ModelStatus _status = const ModelStatus(stage: ModelStage.idle);

  @override
  Stream<ModelStatus> get status => _statusController.stream;

  @override
  ModelStatus get currentStatus => _status;

  @override
  Future<String> ensureModel({required String expectedSha256}) async {
    _publish(
      const ModelStatus(
        stage: ModelStage.checking,
        message: 'Opening the bundled recitation model',
      ),
    );
    _publish(const ModelStatus(stage: ModelStage.ready));
    return ModelManager.bundledAsset;
  }

  @override
  Future<bool> isModelCached() async => true;

  /// The browser asset is part of the application build and cannot be removed
  /// independently. Resetting the status still lets callers reopen the session.
  @override
  Future<void> clearCache() async {
    _publish(const ModelStatus(stage: ModelStage.idle));
  }

  @override
  void dispose() {
    _statusController.close();
  }

  void _publish(ModelStatus status) {
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }
}
