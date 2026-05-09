#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION=""
BUILD=""
MODE="dry-run"

usage() {
    printf 'Usage: %s --version <version> --build <build> [--mode dry-run|unsigned-smoke|signed]\n' "$0"
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
        --mode)
            MODE="${2:-}"
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

step() {
    printf '[%s]\n' "$1"
}

case "$MODE" in
    dry-run)
        "$ROOT_DIR/Scripts/archive-release.sh" --version "$VERSION" --build "$BUILD" --dry-run
        "$ROOT_DIR/Scripts/create-dmg.sh" --version "$VERSION" --dry-run
        "$ROOT_DIR/Scripts/sign-dmg.sh" --dmg "$ROOT_DIR/.build/dmg/WhatTheToken-$VERSION.dmg" --dry-run
        "$ROOT_DIR/Scripts/notarize-dmg.sh" --dmg "$ROOT_DIR/.build/dmg/WhatTheToken-$VERSION.dmg" --dry-run
        "$ROOT_DIR/Scripts/verify-release-artifacts.sh" --dmg "$ROOT_DIR/.build/dmg/WhatTheToken-$VERSION.dmg" --app "$ROOT_DIR/.build/export/WhatTheToken.app" --dry-run
        ;;
    unsigned-smoke)
        APP_PATH="$("$ROOT_DIR/Scripts/smoke-archive-unsigned.sh" --version "$VERSION" --build "$BUILD")"
        DMG_PATH="$ROOT_DIR/.build/dmg-smoke/WhatTheToken-$VERSION-unsigned-smoke.dmg"
        "$ROOT_DIR/Scripts/create-dmg.sh" --version "$VERSION" --app "$APP_PATH" --output "$DMG_PATH"
        hdiutil verify "$DMG_PATH" >/dev/null
        MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/whatthetoken-smoke-dmg.XXXXXX")"
        trap 'hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true; rm -rf "$MOUNT_DIR"' EXIT
        hdiutil attach "$DMG_PATH" -readonly -nobrowse -mountpoint "$MOUNT_DIR" >/dev/null
        test -d "$MOUNT_DIR/WhatTheToken.app"
        test -L "$MOUNT_DIR/Applications"
        hdiutil detach "$MOUNT_DIR" >/dev/null
        trap - EXIT
        rm -rf "$MOUNT_DIR"
        shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"
        printf '%s\n' "$DMG_PATH"
        ;;
    signed)
        APP_PATH="$ROOT_DIR/.build/export/WhatTheToken.app"
        DMG_PATH="$ROOT_DIR/.build/dmg/WhatTheToken-$VERSION.dmg"

        step "1/6 Verify release provenance"
        "$ROOT_DIR/Scripts/verify-release-provenance.sh" --version "$VERSION" --build "$BUILD"

        step "2/6 Archive and export"
        "$ROOT_DIR/Scripts/archive-release.sh" --version "$VERSION" --build "$BUILD"
        test -d "$APP_PATH"
        test -f "$APP_PATH/Contents/Info.plist"
        test -f "$APP_PATH/Contents/MacOS/WhatTheTokenMac"
        lipo -verify_arch arm64 x86_64 "$APP_PATH/Contents/MacOS/WhatTheTokenMac"

        step "3/6 Create DMG"
        "$ROOT_DIR/Scripts/create-dmg.sh" --version "$VERSION"
        test -f "$DMG_PATH"
        hdiutil verify "$DMG_PATH" >/dev/null

        step "4/6 Sign DMG"
        "$ROOT_DIR/Scripts/sign-dmg.sh" --dmg "$DMG_PATH"
        codesign --verify --verbose=2 "$DMG_PATH"

        step "5/6 Notarize and staple"
        "$ROOT_DIR/Scripts/notarize-dmg.sh" --dmg "$DMG_PATH"
        xcrun stapler validate "$DMG_PATH"

        step "6/6 Verify release artifacts"
        "$ROOT_DIR/Scripts/verify-release-artifacts.sh" \
            --dmg "$DMG_PATH" \
            --app "$APP_PATH"
        ;;
    *)
        usage >&2
        exit 64
        ;;
esac
