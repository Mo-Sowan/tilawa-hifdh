import 'dart:async';

import 'package:http/http.dart' as http;

import 'package:tilawa/recitation/data/model_manager.dart';

ModelManager createModelManager({
  http.Client? httpClient,
  String? downloadUrl,
}) {
  return UnsupportedModelManager();
}

/// Reports that on-device recognition is unavailable in a browser.
///
/// This is not a packaging gap that bundling the model would fix. The export's
/// quantized convolutions use the `ConvInteger` operator, which ONNX Runtime
/// Web's WASM backend does not implement — verified by loading the model
/// through both `onnxruntime-web` 1.21 and the full 1.23 bundle, each of which
/// fails session creation with:
///
///     Could not find an implementation for ConvInteger(10) node with name
///     '/encoder/pre_encode/conv/conv.0/Conv_quant'
///
/// The native runtimes on Android, iOS, Windows, macOS and Linux do implement
/// it, so recognition works there. If ONNX Runtime Web gains the kernel, or the
/// model is re-exported without int8 convolutions, this class is the only thing
/// that needs to change.
class UnsupportedModelManager implements ModelManager {
  static const String _reason =
      'On-device recitation needs the ConvInteger operator, which ONNX Runtime '
      'Web does not implement. Use the Android, iOS or desktop build to try the '
      'recogniser.';

  final StreamController<ModelStatus> _statusController =
      StreamController<ModelStatus>.broadcast();

  ModelStatus _status = const ModelStatus(stage: ModelStage.idle);

  @override
  Stream<ModelStatus> get status => _statusController.stream;

  @override
  ModelStatus get currentStatus => _status;

  @override
  Future<String> ensureModel({required String expectedSha256}) async {
    _publish(const ModelStatus(stage: ModelStage.failed, message: _reason));
    throw const ModelUnavailableException(_reason);
  }

  @override
  Future<bool> isModelCached() async => false;

  /// Nothing is cached, so there is nothing to clear.
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
