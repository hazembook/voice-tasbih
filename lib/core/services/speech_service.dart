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
  final StreamController<double> _soundLevelController =
      StreamController<double>.broadcast();

  Stream<String> get logStream => _logController.stream;
  Stream<double> get soundLevelStream => _soundLevelController.stream;

  bool _isInitialized = false;
  bool _isListening = false;
  bool _userRequestedStop = false;
  bool _isRestarting = false;
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
      _isRestarting = false;
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
          if (error.errorMsg == 'error_busy') {
            return;
          }
          if (!error.permanent) {
            _scheduleRestart();
          } else {
            _log('ERROR: ${error.errorMsg}');
            _handleStop();
          }
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (!_userRequestedStop) {
              _scheduleRestart();
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

  void _scheduleRestart() {
    if (_isRestarting || _userRequestedStop) return;
    _isRestarting = true;
    Future.delayed(const Duration(milliseconds: 300), _restartListening);
  }

  Future<void> _restartListening() async {
    if (_userRequestedStop || _onResultCallback == null) {
      _isRestarting = false;
      return;
    }

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
        onSoundLevelChange: (level) {
          _soundLevelController.add(level);
        },
        localeId: _localeId,
      );
    } catch (e) {
      _handleStop();
    } finally {
      _isRestarting = false;
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
        onSoundLevelChange: (level) {
          _soundLevelController.add(level);
        },
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
    _soundLevelController.close();
  }
}
