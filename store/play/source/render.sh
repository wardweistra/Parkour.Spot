#!/bin/bash
# Re-render the Play Store graphics from frame.html (captions live in its FRAMES list).
# Source screenshots in src/ are release-build captures on a 1080x2400 emulator with
# the status bar cropped off (production data, signed out).
set -euo pipefail
cd "$(dirname "$0")"
OUT=../graphics
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
render() {
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
    --force-device-scale-factor=1 --virtual-time-budget=8000 --window-size="$2" \
    --screenshot="$3" "file://$PWD/frame.html?$1" 2>/dev/null
}
render "mode=feature" 1024,500 "$OUT/feature-graphic.png"
for i in 0 1 2 3 4 5 6; do render "i=$i" 1080,1920 "$OUT/phone-$((i+1)).png"; done
echo "Rendered to $OUT"
