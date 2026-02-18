# Voice Tasbih App - Development Prompt

## Project Overview
Build a Flutter app for counting Dhikr (Islamic remembrances) using voice recognition. The app should work **100% offline** with Arabic speech recognition.

## Current Repository State
- **Branch**: `feature/offline-speech`
- **Location**: `/home/hazem/git/hazembook/projects-test/voice-tasbih`
- **Remote**: Not pushed (local only)

## Architecture
```
lib/
├── core/services/
│   ├── speech_service.dart           # Old Google speech_to_text (reference)
│   └── vosk_speech_service.dart      # Current Vosk implementation (BROKEN)
├── features/counter/
│   ├── application/counter_notifier.dart
│   ├── domain/models/counter_state.dart
│   └── presentation/counter_screen.dart
└── main.dart

assets/models/
└── vosk-model-ar-mgb2-0.4.zip       # 333MB Arabic Vosk model
```

## Current Issue
**Vosk model fails to load:**
```
[07:43:59] Model loaded to: /data/user/0/.../models/vosk-model-ar-mgb2-0.4
[07:43:59] Creating recognizer...
[07:43:59] Init error: Failed to create a model
```

The model extracts but `_vosk.createModel(path)` fails.

## Dependencies (pubspec.yaml)
```yaml
dependencies:
  flutter_riverpod: ^3.2.1
  riverpod_annotation: ^4.0.2
  freezed_annotation: ^3.0.0
  permission_handler: ^12.0.1
  intl: ^0.20.2
  path_provider: ^2.1.5
  vosk_flutter_service: ^0.0.6

dev_dependencies:
  build_runner: ^2.11.1
  riverpod_generator: ^4.0.3
  freezed: ^3.0.0
```

## The Task

### 1. Debug Vosk Model Loading Issue
The model zip extracts correctly but `createModel()` fails. Possible causes:
- Model expects specific directory structure
- Path issue after extraction
- Native library not finding model files

**Reference repos:**
- https://github.com/Dhia-Bechattaoui/vosk-flutter-service (official fork with Android fixes)
- Check the example app in this repo for correct usage

### 2. If Vosk Cannot Be Fixed
Research and implement alternatives:

**Option A: Return to speech_to_text with improvements**
- Use Google's speech_to_text (already in pubspec as `speech_to_text: ^7.3.0`)
- Problem: Creates "beep" sound on restart
- Solution: Use Android platform channel to mute AudioManager

**Option B: Try sherpa-onnx streaming model**
- Already tried Whisper (hallucinates on silence)
- Look for streaming zipformer model with Arabic support

### 3. Required App Features
- **Dhikr Selection**: Subhan Allah, Alhamdulillah, Allahu Akbar, La ilaha illallah
- **Target Selection**: 33, 100, 1000
- **Voice Detection**: Must detect Arabic phrases accurately
- **Real-time Feedback**: Haptic + visual on detection
- **Debug Console**: On-screen logs (user cannot use adb)
- **Continuous Listening**: No restart sounds, works until target reached

### 4. Android Configuration
Already configured in `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

May need proguard rules in `android/app/proguard-rules.pro`:
```pro
-keep class com.sun.jna.* { *; }
-keepclassmembers class * extends com.sun.jna.* { public *; }
```

## Commands
```bash
# Build
flutter build apk --debug

# Test
flutter test

# Code generation
dart run build_runner build --delete-conflicting-outputs

# Check dependency conflicts
flutter pub outdated
flutter pub upgrade --major-versions
```

## Success Criteria
1. App initializes speech recognition without errors
2. User taps mic → listening starts (no beep sound)
3. User says "سبحان الله" → counter increments
4. Works with normal recitation speed
5. No false detections on silence
6. Continuous listening until user stops or target reached

## Next Session Tasks
1. **Debug Vosk** - Check model directory structure after extraction
2. **Try alternative approach** if Vosk doesn't work
3. **Ensure no restart sounds** - critical requirement
4. **Test with real Arabic speech**

## Key Files to Read
- `lib/core/services/vosk_speech_service.dart` - Current broken implementation
- `lib/features/counter/presentation/counter_screen.dart` - UI
- `lib/features/counter/application/counter_notifier.dart` - State management
- `lib/features/counter/domain/models/counter_state.dart` - Data model
