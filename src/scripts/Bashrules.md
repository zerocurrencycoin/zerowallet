# Bash Script Conventions

Zerowallet script conventions: the build helpers, packaging, and libsodium, on top of the shared Zero shell rules.

---

## Shared rules

Shell scripts follow the rules shared by every Zero repository, kept in the Zero repository, `CONTRIBUTING.md`, section "Shell scripts"; that section is authoritative, and this file does not restate or change it. The shared helper here is `src/scripts/fbuild.sh`, which sources `fmessage.sh`, identical to Zero's `zcutil/fmessage.sh`.

---

## zerowallet Build Infrastructure

### fbuild.sh and fmessage.sh

`fmessage.sh` provides messaging only (err, warn, notice, step_done). `fbuild.sh` sources it and adds build context (REPO_ROOT, resolve_qt, etc.). Scripts needing only messaging (e.g. install_mxe, wrappers) source fmessage.sh; scripts needing build context source fbuild.

Use `fbuild.sh` as the shared build library. It provides:

- **Logging:** `err`, `warn`, `notice`, `step_done`, `section`. `init_logging` tees all output to the log with `tee -a`, so `-L`/`--log` **appends**. Do not truncate at start.
- **Build:** `build_fail`, `analyze_build_log`
- **Args:** `parse_mkdev_args`, `parse_mkrelease_args`
- **Resolution:** `resolve_zero_dir`, `resolve_qt`, `resolve_path_win`
- **Version:** `resolve_version`, `get_app_from_h`, `write_version_h`
- **Globals:** `SCRIPT_DIR`, `REPO_ROOT`, `JOBS`

**Sourcing:** Use `"$(dirname "${BASH_SOURCE[0]}")/fbuild.sh"` so the script works when invoked by path or from another directory.

### Path resolution

- **src/scripts:** `SCRIPT_DIR` = own dir, `REPO_ROOT` = `SCRIPT_DIR/../..`
- **res/libsodium:** Scripts derive `REPO_ROOT` from their location and source `$REPO_ROOT/res/libsodium/fbuild-libsodium.sh` (which sources fbuild.sh).

### Build patterns

**Parallel jobs:** `make -j"${JOBS:-2}"`, with `JOBS` from `fbuild.sh`.

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

**DMG on macOS only:** `hdiutil` is macOS-only. Linux has no built-in DMG mount; 7z/dmg2img would add deps. Verifying DMG on macOS suffices for release checks.

---

## libsodium

**Scripts:** `res/libsodium/buildlibsodium.sh` (Unix). `res/libsodium/buildlibsodium-win.sh` (Windows target; runs on Linux, MXE cross-compile).

**Windows build:** When `buildlibsodium-win.sh` is invoked from `mkrelease-win.sh`, `resolve_path_win` has already run and prepended `MXE_PATH` to `PATH`. The libsodium script inherits that environment; `command -v x86_64-w64-mingw32.static-gcc` finds the tool. Callers must run `resolve_path_win` (or `resolve_qt win`) before `buildlibsodium-win.sh`.

### Naming

| Platform | Link flag | File name | Notes |
|----------|-----------|-----------|-------|
| Unix | `-lsodium` | `libsodium.a` | Standard: `lib` + name + `.a` |
| MinGW | `-llibsodium` | `liblibsodium.a` | MinGW adds `lib` prefix; library name is `libsodium` |

**Why `liblibsodium.a`?** GNU linker: `-lX` looks for `libX.a`. So `-llibsodium` -> `liblibsodium.a`. Build produces `libsodium.a`; we copy to `liblibsodium.a` for the linker. See `zero-qt-wallet.pro` and BUILD.md.

### Download sources

**Browse:** [download.libsodium.org/libsodium/releases/](https://download.libsodium.org/libsodium/releases/), [GitHub releases](https://github.com/jedisct1/libsodium/releases) ([jedisct1](https://github.com/jedisct1)).

**Default URL:** `fbuild-libsodium.sh` uses GitHub. Override `LIBSODIUM_URL` before sourcing for alternate mirror. Do not claim "same tarball, different mirrors" unless checksums are verified.

### ZERO_DEPENDS

Not supported: each build downloads and builds libsodium.

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
