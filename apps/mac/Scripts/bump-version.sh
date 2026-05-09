#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT_DIR/Packaging/WhatTheToken.xcconfig"
VERSION=""
BUILD=""

usage() {
    printf 'Usage: %s --version <version> --build <monotonic-integer>\n' "$0"
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

if ! [[ "$BUILD" =~ ^[0-9]+$ ]]; then
    printf 'Build must be a monotonically increasing integer.\n' >&2
    exit 64
fi

CURRENT_BUILD="$(awk -F= '/^[[:space:]]*CURRENT_PROJECT_VERSION[[:space:]]*=/{gsub(/[[:space:]]/, "", $2); print $2}' "$CONFIG")"
if [[ -n "$CURRENT_BUILD" && "$CURRENT_BUILD" =~ ^[0-9]+$ && "$BUILD" -le "$CURRENT_BUILD" ]]; then
    printf 'Build must increase. Current build is %s, requested %s.\n' "$CURRENT_BUILD" "$BUILD" >&2
    exit 65
fi

perl -0pi -e "s/\\nMARKETING_VERSION = .*\\n/\\nMARKETING_VERSION = $VERSION\\n/" "$CONFIG"
perl -0pi -e "s/\\nCURRENT_PROJECT_VERSION = .*\\n/\\nCURRENT_PROJECT_VERSION = $BUILD\\n/" "$CONFIG"

rg -n "MARKETING_VERSION = $VERSION|CURRENT_PROJECT_VERSION = $BUILD" "$CONFIG"
