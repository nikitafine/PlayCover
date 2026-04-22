#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build-vendored-playtools"
AKINTERFACE_BUILD_DIR="$BUILD_DIR/akinterface"
PLAYTOOLS_BUILD_DIR="$BUILD_DIR/playtools-iphoneos"
OUTPUT_FRAMEWORK_DIR="$ROOT_DIR/Carthage/Build/PlayTools.xcframework/ios-arm64/PlayTools.framework"
AKINTERFACE_BUNDLE="$AKINTERFACE_BUILD_DIR/AKInterface.bundle"
PLAYTOOLS_FRAMEWORK="$PLAYTOOLS_BUILD_DIR/PlayTools.framework"
PREBUILT_FRAMEWORK_DIR="${PLAYCOVER_PREBUILT_PLAYTOOLS_FRAMEWORK:-}"

echo "Building vendored PlayTools from $ROOT_DIR/Vendor/PlayTools"

/bin/rm -rf "$BUILD_DIR"
/bin/mkdir -p "$BUILD_DIR"
/bin/mkdir -p "$(dirname "$OUTPUT_FRAMEWORK_DIR")"

if [[ -n "$PREBUILT_FRAMEWORK_DIR" ]]; then
  if [[ ! -d "$PREBUILT_FRAMEWORK_DIR" ]]; then
    echo "Prebuilt PlayTools framework not found at:"
    echo "  $PREBUILT_FRAMEWORK_DIR"
    exit 1
  fi

  /bin/rm -rf "$OUTPUT_FRAMEWORK_DIR"
  /bin/mkdir -p "$OUTPUT_FRAMEWORK_DIR"
  /bin/cp -pL "$PREBUILT_FRAMEWORK_DIR/PlayTools" "$OUTPUT_FRAMEWORK_DIR/PlayTools"
  if [[ -d "$PREBUILT_FRAMEWORK_DIR/Modules" ]]; then
    /bin/cp -RL "$PREBUILT_FRAMEWORK_DIR/Modules" "$OUTPUT_FRAMEWORK_DIR/Modules"
  fi
  if [[ -d "$PREBUILT_FRAMEWORK_DIR/PlugIns" ]]; then
    /bin/cp -RL "$PREBUILT_FRAMEWORK_DIR/PlugIns" "$OUTPUT_FRAMEWORK_DIR/PlugIns"
  fi
  if [[ -f "$PREBUILT_FRAMEWORK_DIR/Resources/Info.plist" ]]; then
    /bin/cp -pL "$PREBUILT_FRAMEWORK_DIR/Resources/Info.plist" "$OUTPUT_FRAMEWORK_DIR/Info.plist"
  fi
  for lproj in "$PREBUILT_FRAMEWORK_DIR"/Resources/*.lproj; do
    if [[ -d "$lproj" ]]; then
      /bin/cp -RL "$lproj" "$OUTPUT_FRAMEWORK_DIR/$(basename "$lproj")"
    fi
  done
  /usr/bin/codesign --force --deep --sign - "$OUTPUT_FRAMEWORK_DIR"

  echo
  echo "Prepared prebuilt framework at:"
  echo "  $OUTPUT_FRAMEWORK_DIR"
  exit 0
fi

/bin/mkdir -p "$AKINTERFACE_BUILD_DIR"
/bin/mkdir -p "$PLAYTOOLS_BUILD_DIR/AKInterface.bundle"
/usr/bin/touch "$PLAYTOOLS_BUILD_DIR/AKInterface.bundle/Info.plist"

xcodebuild build \
  -project "$ROOT_DIR/Vendor/PlayTools/PlayTools.xcodeproj" \
  -target AKInterface \
  -configuration Release \
  -sdk macosx \
  -arch arm64 \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CONFIGURATION_BUILD_DIR="$AKINTERFACE_BUILD_DIR" \
  SWIFT_ENABLE_EXPLICIT_MODULES=NO \
  CLANG_ENABLE_EXPLICIT_MODULES=NO

xcodebuild build \
  -project "$ROOT_DIR/Vendor/PlayTools/PlayTools.xcodeproj" \
  -target PlayTools \
  -configuration Release \
  -sdk iphoneos \
  -arch arm64 \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CONFIGURATION_BUILD_DIR="$PLAYTOOLS_BUILD_DIR" \
  SWIFT_ENABLE_EXPLICIT_MODULES=NO \
  CLANG_ENABLE_EXPLICIT_MODULES=NO

/bin/rm -rf "$OUTPUT_FRAMEWORK_DIR"
/bin/cp -R "$PLAYTOOLS_FRAMEWORK" "$OUTPUT_FRAMEWORK_DIR"

xcrun vtool \
  -set-build-version maccatalyst 15.0 26.2 \
  -replace \
  -output "$OUTPUT_FRAMEWORK_DIR/PlayTools" \
  "$PLAYTOOLS_FRAMEWORK/PlayTools"

/bin/rm -rf "$OUTPUT_FRAMEWORK_DIR/PlugIns/AKInterface.bundle"
/bin/mkdir -p "$OUTPUT_FRAMEWORK_DIR/PlugIns"
/bin/cp -R "$AKINTERFACE_BUNDLE" "$OUTPUT_FRAMEWORK_DIR/PlugIns/AKInterface.bundle"

/usr/bin/codesign --force --sign - "$OUTPUT_FRAMEWORK_DIR/PlugIns/AKInterface.bundle"
/usr/bin/codesign --force --sign - "$OUTPUT_FRAMEWORK_DIR/PlayTools"
/usr/bin/codesign --force --deep --sign - "$OUTPUT_FRAMEWORK_DIR"

echo
echo "Prepared framework at:"
echo "  $OUTPUT_FRAMEWORK_DIR"
