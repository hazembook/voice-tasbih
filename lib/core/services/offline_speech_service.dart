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
  sherpa.VoiceActivityDetector? _vad;

  bool _isInitialized = false;
  bool _isListening = false;
  bool _stopRequested = false;

  static const int _sampleRate = 16000;
  String? _modelDir;
  String? _modelsPath;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;

  void _log(String message) {
    _logController.add(message);
  }

  Future<String> get modelsPath async {
    if (_modelsPath != null) return _modelsPath!;
    final appDir = await getApplicationDocumentsDirectory();
    _modelsPath = '${appDir.path}/sherpa_models';
    return _modelsPath!;
  }

  Future<bool> isModelReady() async {
    try {
      final path = await modelsPath;
      final dir = Directory('$path/whisper-tiny');

      if (!await dir.exists()) return false;

      return await File('${dir.path}/tokens.txt').exists() &&
          await File('${dir.path}/tiny-encoder.onnx').exists() &&
          await File('${dir.path}/tiny-decoder.onnx').exists() &&
          await File('$path/silero_vad.onnx').exists();
    } catch (e) {
      return false;
    }
  }

  Future<bool> copyAssetsToFs() async {
    try {
      final path = await modelsPath;
      final whisperDir = Directory('$path/whisper-tiny');

      if (await whisperDir.exists()) {
        await whisperDir.delete(recursive: true);
      }
      await whisperDir.create(recursive: true);

      _log('Copying model from assets...');

      final files = [
        ('whisper-tiny/tokens.txt', 'tokens.txt'),
        ('whisper-tiny/tiny-encoder.onnx', 'tiny-encoder.onnx'),
        ('whisper-tiny/tiny-decoder.onnx', 'tiny-decoder.onnx'),
        ('silero_vad.onnx', '../silero_vad.onnx'),
      ];

      for (final (assetPath, targetName) in files) {
        final data = await rootBundle.load('assets/models/$assetPath');
        final bytes = data.buffer.asUint8List();
        final file = File('${whisperDir.path}/$targetName');
        await file.writeAsBytes(bytes);
      }

      _log('Model copied');
      return true;
    } catch (e) {
      _log('Copy error: $e');
      return false;
    }
  }

  Future<bool> init() async {
    try {
      _log('Initializing...');

      final path = await modelsPath;
      _modelDir = '$path/whisper-tiny';

      if (!await isModelReady()) {
        _log('Extracting model...');
        if (!await copyAssetsToFs()) {
          _log('Failed to extract');
          return false;
        }
      }

      sherpa.initBindings();

      // Create Whisper recognizer
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

      // Create VAD
      final vadConfig = sherpa.VadModelConfig(
        sileroVad: sherpa.SileroVadModelConfig(
          model: '$path/silero_vad.onnx',
          threshold: 0.35,
          minSilenceDuration: 0.8,
          minSpeechDuration: 0.2,
          maxSpeechDuration: 30.0,
        ),
        sampleRate: _sampleRate,
        numThreads: 2,
        debug: false,
      );

      _vad = sherpa.VoiceActivityDetector(
        config: vadConfig,
        bufferSizeInSeconds: 30.0,
      );

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
    if (!_isInitialized || _recognizer == null || _vad == null) {
      _log('Not initialized');
      return;
    }

    _stopRequested = false;
    _isListening = true;
    _vad?.reset();
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

      await for (final chunk in stream) {
        if (_stopRequested) break;

        final samples = _pcm16ToFloat32(chunk);
        final level = _calculateLevel(samples);
        _soundLevelController.add(level);

        // Feed to VAD
        _vad!.acceptWaveform(samples);

        // Process any completed speech segments
        while (!_vad!.isEmpty()) {
          final segment = _vad!.front();
          if (segment.samples.isNotEmpty) {
            _processSegment(segment.samples, onResult);
          }
          _vad!.pop();
        }
      }

      // Flush remaining
      _vad?.flush();
      while (_vad != null && !_vad!.isEmpty()) {
        final segment = _vad!.front();
        if (segment.samples.isNotEmpty) {
          _processSegment(segment.samples, onResult);
        }
        _vad!.pop();
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

  void _processSegment(Float32List samples, Function(String) onResult) {
    if (_recognizer == null) return;

    try {
      final stream = _recognizer!.createStream();
      stream.acceptWaveform(samples: samples, sampleRate: _sampleRate);
      _recognizer!.decode(stream);
      final result = _recognizer!.getResult(stream);
      stream.free();

      final text = result.text.trim();
      if (text.isNotEmpty) {
        _log('Heard: "$text"');
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
    _vad?.free();
    _logController.close();
    _soundLevelController.close();
  }
}
