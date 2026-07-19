#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/WhatTheToken.xcodeproj"
SCHEME="WhatTheToken"
CONFIGURATION="Release"
CONFIG="$ROOT_DIR/Packaging/WhatTheToken.xcconfig"
EXPORT_OPTIONS="$ROOT_DIR/Packaging/ExportOptions.DeveloperID.plist"
APP_ENTITLEMENTS="$ROOT_DIR/Packaging/WhatTheToken.entitlements"
WIDGET_ENTITLEMENTS="$ROOT_DIR/Packaging/WhatTheTokenWidget.entitlements"
ARCHIVE_PATH="$ROOT_DIR/.build/archive/WhatTheToken.xcarchive"
EXPORT_DIR="$ROOT_DIR/.build/export"
DRY_RUN=0
VERSION=""
BUILD=""
TEAM_ID="${DEVELOPER_ID_TEAM_ID:-}"
SENTRY_DSN_VALUE="${SENTRY_DSN:-}"
RELEASE_WITHOUT_SENTRY_VALUE="${RELEASE_WITHOUT_SENTRY:-0}"

. "$ROOT_DIR/Scripts/release-inputs.sh"

usage() {
    printf 'Usage: %s --version <version> --build <build> [--team-id <id>] [--archive-path <path>] [--export-dir <path>] [--dry-run]\n' "$0"
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
        --build)
            BUILD="${2:-}"
            shift 2
            ;;
        --team-id)
            TEAM_ID="${2:-}"
            shift 2
            ;;
        --archive-path)
            ARCHIVE_PATH="${2:-}"
            shift 2
            ;;
        --export-dir)
            EXPORT_DIR="${2:-}"
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

if [[ -z "$VERSION" || -z "$BUILD" ]]; then
    usage >&2
    exit 64
fi

validate_release_version "$VERSION"
validate_release_build "$BUILD"

