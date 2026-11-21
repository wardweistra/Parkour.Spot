# 🏃‍♂️ Parkour·Spot

A cross-platform Flutter application for discovering, reporting, and rating parkour spots. Built with Firebase backend services and modern Flutter architecture.

**🌐 Live App**: [https://Parkour.Spot](https://Parkour.Spot)

## ✨ Features

- **🔐 User Authentication** - Sign up, login, and profile management
- **📍 Spot Discovery** - Browse and search parkour spots
- **🗺️ Interactive Maps** - View spots on maps with location data
- **📱 Add New Spots** - Report new parkour locations with photos
- **⭐ Rating System** - Rate and review spots
- **📱 Progressive Web App** - Works on Web, Mobile, and Desktop via Progressive Web App
- **☁️ Cloud Backend** - Firebase-powered with real-time data sync

## 🚀 Development

### **Prerequisites**
- **Flutter SDK**: 3.47.0 or higher (current stable recommended)
- **Dart SDK**: 3.13.0 or higher
- **Firebase CLI**: Latest version
- **Node.js**: 18.0.0 or higher

### **Setup**

#### 1. **Clone the Repository**
```bash
git clone <your-repo-url>
cd Parkour.Spot
```

#### 2. **Run Setup Script**
```bash
chmod +x setup.sh
./setup.sh
```

The setup script will:
- Check Flutter and Firebase CLI installation
- Install Flutter dependencies
- Initialize Firebase project
- Configure FlutterFire
- Initialize emulator seed data (for local development)

### **Local Development**

There are two development flows depending on whether you have access to the production Firebase project:

#### **Option 1: Using Firebase Emulators (Recommended for Most Developers)**

This is the recommended approach for most developers. No Firebase production access required.

```bash
# Terminal 1: Start Firebase emulators
./scripts/start_emulators.sh

# Terminal 2: Run the app with emulators
./scripts/run_local_with_emulators.sh

# About site from checked-in fixtures (no production database, no emulators)
./scripts/run_about_local.sh
```

**🌱 Emulator Seed Data**: When you start emulators for the first time, seed data from `scripts/seed-data/` is automatically copied to `.firebase/emulator-data/`. This gives you a working dataset with test users, spots, and other sample data to develop with. Your changes are automatically saved when you stop the emulators.

**Seed data reference.** The committed export includes at least four users and sample content:

- **user@parkour.spot** — Password: `user@parkour.spot`. Regular user.
- **moderator@parkour.spot** — Password: `moderator@parkour.spot`. Moderator.
- **admin@parkour.spot** — Password: `admin@parkour.spot`. Admin.
- **google@parkour.spot** — Sign in with Google (not email/password). Regular user.

There are at least two parkour spots in Évry-Courcouronnes, France.

**🖥️ Emulator UI** (http://localhost:4000): The Firebase Emulator Suite provides a web UI for managing your local emulators. Use it to:
- **Create users**: Go to Authentication → Users → Add user (email/password)
- **Verify email**: Open a user → Edit → toggle "Email verified" on
- **View Firestore data**: Browse collections and documents
- **Inspect Storage**: See uploaded files
- **Debug Functions**: View logs and trace invocations

#### **Option 2: Using Firebase Production Instance**

**Only for developers with access to the production Firebase project.**

1. **Environment Configuration**
```bash
cp env.example .env
# Edit .env with your Firebase configuration
```

Required environment variables:
```bash
# Firebase Configuration
FIREBASE_API_KEY=your_api_key_here
FIREBASE_APP_ID_WEB=your_web_app_id_here
FIREBASE_MESSAGING_SENDER_ID=your_sender_id_here
FIREBASE_PROJECT_ID=your_project_id_here
FIREBASE_AUTH_DOMAIN=parkour.spot
FIREBASE_STORAGE_BUCKET=your_project_id.firebasestorage.app
FIREBASE_MEASUREMENT_ID=your_measurement_id_here
```

2. **Run the App**
```bash
./scripts/run_production.sh
```

The crawlable about site can be served the same way, reading production Firestore snapshots instead of `about/fixtures/`. Add `GOOGLE_APPLICATION_CREDENTIALS` to `.env` (see `env.example`), then:

```bash
./scripts/run_about_production.sh
```

### **Backend Google Maps API Key**

The autocomplete and geocoding features use a server-side Google Maps API key via Firebase Functions secrets. Make sure to set the secret in your Firebase project:

```bash
firebase functions:secrets:set GOOGLE_MAPS_API_KEY
```

This key should have at least the following APIs enabled:

- Places API
- Geocoding API

The Flutter client calls callable functions `placesAutocomplete`, `placeDetails`, `geocodeCoordinates`, and `reverseGeocodeAddress`, which proxy Google APIs securely using the backend key.

### **Firebase Web API key (public client identifier)**

The Firebase **Web** API key in `FIREBASE_API_KEY` is a public client identifier. Background FCM requires it inside generated `web/firebase-messaging-sw.js` (gitignored; rebuilt by `scripts/generate-firebase-messaging-sw.js`). Security scanners that report this as a leaked GCP key are false positives: the key cannot be removed from the service worker, and data access is enforced by Auth, App Check, and Firestore/Storage rules.

That browser key is restricted in [Google Cloud credentials](https://console.cloud.google.com/apis/credentials?project=parkourspot-93c90):

- **Application restrictions:** HTTP referrers for `https://parkour.spot/*`, `https://www.parkour.spot/*`, Firebase Hosting defaults, and local web (`http://localhost:*/*`, `http://127.0.0.1:*/*`).
- **API restrictions:** Firebase/Auth/FCM APIs only. Do **not** enable Maps, Places, or Geocoding on this key.

Keep Maps on the separate browser key in `web/index.html` / `functions/html-template.js`, the Android Maps key (`GOOGLE_MAPS_ANDROID_API_KEY`), and the Functions secret `GOOGLE_MAPS_API_KEY`. Native Android Firebase uses the key in `google-services.json`, not the web key.

### **Android App Check**

The Android app activates App Check on startup (`lib/main.dart`), matching the web app's reCAPTCHA Enterprise setup, so callables that spend Maps quota can be enforced for both clients (`ENFORCE_PLACES_APP_CHECK` in `functions/index.js`). It is skipped when `USE_EMULATOR=true`.

- **Release builds** use **Play Integrity**. In Firebase Console → App Check → Apps, register the Android app `parkour.spot` with the SHA-256 of the Play **App signing** certificate (and the upload key for locally installed release builds).
- **Debug/profile builds** use the debug provider. The first run prints a debug token to logcat (`adb logcat | grep -i "debug secret"`); add it under App Check → Apps → `parkour.spot` → Manage debug tokens.

Until the app is registered, token requests fail and the app keeps working as long as enforcement is off. Do not switch enforcement on before `placesAppCheck.missing` stops appearing for Android in the Functions logs.

### **Android signing certificates**

Builds installed from Google Play are re-signed by Play with the **app signing key**, not the upload key. Native Google services check that certificate, so every signing key must be registered in two places:

| Key | Where it comes from |
| --- | --- |
| Debug | `~/.android/debug.keystore` on each developer machine (`flutter run`) |
| Upload | `android/keystore/upload-keystore.jks` (`scripts/build_android_production.sh`, local release installs) |
| Play app signing | Play Console → Protected with Play → App signing (all Play tracks) |

1. **Firebase Console** → Project settings → Android app `parkour.spot` → SHA certificate fingerprints: add the **SHA-1 and SHA-256**. SHA-1 creates the Android OAuth client that **Sign in with Google** needs; SHA-256 is used by App Check (Play Integrity).
2. **Google Cloud Console** → Credentials → **ParkourSpot Android Maps key** → Android apps: add the **SHA-1** with package `parkour.spot`. Without it the **map stays blank** (`Authorization failure` in logcat).

The Play app signing key has been rotated once (Play Console lists a **previous** key and a post-quantum key next to the current one). Keep the fingerprints of all of them registered: Play signs for Android 13+ with the current key and for older Android versions with the previous key. Use **Copy all certificate fingerprints** on the App signing page. After a future key change there, register the new fingerprints in both places again.

Symptoms of a missing registration on a Play install: blank maps, and Google Sign-In failing with `UNREGISTERED_ON_API_CONSOLE` in `adb logcat | grep Auth.Api.Credentials` (the app only sees a cancellation).

### **Publishing to Google Play**

`scripts/upload_android_play.py` uploads `build/app/outputs/bundle/release/app-release.aab` through the Google Play Developer API and releases it to a track. It runs with [uv](https://docs.astral.sh/uv/), which installs its Python dependencies on first run.

```bash
./scripts/build_android_production.sh                        # bump `version:` in pubspec.yaml first
./scripts/upload_android_play.py --dry-run                   # upload + validate, then discard
./scripts/upload_android_play.py --notes "Bug fixes"         # internal testing (default track)
./scripts/upload_android_play.py --track alpha               # closed testing; also beta, production
./scripts/upload_android_play.py --track production --status inProgress --rollout 0.1
```

It refuses a version code that Play already has and a bundle whose version code does not match `pubspec.yaml`. Store listing, content rating and data safety still go through Play Console.

One-time setup:

1. **Google Cloud** (project `parkourspot-93c90`): enable the **Google Play Android Developer API**, create a service account (no project roles needed), and create a **JSON key** for it.
2. Save the key as `play-service-account.json` in the repo root (gitignored), or point `PLAY_SERVICE_ACCOUNT_JSON` at it.
3. **Play Console** → Users and permissions → **Invite new users**: add the service account's email, give it access to Parkour.Spot with **Release to testing tracks** (and **Release to production** if it should publish there).

Permissions can take a few minutes to apply. Until the app has passed its first production review, Play may only accept draft releases from the API: then use `--status draft` and roll out in Play Console.

### **Android cleartext (debug/profile only)**

`android/app/src/debug/AndroidManifest.xml` and `profile/` set `usesCleartextTraffic="true"` so debug/profile builds can talk to local Firebase emulators over HTTP (`10.0.2.2`). The release manifest does not allow cleartext and does not disable TLS certificate validation. Scanner findings that call this "improper SSL certificate validation" should be accepted as a local-emulator exception.

### **Gradle lockfiles**

`android/gradle.lockfile` and `android/app/gradle.lockfile` pin the Android Gradle dependency graph (including transitives) for reproducible builds and SCA. Do not edit them by hand. Locking is **lenient** so AGP/Kotlin can resolve slightly different graphs per task without failing the build. After changing Android Gradle plugins or Flutter plugins that ship native Android libraries, regenerate:

```bash
flutter build apk --config-only
cd android && ./gradlew :app:assembleDebug :app:assembleRelease --write-locks
```

Use Java 17 or 21 (`flutter config --jdk-dir` / `JAVA_HOME`).

The Flutter engine artifacts (`io.flutter:*`) are deliberately **not** locked (`ignoredDependencies` in `android/app/build.gradle.kts`). Their version is the engine revision of the installed Flutter SDK. If the lockfile pins a revision from another SDK version, Gradle packages that engine with Dart code compiled by yours, and the app shows a blank screen on launch with `Invalid kernel binary format version` in logcat.

### **Android build toolchain**

The Android project follows the versions in the current Flutter stable template: Gradle 9.5.0 (`android/gradle/wrapper/gradle-wrapper.properties`), Android Gradle Plugin 9.3.1 and Kotlin 2.4.20 (`android/settings.gradle.kts`). Flutter 3.50 refuses to build with anything below Gradle 9.3.1 / AGP 9.1.1 / Kotlin 2.4.10, so keep these at or above the minimums of the Flutter stable you build with (same channel as CI and Cloud Agents). `android.builtInKotlin=false` and `android.newDsl=false` in `android/gradle.properties` are set by the Flutter tool; leave them in place. When a later Flutter stable raises its minimums, bump these three versions together and regenerate the lockfiles.

### **Common Workflows**

#### **Production Build**
```bash
# Build the Flutter app for production
./scripts/build_production.sh

# Build the signed Android App Bundle for Google Play
# (bump `version:` in pubspec.yaml first; output: build/app/outputs/bundle/release/app-release.aab)
./scripts/build_android_production.sh

# Upload it to the internal testing track (see "Publishing to Google Play")
./scripts/upload_android_play.py --notes "What changed"

# Build about.parkour.spot from Firestore snapshots
./scripts/build_about_production.sh
```

#### **Firebase Deployment**
```bash
# Bind hosting targets once per machine (required; .firebaserc is gitignored)
# Create the second Hosting site in Firebase Console first (e.g. parkourspot-about),
# then attach custom domain about.parkour.spot to that site.
firebase target:apply hosting app <default-hosting-site-id>
firebase target:apply hosting about <about-hosting-site-id>

# Deploy the Flutter app (WASM) hosting target
./scripts/build_production.sh
firebase deploy --only hosting:app

# Deploy the crawlable about site from Firestore snapshots
./scripts/build_about_production.sh
firebase deploy --only hosting:about

# Deploy both hosting targets
firebase deploy --only hosting

# Deploy functions (includes nightly about snapshots + sitemap jobs)
firebase deploy --only functions

# Deploy indexes
firebase deploy --only firestore:indexes
```

#### **about.parkour.spot**

Static Astro site in `about/`. Once per night, Cloud Function `generateAboutSnapshotsScheduled` (00:30 UTC) writes Firestore `snapshots/**` (Admin-only) and dispatches GitHub Actions `about-rebuild`. That single dispatch is the only automatic deploy: the workflow rebuilds from snapshots and deploys `hosting:about`. Monitor via Actions → **About site deploy** run history and Functions logs for `generateAboutSnapshotsScheduled`; recover with **Run workflow** or the admin callable `generateAboutSnapshots`.

**URL map (geo paths match the app):**

| about.parkour.spot | parkour.spot |
| --- | --- |
| `/nl` | `/nl` |
| `/nl/amsterdam` | `/nl/amsterdam` |
| `/events/{slug}` | `/event/{eventId}` |
| `/lists/{slug}` | `/list/{listId}` |

**Secrets / setup**

- Functions secret `GITHUB_ABOUT_DEPLOY_TOKEN` — GitHub PAT that can send `repository_dispatch` to this repo.
- Optional env `ABOUT_GITHUB_REPO` (default `wardweistra/Parkour.Spot`).
- GitHub Actions secrets: `FIREBASE_SERVICE_ACCOUNT`, `FIREBASE_PROJECT_ID`, `FIREBASE_HOSTING_SITE_APP`, `FIREBASE_HOSTING_SITE_ABOUT`.
- Force rebuild: Actions → “About site deploy” → Run workflow, or admin callable `generateAboutSnapshots`.

Local snapshot preview: `./scripts/run_about_production.sh` (production Firestore snapshots). Fixture preview: `./scripts/run_about_local.sh`.

### **Other Development Scripts**
```bash
# Development build
./scripts/build_development.sh
```

### **Testing**

- **Flutter/Dart** (unit tests for `lib/` utilities and widgets):
  ```bash
  flutter test
  ```

- **Cloud Functions** (unit tests for helper logic in `functions/`):
  ```bash
  cd functions && npm test
  ```

- **About site** (Astro build against fixtures):
  ```bash
  cd about && npm ci && npm run build:fixtures
  ```

### **Emulator Data Management**

The project includes seed data for Firebase emulators to help new developers get started quickly. Test accounts and sample spots are documented in the **Seed data reference** subsection under **Option 1: Using Firebase Emulators** above.

**Available Scripts:**
```bash
# Reset emulator data to seed data
./scripts/clear_emulator_data.sh

# Update seed data from current emulator data
./scripts/update_seed_data.sh

# Export emulator data manually (if needed)
./scripts/export_emulator_data.sh
```

**How It Works:**
- **Seed Data**: Located in `scripts/seed-data/`, this is committed to the repository and provides initial test data
- **Emulator Data**: Located in `.firebase/emulator-data/` (gitignored), this is your local development data
- **Auto-Initialization**: When you run `./scripts/start_emulators.sh` for the first time, seed data is automatically copied to emulator data
- **Auto-Export**: When you stop emulators (Ctrl+C), your data is automatically exported to `.firebase/emulator-data/`
- **Reset**: Use `./scripts/clear_emulator_data.sh` to reset your emulator data back to seed data
- **Update Seed**: Use `./scripts/update_seed_data.sh` to update the seed data that new developers will receive

## 🏗️ Architecture

```
[Flutter App (Mobile/Web)] 
    ↕️
[REST API (Cloud Functions)] 
    ↕️
[Database (Firestore)] 
    ↕️
[Cloud Storage (Firebase Storage)] 
    ↕️
[Authentication (Firebase Auth)]
```

### Spots REST API and MCP

External machine clients can read spots via:

- **REST:** `GET https://parkour.spot/api/v1/spots` (name search `q` or bounds), `GET https://parkour.spot/api/v1/spots/:spotId`, and `GET https://parkour.spot/api/v1/spot-lists/:listId/spots` (every spot on a public or unlisted list, in list order)
- **MCP:** `POST https://parkour.spot/mcp` (Streamable HTTP JSON-RPC) with tools `search_spots`, `get_spot`, and `list_spot_list_spots`

`list_spot_list_spots` takes `listId`. Private lists and unknown ids both return not found. Spots keep list order; a section entry note is returned as `listNote`. Missing spot documents are omitted.

Both require an API key from **Admin → API clients** (`X-API-Key` or `Authorization: Bearer ps_…`). Usage is counted per client; there is no hard rate limit yet.

Example remote MCP client config (do not commit real keys):

```json
{
  "mcpServers": {
    "parkourspot": {
      "url": "https://parkour.spot/mcp",
      "headers": {
        "Authorization": "Bearer ps_…"
      }
    }
  }
}
```

Deploy the endpoint with functions and app hosting, e.g. `firebase deploy --only functions:mcpServer,hosting:app`. Against emulators, call the `mcpServer` function URL directly.

### Spot sync sources

External spot lists are imported through Firestore `syncSources` and Cloud Functions (`checkAndRunAutoSyncs`, `syncSingleSource`). Supported types:

- **File** (`sourceType: file`, default) — Google My Maps KMZ/KML or uMap GeoJSON via `kmzUrl`
- **OpenStreetMap** (`sourceType: openstreetmap`) — Overpass query for `sport=parkour` worldwide
- **Naver map** (`sourceType: navermap`) — Shared Naver Map bookmark list via `kmzUrl` (share page, share id, or maps-bookmark API URL). Matching uses `spotSourceExternalId` (`bookmark/123`).

After deploying functions and indexes, create the OSM source in **Admin → Sync sources** (type OpenStreetMap, weekly auto-sync schedules). See `AGENTS.md` for the recommended cron expressions and first-sync steps.

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── spot.dart            # Parkour spot model
│   ├── user.dart            # User model
│   └── rating.dart          # Rating model
├── services/                 # Business logic
│   ├── auth_service.dart    # Authentication
│   ├── spot_service.dart    # Spot management
│   └── share_service_*.dart # Platform-specific sharing
├── screens/                  # UI screens
│   ├── auth/                # Login/signup
│   ├── spots/               # Spot-related screens
│   └── profile/             # User profile
├── widgets/                  # Reusable components
└── router/                  # Navigation and routing
```

## 🗄️ Data Models

### **Spots Collection**
```json
{
  "name": "String",
  "description": "String", 
  "location": "GeoPoint",
  "imageUrls": "List<String>?",
  "rating": "Double?",
  "ratingCount": "Int?",
  "tags": "List<String>?",
  "createdBy": "String",
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

### **Users Collection**
```json
{
  "id": "String",
  "email": "String",
  "displayName": "String?",
  "photoURL": "String?",
  "createdAt": "Timestamp",
  "lastLoginAt": "Timestamp",
  "favoriteSpots": "List<String>?"
}
```

### **Ratings Collection**
```json
{
  "id": "String",
  "spotId": "String",
  "userId": "String",
  "rating": "Double",
  "createdAt": "Timestamp?",
  "updatedAt": "Timestamp?"
}
```

## 🔑 Key Dependencies

- **firebase_core**: Firebase initialization
- **firebase_auth**: User authentication
- **cloud_firestore**: Database operations
- **firebase_storage**: Image storage
- **cloud_functions**: Backend functions
- **provider**: State management
- **geolocator**: Location services
- **image_picker**: Photo selection

## 🔧 Troubleshooting

### **Common Issues**


#### **Firebase Configuration**
- Ensure `.env` file exists with correct values
- Run `flutterfire configure` if Firebase options are missing
- Check Firebase project permissions

#### **Web Build Issues**
```bash
flutter config --enable-web
flutter clean
flutter build web
```

### **Useful Commands**
```bash
# Clean build
flutter clean
flutter pub get

# Check Flutter doctor
flutter doctor

# Update Flutter
flutter upgrade
```

## 📱 Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| **Web** | ✅ Ready | Firebase Hosting + PWA |
| **Mobile Web** | ✅ Ready | Works on iOS Safari, Android Chrome |
| **PWA** | ✅ Ready | Installable on mobile devices |

## 🤝 Contributing

1. **Fork** the repository
2. **Create** a feature branch
3. **Make** your changes
4. **Test** thoroughly on all platforms
5. **Submit** a pull request

### **Code Style**
- Follow [Flutter Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused
- Cloud Functions: run `cd functions && npm run lint` before committing (same check as CI). Enable the shared pre-commit hook once with `./scripts/setup_git_hooks.sh`.

### **Testing**
- Write unit tests for services
- Test UI components with widget tests
- Ensure all new features have tests

## 📚 Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Flutter Widget Catalog](https://flutter.dev/docs/development/ui/widgets)

## 📄 License

This project is licensed under the MIT License.

---

**Built with ❤️ using Flutter and Firebase**
