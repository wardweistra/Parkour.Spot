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
- **Flutter SDK**: 3.38.1 or higher (current stable recommended)
- **Dart SDK**: 3.10.0 or higher
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

### **Android cleartext (debug/profile only)**

`android/app/src/debug/AndroidManifest.xml` and `profile/` set `usesCleartextTraffic="true"` so debug/profile builds can talk to local Firebase emulators over HTTP (`10.0.2.2`). The release manifest does not allow cleartext and does not disable TLS certificate validation. Scanner findings that call this "improper SSL certificate validation" should be accepted as a local-emulator exception.

### **Gradle lockfiles**

`android/gradle.lockfile` and `android/app/gradle.lockfile` pin the Android Gradle dependency graph (including transitives) for reproducible builds and SCA. Do not edit them by hand. Locking is **lenient** so AGP/Kotlin can resolve slightly different graphs per task without failing the build. After changing Android Gradle plugins or Flutter plugins that ship native Android libraries, regenerate:

```bash
flutter build apk --config-only
cd android && ./gradlew :app:assembleDebug :app:assembleRelease --write-locks
```

Use Java 17 or 21 (`flutter config --jdk-dir` / `JAVA_HOME`). Gradle 8.14 cannot compile Kotlin DSL on newer JDKs.

### **Common Workflows**

#### **Production Build**
```bash
# Build the Flutter app for production
./scripts/build_production.sh

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
