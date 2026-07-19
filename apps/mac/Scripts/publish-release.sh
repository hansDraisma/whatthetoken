#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION=""
BUILD=""
NOTES_PATH=""
DMG_PATH=""
CHECKSUM_PATH=""
DRY_RUN=0
RESUME=0
PUBLIC_RELEASE_REPOSITORY="${PUBLIC_RELEASE_REPOSITORY:-hansDraisma/whatthetoken-releases}"
PUBLIC_APPCAST_URL="${PUBLIC_APPCAST_URL:-https://hansdraisma.github.io/whatthetoken-releases/appcast.xml}"
RELEASE_ARTIFACTS_DIR="${RELEASE_ARTIFACTS_DIR:-$HOME/ReleaseArtifacts/WhatTheToken}"

. "$ROOT_DIR/Scripts/release-inputs.sh"

usage() {
    printf 'Usage: %s --version <version> --build <build> --notes <release-notes.md> [--dmg <path>] [--checksum <path>] [--resume] [--dry-run]\n' "$0"
}

quote_command() {
    printf '%q ' "$@"
    printf '\n'
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
        --notes)
            NOTES_PATH="${2:-}"
            shift 2
            ;;
        --dmg)
            DMG_PATH="${2:-}"
            shift 2
            ;;
        --checksum)
            CHECKSUM_PATH="${2:-}"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --resume)
            RESUME=1
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

if [[ -z "$VERSION" || -z "$BUILD" || -z "$NOTES_PATH" ]]; then
    usage >&2
    exit 64
fi

validate_release_version "$VERSION"
validate_release_build "$BUILD"

TAG="v$VERSION"
DMG_PATH="${DMG_PATH:-"$ROOT_DIR/.build/dmg/WhatTheToken-$VERSION.dmg"}"
CHECKSUM_PATH="${CHECKSUM_PATH:-"$DMG_PATH.sha256"}"
APP_PATH="$ROOT_DIR/.build/export/WhatTheToken.app"
APPCAST_INPUT_DIR="$RELEASE_ARTIFACTS_DIR/appcast-input/$VERSION"
APPCAST_PATH="$APPCAST_INPUT_DIR/appcast.xml"
RELEASE_URL="https://github.com/$PUBLIC_RELEASE_REPOSITORY/releases/tag/$TAG"
DOWNLOAD_URL_PREFIX="https://github.com/$PUBLIC_RELEASE_REPOSITORY/releases/download/$TAG/"

if [[ "$DRY_RUN" -eq 1 ]]; then
    quote_command "$ROOT_DIR/Scripts/verify-release-provenance.sh" --version "$VERSION" --build "$BUILD"
    quote_command "$ROOT_DIR/Scripts/verify-release-artifacts.sh" --dmg "$DMG_PATH" --app "$APP_PATH"
    quote_command git ls-remote --exit-code --tags origin "refs/tags/$TAG"
    if [[ "$RESUME" -eq 1 ]]; then
        quote_command gh release view "$TAG" --repo "$PUBLIC_RELEASE_REPOSITORY"
    else
        quote_command gh release create "$TAG" --repo "$PUBLIC_RELEASE_REPOSITORY" --target main --draft --title "WhatTheToken $VERSION" --notes-file "$NOTES_PATH" "$DMG_PATH" "$CHECKSUM_PATH"
    fi
    quote_command "$ROOT_DIR/Scripts/generate-appcast.sh" --updates-dir "$APPCAST_INPUT_DIR" --download-url-prefix "$DOWNLOAD_URL_PREFIX" --release-notes-url "$RELEASE_URL"
    quote_command gh release download "$TAG" --repo "$PUBLIC_RELEASE_REPOSITORY" --pattern "$(basename "$DMG_PATH")" --pattern "$(basename "$CHECKSUM_PATH")"
    quote_command gh release edit "$TAG" --repo "$PUBLIC_RELEASE_REPOSITORY" --draft=false --latest
    quote_command gh api --method PUT "repos/$PUBLIC_RELEASE_REPOSITORY/contents/appcast.xml"
    quote_command curl -fL "$PUBLIC_APPCAST_URL"
    printf 'Dry run only. No release, tag, asset, or appcast was published.\n'
    exit 0
fi

