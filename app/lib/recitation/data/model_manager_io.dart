import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:tilawa/recitation/data/model_manager.dart';

ModelManager createModelManager({
  http.Client? httpClient,
  String? downloadUrl,
}) {
  return FileModelManager(httpClient: httpClient, downloadUrl: downloadUrl);
}

/// Downloads the model once and caches it in the app's support directory.
///
/// The model is far past a sensible app-bundle budget, so it is fetched on
/// first use. Dropping the same file into `assets/model/` makes the app
/// self-contained instead; that path is preferred when present.
class FileModelManager implements ModelManager {
  FileModelManager({
    http.Client? httpClient,
    String? downloadUrl,
    String fileName = ModelManager.defaultFileName,
  })  : _httpClient = httpClient ?? http.Client(),
        _downloadUrl = downloadUrl ?? ModelManager.defaultDownloadUrl,
        _fileName = fileName;

  final http.Client _httpClient;
  final String _downloadUrl;
  final String _fileName;

  final StreamController<ModelStatus> _statusController =
      StreamController<ModelStatus>.broadcast();

  ModelStatus _status = const ModelStatus(stage: ModelStage.idle);

  @override
  Stream<ModelStatus> get status => _statusController.stream;

  @override
  ModelStatus get currentStatus => _status;

  @override
  Future<String> ensureModel({required String expectedSha256}) async {
    _publish(const ModelStatus(stage: ModelStage.checking));

    final target = File(await _targetPath());

    if (await target.exists()) {
      if (expectedSha256.isEmpty ||
          await _sha256OfFile(target) == expectedSha256) {
        _publish(const ModelStatus(stage: ModelStage.ready));
        return target.path;
      }
      debugPrint('Cached model failed checksum; re-fetching.');
      await target.delete();
    }

    if (await _copyBundledAsset(target)) {
      _publish(const ModelStatus(stage: ModelStage.ready));
      return target.path;
    }

    await _download(target, expectedSha256);
    _publish(const ModelStatus(stage: ModelStage.ready));
    return target.path;
  }

  @override
  Future<bool> isModelCached() async => File(await _targetPath()).exists();

  @override
  Future<void> clearCache() async {
    final target = File(await _targetPath());
    if (await target.exists()) await target.delete();
    _publish(const ModelStatus(stage: ModelStage.idle));
  }

  @override
  void dispose() {
    _httpClient.close();
    _statusController.close();
  }

  Future<String> _targetPath() async {
    final directory = await getApplicationSupportDirectory();
    final modelDirectory = Directory('${directory.path}/models');
    if (!await modelDirectory.exists()) {
      await modelDirectory.create(recursive: true);
    }
    return '${modelDirectory.path}/$_fileName';
  }

  Future<bool> _copyBundledAsset(File target) async {
    try {
      final data = await rootBundle.load(ModelManager.bundledAsset);
      await target.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return true;
    } catch (_) {
      // Not bundled in this build — fall through to the network. The catch is
      // broad because rootBundle signals a missing asset with a FlutterError,
      // which is an Error rather than an Exception.
      return false;
    }
  }

  Future<void> _download(File target, String expectedSha256) async {
    _publish(const ModelStatus(stage: ModelStage.downloading));

    final partial = File('${target.path}.part');
    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(_downloadUrl));
      final response = await _httpClient.send(request);
      if (response.statusCode != 200) {
        throw ModelPreparationException(
          'Model download failed with HTTP ${response.statusCode}.',
        );
      }

      final total = response.contentLength ?? 0;
      var received = 0;
      sink = partial.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        _publish(
          ModelStatus(
            stage: ModelStage.downloading,
            receivedBytes: received,
            totalBytes: total,
          ),
        );
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (expectedSha256.isNotEmpty) {
        _publish(const ModelStatus(stage: ModelStage.verifying));
        if (await _sha256OfFile(partial) != expectedSha256) {
          await partial.delete();
          throw const ModelPreparationException(
            'Downloaded model failed checksum verification.',
          );
        }
      }

      await partial.rename(target.path);
    } on ModelPreparationException catch (error) {
      _publish(ModelStatus(stage: ModelStage.failed, message: error.message));
      rethrow;
    } on Exception catch (error) {
      await sink?.close();
      if (await partial.exists()) await partial.delete();
      _publish(ModelStatus(stage: ModelStage.failed, message: '$error'));
      throw ModelPreparationException('Model download failed: $error');
    }
  }

  /// Hashes in chunks — the file is far too large to hold in memory twice.
  static Future<String> _sha256OfFile(File file) async {
    final digest = await file.openRead().transform(sha256).first;
    return digest.toString();
  }

  void _publish(ModelStatus status) {
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }
}
