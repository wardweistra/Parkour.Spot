#!/bin/bash

echo "🚀 Building ParkourSpot for Production..."

# Load environment variables
if [ -f ".env.production" ]; then
    export $(cat .env.production | grep -v '^#' | xargs)
elif [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "❌ No environment file found. Please create .env or .env.production"
    exit 1
fi

# Validate required variables
required_vars=("FIREBASE_API_KEY" "FIREBASE_APP_ID_WEB" "FIREBASE_PROJECT_ID")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Missing required environment variable: $var"
        exit 1
    fi
done

echo "✅ Environment variables loaded"

# Build Flutter app
echo "📱 Building Flutter app..."
flutter build web --wasm \
  --dart-define=FIREBASE_API_KEY="$FIREBASE_API_KEY" \
  --dart-define=FIREBASE_APP_ID_WEB="$FIREBASE_APP_ID_WEB" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="$FIREBASE_MESSAGING_SENDER_ID" \
  --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=FIREBASE_AUTH_DOMAIN="$FIREBASE_AUTH_DOMAIN" \
  --dart-define=FIREBASE_STORAGE_BUCKET="$FIREBASE_STORAGE_BUCKET" \
  --dart-define=FIREBASE_MEASUREMENT_ID="$FIREBASE_MEASUREMENT_ID"

echo "🎉 Production build complete!"
