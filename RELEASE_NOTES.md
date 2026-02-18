# Voice Tasbih v0.1.0 - Vosk Offline ASR

First release with offline Arabic speech recognition for counting Dhikr.

## Features

- **Dhikr Selection**: سبحان الله, الحمد لله, الله أكبر, لا إله إلا الله
- **Target Selection**: 33, 100, 1000 counts
- **100% Offline**: Works without internet using Vosk Arabic model
- **Real-time Counting**: Partial results count immediately for fast response
- **Haptic Feedback**: Vibration on each successful detection
- **Debug Console**: On-screen logs for troubleshooting

## Downloads

| File | Architecture | Size | Device Type |
|------|--------------|------|-------------|
| `app-arm64-v8a-release.apk` | arm64-v8a | ~338 MB | Modern phones (recommended) |
| `app-armeabi-v7a-release.apk` | armeabi-v7a | ~335 MB | Older 32-bit phones |

## Known Issues

- **La ilaha illallah** (لا إله إلا الله) occasionally misrecognized due to phonetic complexity
- **APK size** is large (~335MB) due to embedded Vosk Arabic model

## Requirements

- Android 5.0+ (API 21)
- Microphone permission
- ~400MB storage

## License

Waqf General Public License 2.0
