# Phase 0 — Native scaffold

Parent: [native-android-ios.md](native-android-ios.md)

**Goal:** Android/iOS platform folders exist, web-only imports are isolated so native compiles, Firebase Android app is registered, and the app can launch with email/password auth against emulators.

**Defaults:**
- Application ID / bundle ID: `parkour.spot`
- Both `android/` and `ios/` scaffolded; Phase 0 verifies **Android** only
- Google Sign-In, Maps SDK keys, FCM, deep links, store signing → Phase 1+

## Checklist

- [x] `flutter create . --platforms=android,ios` with `parkour.spot` (renamed from `spot.parkour.app`)
- [x] Isolate `package:web` / `flutter_web_plugins` behind stub/web conditional imports
- [x] Register Firebase Android app `parkour.spot` (`1:999200005209:android:c50362d42802754e926548`)
- [x] Wire `google-services.json` + Gradle Google Services plugin
- [x] Extend `firebase_options.dart` / `AppConfig` with `FIREBASE_APP_ID_ANDROID`
- [x] Emulator host `10.0.2.2` for Android; script `scripts/run_android_with_emulators.sh`
- [x] Web still builds (`flutter build web`)
- [x] Local: `flutter build apk --debug` (requires Android SDK)
- [x] Android AVD created: `parkourspot_api35`
- [x] Local: email login on emulator (fixed `core/duplicate-app`: native Android init uses `google-services.json`; do not pass mismatched dart-define options on mobile)
- [x] App launches and runs on Android emulator (2026-09-05) — Maps/FCM/etc. deferred to Phase 1

**Phase 0 status: complete.**

## What landed

### Platforms

- `android/` and `ios/` trees
- Package / application ID: `parkour.spot`
- Main activity: `android/app/src/main/kotlin/parkour/spot/MainActivity.kt`

### Web isolation pattern

Reuse:

```dart
import 'foo_stub.dart'
    if (dart.library.js_interop) 'foo_web.dart' as impl;
```

Notable new/changed facades:

| Facade | Role |
|--------|------|
| `lib/utils/browser_location.dart` | href, title, reload, meta, service worker ready |
| `lib/utils/path_url_strategy.dart` | `usePathUrlStrategy` web-only |
| `lib/analytics/web_analytics.dart` | stub no-ops on native |
| `lib/services/mobile_detection_service.dart` | `defaultTargetPlatform` on native |
| `lib/services/pwa_install_service.dart` | stub on native |
| `lib/services/web_share_service.dart` | stub → clipboard fallback |
| `lib/screens/admin/device_detection_screen.dart` | stub screen on native |

### Firebase Android

- App ID: `1:999200005209:android:c50362d42802754e926548`
- Local config file (gitignored): `android/app/google-services.json`
- Dart-define: `FIREBASE_APP_ID_ANDROID` (see `env.example`, `.env.emulator`)

### Emulator run (Android)

1. Start emulators: `./scripts/start_emulators.sh`
2. Ensure Android SDK + an AVD / device is available (`flutter doctor`)
3. Run:

```bash
./scripts/run_android_with_emulators.sh emulator-5554
```

Sign in with seed user `user@parkour.spot` / password equal to the email.

## Verification notes (2026-09-05)

| Check | Result |
|-------|--------|
| `flutter analyze lib` | Pass (info-level only) |
| Unit tests (sample) | Pass |
| `flutter build web` | Pass |
| Android toolchain | Pass after cmdline-tools + Temurin JDK 21 (`flutter config --jdk-dir=…`) |
| `flutter build apk --debug` | Pass → `build/app/outputs/flutter-apk/app-debug.apk` |
| Android AVD | Created `parkourspot_api35` (API 35 google_apis arm64) |
| Emulator email login | Pending — start services in two terminals (see below) |

**JDK note:** System Java 26 breaks Gradle (`IllegalArgumentException: 26.0.1`). Use Temurin 21 (already set via `flutter config --jdk-dir`):

```bash
flutter config --jdk-dir="$HOME/Library/Java/JavaVirtualMachines/temurin-21.0.11/Contents/Home"
```

**Emulator email login (two terminals):**

```bash
# Terminal 1
./scripts/start_emulators.sh

# Terminal 2 — after Auth UI is up
flutter emulators --launch parkourspot_api35
# wait until `adb devices` shows emulator-XXXX device
./scripts/run_android_with_emulators.sh emulator-5554
# Sign in: user@parkour.spot / user@parkour.spot
```

## Out of scope (deferred)

Google Sign-In, Maps SDK API key in Manifest, camera/location permission UX, native FCM, App Links, share sheet, analytics, Play signing.
