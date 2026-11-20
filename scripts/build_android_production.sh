#!/bin/bash

# Build the signed Android App Bundle (.aab) for Google Play.
#
# Prerequisites:
#   - android/key.properties + upload keystore (see android/key.properties.example)
#   - GOOGLE_MAPS_ANDROID_API_KEY in android/local.properties or the environment
#   - android/app/google-services.json for the production Firebase project
#   - .env.production or .env with the shared Firebase variables
#
# Bump `version:` in pubspec.yaml first: Play rejects a versionCode it has seen.

set -euo pipefail

cd "$(dirname "$0")/.."

echo "🚀 Building ParkourSpot Android release for Google Play..."

# Load environment variables
if [ -f ".env.production" ]; then
    ENV_FILE=".env.production"
elif [ -f ".env" ]; then
    ENV_FILE=".env"
else
    echo "❌ No environment file found. Please create .env or .env.production"
    exit 1
fi
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

# Release signing: without key.properties Gradle silently falls back to the
# debug key, which Play does not accept.
if [ ! -f "android/key.properties" ]; then
    echo "❌ android/key.properties is missing (see android/key.properties.example)"
    exit 1
fi
STORE_FILE=$(grep -E '^storeFile=' android/key.properties | cut -d= -f2-)
if [ -z "$STORE_FILE" ] || [ ! -f "android/$STORE_FILE" ]; then
    echo "❌ Upload keystore not found: android/${STORE_FILE:-<storeFile not set>}"
    exit 1
fi

# Maps key is injected into the manifest by android/app/build.gradle.kts.
if ! grep -qE '^GOOGLE_MAPS_ANDROID_API_KEY=.+' android/local.properties 2>/dev/null \
    && [ -z "${GOOGLE_MAPS_ANDROID_API_KEY:-}" ]; then
    echo "❌ GOOGLE_MAPS_ANDROID_API_KEY not set in android/local.properties or the environment"
    exit 1
fi

# Native Android Firebase uses the app ID and API key from google-services.json,
# not the web values in .env.
GOOGLE_SERVICES="android/app/google-services.json"
if [ ! -f "$GOOGLE_SERVICES" ]; then
    echo "❌ $GOOGLE_SERVICES is missing"
    exit 1
fi
read -r ANDROID_APP_ID ANDROID_API_KEY < <(python3 - "$GOOGLE_SERVICES" <<'EOF'
import json, sys
data = json.load(open(sys.argv[1]))
client = next(
    c for c in data["client"]
    if c["client_info"]["android_client_info"]["package_name"] == "parkour.spot"
)
print(client["client_info"]["mobilesdk_app_id"], client["api_key"][0]["current_key"])
EOF
)

FIREBASE_APP_ID_ANDROID="${FIREBASE_APP_ID_ANDROID:-$ANDROID_APP_ID}"

# Validate required variables
required_vars=("FIREBASE_APP_ID_ANDROID" "FIREBASE_PROJECT_ID" "FIREBASE_MESSAGING_SENDER_ID")
for var in "${required_vars[@]}"; do
    if [ -z "${!var:-}" ]; then
        echo "❌ Missing required environment variable: $var"
        exit 1
    fi
done

VERSION=$(grep -E '^version:' pubspec.yaml | awk '{print $2}')
echo "✅ Configuration loaded from $ENV_FILE (version $VERSION)"

echo "📱 Building app bundle..."
flutter build appbundle --release \
  --dart-define=USE_EMULATOR=false \
  --dart-define=FIREBASE_API_KEY="$ANDROID_API_KEY" \
  --dart-define=FIREBASE_APP_ID_ANDROID="$FIREBASE_APP_ID_ANDROID" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="$FIREBASE_MESSAGING_SENDER_ID" \
  --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=FIREBASE_AUTH_DOMAIN="${FIREBASE_AUTH_DOMAIN:-}" \
  --dart-define=FIREBASE_STORAGE_BUCKET="${FIREBASE_STORAGE_BUCKET:-}" \
  --dart-define=FIREBASE_MEASUREMENT_ID="${FIREBASE_MEASUREMENT_ID:-}"

AAB="build/app/outputs/bundle/release/app-release.aab"
echo "🎉 Android release build complete!"
echo "   Upload to Play Console: $AAB"
