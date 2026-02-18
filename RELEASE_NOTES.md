# الذاكر (Al-Dhakir) v0.1.1

> «أَيَعْجِزُ أَحَدُكُمْ أَنْ يَكْسِبَ كُلَّ يَوْمٍ أَلْفَ حَسَنَةٍ؟» قَالَ: «يُسَبِّحُ مِائَةَ تَسْبِيحَةٍ، فَيُكْتَبُ لَهُ أَلْفُ حَسَنَةٍ» [صحيح مسلم]

## الذاكر (Al-Dhakir) - The Rememberer

A Flutter app for counting Dhikr using offline Arabic voice recognition.

## Features

- **Dhikr Selection**: سبحان الله، الحمد لله، الله أكبر، لا إله إلا الله
- **Target Selection**: 33, 100, 1000 counts
- **100% Offline**: Works without internet using Vosk Arabic model
- **Real-time Counting**: Immediate feedback on each detection
- **Haptic Feedback**: Vibration on successful detection
- **RTL Arabic UI**: Full right-to-left support

## Downloads

| File | Architecture | Size | Device Type |
|------|--------------|------|-------------|
| `app-arm64-v8a-release.apk` | arm64-v8a | ~356 MB | Modern phones (recommended) |
| `app-armeabi-v7a-release.apk` | armeabi-v7a | ~353 MB | Older 32-bit phones |

## Known Issues

- **La ilaha illallah** (لا إله إلا الله) occasionally misrecognized
- **APK size** is large (~355MB) due to embedded Vosk Arabic model
- **Noise sensitivity**: Background noise may cause confusion

## Requirements

- Android 5.0+ (API 21)
- Microphone permission
- ~400MB storage

## License

Waqf General Public License 2.0
