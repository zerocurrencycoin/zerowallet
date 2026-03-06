# Bash Script Conventions

Coding standards for zerowallet shell scripts. zerowalletwin scripts are the reference; zerowalletlinux should align.

---

## General Scripting

### Script Header

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

### Variable Quoting

**Rule: Quote all expansions**

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

### Command Substitution

Prefer `$(cmd)` over backticks. Quote the result:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
make -j"$(nproc)"
make -j"${JOBS:-$(nproc)}"
```

### Literal Strings

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

### ShellCheck

Run `shellcheck -s bash src/scripts/*.sh`. Use directives when intentional:

```bash
# shellcheck disable=SC2034   # ME used by sourced fbuild
# shellcheck disable=SC1091   # Not following sourced file
```

### Rationale and references

Where authoritative sources only suggest or recommend, this project may **mandate** or make **strong recommendations** for consistency and safety. Inline references point to the [References](#references) section at the end.

**Shebang: `#!/bin/bash` vs `#!/usr/bin/env bash`**

- **First line:** The shebang must be the very first line of the file (no BOM, no blank line, no comment or other text before it). **Project:** Mandate.
- **This project (Bashrules):** Default is `#!/bin/bash` — single interpreter path, no PATH lookup, no risk of a different `bash` in PATH [2][3].
- **Portability:** `#!/usr/bin/env bash` is widely recommended when the same script must run on Linux, macOS, and other Unix-like systems where `bash` may live in `/usr/local/bin/bash`, under a version manager, or elsewhere. `env` is in `/usr/bin` per POSIX, so `#!/usr/bin/env bash` is portable; the script uses the first `bash` in PATH [2][3][4]. [5]. See refs: Baeldung “use #!/usr/bin/env bash if we’re looking for portability”; DevOps Daily; Stack Overflow “Why is #!/usr/bin/env bash superior to #!/bin/bash?”). `env` is required to be in `/usr/bin` by POSIX, so `#!/usr/bin/env bash` is portable; the script uses the first `bash` in PATH [2][3][4]. [5].
- **Trade-off:** `#!/bin/bash` = predictable and slightly more secure (no PATH). `#!/usr/bin/env bash` = portable across install locations and environments. Scripts that must run on macOS and Linux (e.g. ftest.sh, CI) may use `#!/usr/bin/env bash`; scripts that only run in a controlled Linux environment can use `#!/bin/bash`. Document the choice where it matters.

**Comment placement**

- File header at top (what the file does). Function comments when they assist developers: for more complex or longer functions, or when naming is ambiguous; obvious helpers (e.g. `assert_eq`, `assert_empty`) need not have comments. Inline comments for non-obvious logic only. Aligned with [1]. **Project:** Mandate header; add function comments only when warranted (complexity, length, or ambiguous naming).

**Indentation**

- 2 spaces, no tabs. [1] requires this. **Project:** Mandate. (Google Shell Style Guide: “Indent 2 spaces. No tabs.” widespread.)

**Function style**

- `name() { ... }` with `{` on the same line as `)`. [1] allows `function name()` with same-line brace. **Project:** Use `name() {` consistently (no `function` keyword).

**Quoting**

- Single quotes when no expansion; double when expansion is needed. Prefer `"${var}"` when adjacent to text. [1]: single = no substitution, double = substitution required/tolerated. [5] and shell best practice: quote expansions to avoid word splitting and globbing. **Project:** Mandate quote-all-expansions; single for literals. (Google: “’Single’ quotes indicate that no substitution is desired. ‘Double’ quotes indicate that substitution is required/tolerated.” POSIX and shell best practice: quote all expansions to avoid word splitting and globbing.

**Additional standardizations**

- **Errors to STDERR:** All error and warning output must go to stderr (`>&2`). [1] recommends a dedicated err() and sending errors to STDERR. **Project:** Mandate; fmessage.sh provides `err`, `warn`.
- **Local variables:** Use `local` for function-local variables. [1] requires this. **Project:** Strong recommendation for any function that sets variables not intended as output/API.
- **Check return values:** Always check return values of commands and fail explicitly with an informative message. [1]; use `if ! cmd; then ...` or `cmd || err "..."`. **Project:** Mandate for build and packaging steps.
- **Control flow:** Put `; then` and `; do` on the same line as the `if`/`for`/`while`; put `else`, `fi`, `done` on their own lines. [1]. **Project:** Strong recommendation.
- **Case statements:** Indent alternatives by 2 spaces; multiline actions indented one more level; `;;` on its own line for multiline blocks. [1]. **Project:** Strong recommendation.
- **Line length:** Prefer lines ≤80 characters; break long pipelines with `\` and 2-space indent. [1] mandates 80 chars. **Project:** Strong recommendation; allow longer when splitting harms clarity.

---

## zerowallet Build Infrastructure

### fbuild.sh and fmessage.sh

`fmessage.sh` provides messaging only (err, warn, notice, step_done). `fbuild.sh` sources it and adds build context (REPO_ROOT, resolve_qt, etc.). Scripts needing only messaging (e.g. install_mxe, wrappers) source fmessage.sh; scripts needing build context source fbuild.

Use `fbuild.sh` as the shared build library. It provides:

- **Logging:** `err`, `warn`, `info`, `notice`, `step_done`, `section`. With `-L`/`--log`, logs **append** (mkdev: log_capture/tee -a; mkrelease: exec > tee -a). Do not truncate at start.
- **Build:** `log_capture`, `build_fail`, `analyze_build_log`
- **Args:** `parse_mkdev_args` (mkdev scripts)
- **Resolution:** `resolve_zero_dir`, `resolve_qt`, `resolve_path_win`
- **Version:** `resolve_version`, `apply_version_sed`, `check_version_mismatch`
- **Globals:** `SCRIPT_DIR`, `REPO_ROOT`, `JOBS`

**Sourcing:** Use `"$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"` so the script works when invoked by path or from another directory.

### Path resolution

- **src/scripts:** `SCRIPT_DIR` = own dir, `REPO_ROOT` = `SCRIPT_DIR/../..`
- **res/libsodium:** Scripts derive `REPO_ROOT` from their location and source `$REPO_ROOT/res/libsodium/fbuild-libsodium.sh` (which sources fbuild.sh). See BUILD.md § Agreed design.

### Build patterns

**Parallel jobs:**

```bash
make -j"${JOBS:-2}"
# or
make -j"$(nproc)"
```

Quote the expansion. Prefer `JOBS` from fbuild when available.

**Redirection to null:**

Use `>/dev/null` (no space before `/`). Consistent across scripts.

```bash
make distclean >/dev/null 2>&1 || true
cp file dest >/dev/null
command -v tool >/dev/null 2>&1 || err "tool not found"
```

**Packaging (avoid SIGPIPE):**

Use a subshell so `zip`/`tar` are not in a pipeline that can SIGPIPE:

```bash
(cd release && zip -r "file.zip" "dir/" >/dev/null 2>&1) || err "zip failed"
(cd bin && tar czf "file.tar.gz" "dir/" >/dev/null 2>&1) || err "tar failed"
```

**Directories:**

```bash
mkdir -p artifacts
mkdir -p "$PKGDIR"
```

Use `mkdir -p`; it does not fail if the directory exists.

---

## Package Verification

Check for required files by name, not line count. For tar, use a pattern that matches both root-level and nested paths:

```bash
# Linux (tar: match "zerowallet" or "pkg/zerowallet" or "pkg/zerowallet/")
for f in zerowallet zerod zero-cli; do
  tar tf "artifacts/linux-zerowallet-v$APP_VERSION.tgz" | grep -qE "(^|/)${f}(/|$)" || err "package missing $f"
done

# Windows (unzip -l: match filename in listing)
for f in zerowallet.exe zerod.exe zero-cli.exe; do
  unzip -l "artifacts/Windows-zerowallet-v$APP_VERSION.zip" | grep -q "$f" || err "package missing $f"
done
```

**mkrelease scripts:** Call `package-verify.sh --linux`, `--windows`, or `--mac` instead of duplicating inline verify loops.

**Verify:** `./src/scripts/package-verify.sh` with:

| Option | Purpose |
|--------|---------|
| `-v VERSION` | Verify `artifacts/linux-*`, `Windows-*`, `macOS-*` for that version |
| `--linux PATH` | Verify tar (zerowallet, zerod, zero-cli) |
| `--windows PATH` | Verify zip (Windows target package: zerowallet.exe, zerod.exe, zero-cli.exe) |
| `--mac PATH` | Verify dmg (ZeroWallet.app); macOS only |
| `--test` | Self-test tar pattern with sample archives; no real artifacts |

**DMG on Darwin only:** `hdiutil` is macOS-only. Linux has no built-in DMG mount; 7z/dmg2img would add deps. Verifying DMG on macOS suffices for release checks.

---

## libsodium

**Scripts:** `res/libsodium/buildlibsodium.sh` (Unix). `res/libsodium/buildlibsodium-win.sh` (Windows target; runs on Linux, MXE cross-compile).

**Windows build:** When `buildlibsodium-win.sh` is invoked from `mkrelease-win.sh`, `resolve_path_win` has already run and prepended `MXE_PATH` to `PATH`. The libsodium script inherits that environment; `command -v x86_64-w64-mingw32.static-gcc` finds the tool. Callers must run `resolve_path_win` (or `resolve_qt win`) before `buildlibsodium-win.sh`.

### Naming

| Platform | Link flag | File name | Notes |
|----------|-----------|-----------|-------|
| Unix | `-lsodium` | `libsodium.a` | Standard: `lib` + name + `.a` |
| MinGW | `-llibsodium` | `liblibsodium.a` | MinGW adds `lib` prefix; library name is `libsodium` |

**Why `liblibsodium.a`?** GNU linker: `-lX` looks for `libX.a`. So `-llibsodium` → `liblibsodium.a`. Build produces `libsodium.a`; we copy to `liblibsodium.a` for the linker. See `zero-qt-wallet.pro` and BUILD.md.

### Download sources

**Browse:** [download.libsodium.org/libsodium/releases/](https://download.libsodium.org/libsodium/releases/), [GitHub releases](https://github.com/jedisct1/libsodium/releases) ([jedisct1](https://github.com/jedisct1)).

**Default URL:** `fbuild-libsodium.sh` uses GitHub. Override `LIBSODIUM_URL` before sourcing for alternate mirror. Do not claim "same tarball, different mirrors" unless checksums are verified.

### ZERO_DEPENDS

Dropped. Download and build each time. See BUILD.md § Agreed design.

### Artifacts

| Binary | Platform | Notes |
|--------|----------|-------|
| libsodium.a | Unix | 1.0.21 (2026-01-06) |
| libsodiumd.a | Unix debug | Same as release for static |
| liblibsodium.a | MinGW | 1.0.21 (2026-01-06); copy of libsodium.a |
| liblibsodiumd.a | MinGW debug | Same as release for static |

All are build artifacts. Add to `.gitignore`:

```
res/libsodium.a
res/libsodiumd.a
res/liblibsodium.a
res/liblibsodiumd.a
res/libsodium/libsodium*
```

---

## Cross-Repo Sync

zerowalletwin is the reference. When porting to zerowalletlinux:

1. Prefer adopting `fbuild.sh` over keeping `lib-log.sh` + inline logic
2. Use the same quoting, unbound-var, and build patterns
3. Align `.gitignore` for libsodium artifacts
4. Use `fbuild-libsodium.sh` for shared libsodium config (version, URL).

---

## References

Numbered references used inline in the Rationale and Additional standardizations sections. Where a source only suggests or lightly recommends a practice, this project may still mandate or strongly recommend it for consistency.

1. **Google Shell Style Guide**  
   https://google.github.io/styleguide/shellguide.html  
   Official shell style guide for Google-originated open-source projects. Covers shebang (`#!/bin/bash`), set flags, quoting (single vs double), indentation (2 spaces, no tabs), comments (file header, function, implementation), control flow and case style, local variables, checking return values, errors to STDERR, line length (80 chars), and function naming. Often cited by other style guides and tools.

2. **Baeldung: Bash shebang lines**  
   https://www.baeldung.com/linux/bash-shebang-lines  
   Compares `#!/usr/bin/bash` and `#!/usr/bin/env bash`. Explains that the former is more secure and explicit; the latter is more portable because it uses PATH to find the interpreter. Recommends `#!/usr/bin/env bash` for portability and `#!/usr/bin/bash` when security is the priority.

3. **Stack Overflow: Why is #!/usr/bin/env bash superior to #!/bin/bash?**  
   https://stackoverflow.com/questions/21612980/why-is-usr-bin-env-bash-superior-to-bin-bash  
   Community summary: `env` finds the interpreter via PATH, so the same script works when bash is installed in different locations (e.g. macOS Homebrew, Linux, version managers). `/bin/bash` is fixed and can be wrong or missing on some systems.

4. **DevOps Daily: Preferred Bash shebang**  
   https://devops-daily.com/posts/preferred-bash-shebang  
   Short note on shebang choice; favors `#!/usr/bin/env bash` for portability in cross-environment scripts.

5. **POSIX (Shell Command Language, env)**  
   https://pubs.opengroup.org/onlinepubs/9699919799/utilities/env.html  
   POSIX does not standardize the shebang line. The `env` utility is specified to be in the PATH and is commonly installed at `/usr/bin/env`; using `#!/usr/bin/env interpreter` is the portable way to run an interpreter that may be in different locations on different systems.
