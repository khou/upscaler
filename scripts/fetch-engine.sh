#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENGINE_DIR="$ROOT_DIR/Resources/engine"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

UPSCAYL_TAG="20251207-174704"
UPSCAYL_ZIP="upscayl-bin-${UPSCAYL_TAG}-macos.zip"
UPSCAYL_URL="https://github.com/upscayl/upscayl-ncnn/releases/download/${UPSCAYL_TAG}/${UPSCAYL_ZIP}"

REALESRGAN_ZIP="realesrgan-ncnn-vulkan-20220424-macos.zip"
REALESRGAN_URL="https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/${REALESRGAN_ZIP}"

mkdir -p "$ENGINE_DIR/models"

echo "==> Downloading upscayl-ncnn (universal arm64+x86_64 binary)"
curl -fL --progress-bar "$UPSCAYL_URL" -o "$TMP_DIR/upscayl.zip"
unzip -q "$TMP_DIR/upscayl.zip" -d "$TMP_DIR/upscayl"
BIN_PATH="$(find "$TMP_DIR/upscayl" -name 'upscayl-bin' -type f | head -1)"
if [ -z "$BIN_PATH" ]; then
  echo "Error: upscayl-bin not found in archive" >&2
  exit 1
fi
cp "$BIN_PATH" "$ENGINE_DIR/upscayl-bin"
chmod +x "$ENGINE_DIR/upscayl-bin"
xattr -d com.apple.quarantine "$ENGINE_DIR/upscayl-bin" 2>/dev/null || true

echo "==> Downloading Real-ESRGAN models"
curl -fL --progress-bar "$REALESRGAN_URL" -o "$TMP_DIR/realesrgan.zip"
unzip -q "$TMP_DIR/realesrgan.zip" -d "$TMP_DIR/realesrgan"
MODELS_DIR="$(find "$TMP_DIR/realesrgan" -name 'models' -type d | head -1)"
if [ -z "$MODELS_DIR" ]; then
  echo "Error: models directory not found in Real-ESRGAN archive" >&2
  exit 1
fi
for name in realesrgan-x4plus realesrgan-x4plus-anime realesrnet-x4plus; do
  for ext in bin param; do
    src="$MODELS_DIR/$name.$ext"
    if [ -f "$src" ]; then
      cp "$src" "$ENGINE_DIR/models/"
    fi
  done
done

echo
echo "Engine installed to $ENGINE_DIR"
ls -la "$ENGINE_DIR"
ls -la "$ENGINE_DIR/models"
