# shellcheck shell=bash
# Copyright 2026 Zero Developers
# Messaging helpers for scripts. Shared verbatim across zerowallet (fbuild.sh) and
# Zero node (fzero.sh); keep this file identical in both repos. Source from the build
# helper or standalone. Provides: err, warn, notice, step_done
# Usage: ME="script-name"; . "$(dirname "${BASH_SOURCE[0]}")/fmessage.sh"

# Scripts need bash 4 or later (5 recommended); stop at once under macOS /bin/bash 3.2.
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
  echo "${ME:-script}: ERROR: bash 4 or later required, running ${BASH_VERSION:-unknown} (${BASH:-sh});" \
    "on macOS: brew install bash" >&2
  exit 1
fi

err()   { echo "${ME:-script}: ERROR: $*" >&2; exit 1; }
warn()  { echo "${ME:-script}: WARN: $*" >&2; }
notice() { echo "${ME:-script}: $*"; }
step_done() { printf '%s: %-24s [OK]\n' "${ME:-script}" "$1"; }
