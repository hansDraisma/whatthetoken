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
    run_command codesign --verify --strict --verbose=2 "$APP_PATH"
    WIDGET_PATH="$APP_PATH/Contents/PlugIns/WhatTheTokenWidget.appex"
    run_command test -d "$APP_PATH/Contents/PlugIns/WhatTheTokenWidget.appex"
    run_command codesign --verify --strict --verbose=2 "$WIDGET_PATH"
    if [[ "$DRY_RUN" -eq 0 ]]; then
        WIDGET_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$WIDGET_PATH/Contents/Info.plist")"
        [[ "$WIDGET_BUNDLE_ID" == "com.whatthetoken.mac.widget" ]] || {
            printf 'error: widget bundle id is %s, expected com.whatthetoken.mac.widget\n' "$WIDGET_BUNDLE_ID" >&2
            exit 1
        }
        WIDGET_TEAM="$(codesign -dvv "$WIDGET_PATH" 2>&1 | awk -F'=' '/TeamIdentifier/ { print $2; exit }')"
        APP_TEAM="$(codesign -dvv "$APP_PATH" 2>&1 | awk -F'=' '/TeamIdentifier/ { print $2; exit }')"
        [[ -n "$WIDGET_TEAM" && "$WIDGET_TEAM" == "$APP_TEAM" ]] || {
            printf 'error: widget TeamIdentifier (%s) does not match app (%s)\n' "$WIDGET_TEAM" "$APP_TEAM" >&2
            exit 1
        }
        APP_ENTITLEMENTS="$(codesign -d --entitlements :- "$APP_PATH" 2>/dev/null || true)"
        echo "$APP_ENTITLEMENTS" | grep -q "group.com.whatthetoken.mac" || {
            printf 'error: host App Group entitlement (group.com.whatthetoken.mac) missing from signed app\n' >&2
            exit 1
        }
        WIDGET_ENTITLEMENTS="$(codesign -d --entitlements :- "$WIDGET_PATH" 2>/dev/null || true)"
        echo "$WIDGET_ENTITLEMENTS" | grep -q "group.com.whatthetoken.mac" || {
            printf 'error: widget App Group entitlement missing from signed widget\n' >&2
            exit 1
        }
    else
        WIDGET_INFO_PLIST_Q="$(shell_quote "$WIDGET_PATH/Contents/Info.plist")"
        WIDGET_PATH_Q="$(shell_quote "$WIDGET_PATH")"
        APP_PATH_Q="$(shell_quote "$APP_PATH")"
        print_shell_command "/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' $WIDGET_INFO_PLIST_Q | grep -Fx com.whatthetoken.mac.widget"
        print_shell_command "WIDGET_TEAM=\"\$(codesign -dvv $WIDGET_PATH_Q 2>&1 | awk -F= '/TeamIdentifier/ { print \$2; exit }')\""
        print_shell_command "APP_TEAM=\"\$(codesign -dvv $APP_PATH_Q 2>&1 | awk -F= '/TeamIdentifier/ { print \$2; exit }')\""
        print_shell_command "codesign -d --entitlements :- $APP_PATH_Q 2>/dev/null | grep -q group.com.whatthetoken.mac # App Group entitlement"
        print_shell_command "codesign -d --entitlements :- $WIDGET_PATH_Q 2>/dev/null | grep -q group.com.whatthetoken.mac # App Group entitlement"
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
    codesign --verify --deep --strict --verbose=2 "$COPY_DIR/WhatTheToken.app"
    test -d "$COPY_DIR/WhatTheToken.app/Contents/PlugIns/WhatTheTokenWidget.appex"
    codesign --verify --strict --verbose=2 "$COPY_DIR/WhatTheToken.app/Contents/PlugIns/WhatTheTokenWidget.appex"
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
    quote_command bash -c 'cd "$(dirname "$DMG_PATH")" && shasum -a 256 "$(basename "$DMG_PATH")"' ">" "$checksum_path"
else
    ( cd "$(dirname "$DMG_PATH")" && shasum -a 256 "$(basename "$DMG_PATH")" ) > "$checksum_path"
    shasum -a 256 -c "$checksum_path"
    printf '%s\n' "$checksum_path"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'Dry run only. No release artifacts were verified or checksummed.\n'
fi
