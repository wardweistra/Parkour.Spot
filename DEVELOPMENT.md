# 🛠️ Development Guide

This guide covers local development setup and common development tasks for ParkourSpot.

## 🚀 Local Development Setup

### **Prerequisites**
- Flutter SDK 3.9.0+
- Dart SDK 3.9.0+
- Firebase CLI
- Node.js 18.0.0+
- Git

### **Initial Setup**
```bash
# Clone the repository
git clone <your-repo-url>
cd ParkourSpot-frontend

# Install dependencies
flutter pub get

# Setup Firebase (if not already done)
firebase init
flutterfire configure

# Copy environment template
cp env.example .env
# Edit .env with your Firebase configuration
```

### **Environment Configuration**
Create a `.env` file with your Firebase configuration:
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

## 🏃‍♂️ Running the App

### **Web Development**
```bash
# Start web development server
flutter run -d web

# Or use the provided script
./scripts/run_local.sh
```

### **Mobile Development**
```bash
# Android
flutter run -d android

# iOS (macOS only)
flutter run -d ios
```

### **Hot Reload**
- Press `r` in terminal to hot reload
- Press `R` to hot restart
- Press `q` to quit

## 🔧 Development Scripts

### **Local Development**
```bash
# Start local development server
./scripts/run_local.sh
```

### **Build Scripts**
```bash
# Development build
./scripts/build_development.sh

# Production build
./scripts/build_production.sh
```

### **Manual Builds**
```bash
# Web
flutter build web

# Android
flutter build apk --debug
flutter build apk --release

# iOS
flutter build ios --debug --no-codesign
flutter build ios --release --no-codesign
```

## 🧪 Testing

### **Run Tests**
```bash
# All tests
flutter test

# Specific test file
flutter test test/auth_service_test.dart

# With coverage
flutter test --coverage
```

### **Test on Multiple Platforms**
```bash
# Test web
flutter test -d web

# Test Android
flutter test -d android

# Test iOS
flutter test -d ios
```

## 🔍 Debugging

### **Flutter Inspector**
```bash
# Enable debug mode
flutter run --debug

# Open Flutter Inspector in VS Code or Android Studio
```

### **Console Logging**
```dart
import 'package:flutter/foundation.dart';

if (kDebugMode) {
  print('Debug info: $variable');
}
```

### **Common Issues**

#### **Firebase Configuration**
- Ensure `.env` file exists and has correct values
- Run `flutterfire configure` if Firebase options are missing
- Check Firebase project permissions

#### **Platform-Specific Issues**
- **Web**: Check browser console for errors
- **Android**: Check Android Studio logs
- **iOS**: Check Xcode console

## 📱 Platform-Specific Development

### **Web Development**
```bash
# Enable web support
flutter config --enable-web

# Run with specific port
flutter run -d web-server --web-port 8080
```

### **Android Development**
```bash
# Check connected devices
flutter devices

# Install on device
flutter install

# Build APK
flutter build apk --debug
```

### **iOS Development**
```bash
# Install CocoaPods
sudo gem install cocoapods

# Pod install
cd ios && pod install && cd ..

# Run on iOS simulator
flutter run -d ios
```

## 🔄 State Management

### **Provider Pattern**
```dart
// Access provider
final authService = Provider.of<AuthService>(context, listen: false);

// Listen to changes
Consumer<AuthService>(
  builder: (context, authService, child) {
    return Text(authService.currentUser?.email ?? 'Not logged in');
  },
)
```

### **Service Architecture**
- **AuthService**: User authentication
- **SpotService**: Parkour spot management
- **ShareService**: Platform-specific sharing

## 🗄️ Database Development

### **Firestore Rules**
- Rules are in `firestore.rules`
- Test rules locally: `firebase emulators:start`
- Deploy rules: `firebase deploy --only firestore`

### **Data Models**
- **Spot**: Parkour spot information
- **User**: User profile and preferences
- **Rating**: User ratings and reviews

## 🚀 Deployment Testing

### **Web Deployment Test**
```bash
# Build for production
flutter build web

# Test locally
cd build/web
python3 -m http.server 8000
# Visit http://localhost:8000
```

### **Mobile Deployment Test**
```bash
# Android
flutter build apk --release
# Install APK on device

# iOS
flutter build ios --release
# Open in Xcode for final configuration
```

## 📚 Development Resources

- [Flutter DevTools](https://flutter.dev/docs/development/tools/devtools)
- [Flutter Testing](https://flutter.dev/docs/testing)
- [Firebase Emulator Suite](https://firebase.google.com/docs/emulator-suite)
- [Flutter Performance](https://flutter.dev/docs/perf)

## 🆘 Troubleshooting

### **Common Commands**
```bash
# Clean build
flutter clean
flutter pub get

# Check Flutter doctor
flutter doctor

# Update Flutter
flutter upgrade

# Check dependencies
flutter pub deps
```

### **Firebase Issues**
```bash
# Re-login to Firebase
firebase logout
firebase login

# Check Firebase CLI version
firebase --version

# Update Firebase CLI
npm install -g firebase-tools
```

---

**Happy developing! 🚀**
