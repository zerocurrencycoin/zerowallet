#!/bin/bash
# MXE install (default), deps only, or check. Usage: ./install_mxe.sh [--install|--deps|--check]
#   (default): full install = deps + clone + make qtbase qtwebsockets (~1h+)
#   --deps:    apt packages only
#   --check:   verify MXE + qmake ready
# System-wide: MXE_ROOT=/opt/mxe ./install_mxe.sh
set -e -u -o pipefail
QMAKE="x86_64-w64-mingw32.static-qmake-qt5"
MXE_ROOT="${MXE_ROOT:-$HOME/mxe}"
MXE_PATH="${MXE_PATH:-$MXE_ROOT/usr/bin}"

case "${1:---install}" in
  --deps)
    sudo apt install -y autoconf automake bison bzip2 flex g++ g++-multilib gettext git gperf libc6-dev-i386 libgdk-pixbuf2.0-dev libltdl-dev libssl-dev libtool-bin make openssl p7zip-full patch perl pkg-config python3-mako python3-setuptools ruby sed unzip wget xz-utils zstd
    ;;
  --install)
    "$0" --deps
    if [ ! -d "$MXE_ROOT" ]; then
      echo "Cloning MXE to $MXE_ROOT..."
      git clone https://github.com/mxe/mxe.git "$MXE_ROOT"
    fi
    echo "Building MXE qtbase qtwebsockets (this may take over an hour)..."
    cd "$MXE_ROOT"
    make MXE_TARGETS='x86_64-w64-mingw32.static' qtbase qtwebsockets
    echo "Done. MXE at $MXE_PATH"
    ;;
  --check)
    [ -x "$MXE_PATH/$QMAKE" ] && { echo "OK: MXE at $MXE_PATH"; exit 0; }
    echo "MXE not found. Run ./install_mxe.sh --install" >&2
    exit 1
    ;;
  *)
    echo "Usage: ./install_mxe.sh [--install|--deps|--check]" >&2
    echo "  Default: --install. System-wide: MXE_ROOT=/opt/mxe ./install_mxe.sh" >&2
    exit 1
    ;;
esac
