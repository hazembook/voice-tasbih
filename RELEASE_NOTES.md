# ذاكر (Dhakir) v0.1.1 - Branding Update

> «أَيَعْجِزُ أَحَدُكُمْ أَنْ يَكْسِبَ كُلَّ يَوْمٍ أَلْفَ حَسَنَةٍ؟» قَالَ: «يُسَبِّحُ مِائَةَ تَسْبِيحَةٍ، فَيُكْتَبُ لَهُ أَلْفُ حَسَنَةٍ» [صحيح مسلم]

## Changes

- App renamed to **ذاكر** (Dhakir - the one who remembers Allah)
- New custom app icon
- Package name updated to `com.hazembook.dhakir`

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
| `app-arm64-v8a-release.apk` | arm64-v8a | ~340 MB | Modern phones (recommended) |
| `app-armeabi-v7a-release.apk` | armeabi-v7a | ~337 MB | Older 32-bit phones |

## Known Issues

- **La ilaha illallah** (لا إله إلا الله) occasionally misrecognized due to phonetic complexity
- **APK size** is large (~340MB) due to embedded Vosk Arabic model
- **Noise sensitivity**: Background noise or nearby voices may cause recognition confusion

## Requirements

- Android 5.0+ (API 21)
- Microphone permission
- ~400MB storage

## License

Waqf General Public License 2.0
