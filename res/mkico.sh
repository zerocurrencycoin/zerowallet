#!/bin/bash
# Copyright 2026 Zero Developers
# Build Windows .ico from SVG via Inkscape and ImageMagick convert.
# Usage: mkico.sh [SVG_PATH] [ICO_OUT]
#   SVG_PATH  default: logo.svg
#   ICO_OUT   default: icon.ico
set -e -u -o pipefail

SVG_PATH="${1:-logo.svg}"
ICO_OUT="${2:-icon.ico}"

for SIZE in 16 32 48 128 256; do
    inkscape -z -e "${SIZE}.png" -w "$SIZE" -h "$SIZE" "$SVG_PATH" >/dev/null 2>/dev/null
done
convert 16.png 32.png 48.png 128.png 256.png -colors 256 "$ICO_OUT"
rm 16.png 32.png 48.png 128.png 256.png
