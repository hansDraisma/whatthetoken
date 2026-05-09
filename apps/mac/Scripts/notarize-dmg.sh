#!/usr/bin/env bash
set -euo pipefail

DMG_PATH=""
KEYCHAIN_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-}"
DRY_RUN=0
NOTARY_LOG_DIR="${NOTARY_LOG_DIR:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.build/notary"}"

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
    --output-format json
)
staple_command=(xcrun stapler staple "$DMG_PATH")
validate_command=(xcrun stapler validate "$DMG_PATH")

if [[ "$DRY_RUN" -eq 1 && -z "$KEYCHAIN_PROFILE" ]]; then
    submit_command=(
        xcrun notarytool submit
        "$DMG_PATH"
        --keychain-profile "<NOTARY_KEYCHAIN_PROFILE>"
        --wait
        --output-format json
    )
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    run_command "${submit_command[@]}"
    run_command "${staple_command[@]}"
    run_command "${validate_command[@]}"
    printf 'Dry run only. No notarization request was submitted.\n'
    exit 0
fi

mkdir -p "$NOTARY_LOG_DIR"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
submit_json="$NOTARY_LOG_DIR/notary-submit-$timestamp.json"

set +e
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$KEYCHAIN_PROFILE" --wait --output-format json | tee "$submit_json"
submit_status="${PIPESTATUS[0]}"
set -e

submission_id="$(plutil -extract id raw -o - "$submit_json" 2>/dev/null || true)"
if [[ -n "$submission_id" ]]; then
    log_json="$NOTARY_LOG_DIR/notary-log-$submission_id.json"
    xcrun notarytool log "$submission_id" --keychain-profile "$KEYCHAIN_PROFILE" > "$log_json" || true
else
    log_json="$NOTARY_LOG_DIR/notary-log-unavailable-$timestamp.txt"
    printf 'Submission ID unavailable. See submit JSON: %s\n' "$submit_json" > "$log_json"
fi

if [[ "$submit_status" -ne 0 ]]; then
    printf 'Notarization failed. Review sanitized log: %s\n' "$log_json" >&2
    exit "$submit_status"
fi

"${staple_command[@]}"
"${validate_command[@]}"
printf '%s\n' "$log_json"
