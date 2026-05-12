#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/WhatTheToken.xcodeproj"
SCHEME="WhatTheToken"
CONFIGURATION="Release"
ARCHIVE_PATH="$ROOT_DIR/.build/archive-smoke/WhatTheToken.xcarchive"
VERSION=""
BUILD=""

. "$ROOT_DIR/Scripts/release-inputs.sh"

usage() {
    printf 'Usage: %s --version <version> --build <build> [--archive-path <path>]\n' "$0"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            VERSION="${2:-}"
            shift 2
            ;;
        --build)
            BUILD="${2:-}"
            shift 2
            ;;
        --archive-path)
            ARCHIVE_PATH="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 64
            ;;
    esac
done

if [[ -z "$VERSION" || -z "$BUILD" ]]; then
    usage >&2
    exit 64
fi

validate_release_version "$VERSION"
validate_release_build "$BUILD"

rm -rf "$ARCHIVE_PATH"
mkdir -p "$(dirname "$ARCHIVE_PATH")"

xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    DEVELOPMENT_TEAM="" \
    archive >&2

APP_PATH="$ARCHIVE_PATH/Products/Applications/WhatTheToken.app"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
ASSETS_CAR="$APP_PATH/Contents/Resources/Assets.car"
PRIVACY_INFO="$APP_PATH/Contents/Resources/PrivacyInfo.xcprivacy"
BINARY_PATH="$APP_PATH/Contents/MacOS/WhatTheTokenMac"

if [[ ! -d "$APP_PATH" ]]; then
    printf 'Archived app not found: %s\n' "$APP_PATH" >&2
    exit 66
fi

if [[ ! -f "$INFO_PLIST" ]]; then
    printf 'Archived Info.plist not found: %s\n' "$INFO_PLIST" >&2
    exit 66
fi

/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST" | grep -Fx "$VERSION" >/dev/null
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST" | grep -Fx "$BUILD" >/dev/null
/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$INFO_PLIST" | grep -Fx "true" >/dev/null
/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$INFO_PLIST" | grep -Fx "AppIcon" >/dev/null
lipo "$BINARY_PATH" -verify_arch arm64 x86_64

if [[ ! -f "$ASSETS_CAR" ]]; then
    printf 'Compiled asset catalog not found: %s\n' "$ASSETS_CAR" >&2
    exit 66
fi

if [[ ! -f "$PRIVACY_INFO" ]]; then
    printf 'Privacy manifest not found: %s\n' "$PRIVACY_INFO" >&2
    exit 66
fi

printf '%s\n' "$APP_PATH"
