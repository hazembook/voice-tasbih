# Voice Tasbih App - Development Prompt

## Project Overview
Build a Flutter app for counting Dhikr (Islamic remembrances) using voice recognition. The app works **100% offline** with Arabic speech recognition using Vosk.

## Current Repository State
- **Branch**: `feature/offline-speech`
- **Location**: `/home/hazem/git/hazembook/projects-test/voice-tasbih`
- **Remote**: Not pushed (local only)
- **Status**: Working - all 4 dhikr types detected correctly

## Architecture
```
lib/
├── core/services/
│   ├── speech_service.dart           # Old Google speech_to_text (reference)
│   └── vosk_speech_service.dart      # Vosk offline ASR (WORKING)
├── features/counter/
│   ├── application/counter_notifier.dart
│   ├── domain/models/counter_state.dart
│   └── presentation/counter_screen.dart
└── main.dart

assets/models/
└── vosk-model-ar-mgb2-0.4.zip       # 333MB Arabic Vosk model
```

## Implemented Features
- **Dhikr Selection**: سبحان الله, الحمد لله, الله أكبر, لا إله إلا الله
- **Target Selection**: 33, 100, 1000
- **Voice Detection**: Grammar-based recognition with partial result counting
- **Real-time Feedback**: Haptic + visual animation on each count
- **Debug Console**: On-screen logs for troubleshooting
- **Continuous Listening**: No restart sounds, works until target reached

## Technical Implementation

### Grammar-Based Recognition
Uses Vosk's grammar constraint with 19 phrases to bias recognition toward dhikr:
- Full phrases and phonetic variants
- Special handling for "La ilaha illallah" (harder to recognize)

### Partial Result Counting
- Counts dhikr immediately on partial results (faster response)
- Tracks accumulated count to avoid double-counting
- Final results logged but don't add extra counts

### Counting Logic
- `سبحان الله`: Direct string matching
- `الحمد لله`: Direct string matching
- `الله أكبر`: Direct string matching with alef variants
- `لا إله إلا الله`: Special non-overlapping scan for variants

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

## Android Configuration
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

```pro
# android/app/proguard-rules.pro
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
```

## Known Limitations
1. **Model size**: 333MB Arabic model increases APK size
2. **La ilaha illallah**: Occasionally misrecognized as similar-sounding phrases
3. **VAD delay**: Final results wait for silence (~1-2s), but partials count immediately

## Future Improvements
1. **Smaller model**: Try smaller Arabic model if available
2. **Sound effects**: Add optional audio feedback on count
3. **History**: Track daily/weekly dhikr counts
4. **Custom targets**: Allow user-defined target numbers
5. **Multiple dhikr session**: Count different dhikr in one session
6. **Better La ilaha detection**: Add more phonetic variants
7. **Whisper (همس) detection**:
   - Restore sound level indicator to show microphone input level
   - Add sensitivity slider in settings to adjust detection threshold
   - Platform channel to Android AudioManager for manual gain control
   - Test if current Vosk model can detect whisper-level recitation
   - Consider noise suppression toggle for quiet environments
   - Implementation options:
     - Use `flutter_audio_capture` or `record` package to get raw PCM amplitude
     - Calculate RMS (Root Mean Square) of audio buffer for level display
     - Visual indicator: animated bar above mic button that pulses with voice
     - Settings: Low/Medium/High sensitivity presets

## Key Files to Read
- `lib/core/services/vosk_speech_service.dart` - Vosk implementation
- `lib/features/counter/presentation/counter_screen.dart` - UI + counting logic
- `lib/features/counter/application/counter_notifier.dart` - State management
- `lib/features/counter/domain/models/counter_state.dart` - Data model
