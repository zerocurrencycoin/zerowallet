#!/bin/bash
# Build static Qt 5.15.18 for zerowallet Linux release. One-time, ~30-60 min.
# Output: qt5-static/ in zerowallet repo root.
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ME="build-qt-static"
. "$SCRIPT_DIR/lib-log.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
QT_PREFIX="$REPO_ROOT/qt5-static"
QT_SRC="$REPO_ROOT/qt5-static/qt-everywhere-opensource-src-5.15.18"
URL="https://download.qt.io/archive/qt/5.15/5.15.18/single/qt-everywhere-opensource-src-5.15.18.tar.xz"

if [ -x "$QT_PREFIX/bin/qmake" ]; then
    notice "Static Qt already at $QT_PREFIX. Remove to rebuild."
    exit 0
fi

mkdir -p "$REPO_ROOT/qt5-static"
cd "$REPO_ROOT/qt5-static"

if [ ! -f qt-everywhere-opensource-src-5.15.18.tar.xz ]; then
    notice "Downloading Qt 5.15.18..."
    curl -L -o qt-everywhere-opensource-src-5.15.18.tar.xz "$URL" || err "download failed"
fi

if [ ! -d qt-everywhere-opensource-src-5.15.18 ]; then
    notice "Extracting..."
    tar xf qt-everywhere-opensource-src-5.15.18.tar.xz || err "extract failed"
fi

cd qt-everywhere-opensource-src-5.15.18
notice "Configuring (prefix=$QT_PREFIX)..."
./configure -opensource -confirm-license -static -release \
    -prefix "$QT_PREFIX" \
    -ltcg -no-pch \
    -skip webengine -nomake tools -nomake tests -nomake examples

notice "Building (this takes 30-60 min)..."
make -j$(nproc) || err "Qt build failed"
make install || err "Qt install failed"

notice "Done. QT_STATIC=$QT_PREFIX"
