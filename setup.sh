#!/bin/bash

echo "🚀 Setting up ParkourSpot Flutter App..."
echo "=========================================="

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first."
    echo "   Visit: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI is not installed. Installing..."
    npm install -g firebase-tools
fi

# Check if FlutterFire CLI is installed
if ! command -v flutterfire &> /dev/null; then
    echo "❌ FlutterFire CLI is not installed. Installing..."
    dart pub global activate flutterfire_cli
fi

echo "✅ Dependencies checked"

# Install Flutter dependencies
echo "📦 Installing Flutter dependencies..."
flutter pub get

# Create necessary directories
echo "📁 Creating project structure..."
mkdir -p assets/images
mkdir -p assets/icons
mkdir -p functions
mkdir -p .firebase/emulator-data

# Initialize emulator seed data if available
SEED_DATA_DIR="scripts/seed-data"
EMULATOR_DATA_DIR=".firebase/emulator-data"
if [ -d "$SEED_DATA_DIR" ] && [ -f "$SEED_DATA_DIR/firebase-export-metadata.json" ]; then
    echo "🌱 Initializing emulator data from seed data..."
    cp -r "$SEED_DATA_DIR"/* "$EMULATOR_DATA_DIR/"
    echo "✅ Emulator seed data initialized"
else
    echo "ℹ️  No seed data found. Emulators will start with empty data."
fi

# Initialize Firebase (if not already done)
if [ ! -f ".firebaserc" ]; then
    echo "🔥 Initializing Firebase project..."
    echo "   Please create a new Firebase project or select an existing one"
    firebase init
else
    echo "✅ Firebase already initialized"
fi

# Configure FlutterFire
echo "🔧 Configuring FlutterFire..."
echo "   Please enter your Firebase project ID when prompted"
flutterfire configure

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "1. Copy env.example to .env and fill in your Firebase configuration"
echo "2. Run 'flutterfire configure' to set up Firebase options"
echo "3. Run 'flutter run' to test the app"
echo ""
echo "For detailed setup instructions, see README.md"
