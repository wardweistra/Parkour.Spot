# 🏃‍♂️ Parkour.Spot

A cross-platform Flutter application for discovering, reporting, and rating parkour spots. Built with Firebase backend services and modern Flutter architecture.

**🌐 Live App**: [https://Parkour.Spot](https://Parkour.Spot)

## ✨ Features

- **🔐 User Authentication** - Sign up, login, and profile management
- **📍 Spot Discovery** - Browse and search parkour spots
- **🗺️ Interactive Maps** - View spots on maps with location data
- **📱 Add New Spots** - Report new parkour locations with photos
- **⭐ Rating System** - Rate and review spots
- **📱 Cross-Platform** - Works on Web, Android, and iOS
- **☁️ Cloud Backend** - Firebase-powered with real-time data sync

## 🚀 Quick Start

### 1. **Clone the Repository**
```bash
git clone <your-repo-url>
cd Parkour.Spot
```

### 2. **Run Setup Script**
```bash
chmod +x setup.sh
./setup.sh
```

The setup script will:
- Check Flutter and Firebase CLI installation
- Install Flutter dependencies
- Initialize Firebase project
- Configure FlutterFire

### 3. **Environment Configuration**
```bash
cp env.example .env
# Edit .env with your Firebase configuration
```

Required environment variables:
```bash
# Firebase Configuration
FIREBASE_API_KEY=your_api_key_here
FIREBASE_APP_ID_WEB=your_web_app_id_here
FIREBASE_APP_ID_ANDROID=your_android_app_id_here
FIREBASE_APP_ID_IOS=your_ios_app_id_here
FIREBASE_MESSAGING_SENDER_ID=your_sender_id_here
FIREBASE_PROJECT_ID=your_project_id_here
FIREBASE_AUTH_DOMAIN=your_project_id.firebaseapp.com
FIREBASE_STORAGE_BUCKET=your_project_id.firebasestorage.app
FIREBASE_MEASUREMENT_ID=your_measurement_id_here

# Google Maps API Keys
GOOGLE_MAPS_API_KEY_ANDROID=your_android_maps_key_here
GOOGLE_MAPS_API_KEY_IOS=your_ios_maps_key_here
```

### 4. **Run the App**
```bash
# Web
flutter run -d web

# Android
flutter run -d android

# iOS (macOS only)
flutter run -d ios
```

## 🛠️ Development

### **Prerequisites**
- **Flutter SDK**: 3.9.0 or higher
- **Dart SDK**: 3.9.0 or higher
- **Firebase CLI**: Latest version
- **Node.js**: 18.0.0 or higher
- **Android Studio**: For Android development
- **Xcode**: For iOS development (macOS only)

### **Development Scripts**
```bash
# Local development server
./scripts/run_local.sh

# Development build
./scripts/build_development.sh

# Production build
./scripts/build_production.sh
```

### **Testing**
```bash
# All tests
flutter test

# With coverage
flutter test --coverage
```

**Note**: Currently there are no tests implemented.

## 🚀 Building & Deployment

### **Web Build & Deploy**
```bash
# Build for production
flutter build web

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

### **Android Build**
```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# APK location: build/app/outputs/flutter-apk/app-debug.apk
```

### **iOS Build**
```bash
# Build iOS app
flutter build ios --release

# Open in Xcode for final configuration
open ios/Runner.xcworkspace
```

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

#### **NDK Version Issues (Android)**
```bash
# Check NDK versions
ls /Users/ward/Library/Android/sdk/ndk/

# Fix by updating build.gradle.kts
# Set: ndkVersion = "29.0.13846066"
```

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
| **Web** | ✅ Ready | Firebase Hosting |
| **Android** | ✅ Ready | APK ready to build |
| **iOS** | 🔄 Pending | Requires Xcode |

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
