#!/bin/bash

echo "🔥 Starting Firebase Emulators..."
echo "=================================="

# Add Java to PATH if installed via Homebrew
if [ -d "/opt/homebrew/opt/openjdk@17/bin" ]; then
    export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
fi

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI is not installed."
    echo "   Install it with: npm install -g firebase-tools"
    exit 1
fi

# Check if Java is installed (required for emulators)
if ! command -v java &> /dev/null; then
    echo "⚠️  Java is not installed. Some emulators may not work."
    echo "   Install Java with: brew install openjdk@17"
    echo "   Then add to PATH: export PATH=\"/opt/homebrew/opt/openjdk@17/bin:\$PATH\""
    exit 1
fi

# Check and install Firebase Functions dependencies if needed
if [ -d "functions" ] && [ -f "functions/package.json" ]; then
    if [ ! -d "functions/node_modules" ]; then
        echo "📦 Installing Firebase Functions dependencies..."
        (cd functions && npm install)
    else
        echo "✅ Firebase Functions dependencies already installed"
    fi
fi

# Set emulator data directory
EMULATOR_DATA_DIR=".firebase/emulator-data"
SEED_DATA_DIR="scripts/seed-data"

# Create data directory if it doesn't exist
mkdir -p "$EMULATOR_DATA_DIR"

# Initialize from seed data if emulator data doesn't exist
if [ ! -f "$EMULATOR_DATA_DIR/firebase-export-metadata.json" ]; then
    if [ -d "$SEED_DATA_DIR" ] && [ -f "$SEED_DATA_DIR/firebase-export-metadata.json" ]; then
        echo "🌱 Initializing emulator data from seed data..."
        cp -r "$SEED_DATA_DIR"/* "$EMULATOR_DATA_DIR/"
        echo "✅ Seed data copied to emulator data directory"
    else
        echo "ℹ️  No seed data found. Starting with empty emulators."
        echo "   Seed data location: $SEED_DATA_DIR"
    fi
fi

echo "🚀 Starting emulators..."
echo ""
echo "📦 Emulator data will be saved to: $EMULATOR_DATA_DIR"
echo "   Data will be automatically exported when emulators shut down"
echo ""
echo "Press Ctrl+C to stop the emulators"
echo ""

# Start emulators with export-on-exit and import flags
# --export-on-exit: automatically exports data when emulators shut down
# --import: imports existing data if available
firebase emulators:start \
  --only auth,firestore,storage,functions \
  --export-on-exit="$EMULATOR_DATA_DIR" \
  --import="$EMULATOR_DATA_DIR"

