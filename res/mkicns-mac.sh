#!/bin/bash
# Copyright 2026 Zero Developers
# Build macOS .icns from SVG via Inkscape. Adapted from the iconset/iconutil
# pattern in https://stackoverflow.com/a/20703594 (Aidan, CC BY-SA 3.0).
# Usage: mkicns-mac.sh [INKSCAPE] [SVG_PATH] [OUT_BASE]
#   INKSCAPE  default: inkscape
#   SVG_PATH  default: logo.svg
#   OUT_BASE  default: logo (output: logo.icns)
set -e -u -o pipefail

INKSCAPE="${1:-inkscape}"
SVG_PATH="${2:-logo.svg}"
OUT_BASE="${3:-logo}"

ICONSET="${OUT_BASE}.iconset"
mkdir -p "$ICONSET"
"$INKSCAPE" -z -e "${PWD}/${ICONSET}/icon_16x16.png"      -w   16 -h   16 -y 0 "${PWD}/${SVG_PATH}"
"$INKSCAPE" -z -e "${PWD}/${ICONSET}/icon_16x16@2x.png"   -w   32 -h   32 -y 0 "${PWD}/${SVG_PATH}"
"$INKSCAPE" -z -e "${PWD}/${ICONSET}/icon_32x32.png"      -w   32 -h   32 -y 0 "${PWD}/${SVG_PATH}"
"$INKSCAPE" -z -e "${PWD}/${ICONSET}/icon_32x32@2x.png"   -w   64 -h   64 -y 0 "${PWD}/${SVG_PATH}"
"$INKSCAPE" -z -e "${PWD}/${ICONSET}/icon_128x128.png"    -w  128 -h  128 -y 0 "${PWD}/${SVG_PATH}"
"$INKSCAPE" -z -e "${PWD}/${ICONSET}/icon_128x128@2x.png" -w  256 -h  256 -y 0 "${PWD}/${SVG_PATH}"
"$INKSCAPE" -z -e "${PWD}/${ICONSET}/icon_256x256.png"    -w  256 -h  256 -y 0 "${PWD}/${SVG_PATH}"
"$INKSCAPE" -z -e "${PWD}/${ICONSET}/icon_256x256@2x.png" -w  512 -h  512 -y 0 "${PWD}/${SVG_PATH}"
"$INKSCAPE" -z -e "${PWD}/${ICONSET}/icon_512x512.png"    -w  512 -h  512 -y 0 "${PWD}/${SVG_PATH}"
"$INKSCAPE" -z -e "${PWD}/${ICONSET}/icon_512x512@2x.png" -w 1024 -h 1024 -y 0 "${PWD}/${SVG_PATH}"
iconutil -c icns "$ICONSET"
rm -R "$ICONSET"
