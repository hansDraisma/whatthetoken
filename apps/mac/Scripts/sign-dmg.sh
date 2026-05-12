#!/usr/bin/env bash
set -euo pipefail

DMG_PATH=""
SIGNING_IDENTITY="${DEVELOPER_ID_SIGNING_IDENTITY:-}"
DRY_RUN=0

usage() {
    printf 'Usage: %s --dmg <path> [--signing-identity <identity>] [--dry-run]\n' "$0"
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
        --signing-identity)
            SIGNING_IDENTITY="${2:-}"
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

if [[ "$DRY_RUN" -eq 0 && -z "$SIGNING_IDENTITY" ]]; then
    printf 'DEVELOPER_ID_SIGNING_IDENTITY is required for DMG signing. Use the exact certificate name, for example "Developer ID Application: Hans Draisma (TEAMID)".\n' >&2
    exit 65
fi

if [[ "$DRY_RUN" -eq 0 && ! -f "$DMG_PATH" ]]; then
    printf 'DMG not found: %s\n' "$DMG_PATH" >&2
    exit 66
fi

SIGNING_IDENTITY_FOR_COMMAND="$SIGNING_IDENTITY"
if [[ "$DRY_RUN" -eq 1 && -z "$SIGNING_IDENTITY_FOR_COMMAND" ]]; then
    SIGNING_IDENTITY_FOR_COMMAND="<DEVELOPER_ID_SIGNING_IDENTITY>"
fi

run_command hdiutil verify "$DMG_PATH"
run_command codesign --force --timestamp --sign "$SIGNING_IDENTITY_FOR_COMMAND" "$DMG_PATH"
run_command codesign --verify --verbose=2 "$DMG_PATH"

if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'Dry run only. No DMG was signed.\n'
fi
