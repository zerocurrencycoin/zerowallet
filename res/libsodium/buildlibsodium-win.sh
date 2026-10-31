#!/bin/bash
# Copyright 2026 Zero Developers
set -e -u -o pipefail
# Build libsodium for Windows *target*, running on Linux (MXE cross-compile).
# Run from repo root. Matches Zero depends/packages/libsodium.mk: 1.0.21.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC2034
ME="buildlibsodium-win"
# shellcheck disable=SC1091
. "$REPO_ROOT/res/libsodium/fbuild-libsodium.sh"
cd "$REPO_ROOT"
sodium_ensure_archive win
