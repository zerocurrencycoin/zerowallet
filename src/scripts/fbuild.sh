# shellcheck shell=bash
# Copyright 2026 Zero Developers
# Shared build helpers for mkdev/mkrelease scripts.
# Usage: ME="script-name"; . "$(dirname "$0")/fbuild.sh"
# Provides: SCRIPT_DIR, REPO_ROOT, JOBS, err, warn, info, notice, step_done, section,
#           analyze_build_log, log_capture, build_fail, resolve_zero_dir, resolve_path_win,
#           resolve_qt, version helpers, parse_mkdev_args, parse_mkrelease_args,
#           show_mkdev_help, show_mkrelease_help, run_dotranslations, apply_version_sed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
JOBS="$(nproc 2>/dev/null || (sysctl -n hw.ncpu 2>/dev/null) || echo 2)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/fmessage.sh"

section() { echo ""; notice "[$1]"; }

# Build log analysis (call when build fails and LOG_FILE is set)
analyze_build_log() {
  local f="${1:-$LOG_FILE}"
  [ -n "$f" ] && [ -f "$f" ] || return 0
  echo "" >&2
  echo "=== Build analysis (from ${f}) ===" >&2
  echo "--- Errors ---" >&2
  grep -iE "error:|fatal|undefined reference|cannot find|No such file" "$f" 2>/dev/null | tail -30 || echo "(none)" >&2
  echo "--- Warnings (last 15) ---" >&2
  grep -iE "warning:" "$f" 2>/dev/null | tail -15 || echo "(none)" >&2
}

# Log capture: tee to LOG_FILE or cat. Used in mkdev scripts.
log_capture() {
  if [ -n "${LOG_FILE:-}" ]; then tee -a "${LOG_FILE}"; else cat; fi
}

# Call on build failure: analyze log if set, then err.
build_fail() {
  [ -n "${LOG_FILE:-}" ] && [ -f "${LOG_FILE}" ] && analyze_build_log "${LOG_FILE}"
  err "${1:-build failed}"
}

# Parse common mkdev args. Sets LOG_FILE, CONFIG (debug|release), JOBS, RUN_AFTER_BUILD.
# Precedence: environment variable overrides command-line option for every option.
# Platform-specific: -m|--mxe for Windows target (Linux host; sets MXE_PATH).
# Usage: parse_mkdev_args "logs/mkdev-linux.log" "$@"
# shellcheck disable=SC2034
parse_mkdev_args() {
  local default_log="$1"
  shift
  CONFIG="${CONFIG:-debug}"
  RUN_AFTER_BUILD=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--clean) MKDEV_CLEAN=1; shift ;;
      -h|--help) show_mkdev_help "$default_log"; exit 0 ;;
      -j|--jobs) JOBS="${JOBS:-$2}"; shift 2 ;;
      -j*) JOBS="${JOBS:-${1#-j}}"; shift ;;
      --jobs=*) JOBS="${JOBS:-${1#--jobs=}}"; shift ;;
      -L) LOG_FILE="${LOG_FILE:-$REPO_ROOT/$default_log}"; shift ;;
      -L=*) LOG_FILE="${LOG_FILE:-${1#-L=}}"; shift ;;
      --log)
        if [ -n "${2:-}" ] && [[ "$2" != -* ]]; then LOG_FILE="${LOG_FILE:-$2}"; shift 2
        else LOG_FILE="${LOG_FILE:-$REPO_ROOT/$default_log}"; shift; fi
        ;;
      --log=*) LOG_FILE="${LOG_FILE:-${1#--log=}}"; shift ;;
      -m|--mxe) MXE_PATH="${MXE_PATH:-$2}"; shift 2 ;;
      -q|--qt) QT_PREFIX="${QT_PREFIX:-$2}"; shift 2 ;;
      -r|--release) CONFIG="${CONFIG:-release}"; shift ;;
      -R|--run) RUN_AFTER_BUILD=1; shift ;;
      *) shift ;;
    esac
  done
  if [ -n "${LOG_FILE:-}" ]; then mkdir -p "$(dirname "$LOG_FILE")"; fi
}

show_mkdev_help() {
  local log="${1:-logs/mkdev.log}"
  echo "Usage: ${ME} [options]"
  echo "  -c, --clean     force clean/distclean before build (default: incremental)"
  echo "  -h, --help      show this help"
  echo "  -j N, --jobs N  parallel jobs"
  echo "  -L, -L=PATH     capture log (default: ${log})"
  echo "  --log, --log=PATH  same as -L"
  echo "  -m, --mxe PATH  MXE usr/bin (Windows target, Linux host)"
  echo "  -q, --qt PATH   Qt prefix"
  echo "  -r, --release   CONFIG+=release (default: debug)"
  echo "  -R, --run       launch binary after build"
  echo ""
  echo "No -z with dev."
}

