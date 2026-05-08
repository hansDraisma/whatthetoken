#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="WhatTheToken"
PRODUCT_NAME="WhatTheTokenMac"
CONFIGURATION="${CONFIGURATION:-release}"
OUTPUT_DIR="${OUTPUT_DIR:-"$ROOT_DIR/.build/app"}"
APP_DIR="$OUTPUT_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

swift build --package-path "$ROOT_DIR" -c "$CONFIGURATION" --product "$PRODUCT_NAME"

TRIPLE="$(swift build --package-path "$ROOT_DIR" -c "$CONFIGURATION" --show-bin-path)"
BINARY="$TRIPLE/$PRODUCT_NAME"
RESOURCE_BUNDLE="$TRIPLE/${PRODUCT_NAME}_${PRODUCT_NAME}.bundle"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BINARY" "$MACOS_DIR/$PRODUCT_NAME"
cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_DIR/"
fi

echo "$APP_DIR"
