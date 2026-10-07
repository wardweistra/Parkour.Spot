#!/bin/bash

cd "$(dirname "$0")/.."

load_env_file() {
    local file="$1"
    local line key value
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        case "$line" in
            ''|\#*) continue ;;
        esac
        key="${line%%=*}"
        value="${line#*=}"
        if [ "$key" = "$line" ]; then
            continue
        fi
        if [[ "$value" == \"*\" ]]; then
            value="${value:1:$((${#value} - 2))}"
        elif [[ "$value" == \'*\' ]]; then
            value="${value:1:$((${#value} - 2))}"
        fi
        export "$key=$value"
    done < "$file"
}

echo "🚀 Starting about.parkour.spot from production snapshots..."

# Load environment variables (same file as ./scripts/run_production.sh)
if [ ! -f ".env" ]; then
    echo "❌ No .env file found!"
    echo "Set GOOGLE_APPLICATION_CREDENTIALS to a Firebase service account JSON file."
    echo "See env.example."
    exit 1
fi

load_env_file .env

# The about site uses fixtures unless this file is set. Do not call `npm run dev`:
# that script forces ABOUT_USE_FIXTURES=1.
if [ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
    echo "❌ Missing required environment variable: GOOGLE_APPLICATION_CREDENTIALS"
    echo "Point it at a service account JSON that can read Firestore snapshots."
    exit 1
fi

if [[ "$GOOGLE_APPLICATION_CREDENTIALS" != /* ]]; then
    GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/$GOOGLE_APPLICATION_CREDENTIALS"
fi

if [ ! -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
    echo "❌ Service account file not found: $GOOGLE_APPLICATION_CREDENTIALS"
    exit 1
fi

export GOOGLE_APPLICATION_CREDENTIALS
export ABOUT_USE_FIXTURES=0

if [ ! -d "about/node_modules" ]; then
    echo "❌ About site dependencies are not installed."
    echo "Run: cd about && npm ci"
    exit 1
fi

ABOUT_PORT=4321

echo "✅ Using Firestore snapshots (fixtures disabled)"
echo "🌐 Starting Astro dev server on port $ABOUT_PORT..."
cd about
npx astro dev --port "$ABOUT_PORT"
