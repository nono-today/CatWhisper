#!/bin/bash
#
# CatWhisper — Build, Sign, Notarize, and Package
#
# Prerequisites:
#   1. Apple Developer Program membership ($99/year)
#   2. Create a "Developer ID Application" certificate in Keychain Access
#   3. Create an app-specific password at https://appleid.apple.com
#   4. Store credentials (run once):
#        xcrun notarytool store-credentials "catwhisper-notary" \
#          --apple-id "YOUR_APPLE_ID" \
#          --team-id "YOUR_TEAM_ID" \
#          --password "YOUR_APP_SPECIFIC_PASSWORD"
#   5. Update the variables below:

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────
APP_NAME="CatWhisper"
BUNDLE_ID="com.cat.whisper"
DEVELOPER_ID="Developer ID Application: Frank Lin (766AZHGT3J)"
NOTARY_PROFILE="catwhisper-notary"                              # ← Must match store-credentials name
# ──────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/dist"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
ENTITLEMENTS="$SCRIPT_DIR/CatWhisper.entitlements"

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ─── Step 1: Build Release ────────────────────────────────────────────
echo "▸ Building $APP_NAME (Release)..."
xcodebuild build \
  -scheme "$APP_NAME" \
  -destination 'platform=OS X' \
  -configuration Release \
  -skipPackagePluginValidation \
  -quiet

# Locate built app bundle in DerivedData
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
RELEASE_APP=$(find "$DERIVED_DATA"/${APP_NAME}-*/Build/Products/Release \
  -maxdepth 1 -name "$APP_NAME.app" -type d 2>/dev/null | head -1)

if [ -z "$RELEASE_APP" ]; then
  echo "✗ $APP_NAME.app not found in DerivedData"
  exit 1
fi

echo "  App: $RELEASE_APP"

# ─── Step 2: Copy .app Bundle ─────────────────────────────────────────
# The built bundle already contains the binary, Info.plist, Assets.car,
# AppIcon, and companion bundles (MLX, etc.) — re-sign it below.
echo "▸ Copying $APP_NAME.app..."
cp -R "$RELEASE_APP" "$APP_BUNDLE"

# ─── Step 3: Code Sign ────────────────────────────────────────────────
echo "▸ Code signing..."

# Sign embedded bundles first
find "$APP_BUNDLE/Contents/Resources" -name "*.bundle" -type d | while read -r bundle; do
  codesign --force --options runtime \
    --sign "$DEVELOPER_ID" \
    --timestamp \
    "$bundle"
done

# Sign the main app
codesign --force --options runtime \
  --sign "$DEVELOPER_ID" \
  --entitlements "$ENTITLEMENTS" \
  --timestamp \
  "$APP_BUNDLE"

echo "  Verifying signature..."
codesign --verify --deep --strict "$APP_BUNDLE"
echo "  ✓ Signature valid"

# ─── Step 4: Create DMG ──────────────────────────────────────────────
echo "▸ Creating DMG..."
hdiutil create -volname "$APP_NAME" \
  -srcfolder "$APP_BUNDLE" \
  -ov -format UDZO \
  "$DMG_PATH" \
  -quiet

# Sign the DMG
codesign --force --sign "$DEVELOPER_ID" --timestamp "$DMG_PATH"

echo "  ✓ $DMG_PATH"

# ─── Step 5: Notarize ────────────────────────────────────────────────
echo "▸ Submitting for notarization (this may take a few minutes)..."
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

# ─── Step 6: Staple ──────────────────────────────────────────────────
echo "▸ Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"

# ─── Done ─────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════"
echo "  ✓ $APP_NAME is ready for distribution!"
echo "  $DMG_PATH"
echo "═══════════════════════════════════════════════"
