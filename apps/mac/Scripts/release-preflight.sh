#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/../.." && pwd)"
CONFIG="$ROOT_DIR/Packaging/WhatTheToken.xcconfig"
INFO_PLIST="$ROOT_DIR/Packaging/Info.plist"
APP_ENTITLEMENTS="$ROOT_DIR/Packaging/WhatTheToken.entitlements"
WIDGET_ENTITLEMENTS="$ROOT_DIR/Packaging/WhatTheTokenWidget.entitlements"
VERSION=""
BUILD=""
DRY_RUN=0
TEAM_ID="${DEVELOPER_ID_TEAM_ID:-}"
SIGNING_IDENTITY="${DEVELOPER_ID_SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-}"
SENTRY_DSN_VALUE="${SENTRY_DSN:-}"
RELEASE_WITHOUT_SENTRY_VALUE="${RELEASE_WITHOUT_SENTRY:-0}"
PUBLIC_RELEASE_REPOSITORY="${PUBLIC_RELEASE_REPOSITORY:-hansDraisma/whatthetoken-releases}"
PUBLIC_APPCAST_URL="${PUBLIC_APPCAST_URL:-https://hansdraisma.github.io/whatthetoken-releases/appcast.xml}"
EXPECTED_SPARKLE_KEY="rwQnge6z/GQvR9NwGuQFBpN44ZcaUBzixfISv77Z2hg="
FAILURES=0

. "$ROOT_DIR/Scripts/release-inputs.sh"

usage() {
    printf 'Usage: %s --version <version> --build <build> [--dry-run]\n' "$0"
}

ok() {
    printf '[ok] %s\n' "$1"
}

