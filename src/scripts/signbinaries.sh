#!/bin/bash
# Copyright 2026 Zero Developers
set -e -u -o pipefail
# shellcheck disable=SC2034
ME="signbinaries"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
cd "$REPO_ROOT"

# Parse args (env vars override). Same -v/--version as mkrelease scripts.
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--version) APP_VERSION="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[ -z "${APP_VERSION:-}" ] && err "APP_VERSION not set. Use -v/--version or set env."

# Store the hash and signatures here
rm -rf release/signatures
mkdir -p release/signatures
mkdir -p artifacts

cd artifacts

# Remove previous signatures/hashes
rm -f "sha256sum-v${APP_VERSION}.txt"
rm -f "signatures-v${APP_VERSION}.tar.gz"

# sha256 the binaries (sha256sum on Linux, shasum -a 256 on macOS)
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum ./*"${APP_VERSION}"* > "sha256sum-v${APP_VERSION}.txt"
elif command -v shasum >/dev/null 2>&1; then
  shasum -a 256 ./*"${APP_VERSION}"* > "sha256sum-v${APP_VERSION}.txt"
else
  err "Neither sha256sum nor shasum found. Install coreutils (Linux) or use macOS (shasum built-in)."
fi

for i in ./*"${APP_VERSION}"*; do
  [ -e "$i" ] || continue
  notice "Signing $i"
  gpg --batch --output "../release/signatures/$(basename "$i").sig" --detach-sig "$i"
done

mv "sha256sum-v${APP_VERSION}.txt" ../release/signatures/
cp ../res/SIGNATURES_README ../release/signatures/README

cd ../release/signatures
zip "signatures-v${APP_VERSION}.zip" ./*
mv "signatures-v${APP_VERSION}.zip" ../../artifacts
