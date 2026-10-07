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

echo "🚀 Building about.parkour.spot from production snapshots..."

# Load environment variables (same files as ./scripts/build_production.sh)
if [ -f ".env.production" ]; then
    load_env_file .env.production
elif [ -f ".env" ]; then
    load_env_file .env
else
    echo "❌ No environment file found. Please create .env or .env.production"
    echo "Set GOOGLE_APPLICATION_CREDENTIALS to a Firebase service account JSON file."
    exit 1
fi

# The about site uses fixtures unless this file is set. Do not use
# `npm run build:fixtures`.
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

echo "✅ Using Firestore snapshots (fixtures disabled)"
echo "📄 Building Astro site..."
cd about
npx astro build

echo "🎉 About site production build complete! Output: about/dist"
