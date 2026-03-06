#!/usr/bin/env bash
# shellcheck shell=bash
# Copyright 2026 Zero Developers
# Validates fbuild.sh: option/env precedence, resolve_zero_dir, version helpers, apply_version_sed.
# Usage: Run from repo root: ./src/scripts/ftest.sh
# set -e: exit on first command failure. set -u: exit on use of unset variable. set -o pipefail: pipeline fails if any stage fails.
set -e -u -o pipefail
# shellcheck disable=SC2034
ME="ftest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Run a command in a subshell; no pass/fail or expectations (caller checks outcome).
run() { ( "$@"; ); }
assert_eq() {
  if [ "$1" != "$2" ]; then
    echo "FAIL: expected '$2', got '$1'" >&2
    return 1
  fi
  return 0
}
assert_empty() {
  if [ -n "${1:-}" ]; then
    echo 'FAIL: expected empty' >&2
    return 1
  fi
  return 0
}

# Source fbuild; override err so tests can continue (err still prints to stderr).
# shellcheck disable=SC1091
. "$SCRIPT_DIR/fmessage.sh"
err() { echo "${ME}: ERROR (captured): $*" >&2; return 1; }
# shellcheck disable=SC1091
. "$SCRIPT_DIR/fbuild.sh"

passed=0 failed=0

# Run a test: execute command (e.g. assert_eq); on success/failure count and echo OK/FAIL.
run_test() {
  if run "$@"; then
    ((passed++)) || true
    echo '  OK '"$*"
    return 0
  else
    ((failed++)) || true
    echo '  FAIL '"$*"
    return 1
  fi
}

echo '[ftest] env overrides CLI (parse_mkdev_args)'
unset QT_PREFIX MXE_PATH JOBS LOG_FILE CONFIG
export QT_PREFIX="/env/qt"
parse_mkdev_args "logs/mkdev.log" -q /cli/qt 2>/dev/null || true
run_test assert_eq "$QT_PREFIX" "/env/qt"

unset MXE_PATH
export MXE_PATH="/env/mxe"
parse_mkdev_args "logs/mkdev.log" -m /cli/mxe 2>/dev/null || true
run_test assert_eq "$MXE_PATH" "/env/mxe"

unset JOBS
export JOBS=99
parse_mkdev_args "logs/mkdev.log" -j 4 2>/dev/null || true
run_test assert_eq "$JOBS" "99"

unset CONFIG
export CONFIG=release
parse_mkdev_args "logs/mkdev.log" -r 2>/dev/null || true
run_test assert_eq "$CONFIG" "release"

unset LOG_FILE
export LOG_FILE="/env/log.txt"
parse_mkdev_args "logs/mkdev.log" -L 2>/dev/null || true
run_test assert_eq "$LOG_FILE" "/env/log.txt"

echo '[ftest] env overrides CLI (parse_mkrelease_args)'
unset ZERO_DIR APP_VERSION PREV_VERSION QT_PREFIX MXE_PATH SKIP_STRIP SKIP_SIGN SKIP_TRANSLATIONS JOBS LOG_FILE
export ZERO_DIR="/env/zero"
parse_mkrelease_args "logs/mkrelease.log" -z /cli/zero 2>/dev/null || true
run_test assert_eq "$ZERO_DIR" "/env/zero"

export APP_VERSION="9.9.9"
parse_mkrelease_args "logs/mkrelease.log" -v 1.0.0 2>/dev/null || true
run_test assert_eq "$APP_VERSION" "9.9.9"

export PREV_VERSION="8.8.8"
parse_mkrelease_args "logs/mkrelease.log" -p 0.0.1 2>/dev/null || true
run_test assert_eq "$PREV_VERSION" "8.8.8"

export QT_PREFIX="/env/qt"
parse_mkrelease_args "logs/mkrelease.log" -q /cli/qt 2>/dev/null || true
run_test assert_eq "$QT_PREFIX" "/env/qt"

export MXE_PATH="/env/mxe"
parse_mkrelease_args "logs/mkrelease.log" -m /cli/mxe 2>/dev/null || true
run_test assert_eq "$MXE_PATH" "/env/mxe"

export SKIP_STRIP=1
parse_mkrelease_args "logs/mkrelease.log" -P 2>/dev/null || true
run_test assert_eq "${SKIP_STRIP:-}" "1"

export SKIP_SIGN=1
parse_mkrelease_args "logs/mkrelease.log" -N 2>/dev/null || true
run_test assert_eq "${SKIP_SIGN:-}" "1"

export SKIP_TRANSLATIONS=1
parse_mkrelease_args "logs/mkrelease.log" -t 2>/dev/null || true
run_test assert_eq "${SKIP_TRANSLATIONS:-}" "1"

