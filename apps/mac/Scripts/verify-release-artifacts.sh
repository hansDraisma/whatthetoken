#!/usr/bin/env bash
set -euo pipefail

DMG_PATH=""
APP_PATH=""
DRY_RUN=0

usage() {
    printf 'Usage: %s --dmg <path> [--app <WhatTheToken.app>] [--dry-run]\n' "$0"
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
        --dmg)
            DMG_PATH="${2:-}"
            shift 2
            ;;
        --app)
            APP_PATH="${2:-}"
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

if [[ -z "$DMG_PATH" ]]; then
    usage >&2
    exit 64
fi

if [[ "$DRY_RUN" -eq 0 && ! -f "$DMG_PATH" ]]; then
    printf 'DMG not found: %s\n' "$DMG_PATH" >&2
    exit 66
fi

if [[ -n "$APP_PATH" ]]; then
    if [[ "$DRY_RUN" -eq 0 && ! -d "$APP_PATH" ]]; then
        printf 'App bundle not found: %s\n' "$APP_PATH" >&2
        exit 66
    fi
    run_command codesign --verify --deep --strict --verbose=2 "$APP_PATH"
    run_command spctl -a -vv -t exec "$APP_PATH"
fi

run_command xcrun stapler validate "$DMG_PATH"
run_command spctl -a -vv -t open --context context:primary-signature "$DMG_PATH"

checksum_path="$DMG_PATH.sha256"
if [[ "$DRY_RUN" -eq 1 ]]; then
    quote_command shasum -a 256 "$DMG_PATH" ">" "$checksum_path"
else
    shasum -a 256 "$DMG_PATH" > "$checksum_path"
    printf '%s\n' "$checksum_path"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'Dry run only. No release artifacts were verified or checksummed.\n'
fi
