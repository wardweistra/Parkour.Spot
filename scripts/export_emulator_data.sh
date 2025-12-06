#!/bin/bash

echo "💾 Exporting Firebase Emulator Data..."
echo "======================================="

# Set emulator data directory
EMULATOR_DATA_DIR=".firebase/emulator-data"

# Check if emulators are running
if ! pgrep -f "firebase emulators:start" > /dev/null; then
    echo "⚠️  Firebase emulators don't appear to be running."
    echo "   This script exports data from running emulators."
    echo ""
    echo "   To export data:"
    echo "   1. Make sure emulators are running"
    echo "   2. Run: firebase emulators:export $EMULATOR_DATA_DIR"
    echo ""
    echo "   Or simply stop the emulators (Ctrl+C) - they will auto-export"
    exit 1
fi

# Create data directory if it doesn't exist
mkdir -p "$EMULATOR_DATA_DIR"

echo "📦 Exporting emulator data to: $EMULATOR_DATA_DIR"
echo ""

# Export emulator data
firebase emulators:export "$EMULATOR_DATA_DIR"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Emulator data exported successfully!"
    echo "   Location: $EMULATOR_DATA_DIR"
else
    echo ""
    echo "❌ Failed to export emulator data"
    exit 1
fi

