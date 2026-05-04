#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENGINE_DIR="$ROOT_DIR/Resources/engine"
APP_NAME="Upscaler"
APP_DIR="$ROOT_DIR/build/${APP_NAME}.app"
SRC_SCRIPT="$ROOT_DIR/upscaler.applescript"

if [ ! -x "$ENGINE_DIR/upscayl-bin" ]; then
  echo "Engine missing. Run scripts/fetch-engine.sh first." >&2
  exit 1
fi

echo "==> Compiling AppleScript droplet"
mkdir -p "$ROOT_DIR/build"
rm -rf "$APP_DIR"
osacompile -o "$APP_DIR" "$SRC_SCRIPT"

echo "==> Bundling engine into ${APP_NAME}.app/Contents/Resources/engine"
mkdir -p "$APP_DIR/Contents/Resources/engine/models"
cp "$ENGINE_DIR/upscayl-bin" "$APP_DIR/Contents/Resources/engine/upscayl-bin"
chmod +x "$APP_DIR/Contents/Resources/engine/upscayl-bin"
cp "$ENGINE_DIR/models/"* "$APP_DIR/Contents/Resources/engine/models/"

echo "==> Patching Info.plist (name, drop types, high-DPI)"
PLIST="$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName ${APP_NAME}" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string ${APP_NAME}" "$PLIST" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${APP_NAME}" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string ai.tokonoma.upscaler" "$PLIST" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ai.tokonoma.upscaler" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :NSHighResolutionCapable bool true" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :LSApplicationCategoryType string public.app-category.graphics-design" "$PLIST" 2>/dev/null || true

# Declare we accept image and folder drops so the icon highlights when dragging
/usr/libexec/PlistBuddy -c "Delete :CFBundleDocumentTypes" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0 dict" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeName string Image or Folder" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Viewer" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:0 string public.image" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:1 string public.folder" "$PLIST"

echo "==> Ad-hoc signing (so Gatekeeper allows the bundled binary on first run)"
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
xattr -dr com.apple.quarantine "$APP_DIR" 2>/dev/null || true

echo
echo "Built: $APP_DIR"
du -sh "$APP_DIR"
echo
echo "Install with:  cp -R '$APP_DIR' /Applications/"
echo "Or drag '$APP_DIR' to /Applications in Finder."
