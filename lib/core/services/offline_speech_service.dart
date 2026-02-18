import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

part 'offline_speech_service.g.dart';

@Riverpod(keepAlive: true)
OfflineSpeechService offlineSpeechService(Ref ref) {
  final service = OfflineSpeechService();
  ref.onDispose(() => service.dispose());
  return service;
}

class OfflineSpeechService {
  final StreamController<String> _logController =
      StreamController<String>.broadcast();
  final StreamController<double> _soundLevelController =
      StreamController<double>.broadcast();

  Stream<String> get logStream => _logController.stream;
  Stream<double> get soundLevelStream => _soundLevelController.stream;

  final AudioRecorder _audioRecorder = AudioRecorder();
  sherpa.OfflineRecognizer? _recognizer;

  bool _isInitialized = false;
  bool _isListening = false;
  bool _stopRequested = false;

  static const int _sampleRate = 16000;
  String? _modelDir;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;

  void _log(String message) {
    _logController.add(message);
  }

  Future<String> get _modelsPath async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/sherpa_models';
  }

  Future<bool> isModelReady() async {
    try {
      final modelsPath = await _modelsPath;
      final dir = Directory('$modelsPath/whisper-tiny');

      if (!await dir.exists()) return false;

      final tokensFile = File('${dir.path}/tokens.txt');
      final encoderFile = File('${dir.path}/tiny-encoder.onnx');
      final decoderFile = File('${dir.path}/tiny-decoder.onnx');
      final vadFile = File('$modelsPath/silero_vad.onnx');

      return await tokensFile.exists() &&
          await encoderFile.exists() &&
          await decoderFile.exists() &&
          await vadFile.exists();
    } catch (e) {
      return false;
    }
  }

  Future<bool> copyAssetsToFs() async {
    try {
      final modelsPath = await _modelsPath;
      final whisperDir = Directory('$modelsPath/whisper-tiny');

      if (await whisperDir.exists()) {
        await whisperDir.delete(recursive: true);
      }
      await whisperDir.create(recursive: true);

      _log('Copying model from assets...');

      // Copy whisper model files
      final files = [
        ('whisper-tiny/tokens.txt', 'tokens.txt'),
        ('whisper-tiny/tiny-encoder.onnx', 'tiny-encoder.onnx'),
        ('whisper-tiny/tiny-decoder.onnx', 'tiny-decoder.onnx'),
        ('silero_vad.onnx', '../silero_vad.onnx'),
      ];

      for (final (assetPath, targetName) in files) {
        _log('Copying $targetName...');
        final data = await rootBundle.load('assets/models/$assetPath');
        final bytes = data.buffer.asUint8List();
        final file = File('${whisperDir.path}/$targetName');
        await file.writeAsBytes(bytes);
        _log('OK: $targetName (${bytes.length} bytes)');
      }

      _log('Model copied successfully');
      return true;
    } catch (e) {
      _log('Copy error: $e');
      return false;
    }
  }

  Future<bool> init() async {
    try {
      _log('Initializing...');

      final modelsPath = await _modelsPath;
      _modelDir = '$modelsPath/whisper-tiny';

      // Copy from assets if not already done
      if (!await isModelReady()) {
        _log('Extracting model from assets...');
        final copied = await copyAssetsToFs();
        if (!copied) {
          _log('Failed to extract model');
          return false;
        }
      }

      sherpa.initBindings();

      final config = sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          whisper: sherpa.OfflineWhisperModelConfig(
            encoder: '$_modelDir/tiny-encoder.onnx',
            decoder: '$_modelDir/tiny-decoder.onnx',
            language: 'ar',
            task: 'transcribe',
          ),
          tokens: '$_modelDir/tokens.txt',
          numThreads: 2,
          debug: false,
          provider: 'cpu',
        ),
        decodingMethod: 'greedy_search',
      );

      _recognizer = sherpa.OfflineRecognizer(config);

      _isInitialized = true;
      _log('Init OK');
      return true;
    } catch (e) {
      _log('Init error: $e');
      _isInitialized = false;
      return false;
    }
  }

  Future<void> listen({
    required Function(String) onResult,
    Function()? onCancel,
  }) async {
    if (!_isInitialized || _recognizer == null) {
      _log('Not initialized');
      return;
    }

    _stopRequested = false;
    _isListening = true;
    _log('Listening...');

    try {
      if (!await _audioRecorder.hasPermission()) {
        _log('No mic permission');
        return;
      }

      final stream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
      );

      // Process in 2-second chunks
      final chunkSize = _sampleRate * 2;
      final buffer = <double>[];

      await for (final chunk in stream) {
        if (_stopRequested) break;

        final samples = _pcm16ToFloat32(chunk);
        final level = _calculateLevel(samples);
        _soundLevelController.add(level);

        // Add to buffer
        buffer.addAll(samples);

        // Process when buffer is full
        if (buffer.length >= chunkSize) {
          final toProcess = Float32List.fromList(buffer.sublist(0, chunkSize));
          buffer.removeRange(0, chunkSize);
          _processChunk(toProcess, onResult);
        }
      }

      // Process remaining
      if (buffer.isNotEmpty) {
        _processChunk(Float32List.fromList(buffer), onResult);
      }

      await _audioRecorder.stop();
    } catch (e) {
      _log('Listen error: $e');
    } finally {
      _isListening = false;
      _log('Stopped');
      onCancel?.call();
    }
  }

  Float32List _pcm16ToFloat32(List<int> bytes) {
    final samples = Float32List(bytes.length ~/ 2);
    for (var i = 0; i < samples.length; i++) {
      final sample = (bytes[i * 2 + 1] << 8) | (bytes[i * 2] & 0xFF);
      samples[i] = sample.toDouble() / 32768.0;
    }
    return samples;
  }

  double _calculateLevel(Float32List samples) {
    if (samples.isEmpty) return 0;
    var sum = 0.0;
    for (final s in samples) {
      sum += s * s;
    }
    return (sum / samples.length).clamp(0.0, 1.0);
  }

  void _processChunk(Float32List samples, Function(String) onResult) {
    if (_recognizer == null) return;

    try {
      final stream = _recognizer!.createStream();
      stream.acceptWaveform(samples: samples, sampleRate: _sampleRate);
      _recognizer!.decode(stream);
      final result = _recognizer!.getResult(stream);
      stream.free();

      final text = result.text.trim();
      _log('Result: "$text" (${samples.length} samples)');
      if (text.isNotEmpty) {
        onResult(text);
      }
    } catch (e) {
      _log('Process error: $e');
    }
  }

  Future<void> stop() async {
    _stopRequested = true;
    _log('Stopping...');

    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }
  }

  void dispose() {
    _recognizer?.free();
    _logController.close();
    _soundLevelController.close();
  }
}
