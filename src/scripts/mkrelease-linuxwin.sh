#!/bin/bash
# Copyright 2026 Zero Developers
# RETIRED: Use mkrelease-linux.sh and mkrelease-win.sh separately.
# This script previously built Linux + Windows in one run; that flow is deprecated.
set -e -u -o pipefail

echo "mkrelease-linuxwin: RETIRED. Run mkrelease-linux.sh and mkrelease-win.sh separately." >&2
echo "  ./src/scripts/mkrelease-linux.sh" >&2
echo "  ./src/scripts/mkrelease-win.sh" >&2
exit 1
