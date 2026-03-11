#!/bin/bash
# Copyright 2026 Zero Developers
# Practice: build static Qt from single tarball but only qtbase + qtwebsockets (extra -skip).
# Reduces build time and install size; download size unchanged (~633MB).
# Output: qt5-static-skip/ in repo root (separate from qt5-static).
# Usage: ./src/scripts/build-qt-static-skip-extra.sh [ -f | -u | -j N ]
#   -f: force all steps  -u: use existing extract only (reconfigure + build)
set -e -u -o pipefail
# shellcheck disable=SC2034
ME="build-qt-static-skip-extra"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
cd "$REPO_ROOT"

QT_VERSION="${QT_MAJOR:-5}.${QT_MINOR:-15}.${QT_PATCH:-18}"
TARBALL="qt-everywhere-opensource-src-${QT_VERSION}.tar.xz"
URL_BASE="https://download.qt.io/archive/qt/5.15/${QT_VERSION}/single"
URL="${URL_BASE}/${TARBALL}"
OUT_DIR="${QT_STATIC_DIR_SKIP:-qt5-static-skip}"
BUILD_ROOT="$REPO_ROOT/$OUT_DIR"
PREFIX="$BUILD_ROOT/install"
FORCE="${FORCE_SKIP:-}"
USE_EXISTING="${USE_EXISTING_SKIP:-}"
# Skip everything we don't need for zerowallet (Core, Gui, Network, WebSockets, Widgets)
SKIP_LIST="webengine qt3d qtcharts qtconnectivity qtdatavis3d qtdoc qtgamepad qtgraphicaleffects qtlocation qtlottie qtmacextras qtmultimedia qtnetworkauth qtpurchasing qtquick3d qtquickcontrols qtquickcontrols2 qtquicktimeline qtremoteobjects qtscript qtscxml qtsensors qtserialbus qtserialport qtspeech qtsvg qtvirtualkeyboard qtwayland qtwebchannel qtwebengine qtwebglplugin qtwebview qtx11extras qtxmlpatterns"
# qtbase provides Core,Gui,Network,Widgets; qtwebsockets is separate. Don't skip qtwebsockets.

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force) FORCE=1; USE_EXISTING=; shift ;;
    -u|--use) USE_EXISTING=1; shift ;;
    -j|--jobs) JOBS="${JOBS:-$2}"; shift 2 ;;
    -j*) JOBS="${JOBS:-${1#-j}}"; shift ;;
    -h|--help)
      echo "Usage: ${ME} [ -f | -u | -j N ]"
      echo "  Build static Qt from single tarball with extra -skip (only qtbase + qtwebsockets built)."
      echo "  Output: ${OUT_DIR}/install"
      echo "  -f, --force   force download, extract, configure, build"
      echo "  -u, --use     skip download/extract; reconfigure and build only"
      echo "  -j N          parallel jobs"
      exit 0
      ;;
    *) shift ;;
  esac
done

mkdir -p "$BUILD_ROOT"
cd "$BUILD_ROOT"

SRC_DIR=""
for d in qt-everywhere-opensource-src-${QT_VERSION} qt-everywhere-src-${QT_VERSION}; do
  if [ -d "$d" ]; then SRC_DIR="$d"; break; fi
done

if [ -z "$USE_EXISTING" ]; then
  if [ -n "$FORCE" ] || [ ! -f "$TARBALL" ]; then
    notice "Downloading single tarball (~633MB)..."
    curl -L -o "$TARBALL" "$URL" || err "download failed"
  fi
  if [ -n "$FORCE" ] || [ -z "$SRC_DIR" ]; then
    notice "Extracting..."
    rm -rf qt-everywhere-opensource-src-${QT_VERSION} qt-everywhere-src-${QT_VERSION}
    tar xf "$TARBALL" || err "extract failed"
    for d in qt-everywhere-opensource-src-${QT_VERSION} qt-everywhere-src-${QT_VERSION}; do
      if [ -d "$d" ]; then SRC_DIR="$d"; break; fi
    done
  fi
fi

[ -z "$SRC_DIR" ] && SRC_DIR="$(tar tf "$TARBALL" 2>/dev/null | awk -F/ '{print $1; exit}')"
[ -d "$SRC_DIR" ] || err "Source dir not found. Run without -u to extract."
[ -x "$SRC_DIR/configure" ] || err "configure not found in $SRC_DIR"

cd "$SRC_DIR"

if [ ! -f config.summary ] || [ -n "$FORCE" ]; then
  notice "Configuring with extra -skip (qtbase + qtwebsockets only)..."
  SKIP_ARGS=""
  for m in $SKIP_LIST; do SKIP_ARGS="$SKIP_ARGS -skip $m"; done
  ./configure -opensource -confirm-license -static -release \
    -prefix "$PREFIX" \
    -nomake tools -nomake tests -nomake examples \
    $SKIP_ARGS \
    || err 'configure failed'
fi

notice "Building..."
make -j"${JOBS:-2}" || err 'build failed'
notice "Installing..."
make install || err 'install failed'

[ -x "$PREFIX/bin/qmake" ] || err "qmake not found at $PREFIX/bin/qmake"
[ -f "$PREFIX/lib/libQt5WebSockets.a" ] || err "libQt5WebSockets.a not found"
notice "Done. QT_PREFIX=$PREFIX"
notice "Use for zerowallet: mkrelease-linux.sh -q $PREFIX"
