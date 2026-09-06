#!/bin/bash

# Run ParkourSpot on an Android emulator/device against Firebase emulators.
# Prerequisites: ./scripts/start_emulators.sh in another terminal.

set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f ".env.emulator" ]; then
  echo "Missing .env.emulator — copy from env.example or run scripts/run_local_with_emulators.sh once."
  exit 1
fi

# shellcheck disable=SC2046
export $(grep -v '^#' .env.emulator | xargs)

DEVICE="${1:-}"
if [ -z "$DEVICE" ]; then
  echo "Available devices:"
  flutter devices
  echo ""
  echo "Usage: $0 <device_id>"
  echo "Example: $0 emulator-5554"
  exit 1
fi

if [ -z "${FIREBASE_APP_ID_ANDROID:-}" ]; then
  echo "FIREBASE_APP_ID_ANDROID is not set in .env.emulator"
  exit 1
fi

echo "Starting Flutter on $DEVICE (USE_EMULATOR=true, Auth/Firestore via 10.0.2.2)..."
flutter run -d "$DEVICE" \
  --dart-define=USE_EMULATOR=true \
  --dart-define=FIREBASE_API_KEY="$FIREBASE_API_KEY" \
  --dart-define=FIREBASE_APP_ID_ANDROID="$FIREBASE_APP_ID_ANDROID" \
  --dart-define=FIREBASE_APP_ID_WEB="${FIREBASE_APP_ID_WEB:-}" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="$FIREBASE_MESSAGING_SENDER_ID" \
  --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=FIREBASE_AUTH_DOMAIN="$FIREBASE_AUTH_DOMAIN" \
  --dart-define=FIREBASE_STORAGE_BUCKET="$FIREBASE_STORAGE_BUCKET" \
  --dart-define=FIREBASE_MEASUREMENT_ID="${FIREBASE_MEASUREMENT_ID:-}" \
  --dart-define=FIREBASE_WEB_PUSH_VAPID_KEY="${FIREBASE_WEB_PUSH_VAPID_KEY:-}"
