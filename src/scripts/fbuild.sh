# shellcheck shell=bash
# Shared build helpers for mkdev/mkrelease scripts.
# Usage: ME="script-name"; . "$(dirname "$0")/fbuild.sh"
# Provides: SCRIPT_DIR, REPO_ROOT, JOBS, err, warn, info, notice, step_done, section,
#           analyze_build_log, log_capture, build_fail, resolve_zero_dir, detect_mxe,
#           resolve_qt, version helpers, parse_mkdev_args, apply_version_sed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
JOBS=$(nproc 2>/dev/null || (sysctl -n hw.ncpu 2>/dev/null) || echo 2)

# Logging
err()   { echo "${ME:-script}: ERROR: $*" >&2; exit 1; }
warn()  { echo "${ME:-script}: WARN: $*" >&2; }
info()  { echo "${ME:-script}: $*"; }
notice() { echo "${ME:-script}: $*"; }
step_done() { printf "%s: %-24s [OK]\n" "${ME:-script}" "$1"; }
section() { echo ""; notice "[$1]"; }

# Build log analysis (call when build fails and LOG_FILE is set)
analyze_build_log() {
  local f="${1:-$LOG_FILE}"
  [ -n "$f" ] && [ -f "$f" ] || return 0
  echo "" >&2
  echo "=== Build analysis (from $f) ===" >&2
  echo "--- Errors ---" >&2
  grep -iE "error:|fatal|undefined reference|cannot find|No such file" "$f" 2>/dev/null | tail -30 || echo "(none)" >&2
  echo "--- Warnings (last 15) ---" >&2
  grep -iE "warning:" "$f" 2>/dev/null | tail -15 || echo "(none)" >&2
}

# Log capture: tee to LOG_FILE or cat. Used in mkdev scripts.
log_capture() {
  if [ -n "${LOG_FILE:-}" ]; then tee -a "$LOG_FILE"; else cat; fi
}

# Call on build failure: analyze log if set, then err.
build_fail() {
  [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ] && analyze_build_log "$LOG_FILE"
  err "${1:-build failed}"
}

# Parse common mkdev args. Sets LOG_FILE, CONFIG (debug|release), JOBS, RUN_AFTER_BUILD.
# Platform-specific: -m|--mxe for Windows (sets MXE_PATH).
# Usage: parse_mkdev_args "logs/mkdev-linux.log" "$@"
# shellcheck disable=SC2034
parse_mkdev_args() {
  local default_log="$1"
  shift
  LOG_FILE=""
  CONFIG="${CONFIG:-debug}"
  RUN_AFTER_BUILD=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) show_mkdev_help "$default_log"; exit 0 ;;
      -L) LOG_FILE="${LOG_FILE:-$REPO_ROOT/$default_log}"; shift ;;
      -L=*) LOG_FILE="${1#-L=}"; shift ;;
      -j) JOBS="$2"; shift 2 ;;
      -j*) JOBS="${1#-j}"; shift ;;
      -r) CONFIG="release"; shift ;;
      -m|--mxe) MXE_PATH="$2"; shift 2 ;;
      -q|--qt) QT_PREFIX="$2"; shift 2 ;;
      --run) RUN_AFTER_BUILD=1; shift ;;
      --clean) MKDEV_CLEAN=1; shift ;;
      *) shift ;;
    esac
  done
  if [ -n "$LOG_FILE" ]; then mkdir -p "$(dirname "$LOG_FILE")"; fi
}

show_mkdev_help() {
  local log="${1:-logs/mkdev.log}"
  echo "Usage: $ME [options]"
  echo "  -h, --help    show this help"
  echo "  -L, -L=PATH   capture log (default: $log)"
  echo "  -j N          parallel jobs"
  echo "  -r            release config (default: debug)"
  echo "  -q, --qt PATH Qt prefix (macOS)"
  echo "  -m, --mxe PATH MXE usr/bin (Windows)"
  echo "  --run         launch binary after build"
  echo "  --clean       remove build outputs and exit"
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
        QMAKE=$(command -v qmake || command -v qmake-qt5 || true)
      fi ;;
    mac)
      QT_PREFIX="${QT_PREFIX:-$(brew --prefix qt@5 2>/dev/null)}"
      QMAKE="$QT_PREFIX/bin/qmake"
      export PATH="$QT_PREFIX/bin:$PATH"
      ;;
    win)
      detect_mxe
      # shellcheck disable=SC2034
      QMAKE="x86_64-w64-mingw32.static-qmake-qt5"
      export PATH="$MXE_PATH:$PATH"
      ;;
    *) err "resolve_qt: unknown platform $plat" ;;
  esac
}