if [[ "$DRY_RUN" -eq 0 && -z "$TEAM_ID" ]]; then
    printf 'DEVELOPER_ID_TEAM_ID is required for a real release archive.\n' >&2
    exit 65
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
    if [[ "$RELEASE_WITHOUT_SENTRY_VALUE" != "0" && "$RELEASE_WITHOUT_SENTRY_VALUE" != "1" ]]; then
        printf 'RELEASE_WITHOUT_SENTRY must be 0 or 1.\n' >&2
        exit 65
    fi
    if [[ -n "$SENTRY_DSN_VALUE" && "$SENTRY_DSN_VALUE" != https://* ]]; then
        printf 'SENTRY_DSN must be an https Sentry DSN when configured.\n' >&2
        exit 65
    fi
    if [[ -n "$SENTRY_DSN_VALUE" && "$RELEASE_WITHOUT_SENTRY_VALUE" == "1" ]]; then
        printf 'Choose SENTRY_DSN or RELEASE_WITHOUT_SENTRY=1, not both.\n' >&2
        exit 65
    fi
    if [[ -z "$SENTRY_DSN_VALUE" && "$RELEASE_WITHOUT_SENTRY_VALUE" != "1" ]]; then
        printf 'Set SENTRY_DSN to an https DSN or RELEASE_WITHOUT_SENTRY=1 for an explicit telemetry-free release.\n' >&2
        exit 65
    fi
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
    EXPECTED_APP_GROUP="$TEAM_ID.com.whatthetoken.mac"
    APP_GROUP="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.application-groups:0' "$APP_ENTITLEMENTS" 2>/dev/null || true)"
    WIDGET_APP_GROUP="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.application-groups:0' "$WIDGET_ENTITLEMENTS" 2>/dev/null || true)"
    if [[ "$APP_GROUP" != "$EXPECTED_APP_GROUP" || "$WIDGET_APP_GROUP" != "$EXPECTED_APP_GROUP" ]]; then
        printf 'App and widget App Group must match the signing team: %s\n' "$EXPECTED_APP_GROUP" >&2
        exit 65
    fi
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
    assert_release_matches_xcconfig "$VERSION" "$BUILD" "$CONFIG"
fi

EXPORT_OPTIONS_RESOLVED="$ROOT_DIR/.build/export-options/ExportOptions.DeveloperID.$VERSION.plist"

if [[ "$DRY_RUN" -eq 0 ]]; then
    rm -rf "$ARCHIVE_PATH"
    rm -rf "$EXPORT_DIR"
    mkdir -p "$(dirname "$EXPORT_OPTIONS_RESOLVED")" "$(dirname "$ARCHIVE_PATH")" "$EXPORT_DIR"
    cp "$EXPORT_OPTIONS" "$EXPORT_OPTIONS_RESOLVED"
    plutil -lint "$EXPORT_OPTIONS_RESOLVED" >/dev/null
    if /usr/libexec/PlistBuddy -c 'Print :teamID' "$EXPORT_OPTIONS_RESOLVED" >/dev/null 2>&1; then
        /usr/libexec/PlistBuddy -c 'Delete :teamID' "$EXPORT_OPTIONS_RESOLVED"
    fi
    if /usr/libexec/PlistBuddy -c 'Print :provisioningProfiles' "$EXPORT_OPTIONS_RESOLVED" >/dev/null 2>&1; then
        /usr/libexec/PlistBuddy -c 'Delete :provisioningProfiles' "$EXPORT_OPTIONS_RESOLVED"
    fi
    /usr/libexec/PlistBuddy -c "Add :teamID string $TEAM_ID" "$EXPORT_OPTIONS_RESOLVED"
    plutil -lint "$EXPORT_OPTIONS_RESOLVED" >/dev/null
else
    DRY_RUN_TEAM_ID="${TEAM_ID:-DEVELOPER_ID_TEAM_ID}"
    quote_command rm -rf "$ARCHIVE_PATH"
    quote_command rm -rf "$EXPORT_DIR"
    quote_command mkdir -p "$(dirname "$EXPORT_OPTIONS_RESOLVED")" "$(dirname "$ARCHIVE_PATH")" "$EXPORT_DIR"
    quote_command cp "$EXPORT_OPTIONS" "$EXPORT_OPTIONS_RESOLVED"
    quote_command plutil -lint "$EXPORT_OPTIONS_RESOLVED"
    quote_command /usr/libexec/PlistBuddy -c "Print :teamID" "$EXPORT_OPTIONS_RESOLVED"
    quote_command /usr/libexec/PlistBuddy -c "Add :teamID string $DRY_RUN_TEAM_ID" "$EXPORT_OPTIONS_RESOLVED"
    quote_command /usr/libexec/PlistBuddy -c "Print :provisioningProfiles" "$EXPORT_OPTIONS_RESOLVED"
    quote_command /usr/libexec/PlistBuddy -c "Delete :provisioningProfiles" "$EXPORT_OPTIONS_RESOLVED"
    quote_command plutil -lint "$EXPORT_OPTIONS_RESOLVED"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    ARCHIVE_SENTRY_DSN="SENTRY_DSN"
else
    ARCHIVE_SENTRY_DSN="$SENTRY_DSN_VALUE"
fi

archive_command=(
    xcodebuild
    -project "$PROJECT"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -archivePath "$ARCHIVE_PATH"
    MARKETING_VERSION="$VERSION"
    CURRENT_PROJECT_VERSION="$BUILD"
    SENTRY_DSN="$ARCHIVE_SENTRY_DSN"
)

if [[ -n "$TEAM_ID" ]]; then
    archive_command+=(DEVELOPMENT_TEAM="$TEAM_ID")
fi

archive_command+=(archive)

export_command=(
    xcodebuild
    -exportArchive
    -archivePath "$ARCHIVE_PATH"
    -exportPath "$EXPORT_DIR"
    -exportOptionsPlist "$EXPORT_OPTIONS_RESOLVED"
)

run_command "${archive_command[@]}"
run_command "${export_command[@]}"

if [[ "$DRY_RUN" -eq 1 ]]; then
    quote_command lipo "$EXPORT_DIR/WhatTheToken.app/Contents/MacOS/WhatTheTokenMac" -verify_arch arm64 x86_64
    printf 'Dry run only. No archive or export artifacts were created.\n'
else
    lipo "$EXPORT_DIR/WhatTheToken.app/Contents/MacOS/WhatTheTokenMac" -verify_arch arm64 x86_64
    printf '%s\n' "$EXPORT_DIR/WhatTheToken.app"
fi
