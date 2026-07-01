#!/bin/bash
# Copyright 2026 Zero Developers
# Build static Qt for zerowallet Linux release. One-time, ~30-60 min.
# Output: qt5-static/ in zerowallet repo root.
# Options:
#   -L, -L=PATH, --log=PATH [LOG_FILE] capture build log
#   -f/--force [FORCE_ALL] run all steps
#   -u/--use [USE_EXISTING] skip download/extract only
#   -n/--nopatch [NO_PATCH] skip GCC patch step
#   -o/--qtminor [QT_MINOR], -a/--qtlast [QT_PATCH]
set -e -u -o pipefail
# shellcheck disable=SC2034
ME="build-qt-static"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
cd "$REPO_ROOT"

DEFAULT_QT_MAJOR="5"
DEFAULT_QT_MINOR="15"
DEFAULT_QT_PATCH="18"
QT_MAJOR="${QT_MAJOR:-$DEFAULT_QT_MAJOR}"
QT_MINOR="${QT_MINOR:-$DEFAULT_QT_MINOR}"
QT_PATCH="${QT_PATCH:-$DEFAULT_QT_PATCH}"
QT_SRC_PREFIX="qt-everywhere-"
QT_STATIC_DIR="${QT_STATIC_DIR:-qt5-static}"
DEFAULT_LOG="$REPO_ROOT/logs/build-qt-static.log"
FORCE_ALL="${FORCE_ALL:-}"
NO_PATCH="${NO_PATCH:-}"
USE_EXISTING="${USE_EXISTING:-}"
JOBS_CLI=""
TARBALL_MIN="${TARBALL_MIN:-${TARBALL_MIN_BYTES:-$((600 * 1024 * 1024))}}"
BUILD_SENTINEL_REL="qtnetworkauth/lib/libQt5NetworkAuth.a"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      echo "Usage: ${ME} [options]"
      echo "  -h, --help            [--] show this help"
      echo "  -a, --qtlast N        [QT_PATCH] Qt patch/last version"
      echo "                  (default: ${DEFAULT_QT_PATCH})"
      echo "  -f, --force           [FORCE_ALL] run all steps"
      echo "                  (download, extract, configure, build, install)"
      echo "  -j N, --jobs N        [JOBS] parallel jobs (default: auto-detected)"
      echo "  -L, -L=PATH           [LOG_FILE] capture log"
      echo "                  (default: logs/build-qt-static.log)"
      echo "  --log, --log=PATH     [LOG_FILE] same as -L"
      echo "  -n, --nopatch         [NO_PATCH] skip GCC 13 patch step"
      echo "  -o, --qtminor N       [QT_MINOR] Qt minor version"
      echo "                  (default: ${DEFAULT_QT_MINOR})"
      echo "  -u, --use             [USE_EXISTING] skip download/extract,"
      echo "                  run configure/build/install"
      echo ""
      echo "Environment overrides CLI options where applicable."
      echo "Additional env: [QT_STATIC_DIR], [TARBALL_MIN]"
      exit 0
      ;;
    -f|--force) FORCE_ALL="${FORCE_ALL:-1}"; shift ;;
    -j|--jobs) JOBS_CLI="$2"; shift 2 ;;
    -j*) JOBS_CLI="${1#-j}"; shift ;;
    --jobs=*) JOBS_CLI="${1#--jobs=}"; shift ;;
    -L) LOG_FILE="${LOG_FILE:-$DEFAULT_LOG}"; shift ;;
    -L=*) LOG_FILE="${LOG_FILE:-${1#-L=}}"; shift ;;
    --log)
      if [ -n "${2:-}" ] && [[ "$2" != -* ]]; then
        LOG_FILE="${LOG_FILE:-$2}"
        shift 2
      else
        LOG_FILE="${LOG_FILE:-$DEFAULT_LOG}"
        shift
      fi
      ;;
    -a|--qtlast) QT_PATCH="${QT_PATCH:-$2}"; shift 2 ;;
    --qtlast=*) QT_PATCH="${QT_PATCH:-${1#--qtlast=}}"; shift ;;
    -n|--nopatch) NO_PATCH="${NO_PATCH:-1}"; shift ;;
    -o|--qtminor) QT_MINOR="${QT_MINOR:-$2}"; shift 2 ;;
    --qtminor=*) QT_MINOR="${QT_MINOR:-${1#--qtminor=}}"; shift ;;
    -u|--use) USE_EXISTING="${USE_EXISTING:-1}"; shift ;;
    --log=*) LOG_FILE="${LOG_FILE:-${1#--log=}}"; shift ;;
    *) err "Unknown option: $1 (use -h for help)" ;;
  esac
done
resolve_jobs
[ -n "${LOG_FILE:-}" ] && mkdir -p "$(dirname "${LOG_FILE}")"
[ -n "${LOG_FILE:-}" ] && exec > >(tee -a "${LOG_FILE}") 2>&1

