#!/usr/bin/env bash

validate_release_version() {
    local version="${1:-}"

    if [[ -z "$version" ]]; then
        printf 'Version is required.\n' >&2
        return 64
    fi

    if ! [[ "$version" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]]; then
        printf 'Version must use numeric x.y.z format.\n' >&2
        return 64
    fi
}

validate_release_build() {
    local build="${1:-}"

    if [[ -z "$build" ]]; then
        printf 'Build is required.\n' >&2
        return 64
    fi

    if ! [[ "$build" =~ ^[1-9][0-9]*$ ]]; then
        printf 'Build must be a monotonically increasing integer.\n' >&2
        return 64
    fi
}

release_xcconfig_value() {
    local config="$1"
    local key="$2"

    awk -F= -v key="$key" '
        $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
            gsub(/[[:space:]]/, "", $2)
            print $2
            exit
        }
    ' "$config"
}

assert_release_build_increases() {
    local requested_build="$1"
    local config="$2"
    local current_build

    current_build="$(release_xcconfig_value "$config" "CURRENT_PROJECT_VERSION")"
    if [[ -n "$current_build" && "$current_build" =~ ^[1-9][0-9]*$ && "$requested_build" -le "$current_build" ]]; then
        printf 'Build must increase. Current build is %s, requested %s.\n' "$current_build" "$requested_build" >&2
        return 65
    fi
}

assert_release_matches_xcconfig() {
    local requested_version="$1"
    local requested_build="$2"
    local config="$3"
    local current_version
    local current_build

    current_version="$(release_xcconfig_value "$config" "MARKETING_VERSION")"
    current_build="$(release_xcconfig_value "$config" "CURRENT_PROJECT_VERSION")"

    if [[ "$requested_version" != "$current_version" || "$requested_build" != "$current_build" ]]; then
        printf 'Release version/build must match committed Packaging/WhatTheToken.xcconfig.\n' >&2
        printf 'Requested: version=%s build=%s\n' "$requested_version" "$requested_build" >&2
        printf 'Committed: version=%s build=%s\n' "${current_version:-<missing>}" "${current_build:-<missing>}" >&2
        return 65
    fi
}
