# Shared logging for mkdev/mkrelease scripts.
# Usage: ME="script-name"; . "$(dirname "$0")/lib-log.sh"
# err: fatal, to stderr, exit 1
# warn: non-fatal warning, to stderr
# info: informational, to stdout
# notice: progress/status, to stdout
# step_done: step label + [OK] (e.g. "Version files........ [OK]")
# section: blank line + section header (e.g. "[Windows]")
# JOBS: parallel jobs (Linux: nproc, macOS: sysctl hw.ncpu, fallback: 2)
JOBS=$(nproc 2>/dev/null || (sysctl -n hw.ncpu 2>/dev/null) || echo 2)

err()   { echo "${ME:-script}: ERROR: $*" >&2; exit 1; }
warn()  { echo "${ME:-script}: WARN: $*" >&2; }
info()  { echo "${ME:-script}: $*"; }
notice() { echo "${ME:-script}: $*"; }
step_done() { printf "%s: %-24s [OK]\n" "${ME:-script}" "$1"; }
section() { echo ""; notice "[$1]"; }

# Call when build fails and LOG_FILE is set. Outputs analysis to stderr.
analyze_build_log() {
  local f="${1:-$LOG_FILE}"
  [ -n "$f" ] && [ -f "$f" ] || return 0
  echo "" >&2
  echo "=== Build analysis (from $f) ===" >&2
  echo "--- Errors ---" >&2
  grep -iE "error:|fatal|undefined reference|cannot find|No such file" "$f" 2>/dev/null | tail -30 || echo "(none)" >&2
  echo "--- Warnings (last 15) ---" >&2
  grep -iE "warning:" "$f" 2>/dev/null | tail -15 || echo "(none)" >&2
}
