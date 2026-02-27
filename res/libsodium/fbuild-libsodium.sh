# shellcheck shell=bash
# Copyright 2026 Zero Developers
# Shared libsodium config for buildlibsodium.sh and buildlibsodium-win.sh (Windows target, runs on Linux).
# Sources fbuild.sh (provides err, notice, REPO_ROOT). Run from repo root.
#
# libsodium 1.0.21 released 2026-01-06.
# Download: GitHub releases. Override LIBSODIUM_URL before sourcing for alternate mirror.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
. "$REPO_ROOT/src/scripts/fbuild.sh"

LIBSODIUM_VER=1.0.21
# shellcheck disable=SC2034
LIBSODIUM_RELEASE_DATE="2026-01-06"
LIBSODIUM_TAR="libsodium-${LIBSODIUM_VER}.tar.gz"
LIBSODIUM_GITHUB_URL="https://github.com/jedisct1/libsodium/releases/download/${LIBSODIUM_VER}-RELEASE/${LIBSODIUM_TAR}"
LIBSODIUM_URL="${LIBSODIUM_URL:-$LIBSODIUM_GITHUB_URL}"

sodium_download() {
    if [ ! -f "$LIBSODIUM_TAR" ]; then
        wget "$LIBSODIUM_URL" || err "Failed to download libsodium. Try: wget $LIBSODIUM_GITHUB_URL"
    fi
}

# Extract to res/libsodium/libsodium-${VER}/. Call from repo root.
sodium_extract() {
    cd res/libsodium || exit 1
    sodium_download
    rm -rf "libsodium-${LIBSODIUM_VER}"
    tar xf "$LIBSODIUM_TAR"
    cd "libsodium-${LIBSODIUM_VER}" || exit 1
}

# Copy built libsodium.a to res/. Call from res/libsodium/ (parent of libsodium-${VER}/).
# Arg target: "unix" or "win". Win: for Windows target (build runs on Linux); creates libsodiumd.a, liblibsodium.a, liblibsodiumd.a (symlinks).
sodium_copy() {
    local lib_path target="${1:-unix}"
    if [ -f "libsodium-${LIBSODIUM_VER}/src/libsodium/.libs/libsodium.a" ]; then
        lib_path="libsodium-${LIBSODIUM_VER}/src/libsodium/.libs/libsodium.a"
    elif [ -f "libsodium-${LIBSODIUM_VER}/.libs/libsodium.a" ]; then
        lib_path="libsodium-${LIBSODIUM_VER}/.libs/libsodium.a"
    else
        err "libsodium.a not found after build"
    fi
    cp "$lib_path" ../
    if [ "$target" = "win" ]; then
        ln -sf libsodium.a ../libsodiumd.a
        ln -sf libsodium.a ../liblibsodium.a
        ln -sf libsodium.a ../liblibsodiumd.a
    fi
}
