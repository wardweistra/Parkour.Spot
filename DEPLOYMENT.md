# 🚀 ParkourSpot Deployment Guide

Complete deployment guide for the ParkourSpot Flutter app across all platforms.

## 🌐 Web Deployment (Firebase Hosting)

### ✅ **Status: LIVE**
Your web app is currently deployed and live at: **https://parkourspot-93c90.web.app**

### **Deployment Process**
```bash
# 1. Build the web app
flutter build web

# 2. Deploy to Firebase Hosting
firebase deploy --only hosting
```

### **Firebase Hosting Configuration**
- **Project**: parkourspot-93c90
- **Public Directory**: `build/web`
- **Region**: europe-west1 (EU)
- **URLs**: 
  - Primary: https://parkourspot-93c90.web.app
  - Alternative: https://parkourspot-93c90.firebaseapp.com

## 🤖 Android Deployment

### ✅ **Status: APK BUILT**
Your Android APK is successfully built and ready for distribution.

### **Build Process**
```bash
# 1. Clean previous builds
flutter clean

# 2. Build debug APK
flutter build apk --debug

# 3. Build release APK (for production)
flutter build apk --release
```

### **APK Location**
- **Debug APK**: `build/app/outputs/flutter-apk/app-debug.apk`
- **Release APK**: `build/app/outputs/flutter-apk/app-release.apk`

### **Android Configuration**
- **Minimum SDK**: API 21 (Android 5.0)
- **Target SDK**: API 36 (Android 14)
- **NDK Version**: 29.0.13846066 (explicitly set)
- **Build Tools**: 35.0.0

### **Installation**
```bash
# Install on connected device
flutter install

# Or manually install APK
adb install build/app/outputs/flutter-apk/app-debug.apk
```

## 🍎 iOS Deployment

### 🔄 **Status: PENDING**
iOS deployment requires Xcode installation on macOS.

### **Prerequisites**
- macOS with Xcode installed
- Apple Developer Account (for App Store)
- CocoaPods installed

### **Build Process**
```bash
# 1. Install CocoaPods
sudo gem install cocoapods

# 2. Build iOS app
flutter build ios --release

# 3. Open in Xcode for final configuration
open ios/Runner.xcworkspace
```

### **App Store Deployment**
1. **Archive** the app in Xcode
2. **Upload** to App Store Connect
3. **Submit** for review

## ☁️ Firebase Backend Deployment

### ✅ **Status: FULLY DEPLOYED**
All Firebase services are configured and deployed in the EU region.

### **Services Deployed**
- **Firestore Database**: Rules and indexes configured
- **Authentication**: Email/password enabled
- **Storage**: Rules configured for image uploads
- **Cloud Functions**: 4 functions deployed (europe-west1)
- **Hosting**: Web app deployed

### **Deploy All Services**
```bash
# Deploy everything
firebase deploy

# Deploy specific services
firebase deploy --only firestore
firebase deploy --only storage
firebase deploy --only functions
firebase deploy --only hosting
```

### **Firebase Configuration**
```json
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "storage": {
    "rules": "storage.rules"
  },
  "functions": {
    "source": "functions",
    "region": "europe-west1"
  },
  "hosting": {
    "public": "build/web",
    "rewrites": [{"source": "**", "destination": "/index.html"}]
  }
}
```

## 🔧 Troubleshooting

### **Android Build Issues**

#### **NDK Version Problems**
```bash
# Check available NDK versions
ls /Users/ward/Library/Android/sdk/ndk/

# Fix by updating build.gradle.kts
# Set: ndkVersion = "29.0.13846066"
```

#### **Build Failures**
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --debug
```

### **Web Deployment Issues**

#### **Build Failures**
```bash
# Enable web support
flutter config --enable-web

# Clean and rebuild
flutter clean
flutter build web
```

#### **Firebase Deploy Errors**
```bash
# Check Firebase CLI version
firebase --version

# Ensure Node.js 18+ is installed
node --version

# Re-login to Firebase
firebase logout
firebase login
```

### **Firebase Configuration Issues**

#### **Authentication Errors**
- Verify `firebase_options.dart` has correct API keys
- Check Firebase project region matches app configuration
- Ensure Firestore security rules allow authentication

#### **Database Connection Issues**
- Verify Firestore is enabled in Firebase Console
- Check security rules allow read/write operations
- Ensure proper collection structure

## 📱 Platform-Specific Requirements

### **Android**
- **Android Studio**: Latest version
- **SDK Tools**: Build Tools 35.0.0+
- **NDK**: Version 29.0.13846066
- **Gradle**: 8.0+

### **iOS**
- **Xcode**: Latest version
- **macOS**: 12.0+
- **CocoaPods**: Latest version
- **Apple Developer Account**: Required for distribution

### **Web**
- **Flutter Web**: Enabled
- **Firebase CLI**: Latest version
- **Node.js**: 18.0.0+
- **Modern Browser**: Chrome, Firefox, Safari, Edge

## 🚀 Production Deployment Checklist

### **Web**
- [ ] Build optimized web app (`flutter build web`)
- [ ] Test all functionality
- [ ] Deploy to Firebase Hosting
- [ ] Verify live URL works
- [ ] Test authentication flow

### **Android**
- [ ] Build release APK (`flutter build apk --release`)
- [ ] Test on multiple devices
- [ ] Sign APK with release key
- [ ] Upload to Google Play Console
- [ ] Submit for review

### **iOS**
- [ ] Build release iOS app
- [ ] Test on multiple devices
- [ ] Archive in Xcode
- [ ] Upload to App Store Connect
- [ ] Submit for review

### **Backend**
- [ ] Deploy all Firebase services
- [ ] Test authentication
- [ ] Verify database operations
- [ ] Check Cloud Functions
- [ ] Monitor error logs

## 📊 Deployment Status

| Service | Status | URL/Notes |
|---------|--------|-----------|
| **Web App** | ✅ Live | https://parkourspot-93c90.web.app |
| **Android APK** | ✅ Built | Ready for installation |
| **iOS App** | 🔄 Pending | Requires Xcode |
| **Firebase Auth** | ✅ Working | Email/password enabled |
| **Firestore DB** | ✅ Deployed | Rules configured |
| **Cloud Storage** | ✅ Deployed | Image uploads working |
| **Cloud Functions** | ✅ Deployed | 4 functions active |
| **Firebase Hosting** | ✅ Deployed | Web app hosted |

## 🔗 Useful Links

- **Live App**: https://parkourspot-93c90.web.app
- **Firebase Console**: https://console.firebase.google.com/project/parkourspot-93c90
- **Flutter Documentation**: https://flutter.dev/docs/deployment
- **Firebase Documentation**: https://firebase.google.com/docs

---

**Your ParkourSpot app is successfully deployed and ready for users! 🎉**