[[ "$QT_MINOR" =~ ^[0-9]+$ ]] || err "QT_MINOR must be numeric: ${QT_MINOR}"
[[ "$QT_PATCH" =~ ^[0-9]+$ ]] || err "QT_PATCH must be numeric: ${QT_PATCH}"
[[ "$TARBALL_MIN" =~ ^[0-9]+$ ]] || {
  err "TARBALL_MIN must be numeric: ${TARBALL_MIN}"
}

QT_VERSION="${QT_MAJOR}.${QT_MINOR}.${QT_PATCH}"
TARBALL="${QT_SRC_PREFIX}opensource-src-${QT_VERSION}.tar.xz"
QT_SRC_DIR_OPEN_SOURCE="${QT_SRC_PREFIX}opensource-src-${QT_VERSION}"
QT_SRC_DIR_GENERIC="${QT_SRC_PREFIX}src-${QT_VERSION}"
URL_BASE="https://download.qt.io/archive/qt/${QT_MAJOR}.${QT_MINOR}"

QT_WORK_DIR="$REPO_ROOT/$QT_STATIC_DIR"
QT_PREFIX="$QT_WORK_DIR"
URL="${URL_BASE}/${QT_VERSION}/single/${TARBALL}"

source_has_markers() {
  local d="$1"
  [ -d "$d" ] || return 1
  [ -f "$d/qt.pro" ] || return 1
  [ -x "$d/configure" ] || return 1
  [ -f "$d/README" ] || return 1
}

select_qt_source_dir() {
  local extracted_dir other_dir old_dir
  extracted_dir="$(
    tar tf "$TARBALL" 2>/dev/null | awk -F/ 'NF { print $1; exit }'
  )"
  [ -n "$extracted_dir" ] || return 1

  case "$extracted_dir" in
    "$QT_SRC_DIR_OPEN_SOURCE")
      other_dir="$QT_SRC_DIR_GENERIC"
      ;;
    "$QT_SRC_DIR_GENERIC")
      other_dir="$QT_SRC_DIR_OPEN_SOURCE"
      ;;
    *)
      err "Unexpected Qt source dir in tarball: ${extracted_dir}"
      ;;
  esac

  if [ -d "$other_dir" ] && [ ! -L "$other_dir" ]; then
    old_dir="${other_dir}_old"
    warn "SERIOUS: both Qt source directories exist as real directories."
    warn "SERIOUS: moving ${other_dir} -> ${old_dir} and relinking."
    mv -f "$other_dir" "$old_dir" || {
      warn "SERIOUS: move failed: ${other_dir} -> ${old_dir}"
      err "Cannot continue with conflicting Qt source directories."
    }
  fi

  if [ ! -e "$other_dir" ]; then
    ln -s "$extracted_dir" "$other_dir" || {
      warn "SERIOUS: symlink failed: ${other_dir} -> ${extracted_dir}"
      err "Cannot continue without normalized Qt source directory names."
    }
  fi

  QT_SRC_DIR="$extracted_dir"
}

install_is_ready() {
  [ -x "$QT_PREFIX/bin/qmake" ] || return 1
  [ -x "$QT_PREFIX/bin/tracegen" ] || return 1
  [ -f "$QT_PREFIX/lib/libQt5Network.a" ] || return 1
}

if install_is_ready && [ -z "$FORCE_ALL" ] && [ -z "$USE_EXISTING" ]; then
  notice "Static Qt already installed at ${QT_PREFIX}."
  notice "Checked: ${QT_PREFIX}/bin/qmake, bin/tracegen, lib/libQt5Network.a"
  notice "--force: run all steps. --use: skip download/extract, rerun configure/build/install."
  exit 0
fi

if [ -d "$QT_WORK_DIR" ] && [ -n "$(ls -A "$QT_WORK_DIR" 2>/dev/null)" ]; then
  warn "Found existing ${QT_STATIC_DIR}/ without bin/qmake; continuing."
  warn 'This may be a partial build from an earlier run.'
fi

mkdir -p "$QT_WORK_DIR"
cd "$QT_WORK_DIR"

if [ -n "$USE_EXISTING" ]; then
  notice 'Skipping download (--use)'
elif [ -n "$FORCE_ALL" ] || [ ! -f "$TARBALL" ]; then
  notice "Downloading Qt ${QT_VERSION}..."
  curl -L -o "$TARBALL" "$URL" || err 'download failed'
fi

if [ -f "$TARBALL" ]; then
  TARBALL_BYTES="$(wc -c < "$TARBALL")"
  [ "$TARBALL_BYTES" -ge "$TARBALL_MIN" ] || {
    err "Tarball too small (${TARBALL_BYTES} bytes): ${TARBALL}"
  }
  notice "Using tarball: ${TARBALL} (${TARBALL_BYTES} bytes)"
