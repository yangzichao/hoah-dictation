#!/usr/bin/env bash

# Simple DMG packager with Applications link and optional background/volume icon.
# Usage: ./scripts/packaging/build_dmg.sh [version]

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="${1:-3.0.0}"
SCHEME="HoAh"
CONFIG="Release"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"

DERIVED_DIR="$ROOT_DIR/build/DerivedData"
APP_PATH="$DERIVED_DIR/Build/Products/$CONFIG/HoAh.app"
STAGING_DIR="$ROOT_DIR/build/dmg-root"
DMG_PATH="$ROOT_DIR/build/HoAh-$VERSION.dmg"

BACKGROUND_SRC="$ROOT_DIR/docs/dmg-background.png"
VOLUME_ICON_SRC="$ROOT_DIR/docs/volume.icns"

echo "==> Building $SCHEME ($CONFIG)…"
if [ -n "$SIGN_IDENTITY" ]; then
  xcodebuild -scheme "$SCHEME" -configuration "$CONFIG" \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" ARCHS=arm64 ONLY_ACTIVE_ARCH=YES SWIFT_DISABLE_EXPLICIT_MODULES=YES \
    -derivedDataPath "$DERIVED_DIR"
else
  # Ad-hoc / unsigned build to avoid certificate requirements
  xcodebuild -scheme "$SCHEME" -configuration "$CONFIG" \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGNING_IDENTITY="" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=YES SWIFT_DISABLE_EXPLICIT_MODULES=YES ENABLE_HARDENED_RUNTIME=NO \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS="" \
    -derivedDataPath "$DERIVED_DIR"
fi

if [ ! -d "$APP_PATH" ]; then
  echo "✖️  Could not find built app at $APP_PATH" >&2
  exit 1
fi

echo "==> Preparing staging directory…"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

cat > "$STAGING_DIR/README.txt" <<'EOF'
HoAh Install Hint / 安装提示
--------------------------------
Drag HoAh.app onto the Applications icon on the right.
Then launch HoAh from your Applications folder.

将 HoAh.app 拖拽到右侧的 Applications（应用程序）图标。
安装完成后，请从“应用程序”文件夹里启动 HoAh。
EOF

if [ -f "$BACKGROUND_SRC" ]; then
  echo "==> Adding background image from $BACKGROUND_SRC"
  mkdir -p "$STAGING_DIR/.background"
  cp "$BACKGROUND_SRC" "$STAGING_DIR/.background/bg.png"
fi

if [ -f "$VOLUME_ICON_SRC" ]; then
  echo "==> Adding volume icon from $VOLUME_ICON_SRC"
  cp "$VOLUME_ICON_SRC" "$STAGING_DIR/.VolumeIcon.icns"
  SetFile -a C "$STAGING_DIR/.VolumeIcon.icns" || true
fi

echo "==> Creating DMG $DMG_PATH"
rm -f "$DMG_PATH"
hdiutil create -volname "HoAh $VERSION" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"

echo "✅ DMG created at: $DMG_PATH"
