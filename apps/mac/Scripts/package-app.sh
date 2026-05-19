#!/usr/bin/env bash
set -euo pipefail

# Development-only app bundle helper for local smoke tests.
# Public releases must use WhatTheToken.xcodeproj through archive-release.sh.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="WhatTheToken"
CONFIGURATION="${CONFIGURATION:-Debug}"
OUTPUT_DIR="${OUTPUT_DIR:-"$ROOT_DIR/.build/app"}"

case "$CONFIGURATION" in
    debug|Debug)
        CONFIGURATION="Debug"
        ;;
    release|Release)
        CONFIGURATION="Release"
        ;;
    *)
        echo "error: CONFIGURATION must be Debug or Release, got '$CONFIGURATION'" >&2
        exit 64
        ;;
esac

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd -P)"
APP_DIR="$OUTPUT_DIR/$APP_NAME.app"
BUILD_DIR="$OUTPUT_DIR/xcodebuild"

xcodebuild \
    -project "$ROOT_DIR/WhatTheToken.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    CODE_SIGNING_ALLOWED=NO \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
    build >&2

rm -rf "$APP_DIR"
cp -R "$BUILD_DIR/$APP_NAME.app" "$APP_DIR"

WIDGET_EXTENSION="$APP_DIR/Contents/PlugIns/WhatTheTokenWidget.appex"
if [[ ! -d "$WIDGET_EXTENSION" ]]; then
    echo "error: expected embedded widget extension at $WIDGET_EXTENSION" >&2
    exit 1
fi

SPARKLE_FRAMEWORK="$APP_DIR/Contents/Frameworks/Sparkle.framework"
if [[ -d "$SPARKLE_FRAMEWORK" ]]; then
    # --deep is intentional for this ad-hoc development helper. Public release
    # signing must stay in archive-release.sh and ExportOptions.DeveloperID.plist.
    codesign --force --deep --sign - "$SPARKLE_FRAMEWORK" >&2
else
    echo "note: Sparkle.framework not present, skipping re-sign" >&2
fi
codesign --force --sign - --entitlements "$ROOT_DIR/Packaging/WhatTheTokenWidget.entitlements" "$WIDGET_EXTENSION" >&2
codesign --force --sign - --entitlements "$ROOT_DIR/Packaging/WhatTheToken.entitlements" "$APP_DIR" >&2
codesign --verify --strict --verbose=2 "$APP_DIR" >&2
codesign --verify --strict --verbose=2 "$WIDGET_EXTENSION" >&2

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
"$LSREGISTER" -f -R -trusted "$APP_DIR" >&2
REGISTERED_WIDGET=0
PLUGIN_OUTPUT=""
for attempt in 1 2 3 4 5; do
    PLUGIN_OUTPUT="$(pluginkit -m -A -i com.whatthetoken.mac.widget -vv 2>&1 || true)"
    if grep -qF "Path = $WIDGET_EXTENSION" <<<"$PLUGIN_OUTPUT"; then
        REGISTERED_WIDGET=1
        break
    fi
    if [[ "$attempt" != 5 ]]; then
        sleep 1
    fi
done
if [[ "$REGISTERED_WIDGET" -ne 1 ]]; then
    printf '%s\n' "$PLUGIN_OUTPUT" >&2
    echo "error: expected PlugInKit to register widget at $WIDGET_EXTENSION" >&2
    exit 1
fi

echo "Development-only app bundle. Do not notarize or publish this artifact." >&2
echo "$APP_DIR"
