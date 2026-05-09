#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
VERSION=""
BUILD=""

usage() {
    printf 'Usage: %s --version <version> --build <build>\n' "$0"
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

cd "$REPO_ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
    printf 'Release source must be clean before creating public artifacts.\n' >&2
    git status --short >&2
    exit 65
fi

TAG="v$VERSION"
HEAD_SHA="$(git rev-parse HEAD)"
TAG_SHA="$(git rev-list -n 1 "refs/tags/$TAG")"

if [[ "$HEAD_SHA" != "$TAG_SHA" ]]; then
    printf 'Release tag %s does not point at HEAD.\n' "$TAG" >&2
    exit 65
fi

git verify-tag "$TAG" >/dev/null 2>&1 || {
    printf 'Release tag %s must be signed and verifiable on the release machine.\n' "$TAG" >&2
    exit 65
}

PACKAGE_RESOLVED="$ROOT_DIR/WhatTheToken.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if [[ ! -f "$PACKAGE_RESOLVED" ]]; then
    printf 'Package.resolved is required for release reproducibility: %s\n' "$PACKAGE_RESOLVED" >&2
    exit 66
fi

rg -n '"identity" : "sparkle"|"location" : "https://github.com/sparkle-project/Sparkle"' "$PACKAGE_RESOLVED" >/dev/null

MANIFEST_DIR="$ROOT_DIR/.build/release-manifests"
mkdir -p "$MANIFEST_DIR"
MANIFEST="$MANIFEST_DIR/WhatTheToken-$VERSION-build-$BUILD.txt"
PACKAGE_RESOLVED_SHA="$(shasum -a 256 "$PACKAGE_RESOLVED" | awk '{print $1}')"

{
    printf 'version=%s\n' "$VERSION"
    printf 'build=%s\n' "$BUILD"
    printf 'tag=%s\n' "$TAG"
    printf 'commit=%s\n' "$HEAD_SHA"
    printf 'package_resolved_sha256=%s\n' "$PACKAGE_RESOLVED_SHA"
} > "$MANIFEST"

printf '%s\n' "$MANIFEST"
