#!/bin/bash

echo "🌱 Updating Seed Data from Current Emulator Data..."
echo "===================================================="

# Set directories
EMULATOR_DATA_DIR=".firebase/emulator-data"
SEED_DATA_DIR="scripts/seed-data"

# Check if emulator data exists
if [ ! -d "$EMULATOR_DATA_DIR" ] || [ ! -f "$EMULATOR_DATA_DIR/firebase-export-metadata.json" ]; then
    echo "❌ No emulator data found at: $EMULATOR_DATA_DIR"
    echo ""
    echo "   To create seed data:"
    echo "   1. Start emulators: ./scripts/start_emulators.sh"
    echo "   2. Add some test data through the app"
    echo "   3. Stop emulators (Ctrl+C) - data will be auto-exported"
    echo "   4. Run this script again"
    exit 1
fi

# Create seed data directory if it doesn't exist
mkdir -p "$SEED_DATA_DIR"

echo "📦 Copying emulator data to seed data directory..."
echo "   From: $EMULATOR_DATA_DIR"
echo "   To:   $SEED_DATA_DIR"
echo ""

# Remove old seed data
rm -rf "$SEED_DATA_DIR"/*

# Copy current emulator data to seed data
cp -r "$EMULATOR_DATA_DIR"/* "$SEED_DATA_DIR/"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Seed data updated successfully!"
    echo "   Location: $SEED_DATA_DIR"
    echo ""
    echo "💡 Next steps:"
    echo "   - Commit the seed data to git so new developers can use it"
    echo "   - New developers will automatically get this data when they run ./scripts/start_emulators.sh"
else
    echo ""
    echo "❌ Failed to update seed data"
    exit 1
fi

