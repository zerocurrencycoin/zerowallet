#!/bin/bash
# Copyright 2026 Zero Developers
# MXE install (default), deps only, or check. Usage: ./install_mxe.sh [-i|--install|-d|--deps|-c|--check]
#   (default): full install = deps + clone + make qtbase qtwebsockets (~1h+)
#   -d, --deps:    apt packages only
#   -c, --check:   verify MXE + qmake ready
# System-wide: MXE_ROOT=/opt/mxe ./install_mxe.sh
set -e -u -o pipefail
# shellcheck disable=SC2034
ME="install_mxe"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fmessage.sh"
QMAKE="x86_64-w64-mingw32.static-qmake-qt5"
MXE_ROOT="${MXE_ROOT:-$HOME/mxe}"
MXE_PATH="${MXE_PATH:-$MXE_ROOT/usr/bin}"

case "${1:---install}" in
  -d|--deps)
    sudo apt install -y autoconf automake bison bzip2 flex g++ g++-multilib gettext git gperf libc6-dev-i386 libgdk-pixbuf2.0-dev libltdl-dev libssl-dev libtool-bin make openssl p7zip-full patch perl pkg-config python3-mako python3-setuptools ruby sed unzip wget xz-utils zstd
    ;;
  -i|--install)
    "$0" --deps
    if [ ! -d "$MXE_ROOT" ]; then
      notice "Cloning MXE to $MXE_ROOT..."
      git clone https://github.com/mxe/mxe.git "$MXE_ROOT"
    fi
    notice "Building MXE qtbase qtwebsockets (this may take over an hour)..."
    cd "$MXE_ROOT"
    make MXE_TARGETS='x86_64-w64-mingw32.static' qtbase qtwebsockets
    notice "Done. MXE at $MXE_PATH"
    ;;
  -c|--check)
    [ -x "$MXE_PATH/$QMAKE" ] && { notice "OK: MXE at $MXE_PATH"; exit 0; }
    err "MXE not found. Run ./install_mxe.sh --install"
    ;;
  *)
    echo "Usage: ./install_mxe.sh [-i|--install|-d|--deps|-c|--check]" >&2
    echo "  Default: --install. System-wide: MXE_ROOT=/opt/mxe ./install_mxe.sh" >&2
    exit 1
    ;;
esac
