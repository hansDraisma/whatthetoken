#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/WhatTheToken.xcodeproj"
SCHEME="WhatTheToken"
CONFIGURATION="Release"
CONFIG="$ROOT_DIR/Packaging/WhatTheToken.xcconfig"
EXPORT_OPTIONS="$ROOT_DIR/Packaging/ExportOptions.DeveloperID.plist"
ARCHIVE_PATH="$ROOT_DIR/.build/archive/WhatTheToken.xcarchive"
EXPORT_DIR="$ROOT_DIR/.build/export"
DRY_RUN=0
VERSION=""
BUILD=""
TEAM_ID="${DEVELOPER_ID_TEAM_ID:-}"
APP_PROFILE_SPECIFIER="${DEVELOPER_ID_APP_PROFILE_SPECIFIER:-}"
WIDGET_PROFILE_SPECIFIER="${DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER:-}"

. "$ROOT_DIR/Scripts/release-inputs.sh"

usage() {
    printf 'Usage: %s --version <version> --build <build> [--team-id <id>] [--app-profile <name>] [--widget-profile <name>] [--archive-path <path>] [--export-dir <path>] [--dry-run]\n' "$0"
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
        --app-profile)
            APP_PROFILE_SPECIFIER="${2:-}"
            shift 2
            ;;
        --widget-profile)
            WIDGET_PROFILE_SPECIFIER="${2:-}"
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

if [[ "$DRY_RUN" -eq 0 && ( -z "$APP_PROFILE_SPECIFIER" || -z "$WIDGET_PROFILE_SPECIFIER" ) ]]; then
    printf 'DEVELOPER_ID_APP_PROFILE_SPECIFIER is required for a real release archive.\n' >&2
    printf 'DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER is required for a real release archive.\n' >&2
    exit 65
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
    /usr/libexec/PlistBuddy -c 'Add :provisioningProfiles dict' "$EXPORT_OPTIONS_RESOLVED"
    /usr/libexec/PlistBuddy -c "Add :provisioningProfiles:com.whatthetoken.mac string $APP_PROFILE_SPECIFIER" "$EXPORT_OPTIONS_RESOLVED"
    /usr/libexec/PlistBuddy -c "Add :provisioningProfiles:com.whatthetoken.mac.widget string $WIDGET_PROFILE_SPECIFIER" "$EXPORT_OPTIONS_RESOLVED"
    plutil -lint "$EXPORT_OPTIONS_RESOLVED" >/dev/null
else
    DRY_RUN_TEAM_ID="${TEAM_ID:-<DEVELOPER_ID_TEAM_ID>}"
    DRY_RUN_APP_PROFILE="${APP_PROFILE_SPECIFIER:-<DEVELOPER_ID_APP_PROFILE_SPECIFIER>}"
    DRY_RUN_WIDGET_PROFILE="${WIDGET_PROFILE_SPECIFIER:-<DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER>}"
    quote_command rm -rf "$ARCHIVE_PATH"
    quote_command rm -rf "$EXPORT_DIR"
    quote_command mkdir -p "$(dirname "$EXPORT_OPTIONS_RESOLVED")" "$(dirname "$ARCHIVE_PATH")" "$EXPORT_DIR"
    quote_command cp "$EXPORT_OPTIONS" "$EXPORT_OPTIONS_RESOLVED"
    quote_command plutil -lint "$EXPORT_OPTIONS_RESOLVED"
    quote_command /usr/libexec/PlistBuddy -c "Print :teamID" "$EXPORT_OPTIONS_RESOLVED"
    quote_command /usr/libexec/PlistBuddy -c "Add :teamID string $DRY_RUN_TEAM_ID" "$EXPORT_OPTIONS_RESOLVED"
    quote_command /usr/libexec/PlistBuddy -c "Print :provisioningProfiles" "$EXPORT_OPTIONS_RESOLVED"
    quote_command /usr/libexec/PlistBuddy -c "Add :provisioningProfiles dict" "$EXPORT_OPTIONS_RESOLVED"
    quote_command /usr/libexec/PlistBuddy -c "Add :provisioningProfiles:com.whatthetoken.mac string $DRY_RUN_APP_PROFILE" "$EXPORT_OPTIONS_RESOLVED"
    quote_command /usr/libexec/PlistBuddy -c "Add :provisioningProfiles:com.whatthetoken.mac.widget string $DRY_RUN_WIDGET_PROFILE" "$EXPORT_OPTIONS_RESOLVED"
    quote_command plutil -lint "$EXPORT_OPTIONS_RESOLVED"
fi

archive_command=(
    xcodebuild
    -project "$PROJECT"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -archivePath "$ARCHIVE_PATH"
    MARKETING_VERSION="$VERSION"
    CURRENT_PROJECT_VERSION="$BUILD"
    WTT_DEVELOPER_ID_APP_PROFILE_SPECIFIER="${APP_PROFILE_SPECIFIER:-<DEVELOPER_ID_APP_PROFILE_SPECIFIER>}"
    WTT_DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER="${WIDGET_PROFILE_SPECIFIER:-<DEVELOPER_ID_WIDGET_PROFILE_SPECIFIER>}"
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
