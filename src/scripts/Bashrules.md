# Bash Script Conventions

Coding standards for zerowallet shell scripts. zerowalletwin scripts are the reference; zerowalletlinux should align.

## Shared Infrastructure

### fbuild.sh

Use `fbuild.sh` as the shared build library. It provides:

- **Logging:** `err`, `warn`, `info`, `notice`, `step_done`, `section`
- **Build:** `log_capture`, `build_fail`, `analyze_build_log`
- **Args:** `parse_mkdev_args` (mkdev scripts)
- **Resolution:** `resolve_zero_dir`, `resolve_qt`, `detect_mxe`
- **Version:** `resolve_version`, `apply_version_sed`, `check_version_mismatch`
- **Globals:** `SCRIPT_DIR`, `REPO_ROOT`, `JOBS`

**Usage:**
```bash
#!/bin/bash
set -e -u -o pipefail
# shellcheck disable=SC2034
ME="script-name"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
cd "$REPO_ROOT"
```

**Sourcing:** Use `"$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"` so the script works when invoked by path or from another directory.

---

## Variable Quoting

### Rule: Quote all expansions

- **Variables:** `"${VAR}"`, `"${VAR:-default}"`
- **Command substitution:** `"$(cmd)"`
- **Paths, user input:** Always quoted

**Why:** Prevents word splitting and globbing; preserves empty values.

### Unbound variable safety

With `set -u`, unset variables cause errors. Use default syntax when a variable may be unset:

```bash
[ -z "${APP_VERSION:-}" ] && err "APP_VERSION required"
[ -n "${ZERO_DIR:-}" ] && return 0
make -j"${JOBS:-2}"
```

### When to use `${}` vs `$`

- Use `${VAR}` when adjacent to text: `"${APP_VERSION}.tar.gz"`, `"${VAR}_suffix"`
- Use `${VAR:-default}` for defaults
- Use `${VAR#prefix}` for parameter expansion

---

## Command Substitution

### Prefer `$(cmd)` over backticks

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
```

### Quote the result

```bash
make -j"$(nproc)"
make -j"${JOBS:-$(nproc)}"
```

---

## Literal Strings

Use **single quotes** when no expansion is needed:

```bash
notice 'Build complete'
err 'Invalid option'
```

Use **double quotes** when expansion is required:

```bash
notice "Version ${APP_VERSION}"
err "zerod not found at $ZERO_DIR"
```

---

## Script Header

```bash
#!/bin/bash
set -e -u -o pipefail
# shellcheck disable=SC2034
ME="script-name"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"
cd "$REPO_ROOT"
```

- `set -e`: exit on error
- `set -u`: error on unset variable
- `set -o pipefail`: fail pipeline if any command fails
- `BASH_SOURCE[0]`: correct path when script is sourced or symlinked

---

## Build Patterns

### Clean

```bash
make distclean >/dev/null 2>&1 || true
```

Do not use bare `make clean`; prefer `make distclean` with `|| true` so missing Makefile does not fail.

### Parallel jobs

```bash
make -j"${JOBS:-2}"
# or
make -j"$(nproc)"
```

Quote the expansion. Prefer `JOBS` from fbuild when available.

### Packaging (avoid SIGPIPE)

Use a subshell so `zip`/`tar` are not in a pipeline that can SIGPIPE:

```bash
(cd release && zip -r "file.zip" "dir/" >/dev/null 2>&1) || err "zip failed"
(cd bin && tar czf "file.tar.gz" "dir/" >/dev/null 2>&1) || err "tar failed"
```

### Directories

```bash
mkdir -p artifacts
mkdir -p "$PKGDIR"
```

Use `mkdir -p`; it does not fail if the directory exists.

---

## Package Verification

Check for required files by name, not line count:

```bash
# Linux
for f in zerowallet zerod zero-cli; do
  tar tf "artifacts/linux-zerowallet-v$APP_VERSION.tar.gz" | grep -q "/${f}" || err "package missing $f"
done

# Windows
for f in zerowallet.exe zerod.exe zero-cli.exe; do
  unzip -l "artifacts/Windows-zerowallet-v$APP_VERSION.zip" | grep -q "$f" || err "package missing $f"
done
```

---

## libsodium Artifacts

### Naming

| Platform | Link flag | File name | Notes |
|----------|-----------|-----------|-------|
| Unix | `-lsodium` | `libsodium.a` | Standard: `lib` + name + `.a` |
| MinGW | `-llibsodium` | `liblibsodium.a` | MinGW adds `lib` prefix; library name is `libsodium` |

**Why `liblibsodium.a`?** Not a typo. MinGW's linker with `-llibsodium` looks for `lib` + `libsodium` + `.a` = `liblibsodium.a`. The build produces `libsodium.a`; we copy it to `liblibsodium.a` so the linker finds it.

### Artifacts

- **Unix:** `res/libsodium.a`, `res/libsodiumd.a` (debug)
- **MinGW:** `res/liblibsodium.a`, `res/liblibsodiumd.a` (debug)

All are build artifacts. Add to `.gitignore`:

```
res/libsodium.a
res/libsodiumd.a
res/liblibsodium.a
res/liblibsodiumd.a
res/libsodium/libsodium*
res/libsodium/win/
```

---

## ShellCheck

Run `shellcheck -s bash src/scripts/*.sh`. Use directives when intentional:

```bash
# shellcheck disable=SC2034   # ME used by sourced fbuild
# shellcheck disable=SC1091   # Not following sourced file
```

---

## Cross-Repo Sync

zerowalletwin is the reference. When porting to zerowalletlinux:

1. Prefer adopting `fbuild.sh` over keeping `lib-log.sh` + inline logic
2. Use the same quoting, unbound-var, and build patterns
3. Align `.gitignore` for libsodium artifacts
4. Use `libsodium-common.sh` for shared libsodium config (version, URL)
