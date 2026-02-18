import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:speech_to_text/speech_to_text.dart';

part 'speech_service.g.dart';

@riverpod
SpeechService speechService(SpeechServiceRef ref) {
  return SpeechService();
}

class SpeechService {
  final SpeechToText _speech = SpeechToText();
  final StreamController<String> _logController =
      StreamController<String>.broadcast();

  Stream<String> get logStream => _logController.stream;

  bool _isInitialized = false;
  bool _isListening = false;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;

  void _log(String message) {
    _logController.add(message);
  }

  Future<bool> init() async {
    try {
      _log('Requesting microphone permission...');
      final permissionStatus = await Permission.microphone.request();

      if (!permissionStatus.isGranted) {
        _log('Error: Microphone permission denied');
        return false;
      }

      _log('Initializing speech recognition...');
      _isInitialized = await _speech.initialize(
        onError: (error) {
          _log('Speech Error: ${error.errorMsg}');
          _isListening = false;
        },
        onStatus: (status) {
          _log('Speech Status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
      );

      if (_isInitialized) {
        _log('Speech recognition initialized successfully');
        final locales = await _speech.locales();
        _log('Available locales: ${locales.map((l) => l.localeId).join(', ')}');
      } else {
        _log('Error: Speech recognition initialization failed');
      }

      return _isInitialized;
    } catch (e) {
      _log('Error during init: $e');
      return false;
    }
  }

  Future<void> listen({
    required Function(String) onResult,
    String localeId = 'ar-SA',
  }) async {
    if (!_isInitialized) {
      _log('Error: Speech not initialized. Call init() first.');
      return;
    }

    if (_isListening) {
      _log('Already listening...');
      return;
    }

    try {
      _log('Starting to listen with locale: $localeId');
      _isListening = true;

      await _speech.listen(
        onResult: (result) {
          _log('Heard: ${result.recognizedWords}');
          onResult(result.recognizedWords);
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        onSoundLevelChange: (level) {
          _log('Sound level: $level');
        },
        localeId: localeId,
      );
    } catch (e) {
      _log('Error during listen: $e');
      _isListening = false;
    }
  }

  Future<void> stop() async {
    if (!_isListening) {
      return;
    }

    try {
      _log('Stopping speech recognition...');
      await _speech.stop();
      _isListening = false;
      _log('Speech recognition stopped');
    } catch (e) {
      _log('Error stopping speech: $e');
    }
  }

  Future<List<LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) {
      _log('Error: Speech not initialized');
      return [];
    }

    try {
      final locales = await _speech.locales();
      return locales;
    } catch (e) {
      _log('Error getting locales: $e');
      return [];
    }
  }

  void dispose() {
    _logController.close();
  }
}
