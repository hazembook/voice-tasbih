import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vosk_flutter_service/vosk_flutter.dart' as vosk;

part 'vosk_speech_service.g.dart';

@Riverpod(keepAlive: true)
VoskSpeechService voskSpeechService(Ref ref) {
  final service = VoskSpeechService();
  ref.onDispose(() => service.dispose());
  return service;
}

class VoskSpeechService {
  final StreamController<String> _logController =
      StreamController<String>.broadcast();
  final StreamController<double> _soundLevelController =
      StreamController<double>.broadcast();

  final vosk.VoskFlutterPlugin _vosk = vosk.VoskFlutterPlugin.instance();
  vosk.Recognizer? _recognizer;
  vosk.SpeechService? _voskSpeechService;

  bool _isInitialized = false;
  bool _isListening = false;
  String? _modelPath;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;

  Stream<String> get logStream => _logController.stream;
  Stream<double> get soundLevelStream => _soundLevelController.stream;

  void _log(String message) {
    _logController.add(message);
  }

  Future<String> get modelPath async {
    if (_modelPath != null) return _modelPath!;
    final appDir = await getApplicationDocumentsDirectory();
    _modelPath = '${appDir.path}/vosk-model-ar-mgb2-0.4';
    return _modelPath!;
  }

  Future<bool> isModelReady() async {
    try {
      final path = await modelPath;
      return Directory(path).exists();
    } catch (_) {
      return false;
    }
  }

  Future<bool> copyModelFromAssets() async {
    try {
      _log('Loading model from assets...');
      final path = await vosk.ModelLoader().loadFromAssets(
        'assets/models/vosk-model-ar-mgb2-0.4.zip',
      );
      _log('Model loaded to: $path');
      return true;
    } catch (e) {
      _log('Model load error: $e');
      return false;
    }
  }

  Future<bool> init() async {
    try {
      _log('Initializing Vosk...');

      if (!await isModelReady()) {
        if (!await copyModelFromAssets()) {
          _log('Failed to load model');
          return false;
        }
      }

      _log('Creating recognizer...');
      final path = await modelPath;
      final model = await _vosk.createModel(path);

      _recognizer = await _vosk.createRecognizer(
        model: model,
        sampleRate: 16000,
      );

      _log('Creating speech service...');
      _voskSpeechService = await _vosk.initSpeechService(_recognizer!);

      _isInitialized = true;
      _log('Vosk initialized');
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
    if (!_isInitialized || _voskSpeechService == null) {
      _log('Not initialized');
      return;
    }

    _isListening = true;
    _log('Listening...');

    try {
      _voskSpeechService!.onPartial().listen((partial) {
        if (partial.isNotEmpty) {
          _log('Partial: "$partial"');
          onResult(partial);
        }
      });

      _voskSpeechService!.onResult().listen((result) {
        if (result.isNotEmpty) {
          _log('Result: "$result"');
          onResult(result);
        }
      });

      await _voskSpeechService!.start();
    } catch (e) {
      _log('Listen error: $e');
    } finally {
      _isListening = false;
      _log('Stopped');
      onCancel?.call();
    }
  }

  Future<void> stop() async {
    if (_voskSpeechService == null) return;

    try {
      _log('Stopping...');
      await _voskSpeechService!.stop();
      _isListening = false;
    } catch (e) {
      _log('Stop error: $e');
    }
  }

  void dispose() {
    _logController.close();
    _soundLevelController.close();
  }
}
