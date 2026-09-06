# Native Android & iOS (Flutter)

Plan for shipping ParkourSpot as native store apps from the existing Flutter codebase, keeping the web PWA as a first-class client of the same Firebase backend.

Related: [GitHub issue #235](https://github.com/wardweistra/Parkour.Spot/issues/235) (originally PWA packaging). After exploration we chose **Flutter native** over PWABuilder/TWA wrappers — same Dart UI, real plugin backends for maps, location, auth, and messaging.

## Decision summary

| Path | Verdict |
|------|---------|
| **PWABuilder / TWA** | Easier testing (same web runtime), but iOS App Store risk is high and push is weak in wrappers. |
| **Flutter Android / iOS** | More QA surface (native plugin implementations), but one product codebase, better store fit, and reliable FCM/APNs. **Chosen.** |
| **Browser PWA only** | Remains supported; native is an additional client, not a replacement. |

**Why native over PWA packaging:** location, Maps, Google Sign-In, and push already depend on platform behavior. Packaging the website does not remove those gaps on iOS and still leaves a second “almost native” surface to maintain.

## Current state (baseline)

Captured when this plan was written:

- No `android/` or `ios/` folders; `.metadata` tracks **web only**
- `DefaultFirebaseOptions.currentPlatform` always returns **web**
- Firebase project has a **web app only** (no Android/iOS app configs in-repo)
- Many libraries import `package:web` / `dart:js_interop` / `flutter_web_plugins` at top level → native compile **fails** until isolated
- Push backend (`functions/lib/send-web-push.js`) builds **webpush-only** FCM messages
- Google Sign-In uses `signInWithPopup` and explicitly returns `false` when `!kIsWeb`
- `MobileDetectionService` is UA-based; on native `isMobileDevice` / `isIOS` / `isAndroid` are all `false`
- CI runs Flutter tests only; no APK/IPA or signing pipelines
- Production build script is web-only (`flutter build web`)

**Already in good shape for reuse:** go_router routes, Firestore, email/password Auth, map widgets (`google_maps_flutter` with `liteModeEnabled: kIsWeb`), `image_picker` / `geolocator` helpers, Storage uploads, absolute `https://parkour.spot/...` share URLs, stub/conditional-import pattern (`browser_timezone_utils_*`, `web_image_preparation_*`, `browser_emoji_span_*`).

## Risk-ordered workstreams

### Blockers

1. **Platform shells + compile** — `flutter create . --platforms=android,ios`; isolate every unconditional browser import behind stubs / conditional imports.
2. **Firebase Android + iOS apps** — register apps; `google-services.json` / `GoogleService-Info.plist` (already gitignored); extend `firebase_options.dart` and `AppConfig` with platform App IDs.
3. **Google Sign-In (native)** — add `google_sign_in` (or equivalent); SHA-1/256 (Android); URL schemes / client IDs (iOS).
4. **Native push** — FCM/APNs token registration without VAPID; subscription `platform: android|ios`; Functions payloads with `android` / `apns` (not webpush-only); click → in-app routing.
5. **Google Maps SDK keys** — Android Manifest meta-data; iOS AppDelegate / Info.plist; keys restricted by package/bundle (web JS key stays in `web/index.html`).
6. **Deep linking** — App Links / Universal Links for spot, event, user, list URLs; cold-start handling (`app_links` or similar); host `assetlinks.json` / `apple-app-site-association` on the domain.
7. **Signing + store plumbing** — Play App Signing; Apple Developer / certificates / provisioning / App Store Connect.

### High risk / MVP-critical

8. Fix **`MobileDetectionService`** (and call sites) to use `defaultTargetPlatform` / `Platform.is*` on native.
9. **Location + camera** permission strings (Android 13+ photos; iOS Info.plist usage descriptions).
10. **Share** — native system sheet (`share_plus` or similar); keep Web Share on web.
11. **Analytics** — stub or replace `WebAnalytics` (gtag) with `firebase_analytics` on native.
12. **Emulator host** — Android emulator needs `10.0.2.2` (not hardcoded `127.0.0.1`).

### Polish

13. Hide all PWA install UI on native (mostly `kIsWeb`-gated; keep guards after detection fix).
14. Document title / OG meta no-ops on native.
15. Store listing assets, privacy nutrition labels, Crashlytics, CI Fastlane.
16. Update `PRODUCT.md` / README platform tables when native ships.

## Key files to change

### Compile blockers (unconditional web imports)

Reuse existing conditional-import pattern (`if (dart.library.js_interop)`).

| File | Why |
|------|-----|
| `lib/main.dart` | `package:web`, URL strategy, deep link via `web.window`, FCM host check |
| `lib/router/app_router.dart` | `package:web` for GA / document title |
| `lib/analytics/web_analytics.dart` | gtag via `eval` + `web.window` |
| `lib/services/mobile_detection_service.dart` | UA/screen via `web.window` |
| `lib/services/pwa_install_service.dart` | `beforeinstallprompt`, JS interop |
| `lib/services/web_push_subscription_service.dart` | SW + userAgent; web-only by design |
| `lib/services/web_share_service.dart` | `navigator.share` |
| `lib/utils/web_meta_utils.dart` | DOM meta tags |
| `lib/utils/support_debug_report.dart` | web diagnostics |
| `lib/screens/splash_screen.dart` | `web.window.location` |
| `lib/screens/explore_screen.dart` | document title/meta |
| `lib/screens/profile/profile_screen.dart` | `location.reload()` |
| `lib/screens/spots/spot_detail_screen.dart` | `web.document.title` |
| `lib/screens/admin/device_detection_screen.dart` | heavy web/PWA diagnostics |

### Auth / push / config

| File | Why |
|------|-----|
| `lib/services/auth_service.dart` | Google = web popup only |
| `lib/firebase_options.dart` | Always returns `web` |
| `lib/config/app_config.dart`, `env.example` | Add Android/iOS App IDs |
| `lib/services/web_push_subscription_service.dart` | Split into platform abstraction |
| `functions/lib/send-web-push.js` (+ deliver path/tests) | Native message shapes by `platform` |
| `pubspec.yaml` | `google_sign_in`, `app_links`, `share_plus`, `firebase_analytics`, etc. |

### Maps / links / images

| File | Why |
|------|-----|
| New `android/` / `ios/` trees | Manifest, AppDelegate, permissions, Maps keys |
| Map widgets with `liteModeEnabled: kIsWeb` | OK as-is for native (full maps) |
| `lib/services/url_service.dart` | Absolute HTTPS URLs — good for App Links |
| `lib/utils/image_picker_utils.dart`, `location_permission_utils.dart` | Logic ready; need OS declarations |
| `firebase.json` / Hosting | Serve Digital Asset Links + AASA |

## Phased plan

### Phase 0 — Scaffold (Android first)

**Goal:** blank shell runs on Android against emulators/prod with email login.

1. `flutter create . --platforms=android,ios`
2. Conditional-import / stub all `package:web` and `flutter_web_plugins` usage so `flutter build apk` (and iOS) compile
3. Register Firebase Android app; regenerate options; wire `google-services.json`
4. Fix emulator host for Android emulator (`10.0.2.2`)

**Exit criteria:** app launches; email/password auth works; no web-only import crashes.

**Status:** **Complete** (2026-09-05). App launches on Android emulator; email auth path unblocked. Maps / Google Sign-In / FCM / App Links are Phase 1.

### Phase 1 — Android MVP feature parity

- [x] Email/password auth + email verification flows
- [x] Google Sign-In (Play SHA fingerprints)
- [x] Explore/search maps with Maps SDK key
- [x] Add/edit spot: gallery + camera + Storage upload
- [x] Geolocator + permission rationale
- [x] FCM: request permission, store token with `platform: 'android'`, foreground + background open
- [x] Backend send path works for native tokens (not webpush-only)
- [x] App Links for `/spot/…`, `/:cc/:city/:id`, `/event/…`, `/user/…`, `/list/…`
- [x] Share via system sheet; hide all PWA install UI
- [x] Analytics events (`app_start`, page_view equivalent)
- [x] Signed App Bundle → Play internal track

**Exit criteria:** internal testers can discover spots, add photos, sign in with Google, receive a test push, and open a shared spot link into the app.

**Status:** **Code complete** (2026-09-05). See [phase-1-android-mvp.md](phase-1-android-mvp.md). Remaining manual console steps: Firebase SHA fingerprints, Android Maps key in `local.properties`, Hosting deploy of `assetlinks.json`, Play Console internal-track upload.

### Phase 2 — iOS MVP

- [ ] Firebase iOS app + `GoogleService-Info.plist`
- [ ] Google Sign-In URL schemes / reversed client ID
- [ ] APNs key in Firebase; notification entitlements
- [ ] Universal Links + `apple-app-site-association`
- [ ] Camera / photo / location Info.plist strings
- [ ] Apple Maps preferred when `Platform.isIOS`
- [ ] TestFlight → App Review

**Exit criteria:** TestFlight build passes core parity checklist; App Review submission ready.

### Phase 3 — Hardening

- [ ] CI: Android assemble (+ optional Fastlane); macOS iOS build
- [ ] Crashlytics
- [ ] Admin push-subscriptions UI aware of multi-platform
- [ ] Update `PRODUCT.md` and README platform support tables
- [ ] Store listing assets, privacy questionnaires

## Effort (order of magnitude)

| Scope | Rough effort |
|-------|----------------|
| MVP Android (Phases 0–1) | ~3–5 weeks |
| MVP iOS after Android patterns (Phase 2) | +2–4 weeks |
| Store-ready polish (Phase 3) | +1–2 weeks overlapping |

Assumes Apple/Google developer accounts and Maps/Firebase console access are ready. Certificate and account delays often dominate the iOS calendar.

## Testing implications

Native is **not** “same as PWA with a different icon”:

- `google_maps_flutter` → native Maps SDK (not JS)
- `geolocator` / `image_picker` → OS permission + sensor APIs
- `firebase_messaging` → native FCM (APNs on iOS)
- Auth deep links, share sheets, and cold-start URLs behave differently

**Regression strategy:** keep web PWA as the daily driver; treat Android (then iOS) as a separate matrix for auth, maps, camera, location, push, and deep links. Prefer device / internal-track testing over simulator-only for maps and push.

## Out of scope (for now)

- Rewriting the app in Kotlin/Swift or React Native
- Dropping the web PWA
- PWABuilder / TWA packaging (revisit only if Android store presence is needed without native work)
- Feature redesign for native-only UX beyond platform conventions (permissions, share sheet, notifications)

## Progress log

| Date | Note |
|------|------|
| 2026-09-05 | Plan written after comparing PWA packaging vs Flutter native; native route selected. |
| 2026-09-05 | Phase 0 scaffold implemented: android/ios trees, web import isolation, Firebase Android app `spot.parkour.app`, emulator host `10.0.2.2`, run script. See [phase-0-scaffold.md](phase-0-scaffold.md). APK/emulator login verification pending local Android SDK. |
| 2026-09-05 | **Phase 0 complete.** Debug APK builds; app launches on Android emulator with Firebase emulators. Maps SDK keys, Google Sign-In, FCM, deep links remain Phase 1. |
| 2026-09-05 | **Phase 1 code complete.** Permissions/Maps wiring, Google Sign-In native path, Android FCM + Functions payloads, App Links + assetlinks, share sheet, analytics, release signing. Console/Play upload steps documented in [phase-1-android-mvp.md](phase-1-android-mvp.md). |
| 2026-09-05 | Renamed application / bundle ID to `parkour.spot` (Android + iOS). New Firebase apps: Android `…:android:c50362d42802754e926548`, iOS `…:ios:ff99a9aac3ff2902926548`. Old Android app `spot.parkour.app` left in Firebase unused. |

Update this table as phases complete.
