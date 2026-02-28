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
sodium_build unix
