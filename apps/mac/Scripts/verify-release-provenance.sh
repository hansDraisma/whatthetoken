#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
CONFIG="$ROOT_DIR/Packaging/WhatTheToken.xcconfig"
VERSION=""
BUILD=""
ALLOW_UNTAGGED_CANDIDATE=0

. "$ROOT_DIR/Scripts/release-inputs.sh"

usage() {
    printf 'Usage: %s --version <version> --build <build> [--allow-untagged-candidate]\n' "$0"
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
        --allow-untagged-candidate)
            ALLOW_UNTAGGED_CANDIDATE=1
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

if [[ -z "$VERSION" || -z "$BUILD" ]]; then
    usage >&2
    exit 64
fi

validate_release_version "$VERSION"
validate_release_build "$BUILD"
assert_release_matches_xcconfig "$VERSION" "$BUILD" "$CONFIG"

cd "$REPO_ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
    printf 'Release source must be clean before creating public artifacts.\n' >&2
    git status --short >&2
    exit 65
fi

git fetch --tags origin main:refs/remotes/origin/main

CURRENT_BRANCH="$(git branch --show-current)"
if [[ "$CURRENT_BRANCH" != "main" ]]; then
    printf 'Public releases must be created from main, not %s.\n' "${CURRENT_BRANCH:-detached HEAD}" >&2
    exit 65
fi

ORIGIN_MAIN_SHA="$(git rev-parse origin/main)"
HEAD_SHA="$(git rev-parse HEAD)"
if [[ "$HEAD_SHA" != "$ORIGIN_MAIN_SHA" ]]; then
    printf 'Public release HEAD must match origin/main.\n' >&2
    printf 'HEAD:        %s\n' "$HEAD_SHA" >&2
    printf 'origin/main: %s\n' "$ORIGIN_MAIN_SHA" >&2
    exit 65
fi

TAG="v$VERSION"
TAG_REF="refs/tags/$TAG"
if git rev-parse --verify --quiet "$TAG_REF" >/dev/null; then
    TAG_SHA="$(git rev-list -n 1 "$TAG_REF")"
    if [[ "$HEAD_SHA" != "$TAG_SHA" ]]; then
        printf 'Release tag %s does not point at HEAD.\n' "$TAG" >&2
        exit 65
    fi
    git verify-tag "$TAG" >/dev/null 2>&1 || {
        printf 'Release tag %s must be signed and verifiable on the release machine.\n' "$TAG" >&2
        exit 65
    }
elif [[ "$ALLOW_UNTAGGED_CANDIDATE" -ne 1 ]]; then
    printf 'Signed release tag %s is required for publication provenance.\n' "$TAG" >&2
    exit 65
fi

PACKAGE_RESOLVED="$ROOT_DIR/WhatTheToken.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if [[ ! -f "$PACKAGE_RESOLVED" ]]; then
    printf 'Package.resolved is required for release reproducibility: %s\n' "$PACKAGE_RESOLVED" >&2
    exit 66
fi

grep -F '"identity" : "sparkle"' "$PACKAGE_RESOLVED" >/dev/null
grep -F '"location" : "https://github.com/sparkle-project/Sparkle"' "$PACKAGE_RESOLVED" >/dev/null

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
