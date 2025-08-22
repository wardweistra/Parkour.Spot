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
echo "3. Configure platform-specific settings (Android/iOS permissions)"
echo "4. Run 'flutter run' to test the app"
echo ""
echo "For detailed setup instructions, see README.md"
