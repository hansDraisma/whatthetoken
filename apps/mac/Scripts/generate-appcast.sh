#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATES_DIR=""
OUTPUT=""
DOWNLOAD_URL_PREFIX="${SPARKLE_DOWNLOAD_URL_PREFIX:-}"
RELEASE_NOTES_URL="${SPARKLE_RELEASE_NOTES_URL:-}"
SPARKLE_BIN_DIR="${SPARKLE_BIN_DIR:-}"
DRY_RUN=0

usage() {
    printf 'Usage: %s --updates-dir <dir> [--output <appcast.xml>] [--download-url-prefix <url>] [--release-notes-url <url>] [--sparkle-bin-dir <dir>] [--dry-run]\n' "$0"
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

resolve_generate_appcast() {
    if [[ -n "$SPARKLE_BIN_DIR" ]]; then
        printf '%s\n' "$SPARKLE_BIN_DIR/generate_appcast"
        return
    fi

    if command -v generate_appcast >/dev/null 2>&1; then
        command -v generate_appcast
        return
    fi

    local derived_tool=""
    derived_tool="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast' -type f -print -quit 2>/dev/null || true)"
    if [[ -n "$derived_tool" ]]; then
        printf '%s\n' "$derived_tool"
        return
    fi

    printf 'generate_appcast\n'
}

assert_generate_appcast_available() {
    if [[ "$GENERATE_APPCAST" == */* ]]; then
        [[ -x "$GENERATE_APPCAST" ]] && return
    elif command -v "$GENERATE_APPCAST" >/dev/null 2>&1; then
        return
    fi

    printf 'Sparkle generate_appcast tool not found. Set SPARKLE_BIN_DIR, add it to PATH, or resolve Xcode packages so it exists in DerivedData.\n' >&2
    exit 69
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --updates-dir)
            UPDATES_DIR="${2:-}"
            shift 2
            ;;
        --output)
            OUTPUT="${2:-}"
            shift 2
            ;;
        --download-url-prefix)
            DOWNLOAD_URL_PREFIX="${2:-}"
            shift 2
            ;;
        --release-notes-url)
            RELEASE_NOTES_URL="${2:-}"
            shift 2
            ;;
        --sparkle-bin-dir)
            SPARKLE_BIN_DIR="${2:-}"
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

if [[ -z "$UPDATES_DIR" ]]; then
    usage >&2
    exit 64
fi

OUTPUT="${OUTPUT:-"$UPDATES_DIR/appcast.xml"}"

GENERATE_APPCAST="$(resolve_generate_appcast)"

if [[ "$DRY_RUN" -eq 0 ]]; then
    if [[ ! -d "$UPDATES_DIR" ]]; then
        printf 'Updates directory not found: %s\n' "$UPDATES_DIR" >&2
        exit 66
    fi
    assert_generate_appcast_available
fi

command_args=("$GENERATE_APPCAST" "$UPDATES_DIR")

if [[ -n "$DOWNLOAD_URL_PREFIX" ]]; then
    command_args+=(--download-url-prefix "$DOWNLOAD_URL_PREFIX")
fi

if [[ -n "$RELEASE_NOTES_URL" ]]; then
    command_args+=(--link "$RELEASE_NOTES_URL")
fi

run_command "${command_args[@]}"

if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ "$OUTPUT" != "$UPDATES_DIR/appcast.xml" ]]; then
        quote_command cp "$UPDATES_DIR/appcast.xml" "$OUTPUT"
    fi
    printf 'Dry run only. No Sparkle appcast.xml was generated.\n'
elif [[ "$OUTPUT" != "$UPDATES_DIR/appcast.xml" ]]; then
    cp "$UPDATES_DIR/appcast.xml" "$OUTPUT"
    printf '%s\n' "$OUTPUT"
else
    printf '%s\n' "$UPDATES_DIR/appcast.xml"
fi

printf 'Keep the Sparkle EdDSA private key outside the repo and release hosting.\n' >&2
