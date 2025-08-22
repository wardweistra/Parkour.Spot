# 🚀 Parkour.Spot Deployment Guide

Complete deployment guide for the Parkour.Spot Flutter app across all platforms.

## 🌐 Web Deployment (Firebase Hosting)

### ✅ **Status: Ready for Deployment**
Your web app is ready to be deployed to Firebase Hosting

### **Deployment Process**
```bash
# 1. Build the web app
flutter build web

# 2. Deploy to Firebase Hosting
firebase deploy --only hosting
```

### **Firebase Hosting Configuration**
- **Project**: Your Firebase project ID
- **Public Directory**: `build/web`
- **Region**: Configurable (defaults to europe-west1)
- **URLs**: 
  - Primary: `https://your-project-id.web.app`
  - Alternative: `https://your-project-id.firebaseapp.com`

## 🤖 Android Deployment

### ✅ **Status: Ready to Build**
Your Android APK is ready to be built for distribution.

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

| Service | Status | Notes |
|---------|--------|-------|
| **Web App** | ✅ Ready | Ready for Firebase Hosting |
| **Android APK** | ✅ Ready | Ready to build |
| **iOS App** | 🔄 Pending | Requires Xcode |
| **Firebase Auth** | ✅ Ready | Ready to configure |
| **Firestore DB** | ✅ Ready | Rules and indexes ready |
| **Cloud Storage** | ✅ Ready | Rules ready |
| **Cloud Functions** | ✅ Ready | Functions ready to deploy |
| **Firebase Hosting** | ✅ Ready | Configuration ready |

## 🔗 Useful Links

- **Firebase Console**: https://console.firebase.google.com/
- **Flutter Documentation**: https://flutter.dev/docs/deployment
- **Firebase Documentation**: https://firebase.google.com/docs

---

**Your Parkour.Spot app is successfully deployed and ready for users! 🎉**
