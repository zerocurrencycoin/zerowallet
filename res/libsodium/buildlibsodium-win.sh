#!/bin/bash
# Copyright 2026 Zero Developers
set -e -u -o pipefail
# Build libsodium for Windows *target*, running on Linux (MXE cross-compile).
# Run from repo root. Matches Zero depends/packages/libsodium.mk: 1.0.21.
#
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC2034
ME="buildlibsodium-win"
# shellcheck disable=SC1091
. "$REPO_ROOT/res/libsodium/fbuild-libsodium.sh"
cd "$REPO_ROOT"

[ -f res/libsodium.a ] && rm res/libsodium.a
notice "Building libsodium..."

sodium_extract
CC="$(command -v x86_64-w64-mingw32.static-gcc 2>/dev/null)"
[ -n "${CC:-}" ] || err "x86_64-w64-mingw32.static-gcc not found. Run on Linux with MXE in PATH."
CXX="${CC%gcc}g++"
PREFIX="$(pwd)/depends/x86_64-w64-mingw32"
LIBS="" ./configure --prefix="${PREFIX}" --host=x86_64-w64-mingw32 CC="${CC} -g" CXX="${CXX} -g" > /dev/null
make clean > /dev/null 2>&1
make > /dev/null 2>&1
cd ..
sodium_copy win