fi

if [ -n "$USE_EXISTING" ]; then
  notice 'Skipping extract (--use)'
elif [ -n "$FORCE_ALL" ] || {
  ! source_has_markers "$QT_SRC_DIR_OPEN_SOURCE" &&
  ! source_has_markers "$QT_SRC_DIR_GENERIC"
}; then
  [ -f "$TARBALL" ] || err "Tarball missing: ${TARBALL}"
  notice 'Extracting...'
  tar xf "$TARBALL" || err 'extract failed'
fi

QT_SRC_DIR=""
if ! select_qt_source_dir; then
  [ -d "$QT_SRC_DIR_OPEN_SOURCE" ] && QT_SRC_DIR="$QT_SRC_DIR_OPEN_SOURCE"
  [ -d "$QT_SRC_DIR_GENERIC" ] && QT_SRC_DIR="$QT_SRC_DIR_GENERIC"
fi
if [ -z "$QT_SRC_DIR" ]; then
  err "Extracted Qt source dir not found for ${QT_VERSION}"
fi
[ -f "$QT_SRC_DIR/qt.pro" ] || err "qt.pro missing in ${QT_SRC_DIR}"
[ -x "$QT_SRC_DIR/configure" ] || err "configure missing in ${QT_SRC_DIR}"
[ -f "$QT_SRC_DIR/README" ] || err "README missing in ${QT_SRC_DIR}"

cd "$QT_SRC_DIR"
PATCH_FILE="$REPO_ROOT/res/patches/qt-gcc13.diff"
if [ -n "$NO_PATCH" ]; then
  notice 'Skipping GCC 13+ patch (--nopatch)'
elif [ -f "$PATCH_FILE" ]; then
  [ -d qtlocation ] || err "qtlocation not found in ${QT_SRC_DIR}"
  command -v patch >/dev/null 2>&1 || err 'patch command not found'

  PATCH_DRY_OUT="$(mktemp)"
  PATCH_REV_OUT="$(mktemp)"
  trap 'rm -f "$PATCH_DRY_OUT" "$PATCH_REV_OUT"' EXIT

  if (
    cd qtlocation &&
    patch -p1 --dry-run < "$PATCH_FILE" >"$PATCH_DRY_OUT" 2>&1
  ); then
    notice 'Applying GCC 13+ patch...'
    (cd qtlocation && patch -p1 < "$PATCH_FILE") || {
      err "GCC 13 patch failed. Patch: ${PATCH_FILE}. See UpdateWallet.md."
    }
  elif (
    cd qtlocation &&
    patch -R -p1 --dry-run < "$PATCH_FILE" >"$PATCH_REV_OUT" 2>&1
  ); then
    notice 'GCC 13+ patch already applied.'
  else
    warn 'SERIOUS: GCC 13+ patch dry-run failed (forward and reverse).'
    warn "SERIOUS: forward dry-run output:"
    warn "$(sed -n '1,20p' "$PATCH_DRY_OUT")"
    warn "SERIOUS: reverse dry-run output:"
    warn "$(sed -n '1,20p' "$PATCH_REV_OUT")"
    err "Cannot classify patch state for ${PATCH_FILE}"
  fi
  rm -f "$PATCH_DRY_OUT" "$PATCH_REV_OUT"
  trap - EXIT
fi

if [ -n "$FORCE_ALL" ] || [ -n "$USE_EXISTING" ] || {
  [ ! -f config.summary ]
}; then
  notice "Configuring (prefix=${QT_PREFIX})..."
  ./configure -opensource -confirm-license -static -release \
    -prefix "$QT_PREFIX" \
    -ltcg -no-pch \
    -skip webengine -nomake tools -nomake tests -nomake examples \
    || err 'Qt configure failed'
else
  notice 'Configure already complete (config.summary)'
fi
[ -f config.summary ] || err "config.summary missing in ${QT_SRC_DIR}"

if [ -n "$FORCE_ALL" ] || [ -n "$USE_EXISTING" ] || {
  [ ! -f "$BUILD_SENTINEL_REL" ]
}; then
  notice 'Building (this takes 30-60 min)...'
  make -j"$JOBS" || err 'Qt build failed'
else
  notice "Build already complete (${BUILD_SENTINEL_REL})"
fi
[ -f "$BUILD_SENTINEL_REL" ] || {
  err "Build sentinel missing: ${QT_SRC_DIR}/${BUILD_SENTINEL_REL}"
}

if [ -n "$FORCE_ALL" ] || [ -n "$USE_EXISTING" ] || ! install_is_ready; then
  notice 'Installing...'
  make install || err 'Qt install failed'
else
  notice 'Install already complete'
fi
install_is_ready || err "Install artifacts missing under ${QT_PREFIX}"

notice "Done. QT_PREFIX=${QT_PREFIX}"
