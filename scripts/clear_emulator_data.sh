#!/bin/bash

echo "🔄 Resetting Firebase Emulator Data to Seed Data..."
echo "===================================================="

# Set directories
EMULATOR_DATA_DIR=".firebase/emulator-data"
SEED_DATA_DIR="scripts/seed-data"

# Check if emulators are running
if pgrep -f "firebase emulators:start" > /dev/null; then
    echo "⚠️  WARNING: Firebase emulators are currently running!"
    echo "   Please stop the emulators first before resetting data."
    echo "   Run: pkill -f 'firebase emulators:start'"
    exit 1
fi

# Check if seed data exists
if [ ! -d "$SEED_DATA_DIR" ] || [ ! -f "$SEED_DATA_DIR/firebase-export-metadata.json" ]; then
    echo "⚠️  No seed data found at: $SEED_DATA_DIR"
    echo "   Cannot reset to seed data."
    echo ""
    echo "   Options:"
    echo "   1. Create seed data first: ./scripts/update_seed_data.sh"
    echo "   2. Or manually delete emulator data: rm -rf $EMULATOR_DATA_DIR"
    exit 1
fi

echo "📦 Emulator data directory: $EMULATOR_DATA_DIR"
echo "🌱 Seed data directory: $SEED_DATA_DIR"
echo ""
read -p "Are you sure you want to reset emulator data to seed data? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelled. Emulator data was not reset."
    exit 0
fi

# Remove the current emulator data directory
if [ -d "$EMULATOR_DATA_DIR" ]; then
    rm -rf "$EMULATOR_DATA_DIR"
fi

# Create emulator data directory
mkdir -p "$EMULATOR_DATA_DIR"

# Copy seed data to emulator data directory
cp -r "$SEED_DATA_DIR"/* "$EMULATOR_DATA_DIR/"

if [ $? -eq 0 ]; then
    echo "✅ Emulator data reset successfully!"
    echo "   Emulator data has been reset to match seed data."
    echo "   Next time you start emulators, they will use the seed data."
else
    echo "❌ Failed to reset emulator data"
    exit 1
fi

