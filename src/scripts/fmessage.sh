# shellcheck shell=bash
# Copyright 2026 Zero Developers
# Messaging helpers for scripts. Source from fbuild.sh or standalone (install_mxe, wrappers).
# Provides: err, warn, notice, step_done
# Usage: ME="script-name"; . "$(dirname "${BASH_SOURCE[0]}")/fmessage.sh"

err()   { echo "${ME:-script}: ERROR: $*" >&2; exit 1; }
warn()  { echo "${ME:-script}: WARN: $*" >&2; }
notice() { echo "${ME:-script}: $*"; }
step_done() { printf '%s: %-24s [OK]\n' "${ME:-script}" "$1"; }
