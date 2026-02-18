import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:speech_to_text/speech_to_text.dart';

part 'speech_service.g.dart';

@Riverpod(keepAlive: true)
SpeechService speechService(Ref ref) {
  final service = SpeechService();
  ref.onDispose(() => service.dispose());
  return service;
}

class SpeechService {
  final SpeechToText _speech = SpeechToText();
  final StreamController<String> _logController =
      StreamController<String>.broadcast();

  Stream<String> get logStream => _logController.stream;

  bool _isInitialized = false;
  bool _isListening = false;
  Function(String)? _onResultCallback;
  Function()? _onCancelCallback;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;

  void _log(String message) {
    _logController.add(message);
  }

  void _handleStop() {
    if (_isListening) {
      _isListening = false;
      _onCancelCallback?.call();
      _onResultCallback = null;
      _onCancelCallback = null;
    }
  }

  Future<bool> init() async {
    try {
      _log('Requesting microphone permission...');
      final permissionStatus = await Permission.microphone.request();

      if (!permissionStatus.isGranted) {
        _log('ERROR: Microphone permission DENIED');
        return false;
      }
      _log('Permission granted');

      _log('Initializing speech recognition...');
      _isInitialized = await _speech.initialize(
        onError: (error) {
          _log('ERROR: ${error.errorMsg} (permanent: ${error.permanent})');
          _handleStop();
        },
        onStatus: (status) {
          _log('Status: $status');
          if (status == 'done' || status == 'notListening') {
            _handleStop();
          }
        },
      );

      if (_isInitialized) {
        _log('Speech init SUCCESS');
        final locales = await _speech.locales();
        final arabicLocales = locales
            .where((l) => l.localeId.startsWith('ar'))
            .toList();
        _log(
          'Arabic locales: ${arabicLocales.map((l) => '${l.localeId} (${l.name})').join(', ')}',
        );
      } else {
        _log('ERROR: Speech init FAILED');
      }

      return _isInitialized;
    } catch (e) {
      _log('INIT ERROR: $e');
      return false;
    }
  }

  Future<void> listen({
    required Function(String) onResult,
    Function()? onCancel,
    String localeId = 'ar-SA',
  }) async {
    if (!_isInitialized) {
      _log('ERROR: Not initialized. Call init() first.');
      return;
    }

    if (_isListening) {
      _log('Already listening, stopping first...');
      await stop();
    }

    try {
      _log('Starting listen (locale: $localeId)');
      _isListening = true;
      _onResultCallback = onResult;
      _onCancelCallback = onCancel;

      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords;
          if (words.isNotEmpty) {
            _log('Result: "$words" (final: ${result.finalResult})');
            _onResultCallback?.call(words);
          }
        },
        listenFor: const Duration(minutes: 10),
        pauseFor: const Duration(seconds: 10),
        partialResults: true,
        cancelOnError: true,
        localeId: localeId,
      );
    } catch (e) {
      _log('LISTEN ERROR: $e');
      _handleStop();
    }
  }

  Future<void> stop() async {
    if (!_isListening) return;

    try {
      _log('Stopping...');
      await _speech.stop();
      _handleStop();
      _log('Stopped');
    } catch (e) {
      _log('STOP ERROR: $e');
    }
  }

  void dispose() {
    _logController.close();
  }
}
