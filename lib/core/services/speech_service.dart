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
  bool _userRequestedStop = false;
  String _localeId = 'ar-SA';
  Function(String, bool)? _onResultCallback;
  Function()? _onCancelCallback;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;

  void _log(String message) {
    _logController.add(message);
  }

  void _handleStop({bool userRequested = false}) {
    if (_isListening) {
      _isListening = false;
      if (userRequested || _userRequestedStop) {
        _onCancelCallback?.call();
        _onResultCallback = null;
        _onCancelCallback = null;
        _userRequestedStop = false;
      }
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
          _log('ERROR: ${error.errorMsg}');
          if (!error.permanent) {
            _restartListening();
          } else {
            _handleStop();
          }
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (!_userRequestedStop) {
              _restartListening();
            } else {
              _handleStop();
            }
          }
        },
      );

      if (_isInitialized) {
        _log('Speech init: SUCCESS');
      } else {
        _log('ERROR: Speech init FAILED');
      }

      return _isInitialized;
    } catch (e) {
      _log('INIT ERROR: $e');
      return false;
    }
  }

  Future<void> _restartListening() async {
    if (_userRequestedStop) return;

    await Future.delayed(const Duration(milliseconds: 100));

    if (_userRequestedStop || _onResultCallback == null) return;

    try {
      _isListening = true;
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords;
          if (words.isNotEmpty) {
            _onResultCallback?.call(words, result.finalResult);
          }
        },
        listenFor: const Duration(minutes: 30),
        pauseFor: const Duration(seconds: 30),
        partialResults: true,
        cancelOnError: false,
        localeId: _localeId,
      );
    } catch (e) {
      _log('RESTART ERROR: $e');
      _handleStop();
    }
  }

  Future<void> listen({
    required Function(String, bool) onResult,
    Function()? onCancel,
    String localeId = 'ar-SA',
  }) async {
    if (!_isInitialized) {
      _log('ERROR: Not initialized');
      return;
    }

    _localeId = localeId;
    _userRequestedStop = false;
    _onResultCallback = onResult;
    _onCancelCallback = onCancel;
    _isListening = true;

    _log('Listening started');

    try {
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords;
          if (words.isNotEmpty) {
            _onResultCallback?.call(words, result.finalResult);
          }
        },
        listenFor: const Duration(minutes: 30),
        pauseFor: const Duration(seconds: 30),
        partialResults: true,
        cancelOnError: false,
        localeId: _localeId,
      );
    } catch (e) {
      _log('LISTEN ERROR: $e');
      _handleStop();
    }
  }

  Future<void> stop() async {
    _userRequestedStop = true;
    _log('Stopping...');

    try {
      await _speech.stop();
      _handleStop(userRequested: true);
    } catch (e) {
      _log('STOP ERROR: $e');
    }
  }

  void dispose() {
    _logController.close();
  }
}
