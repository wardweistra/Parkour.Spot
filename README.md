# 🏃‍♂️ ParkourSpot - Flutter App

A cross-platform Flutter application for discovering, reporting, and rating parkour spots. Built with Firebase backend services and modern Flutter architecture.

## ✨ Features

- **🔐 User Authentication** - Sign up, login, and profile management
- **📍 Spot Discovery** - Browse and search parkour spots
- **🗺️ Interactive Maps** - View spots on maps with location data
- **📱 Add New Spots** - Report new parkour locations with photos
- **⭐ Rating System** - Rate and review spots
- **📱 Cross-Platform** - Works on Web, Android, and iOS
- **☁️ Cloud Backend** - Firebase-powered with real-time data sync

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

## 🚀 Current Status

### ✅ **Web App - LIVE**
- **URL**: https://parkourspot-93c90.web.app
- **Status**: Fully functional with working authentication
- **Features**: Complete user management and spot functionality

### ✅ **Android App - BUILT**
- **Status**: APK successfully built and ready for installation
- **Location**: `build/app/outputs/flutter-apk/app-debug.apk`
- **Platform**: Android 5.0+ (API 21+)

### ✅ **Firebase Backend - CONFIGURED**
- **Project**: parkourspot-93c90
- **Region**: EU (europe-west1)
- **Services**: Firestore, Auth, Storage, Functions, Hosting

## 🛠️ Prerequisites

- **Flutter SDK**: 3.9.0 or higher
- **Dart SDK**: 3.9.0 or higher
- **Firebase CLI**: Latest version
- **Node.js**: 18.0.0 or higher
- **Android Studio**: For Android development
- **Xcode**: For iOS development (macOS only)

## 🚀 Quick Start

### 1. **Clone and Setup**
```bash
git clone <your-repo-url>
cd ParkourSpot-frontend
flutter pub get
```

### 2. **Firebase Configuration** ✅ **COMPLETED**
Your Firebase project is already configured with:
- **API Key**: `AIzaSyC8DOQMB0A4e0e5cT-csqjaLi_BrDK7FmQ`
- **Project ID**: `parkourspot-93c90`
- **Auth Domain**: `parkourspot-93c90.firebaseapp.com`
- **Storage Bucket**: `parkourspot-93c90.firebasestorage.app`

### 3. **Run the App**
```bash
# Web
flutter run -d web

# Android
flutter run -d android

# iOS (macOS only)
flutter run -d ios
```

## 🏗️ Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── spot.dart            # Parkour spot model
│   └── user.dart            # User model
├── services/                 # Business logic
│   ├── auth_service.dart    # Authentication
│   └── spot_service.dart    # Spot management
├── screens/                  # UI screens
│   ├── auth/                # Login/signup
│   ├── spots/               # Spot-related screens
│   └── profile/             # User profile
└── widgets/                  # Reusable components
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

## 🗄️ Firebase Collections

### **Spots Collection**
```json
{
  "name": "String",
  "description": "String", 
  "location": "GeoPoint",
  "imageUrl": "String?",
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

## 🚀 Deployment

### **Web Deployment** ✅ **COMPLETED**
```bash
flutter build web
firebase deploy --only hosting
```

### **Android Build** ✅ **COMPLETED**
```bash
flutter build apk --debug
# APK created at: build/app/outputs/flutter-apk/app-debug.apk
```

### **iOS Build** (Coming Soon)
```bash
flutter build ios --release
```

## 🔧 Troubleshooting

### **NDK Version Issues (Android)**
If you encounter NDK build errors:
1. **Check NDK versions**: `ls /Users/ward/Library/Android/sdk/ndk/`
2. **Update build.gradle.kts**: Set `ndkVersion = "29.0.13846066"`
3. **Clean build**: `flutter clean && flutter build apk --debug`

### **Firebase Authentication Errors**
- Ensure `firebase_options.dart` has correct API keys
- Verify Firebase project is in the same region as your app
- Check Firestore security rules

### **Web Build Issues**
```bash
flutter config --enable-web
flutter clean
flutter build web
```

### Web support

- Direct links like `https://parkourspot.app/spot/<SPOT_ID>` will be parsed on load and navigate to the spot detail.
- Also supports query-style deeplinks: `https://parkourspot.app/?spot=<SPOT_ID>`.
- Ensure your hosting config rewrites to `index.html` so Flutter can handle routes (Firebase Hosting example):

```json
{
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [{ "source": "**", "destination": "/index.html" }]
  }
}
```

## 📱 Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| **Web** | ✅ Live | Firebase Hosting |
| **Android** | ✅ Built | APK ready |
| **iOS** | 🔄 Pending | Requires Xcode |

## 🌐 Live Demo

**Visit your live app**: https://parkourspot-93c90.web.app

## 📚 Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
- [Flutter Web Deployment](https://flutter.dev/docs/deployment/web)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Built with ❤️ using Flutter and Firebase**

## Deep Links & Sharing

- Share button on `SpotDetailScreen` shares a deep link in the form `parkourspot://spot/<SPOT_ID>`.
- The app listens for incoming links via `uni_links` in `DeepLinkService` and navigates to the spot detail when received.
- Android: custom scheme and https app link intent-filters are added in `android/app/src/main/AndroidManifest.xml`.
- iOS: custom URL scheme is configured in `ios/Runner/Info.plist`. An entitlements file `ios/Runner/Runner.entitlements` with Associated Domains is included (update your Xcode project to use it).

Testing deep links (Android):

```bash
adb shell am start -W -a android.intent.action.VIEW -d "parkourspot://spot/<SPOT_ID>" com.example.parkour_spot
```

Replace the package id if you’ve changed `applicationId`.
