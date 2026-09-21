import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'package:tilawa/features/recitation/engine/recitation_types.dart';

/// Microphone capture producing fixed-size 16 kHz mono `Float32List` chunks.
///
/// The recorder emits PCM16 buffers whose size is decided by the platform, so
/// this class re-frames them to the chunk length the tracker's cadence is
/// tuned around.
class AudioCapture {
  AudioCapture({AudioRecorder? recorder, int chunkMs = 150})
      : _recorder = recorder ?? AudioRecorder(),
        _chunkSamples = (sampleRate * chunkMs / 1000).round();

  final AudioRecorder _recorder;
  final int _chunkSamples;

  final StreamController<Float32List> _chunks =
      StreamController<Float32List>.broadcast();

  StreamSubscription<Uint8List>? _subscription;
  final BytesBuilder _carry = BytesBuilder(copy: false);
  bool _recording = false;

  Stream<Float32List> get chunks => _chunks.stream;

  bool get isRecording => _recording;

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Starts capture. Returns false when microphone permission was refused.
  Future<bool> start() async {
    if (_recording) return true;
    if (!await _recorder.hasPermission()) return false;

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        echoCancel: false,
        noiseSuppress: false,
      ),
    );

    _recording = true;
    _subscription = stream.listen(
      _onBytes,
      onError: _chunks.addError,
      cancelOnError: false,
    );
    return true;
  }

  Future<void> stop() async {
    if (!_recording) return;
    _recording = false;
    await _subscription?.cancel();
    _subscription = null;
    await _recorder.stop();
    _flushCarry();
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
    await _chunks.close();
  }

  void _onBytes(Uint8List bytes) {
    _carry.add(bytes);

    // Two bytes per sample. Only whole chunks are emitted, so the tracker sees
    // a steady cadence no matter how the platform sizes its buffers.
    final chunkBytes = _chunkSamples * 2;
    if (_carry.length < chunkBytes) return;

    final buffered = _carry.takeBytes();
    var offset = 0;
    while (buffered.length - offset >= chunkBytes) {
      _chunks.add(_toFloat32(buffered, offset, chunkBytes));
      offset += chunkBytes;
    }
    if (offset < buffered.length) {
      _carry.add(Uint8List.sublistView(buffered, offset));
    }
  }

  void _flushCarry() {
    final remaining = _carry.takeBytes();
    if (remaining.length < 2) return;
    final usable = remaining.length - (remaining.length % 2);
    _chunks.add(_toFloat32(remaining, 0, usable));
  }

  /// Little-endian signed PCM16 to normalized float samples.
  static Float32List _toFloat32(Uint8List bytes, int offset, int length) {
    final sampleCount = length ~/ 2;
    final view = ByteData.sublistView(bytes, offset, offset + length);
    final samples = Float32List(sampleCount);
    for (var i = 0; i < sampleCount; i++) {
      samples[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }
}