missing() {
    printf '[missing] %s\n' "$1" >&2
    FAILURES=$((FAILURES + 1))
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

if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%s\n' \
        'Would verify clean main source and origin/main provenance.' \
        'Would verify version/build metadata and pinned dependencies.' \
        'Would verify Developer ID identity, certificate lifetime, and Team-ID app group entitlements.' \
        'Would verify SENTRY_DSN or an explicit telemetry-free release mode without printing secrets.' \
        'Would verify the notarytool Keychain profile and Sparkle private key.' \
        'Would verify the public repository, immutable releases, Pages, and appcast.' \
        'Dry run only. No credentials, tags, or artifacts were changed.'
    exit 0
fi

for command_name in git gh curl xmllint security openssl xcrun grep; do
    if command -v "$command_name" >/dev/null 2>&1; then
        ok "command available: $command_name"
    else
        missing "required command: $command_name"
    fi
done

cd "$REPO_ROOT"
git fetch --quiet origin main
if [[ -z "$(git status --porcelain)" ]]; then
    ok 'release source is clean'
else
    missing 'release source must be clean'
fi
if [[ "$(git branch --show-current)" == "main" ]]; then
    ok 'release source is on main'
else
    missing 'run the release from main'
fi
if [[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]]; then
    ok 'HEAD matches origin/main'
else
    missing 'HEAD must match origin/main'
fi

if assert_release_matches_xcconfig "$VERSION" "$BUILD" "$CONFIG"; then
    ok "version/build match committed metadata: $VERSION ($BUILD)"
else
    missing "version/build must match committed metadata: $VERSION ($BUILD)"
fi

if [[ -n "$TEAM_ID" ]]; then
    ok 'DEVELOPER_ID_TEAM_ID is configured'
else
    missing 'DEVELOPER_ID_TEAM_ID'
fi
if [[ -n "$SIGNING_IDENTITY" ]]; then
    ok 'DEVELOPER_ID_SIGNING_IDENTITY is configured'
else
    missing 'DEVELOPER_ID_SIGNING_IDENTITY'
fi
if [[ "$RELEASE_WITHOUT_SENTRY_VALUE" != "0" && "$RELEASE_WITHOUT_SENTRY_VALUE" != "1" ]]; then
    missing 'RELEASE_WITHOUT_SENTRY must be 0 or 1'
elif [[ "$SENTRY_DSN_VALUE" == https://* && "$RELEASE_WITHOUT_SENTRY_VALUE" != "1" ]]; then
    ok 'SENTRY_DSN is a configured HTTPS DSN'
elif [[ -z "$SENTRY_DSN_VALUE" && "$RELEASE_WITHOUT_SENTRY_VALUE" == "1" ]]; then
    ok 'explicit telemetry-free release mode is configured'
elif [[ -n "$SENTRY_DSN_VALUE" && "$RELEASE_WITHOUT_SENTRY_VALUE" == "1" ]]; then
    missing 'choose SENTRY_DSN or RELEASE_WITHOUT_SENTRY=1, not both'
else
    missing 'set a public HTTPS SENTRY_DSN or RELEASE_WITHOUT_SENTRY=1'
fi
if [[ -n "$NOTARY_PROFILE" ]]; then
    ok 'NOTARY_KEYCHAIN_PROFILE is configured'
else
    missing 'NOTARY_KEYCHAIN_PROFILE'
fi

if [[ -n "$SIGNING_IDENTITY" ]]; then
    if security find-identity -v -p codesigning | grep -Fq "\"$SIGNING_IDENTITY\""; then
        ok 'Developer ID signing identity is available in Keychain'
    else
        missing 'Developer ID signing identity is not available in Keychain'
    fi
    if security find-certificate -c "$SIGNING_IDENTITY" -p 2>/dev/null \
        | openssl x509 -checkend 2592000 -noout >/dev/null 2>&1; then
        ok 'Developer ID certificate remains valid for at least 30 days'
    else
        missing 'Developer ID certificate must remain valid for at least 30 days'
    fi
fi

if [[ -n "$TEAM_ID" ]]; then
    EXPECTED_APP_GROUP="$TEAM_ID.com.whatthetoken.mac"
    APP_GROUP="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.application-groups:0' "$APP_ENTITLEMENTS" 2>/dev/null || true)"
    WIDGET_APP_GROUP="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.application-groups:0' "$WIDGET_ENTITLEMENTS" 2>/dev/null || true)"
    if [[ "$APP_GROUP" == "$EXPECTED_APP_GROUP" && "$WIDGET_APP_GROUP" == "$EXPECTED_APP_GROUP" ]]; then
        ok 'app and widget use the profileless Team-ID macOS app group'
    else
        missing "app and widget App Group must be $EXPECTED_APP_GROUP"
    fi
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
    if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" --output-format json >/dev/null 2>&1; then
        ok 'notarytool Keychain profile validates with Apple'
    else
        missing 'valid notarytool Keychain profile'
    fi
fi
if security find-generic-password -s 'https://sparkle-project.org' -a ed25519 >/dev/null 2>&1; then
    ok 'Sparkle EdDSA private key is available in Keychain'
else
    missing 'Sparkle EdDSA private key in Keychain'
fi

EMBEDDED_FEED="$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$INFO_PLIST")"
EMBEDDED_SPARKLE_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$INFO_PLIST")"
if [[ "$EMBEDDED_FEED" == "$PUBLIC_APPCAST_URL" ]]; then
    ok 'embedded Sparkle feed matches the public appcast'
else
    missing 'embedded Sparkle feed must match PUBLIC_APPCAST_URL'
fi
if [[ "$EMBEDDED_SPARKLE_KEY" == "$EXPECTED_SPARKLE_KEY" ]]; then
    ok 'embedded Sparkle public key matches the release keypair'
else
    missing 'embedded Sparkle public key does not match the release keypair'
fi

if gh auth status >/dev/null 2>&1; then
    ok 'GitHub CLI is authenticated'
else
    missing 'GitHub CLI authentication'
fi
if [[ "$(gh repo view "$PUBLIC_RELEASE_REPOSITORY" --json visibility --jq .visibility 2>/dev/null || true)" == 'PUBLIC' ]]; then
    ok 'distribution repository is public'
else
    missing 'public distribution repository'
fi
if [[ "$(gh api "repos/$PUBLIC_RELEASE_REPOSITORY/immutable-releases" --jq .enabled 2>/dev/null || true)" == 'true' ]]; then
    ok 'immutable releases are enabled'
else
    missing 'immutable releases must be enabled'
fi
if curl -fsSL "$PUBLIC_APPCAST_URL" | xmllint --noout - >/dev/null 2>&1; then
    ok 'public HTTPS appcast is reachable and valid XML'
else
    missing 'reachable, valid public HTTPS appcast'
fi

if [[ "$FAILURES" -ne 0 ]]; then
    printf '\nRelease preflight failed with %s missing requirement(s).\n' "$FAILURES" >&2
    printf 'Keep secrets out of source control. Configure the named environment variables and Keychain entries, then rerun this command.\n' >&2
    exit 65
fi

printf '\nRelease preflight passed for WhatTheToken %s (build %s).\n' "$VERSION" "$BUILD"
