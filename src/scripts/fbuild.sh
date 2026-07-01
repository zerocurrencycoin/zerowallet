# shellcheck shell=bash
# Copyright 2026 Zero Developers
# Shared build helpers for mkdev/mkrelease scripts.
# Usage: ME="script-name"; . "$(dirname "$0")/fbuild.sh"
# Provides: SCRIPT_DIR, REPO_ROOT, JOBS, err, warn, notice, step_done, section,
#           analyze_build_log, init_logging, build_fail, check_file, check_zero_binaries,
#           resolve_zero_dir, resolve_path_win, resolve_qt, version helpers (get_app_from_h, resolve_version, etc.),
#           parse_mkdev_args, parse_mkrelease_args, show_mkdev_help, show_mkrelease_help,
#           run_dotranslations, write_version_h

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Do NOT pre-seed JOBS here: a pre-set JOBS would make the -j flag's override a no-op.
# Precedence is applied by resolve_jobs at end of parse.

# CPU count, capped at 4. Linux: nproc; macOS: sysctl hw.ncpu; fallback 2.
detect_jobs() {
  local n
  n="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)"
  [[ "$n" =~ ^[0-9]+$ ]] || n=2
  [ "$n" -gt 4 ] && n=4
  [ "$n" -lt 1 ] && n=2
  echo "$n"
}

# Final JOBS precedence (matches every option's env-wins rule): pre-set JOBS (env) >
# -j flag (JOBS_CLI) > detect_jobs (capped). Call at end of parse.
resolve_jobs() {
  if [ -n "${JOBS:-}" ]; then
    :  # env (or caller) already set it — wins
  elif [ -n "${JOBS_CLI:-}" ]; then
    JOBS="$JOBS_CLI"
  else
    JOBS="$(detect_jobs)"
  fi
}

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

# Start logging: tee all output (stdout+stderr, every command) to LOG_FILE.
# Default is a fresh timestamped file so prior runs are preserved; -L overrides the path.
# Call once, right after parse_*_args.
init_logging() {
  LOG_FILE="${LOG_FILE:-$REPO_ROOT/logs/${ME}-$(date +%Y%m%d-%H%M%S).log}"
  mkdir -p "$(dirname "$LOG_FILE")"
  exec > >(tee -a "$LOG_FILE") 2>&1
  notice "Log: ${LOG_FILE}"
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
  local JOBS_CLI=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--clean) MKDEV_CLEAN="${MKDEV_CLEAN:-1}"; shift ;;
      -C|--check) MKDEV_CHECK_ONLY="${MKDEV_CHECK_ONLY:-1}"; shift ;;
      -h|--help) show_mkdev_help "$default_log"; exit 0 ;;
      -j|--jobs) JOBS_CLI="$2"; shift 2 ;;
      -j*) JOBS_CLI="${1#-j}"; shift ;;
      --jobs=*) JOBS_CLI="${1#--jobs=}"; shift ;;
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
      -R|--run) RUN_AFTER_BUILD="${RUN_AFTER_BUILD:-1}"; shift ;;
      *) shift ;;
    esac
  done
  resolve_jobs
}

show_mkdev_help() {
  local log="${1:-logs/mkdev.log}"
  echo "Usage: ${ME} [options]"
  echo "  -c, --clean         [MKDEV_CLEAN] force clean/distclean"
  echo "                      (default: incremental)"
  echo "  -h, --help          [--] show this help"
  echo "  -j N, --jobs N      [JOBS] parallel jobs (default: min(CPUs,4); env JOBS wins)"
  echo "  -L, -L=PATH         [LOG_FILE] capture log (default: ${log})"
  echo "  --log, --log=PATH   [LOG_FILE] same as -L"
  echo "  -m, --mxe PATH      [MXE_PATH] MXE usr/bin (Windows target)"
  echo "  -q, --qt PATH       [QT_PREFIX] Qt prefix"
  echo "  -r, --release       [CONFIG] CONFIG+=release (default: debug)"
  echo "  -R, --run           [RUN_AFTER_BUILD] launch binary after build"
  echo ""
  echo "No -z with dev."
}

