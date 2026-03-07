#!/bin/bash
# Copyright 2026 Zero Developers
# Report Qt setup for zerowallet: dev/release usage and platform defaults.
# Run from repo root or any dir; detects Linux, macOS, Windows (host or WSL).
# Usage: ./src/scripts/qt-report.sh
set -e -u -o pipefail
# shellcheck disable=SC2034
ME="qt-report"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fmessage.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

report() { printf '  %s\n' "$1"; }
section() { echo ""; notice "[$1]"; }

detect_platform() {
  case "$(uname -s)" in
    Linux)  echo "linux" ;;
    Darwin) echo "mac" ;;
    MINGW*|MSYS*|CYGWIN*) echo "win" ;;
    *) echo "unknown" ;;
  esac
}

# --- Linux ---
report_linux() {
  section "Linux (this host)"
  report "Dev: default is system Qt (qmake from PATH or qtbase5-dev)."
  report "Release: static Qt in repo (qt5-static/). Run build-qt-static.sh once."
  report ""

  local qmake_path prefix_static
  qmake_path="$(command -v qmake 2>/dev/null || command -v qmake-qt5 2>/dev/null || true)"
  if [ -n "$qmake_path" ]; then
    report "qmake (dev default): $qmake_path"
    report "  version: $("$qmake_path" -query QT_VERSION 2>/dev/null || echo "?")"
  else
    report "qmake (dev): not found. Install qtbase5-dev-tools."
  fi

  if [ -n "${QT_PREFIX:-}" ]; then
    report "QT_PREFIX (set): $QT_PREFIX"
    [ -x "$QT_PREFIX/bin/qmake" ] && report "  qmake: present" || report "  qmake: missing"
  fi

  prefix_static="$REPO_ROOT/qt5-static"
  if [ -x "$prefix_static/bin/qmake" ]; then
    report "qt5-static (release): $prefix_static (ready)"
  elif [ -d "$prefix_static" ]; then
    report "qt5-static (release): $prefix_static (incomplete or missing qmake)"
  else
    report "qt5-static (release): not present. Run ./src/scripts/build-qt-static.sh"
  fi

  # Windows target (MXE) when on Linux host
  local mxe_path
  mxe_path="${MXE_PATH:-}"
  if [ -z "$mxe_path" ] && [ -x "$HOME/mxe/usr/bin/x86_64-w64-mingw32.static-qmake-qt5" ]; then
    mxe_path="$HOME/mxe/usr/bin"
  fi
  if [ -z "$mxe_path" ] && [ -x "/opt/mxe/usr/bin/x86_64-w64-mingw32.static-qmake-qt5" ]; then
    mxe_path="/opt/mxe/usr/bin"
  fi
  if [ -n "$mxe_path" ] && [ -x "$mxe_path/x86_64-w64-mingw32.static-qmake-qt5" ]; then
    report "Windows target (MXE): $mxe_path (qmake-qt5 present)"
  else
    report "Windows target (MXE): not found (set MXE_PATH or install to ~/mxe for mkrelease-win)"
  fi
}

# --- macOS ---
report_mac() {
  local brew_qt mac_ver qt_ver
  mac_ver="$(sw_vers -productVersion 2>/dev/null || echo "?")"
  notice "repo zerowallet (${REPO_ROOT})"
  notice "macOS ${mac_ver}"

  brew_qt="$(brew --prefix qt@5 2>/dev/null || true)"
  if [ -n "$brew_qt" ] && [ -x "$brew_qt/bin/qmake" ]; then
    qt_ver="$("$brew_qt/bin/qmake" -query QT_VERSION 2>/dev/null || echo "?")"
    notice "Homebrew qt@5: ${brew_qt} Version: ${qt_ver}"
  else
    notice "Homebrew qt@5: not found"
  fi
  echo "macdeployqt bundles Qt, no static build"
}

# --- Windows (native or WSL) ---
report_win() {
  section "Windows (this host or WSL)"
  report "zerowallet Windows builds are cross-built from Linux with MXE."
  report "On a Windows host: use WSL or a Linux VM; MXE runs on Linux."
  report ""

  if [ "$(uname -s)" = "Linux" ]; then
    report "Host is Linux; Windows target reported under Linux section above."
    return
  fi

  # Native Windows (MinGW/CYGWIN): report what exists
  local qmake_path
  qmake_path="$(command -v qmake 2>/dev/null || true)"
  if [ -n "$qmake_path" ]; then
    report "qmake in PATH: $qmake_path"
  else
    report "qmake: not in PATH. For zerowallet use Linux + MXE to build Windows binaries."
  fi

  if [ -n "${MXE_PATH:-}" ]; then
    report "MXE_PATH (set): $MXE_PATH"
  fi
}

# --- main ---
PLATFORM="$(detect_platform)"
case "$PLATFORM" in
  linux)
    notice "Qt report for zerowallet (repo: ${REPO_ROOT})"
    notice "Platform: ${PLATFORM}"
    report_linux
    ;;
  mac)
    report_mac
    ;;
  win)
    notice "Qt report for zerowallet (repo: ${REPO_ROOT})"
    notice "Platform: ${PLATFORM}"
    report_win
    ;;
  *)
    notice "Qt report for zerowallet (repo: ${REPO_ROOT})"
    notice "Platform: ${PLATFORM}"
    warn "Unknown platform; reporting Linux/Mac/Win hints."
    report_linux
    report_mac
    report_win
    ;;
esac
echo ""
