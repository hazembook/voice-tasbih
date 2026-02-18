import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
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
  sherpa.CircularBuffer? _buffer;

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

  Future<bool> isModelDownloaded() async {
    try {
      final modelsPath = await _modelsPath;
      final dir = Directory('$modelsPath/whisper-tiny');

      if (!await dir.exists()) {
        _log('Model directory not found');
        return false;
      }

      final tokensFile = File('${dir.path}/tokens.txt');
      final encoderFile = File('${dir.path}/tiny-encoder.onnx');
      final decoderFile = File('${dir.path}/tiny-decoder.onnx');
      final vadFile = File('$modelsPath/silero_vad.onnx');

      return await tokensFile.exists() &&
          await encoderFile.exists() &&
          await decoderFile.exists() &&
          await vadFile.exists();
    } catch (e) {
      _log('Check error: $e');
      return false;
    }
  }

  Future<double> downloadModel({
    void Function(String status)? onStatus,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final modelsPath = await _modelsPath;
      final whisperDir = Directory('$modelsPath/whisper-tiny');

      if (await whisperDir.exists()) {
        await whisperDir.delete(recursive: true);
      }
      await whisperDir.create(recursive: true);

      const hfBaseUrl =
          'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main';

      final files = [
        _ModelFile('tokens.txt', '$hfBaseUrl/tokens.txt'),
        _ModelFile('tiny-encoder.onnx', '$hfBaseUrl/tiny-encoder.onnx'),
        _ModelFile('tiny-decoder.onnx', '$hfBaseUrl/tiny-decoder.onnx'),
      ];

      final totalFiles = files.length + 1;
      var completedFiles = 0;

      for (final file in files) {
        onStatus?.call('Downloading ${file.name}...');
        _log('Downloading: ${file.url}');
        final targetFile = File('${whisperDir.path}/${file.name}');
        final success = await _downloadFile(file.url, targetFile, (p) {
          onProgress?.call((completedFiles + p) / totalFiles);
        });
        if (!success) {
          _log('Failed: ${file.name}');
          return -1;
        }
        completedFiles++;
        _log('OK: ${file.name}');
      }

      onStatus?.call('Downloading VAD...');
      const vadUrl =
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx';
      final vadFile = File('$modelsPath/silero_vad.onnx');
      final vadSuccess = await _downloadFile(vadUrl, vadFile, (p) {
        onProgress?.call((completedFiles + p) / totalFiles);
      });
      if (!vadSuccess) {
        _log('Failed: VAD');
        return -1;
      }
      _log('OK: VAD');

      onStatus?.call('Verifying...');
      onProgress?.call(1.0);

      if (!await isModelDownloaded()) {
        _log('Verification failed');
        return -1;
      }

      onStatus?.call('Ready');
      return 1.0;
    } catch (e) {
      _log('Error: $e');
      return -1;
    }
  }

  Future<bool> _downloadFile(
    String url,
    File target,
    void Function(double)? onProgress,
  ) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        _log('HTTP ${response.statusCode}');
        return false;
      }

      final contentLength = response.contentLength ?? 1;
      var downloaded = 0;

      final raf = await target.open(mode: FileMode.writeOnly);
      await for (final chunk in response) {
        await raf.writeFrom(chunk);
        downloaded += chunk.length;
        onProgress?.call(downloaded / contentLength);
      }
      await raf.close();
      return true;
    } catch (e) {
      _log('DL error: $e');
      return false;
    }
  }

  Future<bool> init() async {
    try {
      _log('Initializing...');

      final modelsPath = await _modelsPath;
      _modelDir = '$modelsPath/whisper-tiny';

      if (!await isModelDownloaded()) {
        _log('Model not found');
        return false;
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

      final vadConfig = sherpa.VadModelConfig(
        sileroVad: sherpa.SileroVadModelConfig(
          model: '$modelsPath/silero_vad.onnx',
          threshold: 0.5,
          minSilenceDuration: 0.5,
          minSpeechDuration: 0.3,
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

      _buffer = sherpa.CircularBuffer(capacity: _sampleRate * 30);

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
    _buffer?.reset();
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

        _buffer?.push(samples);
        _vad!.acceptWaveform(samples);

        while (!_vad!.isEmpty()) {
          final segment = _vad!.front();
          if (segment.samples.isNotEmpty) {
            _processSegment(segment.samples, onResult);
          }
          _vad!.pop();
        }
      }

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
    _buffer?.free();
    _logController.close();
    _soundLevelController.close();
  }
}

class _ModelFile {
  final String name;
  final String url;

  const _ModelFile(this.name, this.url);
}
