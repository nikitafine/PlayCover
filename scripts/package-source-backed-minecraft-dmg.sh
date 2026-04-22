#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_DIR="$ROOT_DIR/.source-backed-release-build"
RELEASE_ASSETS_DIR="$ROOT_DIR/release-assets/minecraft"
DIST_DIR="${PLAYCOVER_RELEASE_DIST_DIR:-$ROOT_DIR/../dist}"
RELEASE_STAMP="${PLAYCOVER_RELEASE_STAMP:-$(date +%Y%m%d)}"
RELEASE_NAME="${PLAYCOVER_RELEASE_NAME:-PlayCover-Minecraft-source-backed-${RELEASE_STAMP}}"
STAGING_DIR="$DIST_DIR/$RELEASE_NAME"
DMG_PATH="$DIST_DIR/$RELEASE_NAME.dmg"
APP_PATH="$DERIVED_DATA_DIR/Build/Products/Release/PlayCover.app"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

require_path() {
  if [[ ! -e "$1" ]]; then
    echo "Missing required path:"
    echo "  $1"
    exit 1
  fi
}

echo "Packaging source-backed PlayCover Minecraft DMG"
echo "Root: $ROOT_DIR"
echo "Release name: $RELEASE_NAME"

require_command xcodebuild
require_command hdiutil
require_command codesign
require_command rg
require_command ditto

require_path "$RELEASE_ASSETS_DIR"
require_path "$RELEASE_ASSETS_DIR/Install Minecraft IPA.sh"
require_path "$RELEASE_ASSETS_DIR/Extras/install-minecraft-ipa.sh"
require_path "$RELEASE_ASSETS_DIR/Extras/apply-minecraft-working-state.sh"
require_path "$RELEASE_ASSETS_DIR/Extras/working-state/playcover-settings-minecraft.plist"
require_path "$RELEASE_ASSETS_DIR/Extras/working-state/minecraft-entitlements.template.plist"

mkdir -p "$DIST_DIR"

echo
echo "1. Building vendored PlayTools"
"$ROOT_DIR/scripts/build-vendored-playtools.sh"

echo
echo "2. Building PlayCover.app from source"
rm -rf "$DERIVED_DATA_DIR"
xcodebuild build \
  -project "$ROOT_DIR/PlayCover.xcodeproj" \
  -scheme PlayCover \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="-" \
  SWIFT_ENABLE_EXPLICIT_MODULES=NO \
  CLANG_ENABLE_EXPLICIT_MODULES=NO

require_path "$APP_PATH"

echo
echo "3. Staging release bundle"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
ditto "$APP_PATH" "$STAGING_DIR/PlayCover.app"
ditto "$RELEASE_ASSETS_DIR" "$STAGING_DIR"
ln -sfn /Applications "$STAGING_DIR/Applications"
find "$STAGING_DIR" -type f -name '*.sh' -exec chmod 755 {} +

echo
echo "4. Ad-hoc signing staged PlayCover.app"
codesign --force --deep --sign - "$STAGING_DIR/PlayCover.app"

echo
echo "5. Verifying staged release contents"
if rg -n "/Users/|working-state-20260420|playcover-tests/PlayCover|playcover-tests/PlayTools" "$STAGING_DIR" -S; then
  echo
  echo "Found machine-local or old snapshot paths in staged release bundle."
  exit 1
fi

echo
echo "6. Creating DMG"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "${RELEASE_NAME//-/ }" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo
echo "Created staging folder:"
echo "  $STAGING_DIR"
echo "Created DMG:"
echo "  $DMG_PATH"
