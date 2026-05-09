#!/usr/bin/env bash
set -euo pipefail

DMG_PATH=""
KEYCHAIN_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-}"
DRY_RUN=0

usage() {
    printf 'Usage: %s --dmg <path> [--keychain-profile <profile>] [--dry-run]\n' "$0"
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
        --keychain-profile)
            KEYCHAIN_PROFILE="${2:-}"
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

if [[ "$DRY_RUN" -eq 0 ]]; then
    if [[ -z "$KEYCHAIN_PROFILE" ]]; then
        printf 'NOTARY_KEYCHAIN_PROFILE is required for notarization.\n' >&2
        exit 65
    fi
    if [[ ! -f "$DMG_PATH" ]]; then
        printf 'DMG not found: %s\n' "$DMG_PATH" >&2
        exit 66
    fi
fi

submit_command=(
    xcrun notarytool submit
    "$DMG_PATH"
    --keychain-profile "$KEYCHAIN_PROFILE"
    --wait
)
staple_command=(xcrun stapler staple "$DMG_PATH")
validate_command=(xcrun stapler validate "$DMG_PATH")

if [[ "$DRY_RUN" -eq 1 && -z "$KEYCHAIN_PROFILE" ]]; then
    submit_command=(
        xcrun notarytool submit
        "$DMG_PATH"
        --keychain-profile "<NOTARY_KEYCHAIN_PROFILE>"
        --wait
    )
fi

run_command "${submit_command[@]}"
run_command "${staple_command[@]}"
run_command "${validate_command[@]}"

if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'Dry run only. No notarization request was submitted.\n'
fi
