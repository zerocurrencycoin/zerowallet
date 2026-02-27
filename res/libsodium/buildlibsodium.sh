#!/bin/bash
# Copyright 2026 Zero Developers
set -e -u -o pipefail
# Build libsodium for Unix (Linux, macOS). Run from repo root.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC2034
ME="buildlibsodium"
# shellcheck disable=SC1091
. "$REPO_ROOT/res/libsodium/fbuild-libsodium.sh"
cd "$REPO_ROOT"

[ -f res/libsodium.a ] && rm res/libsodium.a
notice "Building libsodium..."

sodium_extract
LIBS="" ./configure > /dev/null
make clean > /dev/null 2>&1
if [[ "$OSTYPE" == "darwin"* ]]; then
    make CFLAGS="-mmacosx-version-min=10.11" CPPFLAGS="-mmacosx-version-min=10.11" > /dev/null 2>&1
else
    make > /dev/null 2>&1
fi
cd ..
sodium_copy unix
