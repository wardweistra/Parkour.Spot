#!/bin/bash

cd "$(dirname "$0")/.."

echo "🚀 Starting about.parkour.spot from local fixtures..."
echo "=========================================================="
echo ""
echo "📋 This script serves the about site from about/fixtures/."
echo "   It does not read the production Firestore database."
echo "   This is intended for developers who don't have access to the"
echo "   Firebase production instance."
echo ""

if [ ! -d "about/node_modules" ]; then
    echo "❌ About site dependencies are not installed."
    echo "Run: cd about && npm ci"
    exit 1
fi

# Fixtures win even when a service account is already configured in the shell.
unset GOOGLE_APPLICATION_CREDENTIALS
export ABOUT_USE_FIXTURES=1

ABOUT_PORT=4321

echo "✅ Using about/fixtures (production snapshots disabled)"
echo "🌐 Starting Astro dev server on port $ABOUT_PORT..."
cd about
npx astro dev --port "$ABOUT_PORT"