# Parse common mkrelease args. Sets ZERO_DIR, APP_VERSION, PREV_VERSION, QT_PREFIX, MXE_PATH, SKIP_TRANSLATIONS, SKIP_STRIP, SKIP_SIGN, LOG_FILE, JOBS.
# Precedence: environment variable overrides command-line option for every option.
# Usage: parse_mkrelease_args "logs/mkrelease-linux.log" "$@"
# shellcheck disable=SC2034
parse_mkrelease_args() {
  local default_log="${1:-}"
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) show_mkrelease_help "$default_log"; exit 0 ;;
      -j|--jobs) JOBS="${JOBS:-$2}"; shift 2 ;;
      -j*) JOBS="${JOBS:-${1#-j}}"; shift ;;
      --jobs=*) JOBS="${JOBS:-${1#--jobs=}}"; shift ;;
      -L) LOG_FILE="${LOG_FILE:-$REPO_ROOT/$default_log}"; shift ;;
      -L=*) LOG_FILE="${LOG_FILE:-${1#-L=}}"; shift ;;
      --log)
        if [ -n "${2:-}" ] && [[ "$2" != -* ]]; then LOG_FILE="${LOG_FILE:-$2}"; shift 2
        else LOG_FILE="${LOG_FILE:-$REPO_ROOT/$default_log}"; shift; fi
        ;;
      --log=*) LOG_FILE="${LOG_FILE:-${1#--log=}}"; shift ;;
      -m|--mxe) MXE_PATH="${MXE_PATH:-$2}"; shift 2 ;;
      -p|--prev) PREV_VERSION="${PREV_VERSION:-$2}"; shift 2 ;;
      -q|--qt) QT_PREFIX="${QT_PREFIX:-$2}"; shift 2 ;;
      -P|--no-strip) SKIP_STRIP="${SKIP_STRIP:-1}"; shift ;;
      -N|--no-sign) SKIP_SIGN="${SKIP_SIGN:-1}"; shift ;;
      -t|--tran) SKIP_TRANSLATIONS="${SKIP_TRANSLATIONS:-1}"; shift ;;
      -v|--version) APP_VERSION="${APP_VERSION:-$2}"; shift 2 ;;
      -z|--zero) ZERO_DIR="${ZERO_DIR:-$2}"; shift 2 ;;
      *) shift ;;
    esac
  done
  if [ -n "${LOG_FILE:-}" ]; then mkdir -p "$(dirname "$LOG_FILE")"; fi
}

show_mkrelease_help() {
  local log="${1:-logs/mkrelease.log}"
  echo "Usage: ${ME} [options]"
  echo "  -h, --help      show this help"
  echo "  -j N, --jobs N  parallel jobs"
  echo "  -L, -L=PATH     capture log (default: ${log})"
  echo "  --log, --log=PATH  same as -L"
  echo "  -m, --mxe PATH  MXE usr/bin (Windows target, Linux host)"
  echo "  -p, --prev V    PREV_VERSION (default: from version.h or git)"
  echo "  -q, --qt PATH   Qt prefix (static Qt for release)"
  echo "  -P, --no-strip  skip stripping binaries (larger artifacts)"
  echo "  -N, --no-sign   ad-hoc sign only (macOS; no developer identity). App is always signed so it runs."
  echo "  -t, --tran      skip translations"
  echo "  -v, --version V APP_VERSION (X.Y.Z)"
  echo "  -z, --zero PATH Zero src dir (zerod, zero-cli)"
  echo ""
  echo "No -z with dev."
}

# Run dotranslations.sh. Sets DOTRANSLATIONS_SKIP if SKIP_TRANSLATIONS. Call from repo root after resolve_qt.
# Exports QT_PREFIX so dotranslations.sh (child process) can use lrelease.
run_dotranslations() {
  [ -n "${SKIP_TRANSLATIONS:-}" ] && export DOTRANSLATIONS_SKIP=1
  [ -n "${QT_PREFIX:-}" ] && export QT_PREFIX
  "$SCRIPT_DIR/dotranslations.sh"
}