# Resolve ZERO_DIR. $1: platform (linux|mac|win). Uses ZERO_BASE: ../Zero, else ../ZeroLinux or ../ZeroWin.
resolve_zero_dir() {
  local plat="${1:-linux}"
  [ -n "$ZERO_DIR" ] && return 0
  local base="../Zero"
  case "$plat" in
    linux|mac) [ -d "$base" ] || base="../ZeroLinux" ;;
    win)       [ -d "$base" ] || base="../ZeroWin" ;;
  esac
  ZERO_DIR="$base/src"
}

# Resolve ZERO_DIR_LINUX and ZERO_DIR_WIN (mkrelease-linuxwin). Uses ZERO_DIR for both if set.
resolve_zero_dirs_linuxwin() {
  local base
  if [ -n "$ZERO_DIR" ]; then
    ZERO_DIR_LINUX="${ZERO_DIR_LINUX:-$ZERO_DIR}"
    ZERO_DIR_WIN="${ZERO_DIR_WIN:-$ZERO_DIR}"
    return 0
  fi
  for base in "../Zero" "../ZeroLinux"; do [ -d "$base" ] && break; done
  ZERO_DIR_LINUX="${ZERO_DIR_LINUX:-$base/src}"
  for base in "../Zero" "../ZeroWin"; do [ -d "$base" ] && break; done
  ZERO_DIR_WIN="${ZERO_DIR_WIN:-$base/src}"
}

# Detect MXE path. Sets MXE_PATH if unset. Checks $HOME/mxe/usr/bin, /opt/mxe/usr/bin.
detect_mxe() {
  [ -n "$MXE_PATH" ] && return 0
  for p in "$HOME/mxe/usr/bin" /opt/mxe/usr/bin; do
    [ -x "$p/x86_64-w64-mingw32.static-qmake-qt5" ] && { MXE_PATH="$p"; return 0; }
  done
  MXE_PATH="${MXE_PATH:-$HOME/mxe/usr/bin}"
}

# Version helpers (mkrelease-linux)
valid_semver() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; }
get_app_from_h() { grep -E '^#define APP_VERSION "[0-9]+\.[0-9]+\.[0-9]+"' "$REPO_ROOT/src/version.h" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'; }
get_git_tag()  { (cd "$REPO_ROOT" && git describe --tags --abbrev=0 2>/dev/null | sed 's/^[vV]//' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1); }
patch_plus1()  { echo "$1" | awk -F. -v OFS=. '{$3++; print}'; }
patch_minus1() { echo "$1" | awk -F. -v OFS=. '{c=$3-1; if(c<0){c=0; $2--}; if($2<0)$2=0; print $1,$2,c}'; }

# Resolve APP_VERSION and PREV_VERSION (mkrelease-linux logic). Call from repo root.
resolve_version() {
  local app_h; app_h=$(get_app_from_h)
  local git_v; git_v=$(get_git_tag)
  if [ -z "$APP_VERSION" ]; then
    [ -z "$app_h" ] && err "src/version.h has no valid #define APP_VERSION \"X.Y.Z\". Use -v."
    if [ -n "$git_v" ] && [ "$app_h" = "$git_v" ]; then
      APP_VERSION=$(patch_plus1 "$app_h")
      PREV_VERSION="${PREV_VERSION:-$git_v}"
      notice "version.h unchanged ($app_h == git tag); using -v $APP_VERSION -p $git_v"
    else
      APP_VERSION="$app_h"
      PREV_VERSION="${PREV_VERSION:-$(patch_minus1 "$app_h")}"
      [ -n "$git_v" ] && notice "version.h updated ($app_h); using -v $APP_VERSION -p $PREV_VERSION (git: $git_v)"
    fi
  fi
  valid_semver "$APP_VERSION" || err "APP_VERSION invalid format (need X.Y.Z): $APP_VERSION"
  [ -z "$PREV_VERSION" ] && PREV_VERSION=$(patch_minus1 "$APP_VERSION")
  valid_semver "$PREV_VERSION" || err "PREV_VERSION invalid format (need X.Y.Z): $PREV_VERSION"
}

# Warn if version.h does not contain APP_VERSION (mismatch may be intentional).
check_version_mismatch() {
  grep -q "\"$APP_VERSION\"" src/version.h 2>/dev/null || warn "src/version.h does not contain APP_VERSION $APP_VERSION"
}

# Replace PREV_VERSION with APP_VERSION in zero-qt-wallet.pro and README.md. Run from repo root.
apply_version_sed() {
  sed -i "s/${PREV_VERSION}/${APP_VERSION}/g" zero-qt-wallet.pro >/dev/null
  sed -i "s/${PREV_VERSION}/${APP_VERSION}/g" README.md >/dev/null
  step_done "Version files"
}
