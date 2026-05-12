#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT_DIR/Packaging/WhatTheToken.xcconfig"
VERSION=""
BUILD=""

. "$ROOT_DIR/Scripts/release-inputs.sh"

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

validate_release_version "$VERSION"
validate_release_build "$BUILD"
assert_release_build_increases "$BUILD" "$CONFIG"

perl -0pi -e "s/\\nMARKETING_VERSION = .*\\n/\\nMARKETING_VERSION = $VERSION\\n/" "$CONFIG"
perl -0pi -e "s/\\nCURRENT_PROJECT_VERSION = .*\\n/\\nCURRENT_PROJECT_VERSION = $BUILD\\n/" "$CONFIG"

UPDATED_VERSION="$(awk -F= '/^[[:space:]]*MARKETING_VERSION[[:space:]]*=/{gsub(/[[:space:]]/, "", $2); print $2}' "$CONFIG")"
UPDATED_BUILD="$(awk -F= '/^[[:space:]]*CURRENT_PROJECT_VERSION[[:space:]]*=/{gsub(/[[:space:]]/, "", $2); print $2}' "$CONFIG")"

if [[ "$UPDATED_VERSION" != "$VERSION" ]]; then
    printf 'Version rewrite did not round-trip. Expected %s, found %s.\n' "$VERSION" "${UPDATED_VERSION:-<missing>}" >&2
    exit 66
fi

if [[ "$UPDATED_BUILD" != "$BUILD" ]]; then
    printf 'Build rewrite did not round-trip. Expected %s, found %s.\n' "$BUILD" "${UPDATED_BUILD:-<missing>}" >&2
    exit 66
fi

grep -E '^[[:space:]]*(MARKETING_VERSION|CURRENT_PROJECT_VERSION)[[:space:]]*=' "$CONFIG"
