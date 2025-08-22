#!/bin/bash

echo "🔧 Building ParkourSpot for Development..."

# Load environment variables
if [ -f ".env.development" ]; then
    export $(cat .env.development | grep -v '^#' | xargs)
elif [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "❌ No environment file found. Please create .env or .env.development"
    exit 1
fi

# Validate required variables
required_vars=("FIREBASE_API_KEY" "FIREBASE_APP_ID_WEB" "FIREBASE_APP_ID_ANDROID" "FIREBASE_APP_ID_IOS" "FIREBASE_PROJECT_ID")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Missing required environment variable: $var"
        exit 1
    fi
done

echo "✅ Environment variables loaded"

# Build Flutter app
echo "📱 Building Flutter app..."
flutter build web --wasm --debug
# flutter build apk --debug
# flutter build ios --debug --no-codesign

echo "🎉 Development build complete!"
