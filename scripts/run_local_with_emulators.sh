#!/bin/bash

echo "🚀 Starting ParkourSpot locally with Firebase Emulators..."
echo "=========================================================="
echo ""
echo "📋 This script runs the Flutter app configured to use Firebase emulators."
echo "   This is intended for developers who don't have access to the"
echo "   Firebase production instance."
echo ""
echo "⚠️  KNOWN ISSUE: Currently experiencing CORS issues between the"
echo "   running app and emulator cloud functions. This workflow is"
echo "   in progress and may require additional configuration."
echo ""

# Check if .env.emulator file exists, if not, create it
if [ ! -f ".env.emulator" ]; then
    echo "📝 Creating .env.emulator file with dummy values..."
    cat > .env.emulator << 'EOF'
# Firebase Configuration for Local Emulator Development
# These are dummy values - emulators don't require real Firebase credentials
FIREBASE_API_KEY=dummy-api-key-for-emulator
FIREBASE_APP_ID_WEB=1:123456789:web:abcdef
FIREBASE_MESSAGING_SENDER_ID=123456789
FIREBASE_PROJECT_ID=parkourspot-93c90
FIREBASE_AUTH_DOMAIN=localhost
FIREBASE_STORAGE_BUCKET=parkourspot-93c90.firebasestorage.app
FIREBASE_MEASUREMENT_ID=G-XXXXXXXXXX
EOF
    echo "✅ Created .env.emulator file"
fi

# Load environment variables from .env.emulator
export $(cat .env.emulator | grep -v '^#' | xargs)

echo "✅ Environment variables loaded from .env.emulator"
echo ""
echo "📝 Prerequisites:"
echo "   1. Firebase emulators must be running in another terminal"
echo "   2. Start them with: ./scripts/start_emulators.sh"
echo ""
echo "⚠️  Remember: This workflow currently has CORS issues with cloud functions."
echo ""
read -p "Press Enter when emulators are running, or Ctrl+C to cancel..."

# Port configuration
WEB_PORT=8080

# Run Flutter web with dart-define and USE_EMULATOR flag
echo "🌐 Starting Flutter web server on port $WEB_PORT..."
flutter run -d web-server --web-port $WEB_PORT \
  --dart-define=USE_EMULATOR=true \
  --dart-define=FIREBASE_API_KEY="$FIREBASE_API_KEY" \
  --dart-define=FIREBASE_APP_ID_WEB="$FIREBASE_APP_ID_WEB" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="$FIREBASE_MESSAGING_SENDER_ID" \
  --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=FIREBASE_AUTH_DOMAIN="$FIREBASE_AUTH_DOMAIN" \
  --dart-define=FIREBASE_STORAGE_BUCKET="$FIREBASE_STORAGE_BUCKET" \
  --dart-define=FIREBASE_MEASUREMENT_ID="$FIREBASE_MEASUREMENT_ID"

