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
- Initialize emulator seed data (for local development)

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
FIREBASE_MESSAGING_SENDER_ID=your_sender_id_here
FIREBASE_PROJECT_ID=your_project_id_here
FIREBASE_AUTH_DOMAIN=parkour.spot
FIREBASE_STORAGE_BUCKET=your_project_id.firebasestorage.app
FIREBASE_MEASUREMENT_ID=your_measurement_id_here
```

### Backend Google Maps API key

The autocomplete and geocoding features use a server-side Google Maps API key via Firebase Functions secrets. Make sure to set the secret in your Firebase project:

```bash
firebase functions:secrets:set GOOGLE_MAPS_API_KEY
```

This key should have at least the following APIs enabled:

- Places API
- Geocoding API

The Flutter client calls callable functions `placesAutocomplete`, `placeDetails`, `geocodeCoordinates`, and `reverseGeocodeAddress`, which proxy Google APIs securely using the backend key.

### 4. **Run the App Locally**

See the [Local Development](#local-development) section below for detailed instructions on running the app with either Firebase production instance or emulators.

## 🛠️ Development

### **Prerequisites**
- **Flutter SDK**: 3.9.0 or higher
- **Dart SDK**: 3.9.0 or higher
- **Firebase CLI**: Latest version
- **Node.js**: 18.0.0 or higher

### **Common Workflows**

#### **Local Development**

**With Firebase Production Instance:**
```bash
# Run the app locally (requires Firebase project access)
./scripts/run_local.sh
```

**With Firebase Emulators:**
```bash
# Terminal 1: Start Firebase emulators
./scripts/start_emulators.sh

# Terminal 2: Run the app with emulators
./scripts/run_local_with_emulators.sh
```

**🌱 Emulator Seed Data**: When you start emulators for the first time, seed data from `scripts/seed-data/` is automatically copied to `.firebase/emulator-data/`. This gives you a working dataset with test users, spots, and other sample data to develop with. Your changes are automatically saved when you stop the emulators.

#### **Production Build**
```bash
# Build for production
./scripts/build_production.sh
```

#### **Firebase Deployment**
```bash
# Deploy hosting
firebase deploy --only hosting

# Deploy functions
firebase deploy --only functions

# Deploy indexes
firebase deploy --only firestore:indexes
```

### **Other Development Scripts**
```bash
# Development build
./scripts/build_development.sh
```

### **Emulator Data Management**

The project includes seed data for Firebase emulators to help new developers get started quickly.

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

### **Testing**
```bash
# All tests
flutter test

# With coverage
flutter test --coverage
```

**Note**: Currently there are no tests implemented.

## 🚀 Building & Deployment

> **Note**: For common workflows, see the [Common Workflows](#common-workflows) section above.


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
