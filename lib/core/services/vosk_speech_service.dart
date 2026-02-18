import 'dart:async';
import 'dart:convert';

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

  StreamSubscription<String>? _partialSubscription;
  StreamSubscription<String>? _resultSubscription;

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

  String? _extractText(String json, String key) {
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded[key] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _loadModelFromAssets() async {
    try {
      _log('Loading model from assets...');
      final path = await vosk.ModelLoader().loadFromAssets(
        'assets/models/vosk-model-ar-mgb2-0.4.zip',
      );
      _log('Model loaded to: $path');
      _modelPath = path;
      return path;
    } catch (e) {
      _log('Model load error: $e');
      return null;
    }
  }

  Future<bool> init() async {
    try {
      _log('Initializing Vosk...');

      if (_modelPath == null) {
        final path = await _loadModelFromAssets();
        if (path == null) {
          _log('Failed to load model');
          return false;
        }
      }

      _log('Creating recognizer...');
      final model = await _vosk.createModel(_modelPath!);

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
    required Function(String) onPartial,
    required Function(String) onFinal,
    Function()? onCancel,
  }) async {
    if (!_isInitialized || _voskSpeechService == null) {
      _log('Not initialized');
      return;
    }

    _isListening = true;
    _log('Listening...');

    try {
      _partialSubscription = _voskSpeechService!.onPartial().listen((json) {
        final partial = _extractText(json, 'partial');
        if (partial != null && partial.isNotEmpty) {
          onPartial(partial);
        }
      });

      _resultSubscription = _voskSpeechService!.onResult().listen((json) {
        final text = _extractText(json, 'text');
        if (text != null && text.isNotEmpty) {
          _log('Result: "$text"');
          onFinal(text);
        }
      });

      await _voskSpeechService!.start();
    } catch (e) {
      _log('Listen error: $e');
      _isListening = false;
      onCancel?.call();
    }
  }

  Future<void> stop() async {
    if (_voskSpeechService == null) return;

    try {
      _log('Stopping...');
      await _partialSubscription?.cancel();
      await _resultSubscription?.cancel();
      _partialSubscription = null;
      _resultSubscription = null;
      await _voskSpeechService!.stop();
      _isListening = false;
      _log('Stopped');
    } catch (e) {
      _log('Stop error: $e');
    }
  }

  void dispose() {
    _logController.close();
    _soundLevelController.close();
  }
}
