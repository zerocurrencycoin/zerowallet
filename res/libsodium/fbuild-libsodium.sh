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

# Configure and build libsodium. Call from libsodium-${VER}/. Arg: "unix" or "win".
# Win: requires MXE in PATH. When invoked from mkrelease-win.sh, resolve_path_win has
# already prepended MXE_PATH to PATH, so command -v finds the static gcc.
sodium_configure_make() {
  local target="${1:-unix}"
  if [ "$target" = "win" ]; then
    CC="$(command -v x86_64-w64-mingw32.static-gcc 2>/dev/null)"
    [ -n "${CC:-}" ] || err "x86_64-w64-mingw32.static-gcc not found. Run on Linux with MXE in PATH."
    CXX="${CC%gcc}g++"
    PREFIX="$REPO_ROOT/depends/x86_64-w64-mingw32"
    LIBS="" ./configure --prefix="$PREFIX" --host=x86_64-w64-mingw32 CC="${CC} -g" CXX="${CXX} -g" > /dev/null
  else
    LIBS="" ./configure > /dev/null
  fi
  make clean > /dev/null 2>&1
  if [[ "${OSTYPE:-}" == darwin* ]]; then
    make CFLAGS="-mmacosx-version-min=10.11" CPPFLAGS="-mmacosx-version-min=10.11" > /dev/null 2>&1
  else
    make > /dev/null 2>&1
  fi
}

# Classify res/libsodium.a by object format in the first archive member.
# Echoes: unix (ELF/Mach-O), win (COFF/PECOFF), missing, unknown.
sodium_archive_kind() {
  local ar_file="${1:-$REPO_ROOT/res/libsodium.a}" member tmpdir obj kind
  [ -f "$ar_file" ] || { echo "missing"; return 0; }
  # Resolve to absolute: ar x runs after cd into tmpdir, so a relative path would not resolve.
  ar_file="$(cd "$(dirname "$ar_file")" && pwd)/$(basename "$ar_file")"
  member=$(ar t "$ar_file" 2>/dev/null | head -1 || true)
  [ -n "$member" ] || { echo "unknown"; return 0; }
  tmpdir=$(mktemp -d)
  if ! (cd "$tmpdir" && ar x "$ar_file" "$member" 2>/dev/null); then
    rm -rf "$tmpdir"
    echo "unknown"
    return 0
  fi
  obj="$tmpdir/$member"
  if [ ! -f "$obj" ]; then
    rm -rf "$tmpdir"
    echo "unknown"
    return 0
  fi
  kind=$(file -b "$obj")
  rm -rf "$tmpdir"
  case "$kind" in
    *COFF*|*PECOFF*) echo "win" ;;
    *ELF*|*Mach-O*) echo "unix" ;;
    *) echo "unknown" ;;
  esac
}

# Reuse matching archive; rebuild when missing or wrong target (e.g. after mkdev-win on same tree).
sodium_ensure_archive() {
  local target="${1:-unix}"
  local kind
  kind=$(sodium_archive_kind "$REPO_ROOT/res/libsodium.a")
  if [ "$kind" = "$target" ]; then
    notice "libsodium.a OK (${target})"
    return 0
  fi
  if [ "$kind" = "missing" ]; then
    notice "libsodium.a missing; building (${target})..."
  else
    warn "libsodium.a is ${kind}, need ${target}; rebuilding..."
  fi
  sodium_build "$target"
}

# Full build: extract, configure, make, copy. Call from repo root. Arg: "unix" or "win".
sodium_build() {
  local target="${1:-unix}"
  [ -f res/libsodium.a ] && rm res/libsodium.a
  notice "Building libsodium..."
  sodium_extract
  sodium_configure_make "$target"
  cd ..
  sodium_copy "$target"
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