# Parse common mkrelease args. Sets ZERO_DIR, APP_VERSION, QT_PREFIX, MXE_PATH, RUN_TRANSLATIONS, SKIP_STRIP, SKIP_SIGN, LOG_FILE, JOBS.
# Precedence: environment variable overrides command-line option for every option.
# Usage: parse_mkrelease_args "logs/mkrelease-linux.log" "$@"
# shellcheck disable=SC2034
parse_mkrelease_args() {
  local default_log="${1:-}"
  shift
  local JOBS_CLI=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) show_mkrelease_help "$default_log"; exit 0 ;;
      -j|--jobs) JOBS_CLI="$2"; shift 2 ;;
      -j*) JOBS_CLI="${1#-j}"; shift ;;
      --jobs=*) JOBS_CLI="${1#--jobs=}"; shift ;;
      -L) LOG_FILE="${LOG_FILE:-$REPO_ROOT/$default_log}"; shift ;;
      -L=*) LOG_FILE="${LOG_FILE:-${1#-L=}}"; shift ;;
      --log)
        if [ -n "${2:-}" ] && [[ "$2" != -* ]]; then LOG_FILE="${LOG_FILE:-$2}"; shift 2
        else LOG_FILE="${LOG_FILE:-$REPO_ROOT/$default_log}"; shift; fi
        ;;
      --log=*) LOG_FILE="${LOG_FILE:-${1#--log=}}"; shift ;;
      -m|--mxe) MXE_PATH="${MXE_PATH:-$2}"; shift 2 ;;
      -q|--qt) QT_PREFIX="${QT_PREFIX:-$2}"; shift 2 ;;
      -P|--nostrip) SKIP_STRIP="${SKIP_STRIP:-1}"; shift ;;
      -N|--no-sign) SKIP_SIGN="${SKIP_SIGN:-1}"; shift ;;
      -S|--systemqt) USE_SYSTEM_QT="${USE_SYSTEM_QT:-1}"; shift ;;
      -T|--tgz) MAKE_TGZ="${MAKE_TGZ:-1}"; shift ;;
      -t|--translate|--tran) RUN_TRANSLATIONS="${RUN_TRANSLATIONS:-1}"; shift ;;
      -v|--version) APP_VERSION="${APP_VERSION:-$2}"; shift 2 ;;
      -z|--zero) ZERO_DIR="${ZERO_DIR:-$2}"; shift 2 ;;
      *) shift ;;
    esac
  done
  resolve_jobs
}

show_mkrelease_help() {
  local log="${1:-logs/mkrelease.log}"
  echo "Usage: ${ME} [options]"
  echo "  -h, --help          [--] show this help"
  echo "  -j N, --jobs N      [JOBS] parallel jobs (default: min(CPUs,4); env JOBS wins)"
  echo "  -L, -L=PATH         [LOG_FILE] capture log (default: ${log})"
  echo "  --log, --log=PATH   [LOG_FILE] same as -L"
  echo "  -m, --mxe PATH      [MXE_PATH] MXE usr/bin (Windows target)"
  echo "  -q, --qt PATH       [QT_PREFIX] Qt prefix (Linux release link; -t host Qt)"
  echo "  -S, --systemqt      [USE_SYSTEM_QT] Linux release with system Qt (dynamic link)"
  echo "  -P, --nostrip       [SKIP_STRIP] skip stripping binaries"
  echo "  -N, --no-sign       [SKIP_SIGN] ad-hoc sign only (macOS)"
  echo "  -t, --translate     [RUN_TRANSLATIONS] rebuild .ts -> .qm (default: off)"
  echo "  -T, --tgz           [MAKE_TGZ] also create .tgz of app (macOS)"
  echo "  -v, --version V     [APP_VERSION] (X.Y.Z)"
  echo "  -z, --zero PATH     [ZERO_DIR] Zero src dir (zerod, zero-cli)"
  echo ""
  echo "No -z with dev."
}

# Run dotranslations.sh when -t / RUN_TRANSLATIONS. Default: skip (reuse res/*.qm).
# -q / QT_PREFIX: host Qt for lrelease (see resolve_translation_qt_prefix).
run_dotranslations() {
  if [ -z "${RUN_TRANSLATIONS:-}" ]; then
    notice 'Translations off (use -t to rebuild .qm with lrelease)'
    return 0
  fi
  resolve_translation_qt_prefix
  export QT_PREFIX="${TRANSLATION_QT_PREFIX}"
  "$SCRIPT_DIR/dotranslations.sh"
}

