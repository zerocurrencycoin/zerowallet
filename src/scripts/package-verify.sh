#!/bin/bash
# Copyright 2026 Zero Developers
# Verify release package contents (tar, zip, dmg). Run from repo root.
#
# Usage:
#   package-verify.sh -v VERSION     # verify artifacts/ for that version
#   package-verify.sh -l PATH       # verify tar (--linux)
#   package-verify.sh -w PATH       # verify zip (--windows)
#   package-verify.sh -m PATH       # verify dmg (--mac)
#   package-verify.sh -t            # self-test (--test)
#
# See Bashrules.md § Package Verification.
set -e -u -o pipefail

# shellcheck disable=SC2034
ME="package-verify"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
cd "$REPO_ROOT"

check_file() {
  local path="$1"
  local desc="${2:-file}"
  [ -e "$path" ] || err "$desc not found: $path"
  [ -f "$path" ] || err "$desc not a file: $path"
}

verify_tar() {
  local archive="$1"
  check_file "$archive" "tar archive"
  [[ "$archive" == *.tar.gz ]] || [[ "$archive" == *.tgz ]] || err "tar: expected .tar.gz or .tgz: $archive"
  tar tf "$archive" >/dev/null 2>&1 || err "tar: invalid or unreadable: $archive"
  local f
  # Expected: zerowallet, zerod, zero-cli (structure as of 2026-02)
  for f in zerowallet zerod zero-cli; do
    tar tf "$archive" | grep -qE "(^|/)${f}(/|$)" || err "tar: missing required file $f in $archive"
  done
  echo "OK: tar $archive"
}

verify_zip() {
  local archive="$1"
  check_file "$archive" "zip archive"
  [[ "$archive" == *.zip ]] || err "zip: expected .zip: $archive"
  unzip -l "$archive" >/dev/null 2>&1 || err "zip: invalid or unreadable: $archive"
  local f
  # Expected: zerowallet.exe, zerod.exe, zero-cli.exe (structure as of 2026-02)
  for f in zerowallet.exe zerod.exe zero-cli.exe; do
    unzip -l "$archive" | grep -q "$f" || err "zip: missing required file $f in $archive"
  done
  echo "OK: zip $archive"
}

verify_dmg() {
  # DMG only on Darwin: hdiutil is macOS-only. Linux has no built-in DMG mount;
  # 7z/dmg2img would add deps. Verifying DMG on macOS is sufficient for release checks.
  [ "$(uname -s)" = "Darwin" ] || { warn "dmg verification requires macOS (hdiutil); skipping"; return 0; }
  local dmg="$1"
  check_file "$dmg" "dmg"
  [[ "$dmg" == *.dmg ]] || err "dmg: expected .dmg: $dmg"
  local mnt
  mnt="$(mktemp -d)"
  trap 'hdiutil detach "$mnt" 2>/dev/null || true; rm -rf "$mnt"' RETURN
  hdiutil attach "$dmg" -readonly -nobrowse -mountpoint "$mnt" >/dev/null 2>&1 || err "dmg: cannot mount: $dmg"
  # Expected: ZeroWallet.app, zerod, zero-cli, zerowallet/ZeroWallet (structure as of 2026-02)
  [ -d "$mnt/ZeroWallet.app" ] || err "dmg: ZeroWallet.app not found in $dmg"
  [ -f "$mnt/ZeroWallet.app/Contents/MacOS/zerod" ] || err "dmg: zerod not found in app"
  [ -f "$mnt/ZeroWallet.app/Contents/MacOS/zero-cli" ] || err "dmg: zero-cli not found in app"
  [ -f "$mnt/ZeroWallet.app/Contents/MacOS/zerowallet" ] || [ -f "$mnt/ZeroWallet.app/Contents/MacOS/ZeroWallet" ] || err "dmg: main executable (zerowallet/ZeroWallet) not found in app"
  hdiutil detach "$mnt" >/dev/null 2>&1 || true
  echo "OK: dmg $dmg"
}

# Parse args
APP_VERSION=""
LINUX_PATH="" MAC_PATH="" WIN_PATH=""
DO_TEST=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -l|--linux) LINUX_PATH="$2"; shift 2 ;;
    -m|--mac|--macos) MAC_PATH="$2"; shift 2 ;;
    -t|--test) DO_TEST=1; shift ;;
    -v|--version) APP_VERSION="$2"; shift 2 ;;
    -w|--windows) WIN_PATH="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Self-test: verify tar pattern with sample archives
if [ -n "$DO_TEST" ]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  mkdir -p "$TMP/root"
  touch "$TMP/root/zerowallet" "$TMP/root/zerod" "$TMP/root/zero-cli"
  tar -C "$TMP/root" -czf "$TMP/root.tar.gz" zerowallet zerod zero-cli
  mkdir -p "$TMP/nested/linux-zerowallet-v1.0"
  touch "$TMP/nested/linux-zerowallet-v1.0/zerowallet" "$TMP/nested/linux-zerowallet-v1.0/zerod" "$TMP/nested/linux-zerowallet-v1.0/zero-cli"
  tar -C "$TMP/nested" -czf "$TMP/nested.tar.gz" linux-zerowallet-v1.0/zerowallet linux-zerowallet-v1.0/zerod linux-zerowallet-v1.0/zero-cli
  verify_tar "$TMP/root.tar.gz"
  verify_tar "$TMP/nested.tar.gz"
  tar -C "$TMP/root" -czf "$TMP/incomplete.tar.gz" zerowallet zero-cli
  if tar tf "$TMP/incomplete.tar.gz" | grep -qE "(^|/)zerod(/|$)"; then
    err "self-test: incomplete tar should not contain zerod"
  fi
  echo "Self-test passed."
  exit 0
fi

# If -v given, verify artifacts/
if [ -n "$APP_VERSION" ]; then
  [ -n "$LINUX_PATH" ] || LINUX_PATH="artifacts/linux-zerowallet-v${APP_VERSION}.tar.gz"
  [ -n "$WIN_PATH" ]  || WIN_PATH="artifacts/Windows-zerowallet-v${APP_VERSION}.zip"
  [ -n "$MAC_PATH" ]  || MAC_PATH="artifacts/macOS-zerowallet-v${APP_VERSION}.dmg"
fi

ran=0
[ -n "$LINUX_PATH" ] && [ -e "$LINUX_PATH" ] && { verify_tar "$LINUX_PATH"; ran=1; }
[ -n "$WIN_PATH" ]  && [ -e "$WIN_PATH" ]  && { verify_zip "$WIN_PATH"; ran=1; }
[ -n "$MAC_PATH" ]  && [ -e "$MAC_PATH" ]  && { verify_dmg "$MAC_PATH"; ran=1; }

[ "$ran" -eq 1 ] || err "No packages to verify. Use -v VERSION or --linux/--mac/--windows PATH"
