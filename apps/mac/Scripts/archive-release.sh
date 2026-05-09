#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/WhatTheToken.xcodeproj"
SCHEME="WhatTheToken"
CONFIGURATION="Release"
EXPORT_OPTIONS="$ROOT_DIR/Packaging/ExportOptions.DeveloperID.plist"
ARCHIVE_PATH="$ROOT_DIR/.build/archive/WhatTheToken.xcarchive"
EXPORT_DIR="$ROOT_DIR/.build/export"
DRY_RUN=0
VERSION=""
BUILD=""
TEAM_ID="${DEVELOPER_ID_TEAM_ID:-}"

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

if [[ "$DRY_RUN" -eq 0 && -z "$TEAM_ID" ]]; then
    printf 'DEVELOPER_ID_TEAM_ID is required for a real release archive.\n' >&2
    exit 65
fi

mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_DIR"

archive_command=(
    xcodebuild
    -project "$PROJECT"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -archivePath "$ARCHIVE_PATH"
    MARKETING_VERSION="$VERSION"
    CURRENT_PROJECT_VERSION="$BUILD"
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
    -exportOptionsPlist "$EXPORT_OPTIONS"
)

run_command "${archive_command[@]}"
run_command "${export_command[@]}"

if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'Dry run only. No archive or export artifacts were created.\n'
else
    printf '%s\n' "$EXPORT_DIR/WhatTheToken.app"
fi
