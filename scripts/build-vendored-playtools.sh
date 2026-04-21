#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build-vendored-playtools"
PRODUCT_DIR="$BUILD_DIR/Release-iphoneos"
OUTPUT_FRAMEWORK_DIR="$ROOT_DIR/Carthage/Build/PlayTools.xcframework/ios-arm64/PlayTools.framework"

echo "Building vendored PlayTools from $ROOT_DIR/Vendor/PlayTools"

/bin/rm -rf "$BUILD_DIR"
/bin/mkdir -p "$BUILD_DIR"
/bin/mkdir -p "$(dirname "$OUTPUT_FRAMEWORK_DIR")"

xcodebuild build \
  -project "$ROOT_DIR/Vendor/PlayTools/PlayTools.xcodeproj" \
  -scheme PlayTools \
  -configuration Release \
  -sdk iphoneos \
  -arch arm64 \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  BUILD_DIR="$BUILD_DIR" \
  SWIFT_ENABLE_EXPLICIT_MODULES=NO \
  CLANG_ENABLE_EXPLICIT_MODULES=NO

/bin/rm -rf "$OUTPUT_FRAMEWORK_DIR"
/bin/cp -R "$PRODUCT_DIR/PlayTools.framework" "$OUTPUT_FRAMEWORK_DIR"

xcrun vtool \
  -set-build-version maccatalyst 15.0 26.2 \
  -replace \
  -output "$OUTPUT_FRAMEWORK_DIR/PlayTools" \
  "$PRODUCT_DIR/PlayTools.framework/PlayTools"

/usr/bin/codesign --force --sign - "$OUTPUT_FRAMEWORK_DIR/PlugIns/AKInterface.bundle"
/usr/bin/codesign --force --sign - "$OUTPUT_FRAMEWORK_DIR/PlayTools"
/usr/bin/codesign --force --deep --sign - "$OUTPUT_FRAMEWORK_DIR"

echo
echo "Prepared framework at:"
echo "  $OUTPUT_FRAMEWORK_DIR"