# Resolve QT_PREFIX and QMAKE for build. Call after parsing -q/--qt.
# Usage: resolve_qt <platform> <mode>
#   platform: linux|mac|win
#   mode: dev|release
# Sets: QT_PREFIX (except linux dev), QMAKE, PATH (mac/win)
resolve_qt() {
  local plat="$1" mode="$2"
  case "$plat" in
    linux)
      if [ "$mode" = "release" ]; then
        QT_PREFIX="${QT_PREFIX:-$REPO_ROOT/qt5-static}"
        QMAKE="$QT_PREFIX/bin/qmake"
      else
        if [ -n "${QT_PREFIX:-}" ]; then
          QMAKE="$QT_PREFIX/bin/qmake"
        else
          QMAKE="$(command -v qmake || command -v qmake-qt5 || true)"
        fi
      fi ;;
    mac)
      QT_PREFIX="${QT_PREFIX:-$(brew --prefix qt@5 2>/dev/null)}"
      QMAKE="$QT_PREFIX/bin/qmake"
      export PATH="$QT_PREFIX/bin:$PATH"
      ;;
    win)
      resolve_path_win
      # Host Qt for dotranslations (lrelease). Precedence: -q/QT_PREFIX > default qt5-static.
      if [ "$mode" = "release" ]; then
        QT_PREFIX="${QT_PREFIX:-$REPO_ROOT/qt5-static}"
      fi
      ;;
    *) err "resolve_qt: unknown platform ${plat}" ;;
  esac
}

# Check zerod and zero-cli exist in ZERO_DIR. $1: platform (linux|mac|win). Err if missing.
check_zero_binaries() {
  local plat="${1:-linux}" suf=""
  [ "$plat" = "win" ] && suf=".exe"
  [ -f "$ZERO_DIR/zerod$suf" ] || err "zerod${suf} not found in ${ZERO_DIR}. Build Zero first."
  [ "$plat" = "mac" ] && return 0
  [ -f "$ZERO_DIR/zero-cli$suf" ] || err "zero-cli${suf} not found in ${ZERO_DIR}. Build Zero first."
}

# Resolve ZERO_DIR. $1: platform (linux|mac|win). Uses ../Zero if it exists and is non-empty, else ../ZeroLinux, ../ZeroMac, ../ZeroWin.
resolve_zero_dir() {
  local plat="${1:-linux}"
  [ -n "${ZERO_DIR:-}" ] && return 0
  local base="../Zero"
  if [ -d "$base" ] && [ -n "$(ls -A "$base" 2>/dev/null)" ]; then
    : # use ../Zero
  else
    case "$plat" in
      linux) base="../ZeroLinux" ;;
      mac)   base="../ZeroMac" ;;
      win)   base="../ZeroWin" ;;
    esac
  fi
  ZERO_DIR="$base/src"
}

# Resolve ZERO_DIR_LINUX and ZERO_DIR_WIN (retired mkrelease-linuxwin). Uses ZERO_DIR for both if set.
resolve_zero_dirs_linuxwin() {
  local base
  if [ -n "${ZERO_DIR:-}" ]; then
    ZERO_DIR_LINUX="${ZERO_DIR_LINUX:-$ZERO_DIR}"
    ZERO_DIR_WIN="${ZERO_DIR_WIN:-$ZERO_DIR}"
    return 0
  fi
  for base in "../Zero" "../ZeroLinux"; do [ -d "$base" ] && break; done
  ZERO_DIR_LINUX="${ZERO_DIR_LINUX:-$base/src}"
  for base in "../Zero" "../ZeroWin"; do [ -d "$base" ] && break; done
  ZERO_DIR_WIN="${ZERO_DIR_WIN:-$base/src}"
}

