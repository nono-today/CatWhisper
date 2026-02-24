#!/bin/bash
# Build and run CatWhisper using xcodebuild (required for Metal shader compilation)
set -e

SCHEME="CatWhisper"
CONFIGURATION="${1:-Release}"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"

echo "Building $SCHEME ($CONFIGURATION)..."
xcodebuild build \
  -scheme "$SCHEME" \
  -destination 'platform=OS X' \
  -configuration "$CONFIGURATION" \
  -skipPackagePluginValidation \
  -quiet

# Find built binary in DerivedData
BINARY=$(find "$DERIVED_DATA"/CatWhisper-*/Build/Products/"$CONFIGURATION"/ \
  -maxdepth 1 -name "$SCHEME" -type f 2>/dev/null | head -1)

if [ -z "$BINARY" ] || [ ! -f "$BINARY" ]; then
  echo "Error: Binary not found in DerivedData"
  exit 1
fi

BUILD_DIR=$(dirname "$BINARY")
echo "Launching $SCHEME from $BUILD_DIR..."
DYLD_FRAMEWORK_PATH="$BUILD_DIR/PackageFrameworks:$BUILD_DIR" \
  exec "$BINARY" "$@"