for command_name in gh curl xmllint base64 shasum cmp; do
    command -v "$command_name" >/dev/null 2>&1 || {
        printf 'Required command not found: %s\n' "$command_name" >&2
        exit 69
    }
done

for required_path in "$NOTES_PATH" "$DMG_PATH" "$CHECKSUM_PATH"; do
    [[ -f "$required_path" ]] || {
        printf 'Required release file not found: %s\n' "$required_path" >&2
        exit 66
    }
done

[[ -d "$APP_PATH" ]] || {
    printf 'Signed release app not found: %s\n' "$APP_PATH" >&2
    exit 66
}

"$ROOT_DIR/Scripts/verify-release-provenance.sh" --version "$VERSION" --build "$BUILD"
"$ROOT_DIR/Scripts/verify-release-artifacts.sh" --dmg "$DMG_PATH" --app "$APP_PATH"

git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null || {
    printf 'Signed source tag %s must be pushed to origin before publication.\n' "$TAG" >&2
    exit 65
}

( cd "$(dirname "$CHECKSUM_PATH")" && shasum -a 256 -c "$(basename "$CHECKSUM_PATH")" )

gh auth status >/dev/null
REPOSITORY_VISIBILITY="$(gh repo view "$PUBLIC_RELEASE_REPOSITORY" --json visibility --jq .visibility)"
[[ "$REPOSITORY_VISIBILITY" == "PUBLIC" ]] || {
    printf 'Release repository must be public: %s\n' "$PUBLIC_RELEASE_REPOSITORY" >&2
    exit 65
}
RELEASE_IMMUTABILITY="$(gh api \
    "repos/$PUBLIC_RELEASE_REPOSITORY/immutable-releases" \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2026-03-10' \
    --jq .enabled)"
[[ "$RELEASE_IMMUTABILITY" == "true" ]] || {
    printf 'Immutable releases must be enabled before publication: %s\n' "$PUBLIC_RELEASE_REPOSITORY" >&2
    exit 65
}

RELEASE_EXISTS=0
if gh release view "$TAG" --repo "$PUBLIC_RELEASE_REPOSITORY" >/dev/null 2>&1; then
    RELEASE_EXISTS=1
fi
if [[ "$RELEASE_EXISTS" -eq 1 && "$RESUME" -eq 0 ]]; then
    printf 'Release already exists; refusing to replace immutable public artifacts: %s\n' "$TAG" >&2
    exit 65
fi
if [[ "$RELEASE_EXISTS" -eq 0 && "$RESUME" -eq 1 ]]; then
    printf 'Cannot resume because the public release does not exist: %s\n' "$TAG" >&2
    exit 65
fi

rm -rf "$APPCAST_INPUT_DIR"
mkdir -p "$APPCAST_INPUT_DIR"
cp "$DMG_PATH" "$APPCAST_INPUT_DIR/$(basename "$DMG_PATH")"

"$ROOT_DIR/Scripts/generate-appcast.sh" \
    --updates-dir "$APPCAST_INPUT_DIR" \
    --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
    --release-notes-url "$RELEASE_URL"
xmllint --noout "$APPCAST_PATH"
grep -F "$(basename "$DMG_PATH")" "$APPCAST_PATH" >/dev/null
grep -F "$DOWNLOAD_URL_PREFIX" "$APPCAST_PATH" >/dev/null
grep -F 'sparkle:edSignature' "$APPCAST_PATH" >/dev/null

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/whatthetoken-publish.XXXXXX")"
cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

if [[ "$RELEASE_EXISTS" -eq 0 ]]; then
    gh release create "$TAG" \
        --repo "$PUBLIC_RELEASE_REPOSITORY" \
        --target main \
        --draft \
        --title "WhatTheToken $VERSION" \
        --notes-file "$NOTES_PATH" \
        "$DMG_PATH" \
        "$CHECKSUM_PATH"
fi

