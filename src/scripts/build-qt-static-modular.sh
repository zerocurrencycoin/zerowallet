#!/bin/bash
# Copyright 2026 Zero Developers
# Practice: build static Qt from modular downloads (qtbase + qtwebsockets only).
# Download ~50MB instead of ~633MB; build flow differs from single tarball.
# Output: qt5-static-modular/ in repo root (separate from qt5-static).
# Usage: ./src/scripts/build-qt-static-modular.sh [ -f | -j N ]
#   -f: force full rebuild  -j N: parallel jobs
set -e -u -o pipefail
# shellcheck disable=SC2034
ME="build-qt-static-modular"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
cd "$REPO_ROOT"

QT_VERSION="${QT_MAJOR:-5}.${QT_MINOR:-15}.${QT_PATCH:-18}"
SUBMODULES_BASE="https://download.qt.io/archive/qt/5.15/${QT_VERSION}/submodules"
OUT_DIR="${QT_STATIC_DIR_MODULAR:-qt5-static-modular}"
BUILD_ROOT="$REPO_ROOT/$OUT_DIR"
PREFIX="$BUILD_ROOT/install"
FORCE="${FORCE_MODULAR:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force) FORCE=1; shift ;;
    -j|--jobs) JOBS="${JOBS:-$2}"; shift 2 ;;
    -j*) JOBS="${JOBS:-${1#-j}}"; shift ;;
    -h|--help)
      echo "Usage: ${ME} [ -f | -j N ]"
      echo "  Build static Qt from modular source (qtbase + qtwebsockets). Output: ${OUT_DIR}/install"
      echo "  -f, --force   force full rebuild"
      echo "  -j N          parallel jobs (default: auto)"
      exit 0
      ;;
    *) shift ;;
  esac
done

mkdir -p "$BUILD_ROOT"
cd "$BUILD_ROOT"

# --- qtbase ---
QBASE_TAR="qtbase-everywhere-opensource-src-${QT_VERSION}.tar.xz"
QBASE_DIR="qtbase-everywhere-src-${QT_VERSION}"
QBASE_URL="${SUBMODULES_BASE}/${QBASE_TAR}"

if [ -n "$FORCE" ]; then
  rm -rf "$QBASE_DIR" build-qtbase
fi
if [ ! -d "$QBASE_DIR" ]; then
  [ ! -f "$QBASE_TAR" ] && notice "Downloading qtbase..." && curl -L -o "$QBASE_TAR" "$QBASE_URL" || err "qtbase download failed"
  notice "Extracting qtbase..."
  tar xf "$QBASE_TAR" || err "qtbase extract failed"
fi
[ -d "$QBASE_DIR" ] || err "qtbase dir missing: $QBASE_DIR"

mkdir -p build-qtbase
cd build-qtbase
if [ ! -f config.summary ] || [ -n "$FORCE" ]; then
  notice "Configuring qtbase (static, prefix=$PREFIX)..."
  ../"$QBASE_DIR"/configure -opensource -confirm-license -static -release \
    -prefix "$PREFIX" \
    -nomake tools -nomake tests -nomake examples \
    || err 'qtbase configure failed'
fi
notice "Building qtbase..."
make -j"${JOBS:-2}" || err 'qtbase build failed'
notice "Installing qtbase..."
make install || err 'qtbase install failed'
cd ..

# --- qtwebsockets (needs qtbase in prefix) ---
QWS_TAR="qtwebsockets-everywhere-opensource-src-${QT_VERSION}.tar.xz"
QWS_DIR="qtwebsockets-everywhere-src-${QT_VERSION}"
QWS_URL="${SUBMODULES_BASE}/${QWS_TAR}"

if [ -n "$FORCE" ]; then
  rm -rf "$QWS_DIR" build-qtwebsockets
fi
if [ ! -d "$QWS_DIR" ]; then
  [ ! -f "$QWS_TAR" ] && notice "Downloading qtwebsockets..." && curl -L -o "$QWS_TAR" "$QWS_URL" || err "qtwebsockets download failed"
  notice "Extracting qtwebsockets..."
  tar xf "$QWS_TAR" || err "qtwebsockets extract failed"
fi
[ -d "$QWS_DIR" ] || err "qtwebsockets dir missing: $QWS_DIR"

export PATH="$PREFIX/bin:$PATH"
mkdir -p build-qtwebsockets
cd build-qtwebsockets
if [ ! -f config.summary ] || [ -n "$FORCE" ]; then
  notice "Configuring qtwebsockets (prefix=$PREFIX)..."
  ../"$QWS_DIR"/configure -prefix "$PREFIX" -release || err 'qtwebsockets configure failed'
fi
notice "Building qtwebsockets..."
make -j"${JOBS:-2}" || err 'qtwebsockets build failed'
notice "Installing qtwebsockets..."
make install || err 'qtwebsockets install failed'
cd ..

[ -x "$PREFIX/bin/qmake" ] || err "qmake not found at $PREFIX/bin/qmake"
notice "Done. QT_PREFIX=$PREFIX"
notice "Use for zerowallet: mkrelease-linux.sh -q $PREFIX"