# Host Qt prefix for lrelease/lconvert. Precedence: -q/QT_PREFIX > qt5-static > system Qt.
resolve_translation_qt_prefix() {
  local candidate lrelease_bin trans_dir

  if [ -n "${QT_PREFIX:-}" ]; then
    candidate="$QT_PREFIX"
    lrelease_bin="$candidate/bin/lrelease"
    [ ! -x "$lrelease_bin" ] && lrelease_bin="$(command -v lrelease 2>/dev/null || true)"
    trans_dir="$(qt_translation_dir "$candidate" "$lrelease_bin")"
    if [ -n "$lrelease_bin" ] && [ -n "$trans_dir" ] && [ -f "$trans_dir/qtbase_de.qm" ]; then
      TRANSLATION_QT_PREFIX="$candidate"
      export QT_LRELEASE="$lrelease_bin"
      export QT_TRANSLATIONS_DIR="$trans_dir"
      return 0
    fi
  fi

  candidate="$REPO_ROOT/qt5-static"
  if [ -x "$candidate/bin/lrelease" ] && [ -f "$candidate/translations/qtbase_de.qm" ]; then
    TRANSLATION_QT_PREFIX="$candidate"
    export QT_LRELEASE="$candidate/bin/lrelease"
    export QT_TRANSLATIONS_DIR="$candidate/translations"
    return 0
  fi

  lrelease_bin="$(command -v lrelease 2>/dev/null || true)"
  [ -z "$lrelease_bin" ] && [ -x /usr/lib/qt5/bin/lrelease ] && lrelease_bin=/usr/lib/qt5/bin/lrelease
  trans_dir="$(qt_translation_dir "" "$lrelease_bin")"
  if [ -n "$lrelease_bin" ] && [ -n "$trans_dir" ] && [ -f "$trans_dir/qtbase_de.qm" ]; then
    TRANSLATION_QT_PREFIX="$(cd "$(dirname "$lrelease_bin")/.." && pwd)"
    export QT_LRELEASE="$lrelease_bin"
    export QT_TRANSLATIONS_DIR="$trans_dir"
    return 0
  fi

  err "Translations (-t) need lrelease and qtbase_*.qm. Install qtbase5-dev-tools, use -q PATH, or build qt5-static/."
}

# Resolve directory containing qtbase_XX.qm for lconvert merge.
qt_translation_dir() {
  local prefix="${1:-}" lrelease_bin="${2:-}" qmake_bin trans
  if [ -n "$prefix" ] && [ -d "$prefix/translations" ] && [ -f "$prefix/translations/qtbase_de.qm" ]; then
    echo "$prefix/translations"
    return 0
  fi
  qmake_bin="$(command -v qmake 2>/dev/null || command -v qmake-qt5 2>/dev/null || true)"
  if [ -n "$qmake_bin" ]; then
    trans="$("$qmake_bin" -query QT_INSTALL_TRANSLATIONS 2>/dev/null || true)"
    if [ -n "$trans" ] && [ -f "$trans/qtbase_de.qm" ]; then
      echo "$trans"
      return 0
    fi
  fi
  if [ -f /usr/share/qt5/translations/qtbase_de.qm ]; then
    echo /usr/share/qt5/translations
    return 0
  fi
  return 1
}

# Resolve QT_PREFIX and QMAKE for build. Call after parsing -q/--qt.
# Usage: resolve_qt <platform> <mode>   platform: linux|mac|win   mode: dev|release
#
# Qt source per platform + build type:
#   linux dev      system qmake from PATH (or -q). Dynamic link.
#   linux release  static qt5-static/ (or -q); -S/USE_SYSTEM_QT -> system qmake, dynamic.
#   mac  dev/rel   Homebrew qt@5 (brew --prefix, or -q). macdeployqt bundles Qt.
#   win  dev/rel   MXE static Qt (resolve_path_win); cross-build on Linux host only.
# Sets: QT_PREFIX (except linux dev), QMAKE, PATH (mac/win).
resolve_qt() {
  local plat="$1" mode="$2"
  case "$plat" in
    linux)
      if [ "$mode" = "release" ]; then
        if [ -n "${USE_SYSTEM_QT:-}" ]; then
          QMAKE="$(command -v qmake || command -v qmake-qt5 || true)"
          if [ -n "$QMAKE" ]; then
            QT_PREFIX="$("$QMAKE" -query QT_INSTALL_PREFIX 2>/dev/null || true)"
          fi
        else
          QT_PREFIX="${QT_PREFIX:-$REPO_ROOT/qt5-static}"
          QMAKE="$QT_PREFIX/bin/qmake"
        fi
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
      ;;
    *) err "resolve_qt: unknown platform ${plat}" ;;
  esac
}