RELEASE_IS_DRAFT="$(gh release view "$TAG" --repo "$PUBLIC_RELEASE_REPOSITORY" --json isDraft --jq .isDraft)"
RELEASE_ASSET_NAMES="$(gh release view "$TAG" --repo "$PUBLIC_RELEASE_REPOSITORY" --json assets --jq '.assets[].name')"
for RELEASE_ASSET_PATH in "$DMG_PATH" "$CHECKSUM_PATH"; do
    RELEASE_ASSET_NAME="$(basename "$RELEASE_ASSET_PATH")"
    if ! grep -Fxq "$RELEASE_ASSET_NAME" <<< "$RELEASE_ASSET_NAMES"; then
        [[ "$RELEASE_IS_DRAFT" == "true" ]] || {
            printf 'Published release is missing an immutable asset: %s\n' "$RELEASE_ASSET_NAME" >&2
            exit 65
        }
        gh release upload "$TAG" --repo "$PUBLIC_RELEASE_REPOSITORY" "$RELEASE_ASSET_PATH"
    fi
done

REMOTE_VERIFY_DIR="$WORK_DIR/hosted"
mkdir -p "$REMOTE_VERIFY_DIR"
gh release download "$TAG" \
    --repo "$PUBLIC_RELEASE_REPOSITORY" \
    --dir "$REMOTE_VERIFY_DIR" \
    --pattern "$(basename "$DMG_PATH")" \
    --pattern "$(basename "$CHECKSUM_PATH")"
cmp -s "$DMG_PATH" "$REMOTE_VERIFY_DIR/$(basename "$DMG_PATH")" || {
    printf 'Hosted DMG does not match the locally verified artifact: %s\n' "$TAG" >&2
    exit 65
}
cmp -s "$CHECKSUM_PATH" "$REMOTE_VERIFY_DIR/$(basename "$CHECKSUM_PATH")" || {
    printf 'Hosted checksum does not match the locally verified artifact: %s\n' "$TAG" >&2
    exit 65
}
( cd "$REMOTE_VERIFY_DIR" && shasum -a 256 -c "$(basename "$CHECKSUM_PATH")" )

if [[ "$RELEASE_IS_DRAFT" == "true" ]]; then
    gh release edit "$TAG" --repo "$PUBLIC_RELEASE_REPOSITORY" --draft=false --latest
fi

APPCAST_SHA="$(gh api "repos/$PUBLIC_RELEASE_REPOSITORY/contents/appcast.xml?ref=main" --jq .sha)"
APPCAST_CONTENT="$(base64 < "$APPCAST_PATH" | tr -d '\n')"
CURRENT_APPCAST_CONTENT="$(gh api "repos/$PUBLIC_RELEASE_REPOSITORY/contents/appcast.xml?ref=main" --jq .content | tr -d '\n')"
if [[ "$CURRENT_APPCAST_CONTENT" != "$APPCAST_CONTENT" ]]; then
    gh api \
        --method PUT \
        "repos/$PUBLIC_RELEASE_REPOSITORY/contents/appcast.xml" \
        -f message="release: publish appcast for $TAG" \
        -f content="$APPCAST_CONTENT" \
        -f sha="$APPCAST_SHA" \
        -f branch=main \
        >/dev/null
fi

EXPECTED_ASSET_URL="$DOWNLOAD_URL_PREFIX$(basename "$DMG_PATH")"
APPCAST_READY=0
for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18; do
    if curl -fsSL "$PUBLIC_APPCAST_URL" | grep -F "$EXPECTED_ASSET_URL" >/dev/null; then
        APPCAST_READY=1
        break
    fi
    sleep 5
done
[[ "$APPCAST_READY" -eq 1 ]] || {
    printf 'Release is public, but the Pages appcast did not update in time: %s\n' "$PUBLIC_APPCAST_URL" >&2
    exit 1
}

PUBLISHED_VERIFY_DIR="$WORK_DIR/published"
mkdir -p "$PUBLISHED_VERIFY_DIR"
curl -fL "$EXPECTED_ASSET_URL" -o "$PUBLISHED_VERIFY_DIR/$(basename "$DMG_PATH")"
curl -fL "$DOWNLOAD_URL_PREFIX$(basename "$CHECKSUM_PATH")" -o "$PUBLISHED_VERIFY_DIR/$(basename "$CHECKSUM_PATH")"
( cd "$PUBLISHED_VERIFY_DIR" && shasum -a 256 -c "$(basename "$CHECKSUM_PATH")" )

gh release view "$TAG" --repo "$PUBLIC_RELEASE_REPOSITORY" --json isDraft,isPrerelease,url --jq '{isDraft, isPrerelease, url}'
printf 'release_url=%s\nappcast_url=%s\n' "$RELEASE_URL" "$PUBLIC_APPCAST_URL"
