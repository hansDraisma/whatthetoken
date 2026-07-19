#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION=""
BUILD=""
INSTALL=0
DRY_RUN=0
PUBLIC_RELEASE_REPOSITORY="${PUBLIC_RELEASE_REPOSITORY:-hansDraisma/whatthetoken-releases}"
PUBLIC_APPCAST_URL="${PUBLIC_APPCAST_URL:-https://hansdraisma.github.io/whatthetoken-releases/appcast.xml}"
RELEASE_ARTIFACTS_DIR="${RELEASE_ARTIFACTS_DIR:-$HOME/ReleaseArtifacts/WhatTheToken}"
INSTALL_PATH="/Applications/WhatTheToken.app"

. "$ROOT_DIR/Scripts/release-inputs.sh"

usage() {
    printf 'Usage: %s --version <version> --build <build> [--install] [--dry-run]\n' "$0"
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
        --install)
            INSTALL=1
            shift
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

if [[ -z "$VERSION" || -z "$BUILD" ]]; then
    usage >&2
    exit 64
fi

validate_release_version "$VERSION"
validate_release_build "$BUILD"

TAG="v$VERSION"
ASSET_NAME="WhatTheToken-$VERSION.dmg"
CHECKSUM_NAME="$ASSET_NAME.sha256"
DOWNLOAD_URL_PREFIX="https://github.com/$PUBLIC_RELEASE_REPOSITORY/releases/download/$TAG/"
DOWNLOAD_DIR="$RELEASE_ARTIFACTS_DIR/downloads/$VERSION"
DMG_PATH="$DOWNLOAD_DIR/$ASSET_NAME"
CHECKSUM_PATH="$DOWNLOAD_DIR/$CHECKSUM_NAME"

if [[ "$DRY_RUN" -eq 1 ]]; then
    quote_command curl -fL --retry 3 "$DOWNLOAD_URL_PREFIX$ASSET_NAME" -o "$DMG_PATH"
    quote_command curl -fL --retry 3 "$DOWNLOAD_URL_PREFIX$CHECKSUM_NAME" -o "$CHECKSUM_PATH"
    quote_command shasum -a 256 -c "$CHECKSUM_NAME"
    quote_command "$ROOT_DIR/Scripts/verify-release-artifacts.sh" --dmg "$DMG_PATH" --app '<mounted WhatTheToken.app>'
    if [[ "$INSTALL" -eq 1 ]]; then
        quote_command ditto '<mounted WhatTheToken.app>' '<staged app under /Applications>'
        quote_command mv "$INSTALL_PATH" '<recoverable release backup>'
        quote_command mv '<verified staged app>' "$INSTALL_PATH"
        quote_command open "$INSTALL_PATH"
        printf 'Install mode would preserve any existing app as a recoverable release backup.\n'
    fi
    printf 'Dry run only. No artifact was downloaded, installed, replaced, or launched.\n'
    exit 0
fi

for command_name in curl shasum hdiutil codesign spctl xcrun ditto pgrep pkill open; do
    command -v "$command_name" >/dev/null 2>&1 || {
        printf 'Required command not found: %s\n' "$command_name" >&2
        exit 69
    }
done

mkdir -p "$DOWNLOAD_DIR"
curl -fL --retry 3 "$DOWNLOAD_URL_PREFIX$ASSET_NAME" -o "$DMG_PATH"
curl -fL --retry 3 "$DOWNLOAD_URL_PREFIX$CHECKSUM_NAME" -o "$CHECKSUM_PATH"
( cd "$DOWNLOAD_DIR" && shasum -a 256 -c "$CHECKSUM_NAME" )
hdiutil verify "$DMG_PATH" >/dev/null
codesign --verify --verbose=2 "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type install --verbose=2 "$DMG_PATH"

MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/whatthetoken-install.XXXXXX")"
EXTRACT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/whatthetoken-extract.XXXXXX")"
BACKUP_PATH=""
STAGED_APP=""
INSTALL_SWITCHED=0
INSTALL_VERIFIED=0
MOUNT_ATTACHED=0
cleanup() {
    if [[ "$INSTALL_VERIFIED" -eq 0 ]]; then
        if [[ "$INSTALL_SWITCHED" -eq 1 || ( -n "$STAGED_APP" && -e "$STAGED_APP" ) ]]; then
            FAILED_INSTALL_DIR="$RELEASE_ARTIFACTS_DIR/failed-installs"
            FAILED_INSTALL_PATH="$FAILED_INSTALL_DIR/WhatTheToken-$VERSION-build-$BUILD-$$.app"
            mkdir -p "$FAILED_INSTALL_DIR" || true
            if [[ -e "$INSTALL_PATH" && ! -e "$FAILED_INSTALL_PATH" ]]; then
                mv "$INSTALL_PATH" "$FAILED_INSTALL_PATH" || true
            elif [[ -n "$STAGED_APP" && -e "$STAGED_APP" && ! -e "$FAILED_INSTALL_PATH" ]]; then
                mv "$STAGED_APP" "$FAILED_INSTALL_PATH" || true
            fi
        fi
        if [[ -n "$BACKUP_PATH" && -e "$BACKUP_PATH" && ! -e "$INSTALL_PATH" ]]; then
            mv "$BACKUP_PATH" "$INSTALL_PATH" || true
            printf 'Post-install verification failed; the previous app was restored.\n' >&2
        fi
    fi
    if [[ "$MOUNT_ATTACHED" -eq 1 ]]; then
        hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
    fi
    rm -rf "$MOUNT_DIR" "$EXTRACT_DIR"
}
trap cleanup EXIT
hdiutil attach "$DMG_PATH" -readonly -nobrowse -mountpoint "$MOUNT_DIR" >/dev/null
MOUNT_ATTACHED=1
MOUNTED_APP="$MOUNT_DIR/WhatTheToken.app"
[[ -d "$MOUNTED_APP" ]] || {
    printf 'Published DMG does not contain WhatTheToken.app.\n' >&2
    exit 66
}
SOURCE_APP="$EXTRACT_DIR/WhatTheToken.app"
ditto "$MOUNTED_APP" "$SOURCE_APP"
hdiutil detach "$MOUNT_DIR" >/dev/null
MOUNT_ATTACHED=0

