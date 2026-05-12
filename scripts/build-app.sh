#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/VaultBar.app"
OUTPUT_DIR="$ROOT_DIR/build"
APP_OUTPUT_DIR="$OUTPUT_DIR/VaultBar.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
mkdir -p "$ROOT_DIR/.build/cache/xdg" "$ROOT_DIR/.build/cache/clang" "$ROOT_DIR/.build/cache/swiftpm"
XDG_CACHE_HOME="$ROOT_DIR/.build/cache/xdg" \
CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/cache/clang" \
swift build -c release \
  --cache-path "$ROOT_DIR/.build/cache/swiftpm" \
  --manifest-cache local \
  --disable-sandbox

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/release/VaultBar" "$MACOS_DIR/VaultBar"
cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$ROOT_DIR/Resources/AppIconMenu.png" "$RESOURCES_DIR/AppIconMenu.png"

xattr -cr "$APP_DIR"
codesign --force --sign - --entitlements "$ROOT_DIR/VaultBar.entitlements" "$APP_DIR" >/dev/null
rm -rf "$APP_OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
cp -R "$APP_DIR" "$APP_OUTPUT_DIR"
echo "$APP_OUTPUT_DIR"
