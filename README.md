# 🏃‍♂️ Parkour.Spot - Flutter App

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

### ✅ **Web App - Ready for Deployment**
- **Status**: Fully functional with working authentication
- **Features**: Complete user management and spot functionality
- **Deployment**: Ready for Firebase Hosting

### ✅ **Android App - Ready for Build**
- **Status**: Ready to build APK for installation
- **Location**: `build/app/outputs/flutter-apk/app-debug.apk`
- **Platform**: Android 5.0+ (API 21+)

### ✅ **Firebase Backend - Ready for Configuration**
- **Services**: Firestore, Auth, Storage, Functions, Hosting
- **Region**: Configurable (defaults to europe-west1)

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
cd Parkour.Spot
flutter pub get
```

### 2. **Environment Configuration** 🔧 **REQUIRED**
Before running the app, you need to set up your environment variables:

1. **Copy the example environment file:**
   ```bash
   cp env.example .env
   ```

2. **Edit `.env` with your Firebase configuration:**
   ```bash
   # Firebase Configuration
   FIREBASE_API_KEY=your_actual_api_key_here
   FIREBASE_APP_ID_WEB=your_web_app_id_here
   FIREBASE_APP_ID_ANDROID=your_android_app_id_here
   FIREBASE_APP_ID_IOS=your_ios_app_id_here
   FIREBASE_MESSAGING_SENDER_ID=your_actual_sender_id_here
   FIREBASE_PROJECT_ID=your_actual_project_id_here
   FIREBASE_AUTH_DOMAIN=your_project_id.firebaseapp.com
   FIREBASE_STORAGE_BUCKET=your_project_id.firebasestorage.app
   FIREBASE_MEASUREMENT_ID=your_actual_measurement_id_here
   
   # Google Maps API Keys
   GOOGLE_MAPS_API_KEY_ANDROID=your_android_maps_key_here
   GOOGLE_MAPS_API_KEY_IOS=your_ios_maps_key_here
   ```

3. **Get your Firebase configuration:**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your project
   - Go to Project Settings → General
   - Copy the configuration values

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

## 📱 Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| **Web** | ✅ Live | Firebase Hosting |
| **Android** | ✅ Built | APK ready |
| **iOS** | 🔄 Pending | Requires Xcode |

## 🌐 Live Demo

**After deployment, your app will be available at**: `https://your-project-id.web.app`

**To deploy your app**:
```bash
flutter build web
firebase deploy --only hosting
```

## 📚 Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
- [Flutter Web Deployment](https://flutter.dev/docs/deployment/web)

## 📖 Documentation

- **[DEVELOPMENT.md](DEVELOPMENT.md)** - Local development setup and tasks
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - How to contribute to the project
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Deployment guide for all platforms
- **[URL_SYSTEM.md](URL_SYSTEM.md)** - Deep linking and URL system documentation

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for detailed information on how to:

1. Set up your development environment
2. Fork the repository
3. Create a feature branch
4. Make your changes
5. Test thoroughly
6. Submit a pull request

For quick development setup, see [DEVELOPMENT.md](DEVELOPMENT.md).

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Built with ❤️ using Flutter and Firebase**