# Check path exists and is a file. $1: path, $2: description (default "file"). Err if missing or not file.
check_file() {
  local path="$1" desc="${2:-file}"
  [ -e "$path" ] || err "${desc} not found: ${path}"
  [ -f "$path" ] || err "${desc} not a file: ${path}"
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

# Quick preflight for mkdev-win (Linux host, MXE cross-build). Fatal on missing build tools.
# Call after parse_mkdev_args and resolve_qt win dev (MXE_PATH, QMAKE set).
preflight_mkdev_win() {
  local qt_ver sodium_tar
  case "$(uname -s)" in
    Linux) ;;
    *) err "mkdev-win requires a Linux host (MXE cross-build). Got: $(uname -s)" ;;
  esac
  command -v make >/dev/null 2>&1 || err "make not found. Install: sudo apt install build-essential"
  [ -f "$REPO_ROOT/zero-qt-wallet.pro" ] || err "zero-qt-wallet.pro not found at repo root (committed source; not generated)"
  sodium_tar="$REPO_ROOT/res/libsodium/libsodium-1.0.21.tar.gz"
  if [ -f "$sodium_tar" ]; then
    notice "preflight: libsodium tarball cached"
  else
    command -v wget >/dev/null 2>&1 || err "wget not found (first Windows libsodium build downloads tarball). Install: sudo apt install wget"
    notice "preflight: wget OK (libsodium tarball will download on build)"
  fi
  [ -n "${MXE_PATH:-}" ] && [ -x "${QMAKE:-}" ] || err "MXE not resolved (internal error)"
  qt_ver="$("$QMAKE" -query QT_VERSION 2>/dev/null || echo "?")"
  notice "preflight: Linux host OK"
  notice "preflight: MXE ${MXE_PATH} (gcc, qmake Qt ${qt_ver})"
  if [ -n "${RUN_AFTER_BUILD:-}" ] && ! command -v wine >/dev/null 2>&1; then
    warn "preflight: wine not found; -R/--run smoke test will be skipped"
  fi
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

# Version: src/version.h is the single source of truth (qmake imports it via
# VERSION=$$system(get-version), C++ uses the APP_VERSION macro). No git, no PREV.
valid_semver() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; }
# No-match is a normal empty result, not an error: trailing '|| true' keeps a failing
# grep from aborting the caller under set -e -o pipefail.
get_app_from_h() { grep -E '^#define APP_VERSION "[0-9]+\.[0-9]+\.[0-9]+"' "$REPO_ROOT/src/version.h" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true; }

# Resolve APP_VERSION from version.h (or -v/APP_VERSION override). Call from repo root.
# With -v, write it back into version.h so the header stays the source of truth.
resolve_version() {
  local app_h; app_h=$(get_app_from_h)
  if [ -z "${APP_VERSION:-}" ]; then
    [ -z "$app_h" ] && err 'src/version.h has no valid #define APP_VERSION "X.Y.Z". Use -v.'
    APP_VERSION="$app_h"
  fi
  valid_semver "$APP_VERSION" || err "APP_VERSION invalid format (need X.Y.Z): ${APP_VERSION}"
  if [ "$APP_VERSION" != "$app_h" ]; then
    write_version_h "$APP_VERSION"
    notice "version.h set to ${APP_VERSION} (was ${app_h:-none})"
  fi
}

# Warn if version.h does not contain APP_VERSION (mismatch may be intentional).
check_version_mismatch() {
  grep -q "\"$APP_VERSION\"" src/version.h 2>/dev/null || warn "src/version.h does not contain APP_VERSION ${APP_VERSION}"
}

# Write APP_VERSION into src/version.h by anchoring on the APP_VERSION key (never on the
# old value, so no PREV needed). Portable sed -i: BSD (macOS) needs a backup suffix.
write_version_h() {
  local v="$1"
  sed -i.bak -E "s/(#define APP_VERSION \")[0-9]+\.[0-9]+\.[0-9]+(\")/\1${v}\2/" src/version.h \
    && rm -f src/version.h.bak
  step_done 'version.h'
}
