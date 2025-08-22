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
flutter build web --wasm
# flutter build apk --release
# flutter build ios --release --no-codesign

echo "🎉 Production build complete!"
