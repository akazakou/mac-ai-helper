#!/bin/bash
# ==============================================================================
# Convert SVG to macOS .icns icon file
# Uses native macOS tools: sips + iconutil (no external dependencies)
#
# Usage: create-icns.sh <input.svg> <output.icns> <temp_iconset_dir>
# ==============================================================================

set -euo pipefail

SVG_INPUT="${1:?Usage: create-icns.sh <input.svg> <output.icns> <temp_iconset_dir>}"
ICNS_OUTPUT="${2:?Missing output .icns path}"
ICONSET_DIR="${3:?Missing temp iconset directory path}"

# Ensure input file exists
if [ ! -f "$SVG_INPUT" ]; then
    echo "Error: Input file not found: $SVG_INPUT"
    exit 1
fi

# Clean and create iconset directory
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Required icon sizes for macOS .icns
# Format: filename dimensions
ICON_SIZES=(
    "icon_16x16.png 16"
    "icon_16x16@2x.png 32"
    "icon_32x32.png 32"
    "icon_32x32@2x.png 64"
    "icon_128x128.png 128"
    "icon_128x128@2x.png 256"
    "icon_256x256.png 256"
    "icon_256x256@2x.png 512"
    "icon_512x512.png 512"
    "icon_512x512@2x.png 1024"
)

# Check if we have a rasterizer available
# Try: qlmanage (built-in), rsvg-convert (homebrew), or sips with a temp PNG
RASTERIZER=""

if command -v rsvg-convert &>/dev/null; then
    RASTERIZER="rsvg"
elif command -v qlmanage &>/dev/null; then
    RASTERIZER="qlmanage"
else
    echo "Warning: No SVG rasterizer found. Trying sips (may not support SVG)."
    RASTERIZER="sips"
fi

# Generate a high-res base PNG from SVG first
BASE_PNG="${ICONSET_DIR}/base_1024.png"

case "$RASTERIZER" in
    rsvg)
        rsvg-convert -w 1024 -h 1024 "$SVG_INPUT" -o "$BASE_PNG"
        ;;
    qlmanage)
        # qlmanage can render SVG to thumbnail
        qlmanage -t -s 1024 -o "$ICONSET_DIR" "$SVG_INPUT" &>/dev/null
        # qlmanage creates file with .svg.png extension
        QLMANAGE_OUTPUT=$(find "$ICONSET_DIR" -name "*.png" -maxdepth 1 | head -1)
        if [ -n "$QLMANAGE_OUTPUT" ] && [ -f "$QLMANAGE_OUTPUT" ]; then
            mv "$QLMANAGE_OUTPUT" "$BASE_PNG"
        else
            echo "Error: qlmanage failed to render SVG"
            echo "Install rsvg-convert for reliable SVG support: brew install librsvg"
            exit 1
        fi
        ;;
    sips)
        # sips may not handle SVG directly; try anyway
        sips -s format png -z 1024 1024 "$SVG_INPUT" --out "$BASE_PNG" 2>/dev/null || {
            echo "Error: sips cannot convert SVG."
            echo "Install rsvg-convert: brew install librsvg"
            exit 1
        }
        ;;
esac

if [ ! -f "$BASE_PNG" ]; then
    echo "Error: Failed to create base PNG from SVG"
    exit 1
fi

# Generate all required icon sizes from the base PNG
for ENTRY in "${ICON_SIZES[@]}"; do
    FILENAME=$(echo "$ENTRY" | cut -d' ' -f1)
    SIZE=$(echo "$ENTRY" | cut -d' ' -f2)
    sips -z "$SIZE" "$SIZE" "$BASE_PNG" --out "${ICONSET_DIR}/${FILENAME}" &>/dev/null
done

# Remove the base PNG (not part of iconset)
rm -f "$BASE_PNG"

# Convert iconset to icns
iconutil -c icns -o "$ICNS_OUTPUT" "$ICONSET_DIR"

# Clean up iconset directory
rm -rf "$ICONSET_DIR"

echo "  Generated $(du -h "$ICNS_OUTPUT" | cut -f1 | tr -d ' ') icon: $ICNS_OUTPUT"
