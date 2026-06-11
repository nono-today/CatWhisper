#!/bin/bash
# Build and run CatWhisper using xcodebuild (required for Metal shader compilation)
set -e

SCHEME="CatWhisper"
CONFIGURATION="${1:-Release}"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEV_APP="$SCRIPT_DIR/dist/$SCHEME.app"

echo "Building $SCHEME ($CONFIGURATION)..."
xcodebuild build \
  -scheme "$SCHEME" \
  -destination 'platform=OS X' \
  -configuration "$CONFIGURATION" \
  -skipPackagePluginValidation \
  -quiet

# Find built app bundle in DerivedData
BUILT_APP=$(find "$DERIVED_DATA"/CatWhisper-*/Build/Products/"$CONFIGURATION" \
  -maxdepth 1 -name "$SCHEME.app" -type d 2>/dev/null | head -1)

if [ -z "$BUILT_APP" ]; then
  echo "Error: $SCHEME.app not found in DerivedData"
  exit 1
fi

echo "  App: $BUILT_APP"

# Kill any running instance so we can replace the bundle
pkill -x "$SCHEME" 2>/dev/null || true
sleep 0.5

# Copy the complete built bundle (binary, Info.plist, Assets.car, companion bundles)
rm -rf "$DEV_APP"
mkdir -p "$(dirname "$DEV_APP")"
cp -R "$BUILT_APP" "$DEV_APP"

echo "Launching $SCHEME..."
open -n "$DEV_APP"
