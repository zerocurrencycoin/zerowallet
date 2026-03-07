#!/bin/bash
# Copyright 2026 Zero Developers
# Report Qt system setup and for zerowallet: dev/release usage and platform defaults.
# Run from repo root or any dir; detects Linux, macOS, Windows (host or WSL).
# Usage: ./src/scripts/qt-report.sh
set -e -u -o pipefail
# shellcheck disable=SC2034
ME="qt-report"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"

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
  local qmake_path prefix_static mxe_path qt_ver static_ready mxe_ready
  notice "repo zerowallet (${REPO_ROOT})"
  notice "Linux"

  qmake_path="$(command -v qmake 2>/dev/null || command -v qmake-qt5 2>/dev/null || true)"
  if [ -n "$qmake_path" ]; then
    qt_ver="$("$qmake_path" -query QT_VERSION 2>/dev/null || echo "?")"
    notice "qmake (dev): ${qmake_path} Version: ${qt_ver}"
  else
    notice "qmake (dev): not found"
  fi

  prefix_static="$REPO_ROOT/qt5-static"
  static_ready=false
  if [ -x "$prefix_static/bin/qmake" ]; then
    notice "qt5-static (release): ${prefix_static} (ready)"
    static_ready=true
  elif [ -d "$prefix_static" ]; then
    notice "qt5-static (release): ${prefix_static} (incomplete)"
  else
    notice "qt5-static (release): not present"
  fi

  mxe_path="${MXE_PATH:-}"
  [ -z "$mxe_path" ] && [ -x "$HOME/mxe/usr/bin/x86_64-w64-mingw32.static-qmake-qt5" ] && mxe_path="$HOME/mxe/usr/bin"
  [ -z "$mxe_path" ] && [ -x "/opt/mxe/usr/bin/x86_64-w64-mingw32.static-qmake-qt5" ] && mxe_path="/opt/mxe/usr/bin"
  mxe_ready=false
  if [ -n "$mxe_path" ] && [ -x "$mxe_path/x86_64-w64-mingw32.static-qmake-qt5" ]; then
    notice "Windows target (MXE): ${mxe_path} (ready)"
    mxe_ready=true
  else
    notice "Windows target (MXE): not found"
  fi

  if [ "$static_ready" = true ] && [ "$mxe_ready" = true ]; then
    echo "Linux target (qt5-static) and Windows target (MXE) ready; use mkrelease-linux or mkrelease-win."
  elif [ "$static_ready" = true ]; then
    echo "Linux target ready; Windows target: install MXE, then mkrelease-win."
  else
    echo "Linux target: run build-qt-static.sh; Windows target: install MXE, then mkrelease-win."
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

# --- Windows (native MinGW/MSYS/CYGWIN) ---
report_win() {
  local qmake_path qt_ver
  notice "repo zerowallet (${REPO_ROOT})"
  notice "Windows"

  qmake_path="$(command -v qmake 2>/dev/null || true)"
  if [ -n "$qmake_path" ]; then
    qt_ver="$("$qmake_path" -query QT_VERSION 2>/dev/null || echo "?")"
    notice "qmake: ${qmake_path} Version: ${qt_ver}"
  else
    notice "qmake: not found"
  fi
  echo "Windows builds: cross-build from Linux with MXE."
}

# --- main ---
PLATFORM="$(detect_platform)"
UNAME_S="$(uname -s)"
case "$PLATFORM" in
  linux) report_linux ;;
  mac)   report_mac ;;
  win)   report_win ;;
  *)
    notice "repo zerowallet (${REPO_ROOT})"
    notice "Platform: unknown (${UNAME_S})"
    warn "Unsupported host. Use Linux, macOS, or Windows (WSL)."
    ;;
esac
echo ""
