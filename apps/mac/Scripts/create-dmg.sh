#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION=""
APP_PATH="$ROOT_DIR/.build/export/WhatTheToken.app"
OUTPUT=""
VOLUME_NAME="WhatTheToken"
STAGING_DIR=""
DRY_RUN=0

usage() {
    printf 'Usage: %s --version <version> [--app <WhatTheToken.app>] [--output <dmg>] [--dry-run]\n' "$0"
}

quote_command() {
    printf '%q ' "$@"
    printf '\n'
}

run_command() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        quote_command "$@"
    else
        "$@"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            VERSION="${2:-}"
            shift 2
            ;;
        --app)
            APP_PATH="${2:-}"
            shift 2
            ;;
        --output)
            OUTPUT="${2:-}"
            shift 2
            ;;
        --volume-name)
            VOLUME_NAME="${2:-}"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
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

if [[ -z "$VERSION" ]]; then
    usage >&2
    exit 64
fi

OUTPUT="${OUTPUT:-"$ROOT_DIR/.build/dmg/WhatTheToken-$VERSION.dmg"}"
STAGING_DIR="$ROOT_DIR/.build/dmg/staging-$VERSION"

if [[ "$DRY_RUN" -eq 0 && ! -d "$APP_PATH" ]]; then
    printf 'App bundle not found: %s\n' "$APP_PATH" >&2
    exit 66
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
    rm -rf "$STAGING_DIR" "$OUTPUT"
fi

run_command mkdir -p "$STAGING_DIR"
run_command cp -R "$APP_PATH" "$STAGING_DIR/WhatTheToken.app"
run_command ln -s /Applications "$STAGING_DIR/Applications"
run_command mkdir -p "$(dirname "$OUTPUT")"
run_command hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$OUTPUT"

if [[ "$DRY_RUN" -eq 0 ]]; then
    rm -rf "$STAGING_DIR"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'Dry run only. No DMG was created.\n'
else
    printf '%s\n' "$OUTPUT"
fi