export JOBS=88
parse_mkrelease_args "logs/mkrelease.log" -j 2 2>/dev/null || true
run_test assert_eq "$JOBS" "88"

export LOG_FILE="/env/release.log"
parse_mkrelease_args "logs/mkrelease.log" -L 2>/dev/null || true
run_test assert_eq "$LOG_FILE" "/env/release.log"

echo '[ftest] resolve_zero_dir: ZERO_DIR set -> no change'
export ZERO_DIR="/already/set"
resolve_zero_dir mac
run_test assert_eq "$ZERO_DIR" "/already/set"

echo '[ftest] resolve_zero_dir: ../Zero exists and non-empty -> ../Zero/src'
tmpdir=""
tmpdir="$(mktemp -d 2>/dev/null)" || tmpdir="/tmp/ftest.$$"; mkdir -p "$tmpdir"
repo="$tmpdir/repo"
zero="$tmpdir/Zero"
mkdir -p "$repo" "$zero/src"
touch "$zero/foo"
(
  cd "$repo" && ZERO_DIR="" bash -c '
    . "'"$SCRIPT_DIR"'/fbuild.sh" 2>/dev/null
    resolve_zero_dir linux
    case "$ZERO_DIR" in
      ../Zero/src) exit 0 ;;
      *) echo "ZERO_DIR=$ZERO_DIR"; exit 1 ;;
    esac
  '
) 2>/dev/null && run_test true || run_test false
rm -rf "$tmpdir"

echo '[ftest] resolve_zero_dir: ../Zero empty -> platform fallback (mac -> ../ZeroMac)'
tmpdir="$(mktemp -d 2>/dev/null)" || tmpdir="/tmp/ftest.$$"; mkdir -p "$tmpdir"
repo="$tmpdir/repo"
zeromac="$tmpdir/ZeroMac"
mkdir -p "$repo" "$zeromac/src"
mkdir -p "$tmpdir/Zero"
(
  cd "$repo" && ZERO_DIR="" bash -c '
    . "'"$SCRIPT_DIR"'/fmessage.sh"
    err() { return 1; }
    . "'"$SCRIPT_DIR"'/fbuild.sh" 2>/dev/null
    resolve_zero_dir mac
    case "$ZERO_DIR" in
      ../ZeroMac/src) exit 0 ;;
      *) echo "ZERO_DIR=$ZERO_DIR"; exit 1 ;;
    esac
  '
) 2>/dev/null && run_test true || run_test false
rm -rf "$tmpdir"

echo '[ftest] version helpers'
run_test assert_eq "$(patch_plus1 1.0.0)" "1.0.1"
run_test assert_eq "$(patch_plus1 2.1.9)" "2.1.10"
run_test assert_eq "$(patch_minus1 1.0.1)" "1.0.0"
run_test assert_eq "$(patch_minus1 1.0.0)" "1.0.0"
valid_semver 1.0.0 && run_test true || run_test false
valid_semver 1.0 && run_test false || run_test true
valid_semver "x.y.z" && run_test false || run_test true

echo '[ftest] apply_version_sed: portable sed, no .bak left'
tmpdir="$(mktemp -d 2>/dev/null)" || tmpdir="/tmp/ftest.$$"
mkdir -p "$tmpdir"
echo "prev 1.2.3 prev" > "$tmpdir/zero-qt-wallet.pro"
echo "prev 1.2.3 prev" > "$tmpdir/README.md"
(
  cd "$tmpdir"
  PREV_VERSION="1.2.3" APP_VERSION="1.2.4" REPO_ROOT="$tmpdir" \
  bash -c '
    SCRIPT_DIR="'"$SCRIPT_DIR"'"
    . "'"$SCRIPT_DIR"'/fmessage.sh" 2>/dev/null
    . "'"$SCRIPT_DIR"'/fbuild.sh" 2>/dev/null
    step_done() { :; }
    apply_version_sed 2>/dev/null
  '
)
grep -q "1.2.4" "$tmpdir/zero-qt-wallet.pro" && grep -q "1.2.4" "$tmpdir/README.md" || { rm -rf "$tmpdir"; run_test false; }
[ ! -f "$tmpdir/zero-qt-wallet.pro.bak" ] && [ ! -f "$tmpdir/README.md.bak" ] && run_test true || run_test false
rm -rf "$tmpdir"

echo '[ftest] help exits 0 and mentions options'
parse_mkrelease_args "x.log" -h 2>/dev/null | grep -q "no-strip" && run_test true || run_test false
parse_mkrelease_args "x.log" -h 2>/dev/null | grep -q "no-sign" && run_test true || run_test false

echo ''
echo "[ftest] passed=$passed failed=$failed"
[ "$failed" -eq 0 ] && exit 0 || exit 1
