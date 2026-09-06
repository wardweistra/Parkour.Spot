# Phase 1 — Android MVP feature parity

Parent: [native-android-ios.md](native-android-ios.md) · Prior: [phase-0-scaffold.md](phase-0-scaffold.md)

**Goal:** Internal Android testers can discover spots on maps, add photos, sign in with Google, receive a test push, open a shared `https://parkour.spot/...` link into the app, and install via Play internal testing.

**Defaults:**
- Application ID: `parkour.spot`
- Email verification / password-reset remain browser-based
- iOS scaffold only (usage strings added); no TestFlight

## Checklist

- [x] Android Manifest permissions (location, camera, notifications, media)
- [x] Maps SDK API key via `manifestPlaceholders` + `android/local.properties` (`GOOGLE_MAPS_ANDROID_API_KEY`)
- [x] `google_sign_in` + native credential path in `AuthService`
- [x] Android FCM: `platform: android`, token without VAPID, listeners, token refresh
- [x] Functions: `buildWebPushMessage` branches on `platform` (web / android / ios)
- [x] App Links intent-filters + `app_links` cold-start / stream routing
- [x] `web/.well-known/assetlinks.json` + Hosting ignore fix so `.well-known` is served
- [x] `share_plus` system share sheet on native
- [x] Profile PWA install banner gated with `kIsWeb`
- [x] `firebase_analytics` behind `WebAnalytics` stub on native
- [x] Release signing config (`key.properties` + upload keystore, gitignored)
- [x] Debug APK builds; release AAB signing wired
- [ ] Console: register debug + release SHA-1/256 in Firebase (Google Sign-In)
- [ ] Console: Android-restricted Maps API key in `local.properties`
- [ ] Deploy Hosting so `https://parkour.spot/.well-known/assetlinks.json` is live
- [ ] Play Console: create app, enroll App Signing, upload AAB to internal testing
- [ ] After Play App Signing: update `assetlinks.json` with **App signing** cert SHA-256

## What landed

### Permissions + Maps

- [android/app/src/main/AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml): location, camera, `POST_NOTIFICATIONS`, `READ_MEDIA_IMAGES`, Maps meta-data, App Links intent-filter
- [android/app/build.gradle.kts](../android/app/build.gradle.kts): `GOOGLE_MAPS_ANDROID_API_KEY` placeholder + release signing
- Documented in [env.example](../env.example)

Set locally (gitignored `android/local.properties`):

```properties
GOOGLE_MAPS_ANDROID_API_KEY=your_android_sdk_key
```

Create a **separate** Maps key restricted to package `parkour.spot` + SHA-1 (do not reuse the web JS key).

### Google Sign-In

- [lib/services/auth_service.dart](../lib/services/auth_service.dart): web keeps popup; native uses `GoogleSignIn.instance.authenticate()` → `signInWithCredential`
- Relies on web OAuth client in `google-services.json` (`client_type: 3`)
- **Required:** add debug and release SHA fingerprints in Firebase Console → Project settings → Android app

### Push (client + backend)

- [lib/services/web_push_subscription_service.dart](../lib/services/web_push_subscription_service.dart): supported on web + Android; `platform` field; native `getToken()` without VAPID
- [lib/main.dart](../lib/main.dart): FCM foreground snackbar + `onMessageOpenedApp` / `getInitialMessage` open `data.openUrl` in-app
- [functions/lib/send-web-push.js](../functions/lib/send-web-push.js): platform-aware payloads; tests in `functions/test/send-web-push.test.js`

### App Links

- Manifest `autoVerify` for `https://parkour.spot` and `www.parkour.spot`
- `app_links` wiring in `main.dart`
- [web/.well-known/assetlinks.json](../web/.well-known/assetlinks.json) — upload-keystore SHA-256 included; replace with Play App Signing cert after enrollment
- [firebase.json](../firebase.json): stop ignoring all `**/.*` so `.well-known` deploys with `flutter build web` → Hosting

### Share + PWA gate + Analytics

- Native share sheet via `share_plus` in web share stub
- Profile install banner: `kIsWeb` required
- Native analytics: Firebase Analytics in `web_analytics_stub.dart`

### Signing / Play

Local (gitignored):

1. Copy [android/key.properties.example](../android/key.properties.example) → `android/key.properties`
2. Upload keystore at `android/keystore/upload-keystore.jks` (gitignored)
3. `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`

Play Console (manual):

1. Create app `parkour.spot`
2. Enroll Play App Signing; upload AAB to **internal testing**
3. Register **App signing** SHA-1/256 in Firebase + Maps key restrictions
4. Update `assetlinks.json` with App signing SHA-256 and redeploy Hosting

**Upload keystore SHA-256 (pre–Play App Signing):**  
`A8:94:73:3B:92:D5:19:74:BA:D5:10:D3:B2:F5:8C:4C:53:F3:63:F7:14:51:4F:A8:49:EA:DC:F3:9F:B9:E2:6D`  
(Change the keystore password from the temporary local value before production use.)

## Verification

| Check | How |
|-------|-----|
| Debug APK | `flutter build apk --debug` |
| Maps | Set Maps key; open Explore on emulator/device |
| Google Sign-In | Register SHAs; Continue with Google |
| Push | Enable in account settings; admin test-send; tap opens route |
| App Links | Deploy assetlinks; `adb shell am start -a android.intent.action.VIEW -d "https://parkour.spot/spot/<id>"` |
| Share | Share spot → system sheet |
| Analytics | Firebase DebugView for `app_start` / screen views |
| AAB | `flutter build appbundle --release` |

## Notes

- Firebase packages are **pinned** in `pubspec.yaml` (`firebase_core: 4.3.0`, etc.) so `flutter pub add` does not pull `firebase_core_web` versions that break dart2js. Keep pins until Flutter/Firebase align on web.
- Upload keystore password was generated for local use only — change it before production Play uploads.

## Out of scope (Phase 2+)

iOS Firebase/APNs/Universal Links/TestFlight; Crashlytics; CI Fastlane; in-app email `oobCode`; PRODUCT/README platform tables.

