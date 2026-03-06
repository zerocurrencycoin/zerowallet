#!/bin/bash
# Copyright 2026 Zero Developers
# Build static Qt 5.15.18 for zerowallet Linux release. One-time, ~30-60 min.
# Output: qt5-static/ in zerowallet repo root.
# Options: -L, -L=PATH, --log=PATH  capture build log (default: logs/build-qt-static.log)
set -e -u -o pipefail
# shellcheck disable=SC2034
ME="build-qt-static"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
cd "$REPO_ROOT"

LOG_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -L) LOG_FILE="${LOG_FILE:-$REPO_ROOT/logs/build-qt-static.log}"; shift ;;
    -L=*) LOG_FILE="${1#-L=}"; shift ;;
    --log)
      if [ -n "${2:-}" ] && [[ "$2" != -* ]]; then LOG_FILE="$2"; shift 2
      else LOG_FILE="${LOG_FILE:-$REPO_ROOT/logs/build-qt-static.log}"; shift; fi
      ;;
    --log=*) LOG_FILE="${1#--log=}"; shift ;;
    *) break ;;
  esac
done
[ -n "${LOG_FILE:-}" ] && mkdir -p "$(dirname "${LOG_FILE}")" && exec > >(tee -a "${LOG_FILE}") 2>&1

QT_PREFIX="$REPO_ROOT/qt5-static"
# shellcheck disable=SC2034
QT_SRC="$REPO_ROOT/qt5-static/qt-everywhere-opensource-src-5.15.18"
URL="https://download.qt.io/archive/qt/5.15/5.15.18/single/qt-everywhere-opensource-src-5.15.18.tar.xz"

if [ -x "$QT_PREFIX/bin/qmake" ]; then
    notice "Static Qt already at ${QT_PREFIX}. Remove to rebuild."
    exit 0
fi

mkdir -p "$REPO_ROOT/qt5-static"
cd "$REPO_ROOT/qt5-static"

if [ ! -f qt-everywhere-opensource-src-5.15.18.tar.xz ]; then
    notice 'Downloading Qt 5.15.18...'
    curl -L -o qt-everywhere-opensource-src-5.15.18.tar.xz "$URL" || err 'download failed'
fi

if [ ! -d qt-everywhere-opensource-src-5.15.18 ]; then
    notice 'Extracting...'
    tar xf qt-everywhere-opensource-src-5.15.18.tar.xz || err 'extract failed'
fi

cd qt-everywhere-opensource-src-5.15.18
PATCH_FILE="$REPO_ROOT/res/patches/qt-gcc13.diff"
if [ -f "$PATCH_FILE" ]; then
  notice 'Applying GCC 13+ patch...'
  (cd qtlocation && patch -p1 < "$PATCH_FILE") || err "GCC 13 patch failed. Script: ${SCRIPT_DIR}/build-qt-static.sh. Patch: ${PATCH_FILE}. See BUILD.md § GCC 13+ (Linux static Qt)."
fi
notice "Configuring (prefix=${QT_PREFIX})..."
./configure -opensource -confirm-license -static -release \
    -prefix "$QT_PREFIX" \
    -ltcg -no-pch \
    -skip webengine -nomake tools -nomake tests -nomake examples

notice 'Building (this takes 30-60 min)...'
make -j"$(nproc)" || err 'Qt build failed'
make install || err 'Qt install failed'

notice "Done. QT_PREFIX=${QT_PREFIX}"
