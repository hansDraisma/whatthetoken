#!/usr/bin/env bash
set -euo pipefail

DMG_PATH=""
APP_PATH=""
DRY_RUN=0
EXPECTED_TEAM_ID="${DEVELOPER_ID_TEAM_ID:-3U98C8T3DT}"
EXPECTED_APP_GROUP="$EXPECTED_TEAM_ID.com.whatthetoken.mac"

usage() {
    printf 'Usage: %s --dmg <path> [--app <WhatTheToken.app>] [--dry-run]\n' "$0"
}

quote_command() {
    printf '%q ' "$@"
    printf '\n'
}

shell_quote() {
    printf '%q' "$1"
}

print_shell_command() {
    printf '%s\n' "$1"
}

run_command() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        quote_command "$@"
    else
        "$@"
    fi
}

verify_profileless_app_bundle() {
    local app_path="$1"
    local widget_path="$app_path/Contents/PlugIns/WhatTheTokenWidget.appex"
    local app_bundle_id
    local widget_bundle_id
    local app_team
    local widget_team
    local app_entitlements
    local widget_entitlements

    codesign --verify --strict --verbose=2 "$app_path"
    test -d "$widget_path"
    codesign --verify --strict --verbose=2 "$widget_path"

    app_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist")"
    [[ "$app_bundle_id" == "com.whatthetoken.mac" ]] || {
        printf 'error: app bundle id is %s, expected com.whatthetoken.mac\n' "$app_bundle_id" >&2
        exit 1
    }
    widget_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$widget_path/Contents/Info.plist")"
    [[ "$widget_bundle_id" == "com.whatthetoken.mac.widget" ]] || {
        printf 'error: widget bundle id is %s, expected com.whatthetoken.mac.widget\n' "$widget_bundle_id" >&2
        exit 1
    }

    widget_team="$(codesign -dvv "$widget_path" 2>&1 | awk -F'=' '/TeamIdentifier/ { print $2; exit }')"
    app_team="$(codesign -dvv "$app_path" 2>&1 | awk -F'=' '/TeamIdentifier/ { print $2; exit }')"
    [[ -n "$widget_team" && "$widget_team" == "$app_team" ]] || {
        printf 'error: widget TeamIdentifier (%s) does not match app (%s)\n' "$widget_team" "$app_team" >&2
        exit 1
    }
    [[ "$app_team" == "$EXPECTED_TEAM_ID" ]] || {
        printf 'error: app TeamIdentifier is %s, expected %s\n' "$app_team" "$EXPECTED_TEAM_ID" >&2
        exit 1
    }

    app_entitlements="$(codesign -d --entitlements :- "$app_path" 2>/dev/null || true)"
    echo "$app_entitlements" | grep -Fq "$EXPECTED_APP_GROUP" || {
        printf 'error: host App Group entitlement (%s) missing from signed app\n' "$EXPECTED_APP_GROUP" >&2
        exit 1
    }
    widget_entitlements="$(codesign -d --entitlements :- "$widget_path" 2>/dev/null || true)"
    echo "$widget_entitlements" | grep -Fq "$EXPECTED_APP_GROUP" || {
        printf 'error: widget App Group entitlement missing from signed widget\n' >&2
        exit 1
    }
    echo "$widget_entitlements" | plutil -p - | grep -Fq '"com.apple.security.app-sandbox" => true' || {
        printf 'error: widget sandbox entitlement is missing or disabled\n' >&2
        exit 1
    }
    if find "$app_path" -name embedded.provisionprofile -print -quit | grep -q .; then
        printf 'error: Team-ID app group release must not embed provisioning profiles\n' >&2
        exit 1
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

if [[ "$DRY_RUN" -eq 0 ]]; then
    spctl --status | grep -F "assessments enabled" >/dev/null || {
        printf 'Gatekeeper assessments must be enabled before release verification.\n' >&2
        exit 65
    }
else
    quote_command spctl --status "|" grep -F "assessments enabled"
fi

if [[ -n "$APP_PATH" ]]; then
    if [[ "$DRY_RUN" -eq 0 && ! -d "$APP_PATH" ]]; then
        printf 'App bundle not found: %s\n' "$APP_PATH" >&2
        exit 66
    fi
    WIDGET_PATH="$APP_PATH/Contents/PlugIns/WhatTheTokenWidget.appex"
    if [[ "$DRY_RUN" -eq 0 ]]; then
        verify_profileless_app_bundle "$APP_PATH"
    else
        WIDGET_INFO_PLIST_Q="$(shell_quote "$WIDGET_PATH/Contents/Info.plist")"
        WIDGET_PATH_Q="$(shell_quote "$WIDGET_PATH")"
        APP_PATH_Q="$(shell_quote "$APP_PATH")"
        print_shell_command "/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' $WIDGET_INFO_PLIST_Q | grep -Fx com.whatthetoken.mac.widget"
        print_shell_command "WIDGET_TEAM=\"\$(codesign -dvv $WIDGET_PATH_Q 2>&1 | awk -F= '/TeamIdentifier/ { print \$2; exit }')\""
        print_shell_command "APP_TEAM=\"\$(codesign -dvv $APP_PATH_Q 2>&1 | awk -F= '/TeamIdentifier/ { print \$2; exit }')\""
        print_shell_command "test \"\$APP_TEAM\" = $EXPECTED_TEAM_ID # Developer ID team"
        print_shell_command "codesign -d --entitlements :- $APP_PATH_Q 2>/dev/null | grep -Fq $EXPECTED_APP_GROUP # App Group entitlement"
        print_shell_command "codesign -d --entitlements :- $WIDGET_PATH_Q 2>/dev/null | grep -Fq $EXPECTED_APP_GROUP # App Group entitlement"
        print_shell_command "codesign -d --entitlements :- $WIDGET_PATH_Q 2>/dev/null | plutil -p - | grep -Fq '\"com.apple.security.app-sandbox\" => true' # widget sandbox"
        print_shell_command "test -z \"\$(find $APP_PATH_Q -name embedded.provisionprofile -print -quit)\" # profileless Team-ID app group"
    fi
    if [[ "$DRY_RUN" -eq 0 ]]; then
        codesign -dv --verbose=4 "$APP_PATH" 2>&1 | grep -F "Timestamp="
    else
        quote_command codesign -dv --verbose=4 "$APP_PATH" "2>&1" "|" grep -F "Timestamp="
    fi
    run_command spctl -a -vv -t exec "$APP_PATH"
fi

run_command hdiutil verify "$DMG_PATH"
if [[ "$DRY_RUN" -eq 0 ]]; then
    codesign -dv --verbose=4 "$DMG_PATH" 2>&1 | grep -F "Timestamp="
else
    quote_command codesign -dv --verbose=4 "$DMG_PATH" "2>&1" "|" grep -F "Timestamp="
fi
run_command xcrun stapler validate "$DMG_PATH"
run_command spctl -a -vv -t open --context context:primary-signature "$DMG_PATH"

if [[ "$DRY_RUN" -eq 0 ]]; then
    MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/whatthetoken-dmg.XXXXXX")"
    COPY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/whatthetoken-copy.XXXXXX")"
    detach_dmg() {
        hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
        rm -rf "$MOUNT_DIR" "$COPY_DIR"
    }
    trap detach_dmg EXIT

    hdiutil attach "$DMG_PATH" -readonly -nobrowse -mountpoint "$MOUNT_DIR" >/dev/null

    if [[ ! -d "$MOUNT_DIR/WhatTheToken.app" ]]; then
        printf 'Mounted DMG does not contain WhatTheToken.app.\n' >&2
        exit 66
    fi
    if [[ ! -L "$MOUNT_DIR/Applications" ]]; then
        printf 'Mounted DMG does not contain an Applications symlink.\n' >&2
        exit 66
    fi

    cp -R "$MOUNT_DIR/WhatTheToken.app" "$COPY_DIR/WhatTheToken.app"
    verify_profileless_app_bundle "$COPY_DIR/WhatTheToken.app"
    codesign --verify --deep --strict --verbose=2 "$COPY_DIR/WhatTheToken.app"
    codesign -dv --verbose=4 "$COPY_DIR/WhatTheToken.app" 2>&1 | grep -F "Timestamp="
    spctl -a -vv -t exec "$COPY_DIR/WhatTheToken.app"
    /usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$COPY_DIR/WhatTheToken.app/Contents/Info.plist" | grep -Fx "AppIcon" >/dev/null
    test -f "$COPY_DIR/WhatTheToken.app/Contents/Resources/Assets.car"
    test -f "$COPY_DIR/WhatTheToken.app/Contents/Resources/PrivacyInfo.xcprivacy"
    lipo "$COPY_DIR/WhatTheToken.app/Contents/MacOS/WhatTheTokenMac" -verify_arch arm64 x86_64
else
    quote_command hdiutil attach "$DMG_PATH" -readonly -nobrowse -mountpoint /tmp/whatthetoken-dmg
    quote_command test -d /tmp/whatthetoken-dmg/WhatTheToken.app
    quote_command test -L /tmp/whatthetoken-dmg/Applications
    quote_command test -d /tmp/whatthetoken-dmg/WhatTheToken.app/Contents/PlugIns/WhatTheTokenWidget.appex
    quote_command test -f /tmp/whatthetoken-dmg/WhatTheToken.app/Contents/Resources/PrivacyInfo.xcprivacy
    quote_command hdiutil detach /tmp/whatthetoken-dmg
fi

checksum_path="$DMG_PATH.sha256"
if [[ "$DRY_RUN" -eq 1 ]]; then
    quote_command cd "$(dirname "$DMG_PATH")" "&&" shasum -a 256 "$(basename "$DMG_PATH")" ">" "$checksum_path"
    quote_command cd "$(dirname "$DMG_PATH")" "&&" shasum -a 256 -c "$(basename "$DMG_PATH").sha256"
else
    ( cd "$(dirname "$DMG_PATH")" && shasum -a 256 "$(basename "$DMG_PATH")" ) > "$checksum_path"
    ( cd "$(dirname "$DMG_PATH")" && shasum -a 256 -c "$(basename "$DMG_PATH").sha256" )
    printf '%s\n' "$checksum_path"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'Dry run only. No release artifacts were verified or checksummed.\n'
fi
