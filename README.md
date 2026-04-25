# DeenLab

DeenLab is a mobile Islamic utility app that combines daily worship tools with an Android-native Machine Learning engine that can automatically silence your phone during salah (nimaz).

## What It Does

At a high level, DeenLab is designed around a simple workflow:

1. **Prayer reminders** fire shortly before salah.
2. A reminder can **start the native Silence of Salah engine** (when enabled).
3. The engine runs **on-device** as an Android foreground service, performs sensor-driven ML inference, and manages its own shutdown when prayer is no longer detected.

The app also includes a set of core tools (Quran, Hadith, Qibla, timings) and a built-in Tool Builder to add more utilities when needed.

## Key Features

- **Prayer Times**: City-based prayer timings with calculation method selection.
- **Prayer Reminders**: 3-minute reminders with per-prayer enable/disable.
- **Silence of Salah (Android)**: Android-native foreground service for ML-driven silent/restore behavior (permission-gated).
- **Qibla Direction**: Compass-driven direction with fallbacks when sensors are unavailable.
- **Quran**: Surah list and reader.
- **Hadith Library**: Local hadith database shipped with the app (`resources/hadith.db`).
- **Sehri & Iftari**: Daily countdowns and monthly fasting calendar.
- **Feature Studio / Tool Builder**: Generate new tool tabs when something you need is not built-in yet.

## Platform Support

- **Android**: Supported (includes the Silence of Salah engine and reminder scheduling).
- **iOS**: The Silence of Salah engine is not implemented on iOS. Other Flutter-only tools may work depending on platform constraints.

## Permissions (Android) and Why They're Needed

Some features require Android permissions/settings for reliability:

- **Location**: Auto-detect city/country for prayer timings and Qibla utilities.
- **Notifications**: Prayer reminders and foreground notifications.
- **Exact alarms**: Reliable reminder timing on modern Android.
- **Do Not Disturb access**: Required to switch silent/restore policy correctly.
- **Battery optimizations**: Improves reliability when running background/foreground tasks.

DeenLab's Prayer Settings screen explains the dependency chain (reminders -> permissions -> engine start from reminders).

## Developer Setup

### Prerequisites

- Flutter SDK (Dart SDK included)
- Android Studio (Android SDK / emulator) or a physical Android device

### Run Locally

```bash
flutter pub get
flutter run
```

### Data Sources

- Prayer timings, Quran, and Qibla direction use network APIs (when available).
- Hadith content is stored locally in `resources/hadith.db`.

## Project Structure (High Level)

- `lib/features/*`: Feature modules (Prayer Times, Quran, Hadith, Qibla, Sehri/Iftari, Feature Studio).
- `lib/app_shell/*`: Tab shell, navigation, and Home dashboard.
- `android/`: Android-specific components, including reminder receivers and the integration channel used by the app.

## Privacy

- **On-device ML inference**: The Silence of Salah engine runs locally on your device.
- **No accounts by default**: DeenLab does not require an account to use the core tools.
- **Location usage**: Location is used to auto-detect city/country for religious utilities and may be stored in app settings/caches for convenience.

## Troubleshooting

- **Quran loads slowly / times out**: Check your internet connection and retry. The app will show an error state instead of crashing.
- **Prayer reminders not firing**: Ensure notifications are allowed, exact alarms are permitted, and battery optimization restrictions are relaxed for DeenLab.
- **Location detection fails**: Enable GPS/location services and grant location permission (or enable it from app settings if permanently denied).

## License

**Proprietary**. All rights reserved.

## Roadmap (Short)

- Improved offline caching and resilience for network-based tools.
- Richer Home widgets and deeper quick actions.
- More Tool Builder templates and better generated-tab management.
- iOS parity planning for non-engine features (engine support would require separate native work).
