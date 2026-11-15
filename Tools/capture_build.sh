#!/bin/zsh
# Builds and launches a copy of FuzzyBar for screenshots, its clock held at one
# time, so a personality's strip can be retaken on its own and still match the
# rest of the set:
#
#   Tools/capture_build.sh          # held at 08:44, the time the strips show
#   Tools/capture_build.sh 15:50
#
# It is a debug build (the only kind that reads -fuzzyNow) with its own bundle
# identifier, so it keeps its settings apart from an installed FuzzyBar's and
# both can run at once. Quit it from its popover.
set -euo pipefail
cd "$(dirname "$0")/.."

AT="${1:-08:44}"
swift build -c debug --arch arm64
BIN="$(swift build -c debug --arch arm64 --show-bin-path)/FuzzyBar"
[[ -x "$BIN" ]] || { echo "Missing built executable: $BIN" >&2; exit 1; }

# Assembled and signed in a temp dir, for build.sh's reason.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
APP_STAGE="$STAGE/FuzzyBar Capture.app"
mkdir -p "$APP_STAGE/Contents/MacOS" "$APP_STAGE/Contents/Resources"
cp "$BIN" "$APP_STAGE/Contents/MacOS/FuzzyBar"
cp Info.plist "$APP_STAGE/Contents/Info.plist"
cp Assets/AppIcon.icns "$APP_STAGE/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier dev.plumpbug.fuzzybar.capture" \
    -c "Set :CFBundleName FuzzyBar Capture" "$APP_STAGE/Contents/Info.plist"
xattr -cr "$APP_STAGE"
codesign --force --sign - "$APP_STAGE"

APP="build/FuzzyBar Capture.app"
rm -rf "$APP"
mkdir -p build
ditto "$APP_STAGE" "$APP"
open -n "$APP" --args -fuzzyNow "$AT"
echo "Launched $APP, held at $AT"
