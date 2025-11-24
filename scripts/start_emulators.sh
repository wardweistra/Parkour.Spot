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

echo "🚀 Starting emulators..."
echo ""
echo "Emulator UI will be available at: http://localhost:4000"
echo ""
echo "Emulator ports:"
echo "  - Firestore: 8082"
echo "  - Auth: 9099"
echo "  - Storage: 9199"
echo "  - Functions: 5001"
echo "  - UI: 4000"
echo ""
echo "Press Ctrl+C to stop the emulators"
echo ""

# Start emulators
firebase emulators:start

