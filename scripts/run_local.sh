#!/bin/bash

echo "🚀 Starting ParkourSpot locally..."

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "❌ No .env file found!"
    echo "Please create a .env file with your Firebase configuration."
    echo "See env.example for the required variables."
    exit 1
fi

# Load environment variables
export $(cat .env | grep -v '^#' | xargs)

# Validate required variables
required_vars=("FIREBASE_API_KEY" "FIREBASE_APP_ID_WEB" "FIREBASE_PROJECT_ID")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Missing required environment variable: $var"
        exit 1
    fi
done

echo "✅ Environment variables loaded"

# Run Flutter web with dart-define
echo "🌐 Starting Flutter web server on port 8080..."
flutter run -d web-server --web-port 8080 \
  --dart-define=FIREBASE_API_KEY="$FIREBASE_API_KEY" \
  --dart-define=FIREBASE_APP_ID_WEB="$FIREBASE_APP_ID_WEB" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="$FIREBASE_MESSAGING_SENDER_ID" \
  --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=FIREBASE_AUTH_DOMAIN="$FIREBASE_AUTH_DOMAIN" \
  --dart-define=FIREBASE_STORAGE_BUCKET="$FIREBASE_STORAGE_BUCKET" \
  --dart-define=FIREBASE_MEASUREMENT_ID="$FIREBASE_MEASUREMENT_ID"