# Resolve MXE path and tools for Windows target (Linux host).
# Precedence: MXE_PATH (env overrides -m/--mxe) > tools in PATH > probe $HOME/mxe, /opt/mxe.
# Sets: MXE_PATH, QMAKE, STRIP. Prepends MXE_PATH to PATH.
# STRIP: warn-but-continue if not found (larger binaries).
resolve_path_win() {
  local d p

  # 1. MXE_PATH from environment
  if [ -n "${MXE_PATH:-}" ] && [ -d "${MXE_PATH}" ]; then
    d="$MXE_PATH"
  # 2. Tools in PATH
  elif d=$(command -v x86_64-w64-mingw32.static-gcc 2>/dev/null) && [ -n "$d" ]; then
    d="$(dirname "$d")"
    [ -x "$d/x86_64-w64-mingw32.static-qmake-qt5" ] || d=""
  # 3. Probe
  else
    d=""
    for p in "$HOME/mxe/usr/bin" /opt/mxe/usr/bin; do
      if [ -x "$p/x86_64-w64-mingw32.static-gcc" ] && [ -x "$p/x86_64-w64-mingw32.static-qmake-qt5" ]; then
        d="$p"
        break
      fi
    done
  fi

  [ -z "${d:-}" ] && err 'MXE not found. Set MXE_PATH or -m/--mxe, or install to ~/mxe. See BUILD.md Windows.'
  [ -x "$d/x86_64-w64-mingw32.static-gcc" ] || err "MXE gcc not found at ${d}"
  [ -x "$d/x86_64-w64-mingw32.static-qmake-qt5" ] || err "MXE qmake not found at ${d}"

  MXE_PATH="$d"
  PATH="${MXE_PATH}:${PATH}"
  export PATH
  QMAKE="${MXE_PATH}/x86_64-w64-mingw32.static-qmake-qt5"
  if [ -x "${MXE_PATH}/x86_64-w64-mingw32.static-strip" ]; then
    STRIP="${MXE_PATH}/x86_64-w64-mingw32.static-strip"
  elif command -v x86_64-w64-mingw32-strip >/dev/null 2>&1; then
    STRIP="x86_64-w64-mingw32-strip"
  else
    STRIP=""
    warn 'MinGW strip not found; packaging without stripping (larger binaries)'
  fi
}

# Version helpers (mkrelease-linux)
valid_semver() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; }
get_app_from_h() { grep -E '^#define APP_VERSION "[0-9]+\.[0-9]+\.[0-9]+"' "$REPO_ROOT/src/version.h" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'; }
get_git_tag()  { (cd "$REPO_ROOT" && git describe --tags --abbrev=0 2>/dev/null | sed 's/^[vV]//' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1); }
patch_plus1()  { echo "$1" | awk -F. -v OFS=. '{$3++; print}'; }
# Patch component never goes below 0; minor/major unchanged when patch would underflow.
patch_minus1() { echo "$1" | awk -F. -v OFS=. '{c=$3-1; if(c<0)c=0; print $1,$2,c}'; }

# Resolve APP_VERSION and PREV_VERSION (mkrelease-linux logic). Call from repo root.
resolve_version() {
  local app_h; app_h=$(get_app_from_h)
  local git_v; git_v=$(get_git_tag)
  if [ -z "${APP_VERSION:-}" ]; then
    [ -z "$app_h" ] && err 'src/version.h has no valid #define APP_VERSION "X.Y.Z". Use -v.'
    if [ -n "$git_v" ] && [ "$app_h" = "$git_v" ]; then
      APP_VERSION=$(patch_plus1 "$app_h")
      PREV_VERSION="${PREV_VERSION:-$git_v}"
      notice "version.h unchanged (${app_h} == git tag); using -v ${APP_VERSION} -p ${git_v}"
    else
      APP_VERSION="$app_h"
      PREV_VERSION="${PREV_VERSION:-$(patch_minus1 "$app_h")}"
      [ -n "$git_v" ] && notice "version.h updated (${app_h}); using -v ${APP_VERSION} -p ${PREV_VERSION} (git: ${git_v})"
    fi
  fi
  valid_semver "$APP_VERSION" || err "APP_VERSION invalid format (need X.Y.Z): ${APP_VERSION}"
  [ -z "${PREV_VERSION:-}" ] && PREV_VERSION=$(patch_minus1 "$APP_VERSION")
  valid_semver "$PREV_VERSION" || err "PREV_VERSION invalid format (need X.Y.Z): ${PREV_VERSION}"
}

# Warn if version.h does not contain APP_VERSION (mismatch may be intentional).
check_version_mismatch() {
  grep -q "\"$APP_VERSION\"" src/version.h 2>/dev/null || warn "src/version.h does not contain APP_VERSION ${APP_VERSION}"
}

# Replace PREV_VERSION with APP_VERSION in zero-qt-wallet.pro and README.md. Run from repo root.
# Portable sed -i: BSD (macOS) requires backup suffix; use .bak then remove.
apply_version_sed() {
  sed -i.bak "s/${PREV_VERSION}/${APP_VERSION}/g" zero-qt-wallet.pro && rm -f zero-qt-wallet.pro.bak
  sed -i.bak "s/${PREV_VERSION}/${APP_VERSION}/g" README.md && rm -f README.md.bak
  step_done 'Version files'
}