"$ROOT_DIR/Scripts/verify-release-artifacts.sh" --dmg "$DMG_PATH" --app "$SOURCE_APP"

SOURCE_INFO_PLIST="$SOURCE_APP/Contents/Info.plist"
SOURCE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SOURCE_INFO_PLIST")"
SOURCE_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$SOURCE_INFO_PLIST")"
SOURCE_FEED="$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$SOURCE_INFO_PLIST")"
[[ "$SOURCE_VERSION" == "$VERSION" && "$SOURCE_BUILD" == "$BUILD" ]] || {
    printf 'Published app version/build mismatch. Expected %s (%s), found %s (%s).\n' \
        "$VERSION" "$BUILD" "$SOURCE_VERSION" "$SOURCE_BUILD" >&2
    exit 65
}
[[ "$SOURCE_FEED" == "$PUBLIC_APPCAST_URL" ]] || {
    printf 'Published app contains an unexpected update feed: %s\n' "$SOURCE_FEED" >&2
    exit 65
}

if [[ "$INSTALL" -eq 0 ]]; then
    printf 'Published WhatTheToken %s (build %s) verified. Re-run with --install to install it.\n' "$VERSION" "$BUILD"
    exit 0
fi

STAGED_APP="/Applications/.WhatTheToken.installing.$$.app"
[[ ! -e "$STAGED_APP" ]] || {
    printf 'Refusing to replace an existing staged path: %s\n' "$STAGED_APP" >&2
    exit 65
}
ditto "$SOURCE_APP" "$STAGED_APP"
codesign --verify --strict --verbose=2 "$STAGED_APP"
spctl --assess --type execute --verbose=2 "$STAGED_APP"

if pgrep -x WhatTheTokenMac >/dev/null 2>&1; then
    pkill -TERM -x WhatTheTokenMac
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        pgrep -x WhatTheTokenMac >/dev/null 2>&1 || break
        sleep 1
    done
    pgrep -x WhatTheTokenMac >/dev/null 2>&1 && {
        printf 'WhatTheToken did not quit; leaving the verified staged app at %s.\n' "$STAGED_APP" >&2
        exit 65
    }
fi

if [[ -e "$INSTALL_PATH" ]]; then
    BACKUP_DIR="$RELEASE_ARTIFACTS_DIR/install-backups"
    mkdir -p "$BACKUP_DIR"
    BACKUP_PATH="$BACKUP_DIR/WhatTheToken-$(date -u +%Y%m%dT%H%M%SZ).app"
    [[ ! -e "$BACKUP_PATH" ]] || {
        printf 'Refusing to replace an existing backup: %s\n' "$BACKUP_PATH" >&2
        exit 65
    }
    mv "$INSTALL_PATH" "$BACKUP_PATH"
fi

if ! mv "$STAGED_APP" "$INSTALL_PATH"; then
    if [[ -n "$BACKUP_PATH" && ! -e "$INSTALL_PATH" ]]; then
        mv "$BACKUP_PATH" "$INSTALL_PATH"
    fi
    printf 'Installation failed; the previous app was restored when available.\n' >&2
    exit 1
fi
INSTALL_SWITCHED=1

codesign --verify --strict --verbose=2 "$INSTALL_PATH"
spctl --assess --type execute --verbose=2 "$INSTALL_PATH"
INSTALLED_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INSTALL_PATH/Contents/Info.plist")"
INSTALLED_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INSTALL_PATH/Contents/Info.plist")"
[[ "$INSTALLED_VERSION" == "$VERSION" && "$INSTALLED_BUILD" == "$BUILD" ]]
INSTALL_VERIFIED=1
open "$INSTALL_PATH"

printf 'Installed WhatTheToken %s (build %s) at %s.\n' "$VERSION" "$BUILD" "$INSTALL_PATH"
if [[ -n "$BACKUP_PATH" ]]; then
    printf 'Previous app backup: %s\n' "$BACKUP_PATH"
fi
