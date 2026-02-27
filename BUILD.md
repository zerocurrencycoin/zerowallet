# Build and Release Guide

Build and release workflow for zerowallet. Supports local builds, with [GitHub Actions](.github/workflows/) on the roadmap. Platforms: Linux, macOS, Windows.

## Status

| Platform | Dev | Release | Notes |
|----------|-----|---------|-------|
| Linux | ✓ | ✓ | Static Qt via `build-qt-static.sh`; GCC 13+ needs [patch](#gcc-13-linux-static-qt) |
| macOS | ✓ | ✓ | Homebrew Qt |
| Windows | ✓ | ✓ | MXE cross-build from Linux; host Qt for lrelease from `qt5-static/` |

## Quick Start

**System prerequisites:**

- **Linux:** `sudo apt install build-essential qtbase5-dev qtbase5-dev-tools libqt5websockets5-dev`
- **macOS:** `brew install create-dmg qt@5`
- **Windows:** Cross-build from Linux; see [Windows](#windows) below.

Build zerod in the Zero repo root, then run the platform mkrelease script. See [ZERO_DIR](#zero_dir), [Platform Notes](#platform-notes), and [Test sequence](#test-sequence).

---

## Dependencies

| Component | Version / Source | Notes |
|-----------|------------------|-------|
| Qt | 5.15.18 or later | See [Qt](#qt). |
| zerod | - | Built from [Zero](https://github.com/zerocurrencycoin/zero); Binaries in `ZERO_DIR` |
| libsodium | 1.0.21 | Built into `res/`; we maintain build scripts (see [libsodium](#libsodium-requirements-and-per-platform-review)) |
| nlohmann/json | 3.6.1 | Vendored in `src/3rdparty/` |
| SingleApplication | v3.5.4 Vendored | `singleapplication/`; single-instance |

Qt is the only versioned external dependency; others are vendored.

### Qt

One-time install per platform. Custom path via `-q` or `QT_PREFIX`, only when needed.

| Platform | Source | Install |
|----------|--------|---------|
| **Linux** | Static Qt 5.15.18+ from [Qt archives](https://download.qt.io/archive/qt/5.15/5.15.18/single/) | `./src/scripts/build-qt-static.sh` |
| **macOS** | Homebrew `qt@5` | `brew install qt@5`. Default: `$(brew --prefix qt@5)`. |
| **Windows** | MXE (cross-build) | See [Windows](#windows) below. |

#### GCC 13+ (Linux static Qt)

Qt 5.15.18's bundled mapbox-gl-native (qtlocation) fails with GCC 13+ due to missing `#include <cstdint>` in three files. We provide `res/patches/qt-gcc13.diff`; `build-qt-static.sh` applies it after extract, before configure. On patch failure, the script errors with script path, patch path, and this section.

**Files modified:** `qtlocation/src/3rdparty/mapbox-gl-native/` — geometry.hpp, string.hpp, stencil_mode.hpp.

**References (publicly identified):**
- [Gentoo #885431](https://bugs.gentoo.org/show_bug.cgi?id=885431)
- [Debian gcc_13.diff](https://sources.debian.org/src/qtlocation-opensource-src/5.15.17+dfsg-3/debian/patches/gcc_13.diff)
- [mapbox-gl-native PR #16669](https://github.com/mapbox/mapbox-gl-native/pull/16669)

---

## Script Reference

### src/scripts inventory

| File | Purpose |
|------|---------|
| `fbuild.sh` | Shared build helpers: paths, logging, log_capture, build_fail, resolve_zero_dir, detect_mxe, resolve_qt, version helpers, parse_mkdev_args |
| `mkdev.sh` | Wrapper: runs mkdev-linux, mkdev-mac, or mkdev-win per platform |
| `mkdev-linux.sh` | Linux dev build. Output: `zerowallet`. See [mkdev options](#script-argument-lists). |
| `mkdev-mac.sh` | macOS dev build. Output: `zerowallet.app`. See [mkdev options](#script-argument-lists). |
| `mkdev-win.sh` | Linux→Win dev (MXE). Output: `debug/` or `release/zerowallet.exe`. See [mkdev options](#script-argument-lists). |
| `mkrelease.sh` | Wrapper: runs mkrelease-linux, mkrelease-mac, or mkrelease-win per platform |
| `mkrelease-linux.sh` | Linux release. Output: `artifacts/linux-zerowallet-vX.Y.Z.tar.gz`, `.deb`. See [mkrelease options](#script-argument-lists). |
| `mkrelease-mac.sh` | macOS release. Output: `artifacts/macOS-zerowallet-vX.Y.Z.dmg`. See [mkrelease options](#script-argument-lists). |
| `mkrelease-win.sh` | Linux→Win release (MXE). Output: `artifacts/Windows-zerowallet-vX.Y.Z.zip`. See [mkrelease options](#script-argument-lists). |
| `build-qt-static.sh` | Linux: static Qt in `qt5-static/` (one-time). Skips if `qt5-static/bin/qmake` exists. No args; uses `QT_PREFIX` env. |
| `dotranslations.sh` | Compile .ts→.qm (lrelease), merge Qt base (lconvert). Called by mkrelease; `DOTRANSLATIONS_SKIP=1` or mkrelease `-t` to skip. |
| `install_mxe.sh` | MXE: `--install` (default), `--deps`, `--check`. See [install_mxe options](#script-argument-lists). |
| `signbinaries.sh` | GPG signatures and sha256sums. See [signbinaries options](#script-argument-lists). |
| `package-verify.sh` | Verify release packages. See [package-verify options](#script-argument-lists). |
| `control` | Debian package control template |
| `desktopentry` | Desktop entry for Linux .deb |


### res/ scripts

| File | Purpose |
|------|---------|
| `res/mkicns-mac.sh` | Build macOS .icns from SVG. `[INKSCAPE] [SVG_PATH] [OUT_BASE]`; defaults: inkscape, logo.svg, logo |
| `res/mkico.sh` | Build Windows .ico from SVG. `[SVG_PATH] [ICO_OUT]`; defaults: logo.svg, icon.ico |
| `res/libsodium/fbuild-libsodium.sh` | Shared libsodium config; sources fbuild.sh |
| `res/libsodium/buildlibsodium.sh` | Unix (Linux, macOS) libsodium build |
| `res/libsodium/buildlibsodium-win.sh` | Windows target libsodium build (runs on Linux, MXE) |


### Script summary

| Script | Platform | Output |
|--------|----------|--------|
| `mkdev.sh` | default | Wrapper |
| `mkdev-linux.sh` | Linux | `zerowallet` |
| `mkdev-mac.sh` | macOS | `zerowallet.app` |
| `mkdev-win.sh` | Windows | `debug/zerowallet.exe` or `release/zerowallet.exe` |
| `mkrelease.sh` | default | Wrapper |
| `mkrelease-linux.sh` | Linux | `artifacts/*.tar.gz`, `artifacts/*.deb` |
| `mkrelease-mac.sh` | macOS | `artifacts/*.dmg` |
| `mkrelease-win.sh` | Windows | `artifacts/*.zip` |
| `build-qt-static.sh` | Linux | `qt5-static/` |
| `signbinaries.sh` | any | GPG signatures |

### Script argument lists

**Both mkdev and mkrelease** (alphabetically):

| Option | Description |
|--------|--------------|
| `-h`, `--help` | Show help |
| `-j N`, `--jobs N` | Parallel jobs |
| `-L`, `-L=PATH`, `--log`, `--log=PATH` | Capture log (default: `logs/mkdev-<platform>.log` or `logs/mkrelease-<platform>.log`) |
| `-m`, `--mxe PATH` | MXE usr/bin (Windows target, Linux host) |
| `-q`, `--qt PATH` | Qt prefix |

**mkdev only** (alphabetically):

| Option | Description |
|--------|--------------|
| `-c`, `--clean` | Force clean/distclean before build (default: incremental) |
| `-r`, `--release` | CONFIG+=release (default: debug) |
| `-R`, `--run` | Launch binary after build |

**mkrelease only** (alphabetically):

| Option | Description |
|--------|--------------|
| `-p`, `--prev V` | PREV_VERSION (default: from version.h or git) |
| `-t`, `--tran` | Skip translations |
| `-v`, `--version V` | APP_VERSION (X.Y.Z) |
| `-z`, `--zero PATH` | Zero src dir (zerod, zero-cli) |

**Other scripts** (alphabetically by script):

| Script | Options |
|--------|---------|
| `install_mxe.sh` | `-c`, `--check`; `-d`, `--deps`; `-i`, `--install` (default) |
| `package-verify.sh` | `-l`, `--linux PATH`; `-m`, `--mac PATH`; `-t`, `--test`; `-v`, `--version V`; `-w`, `--windows PATH` |
| `res/mkicns-mac.sh` | `[INKSCAPE] [SVG_PATH] [OUT_BASE]` (positional; defaults: inkscape, logo.svg, logo) |
| `res/mkico.sh` | `[SVG_PATH] [ICO_OUT]` (positional; defaults: logo.svg, icon.ico) |
| `signbinaries.sh` | `-v`, `--version V` |

---

### Unified Arguments

| Flag | Env | Default | Description |
|------|-----|---------|-------------|
| `-z`, `--zero` | `ZERO_DIR` | `../Zero/src` or `../ZeroLinux/src`/`../ZeroWin/src` if absent | Directory with zerod binaries; see [ZERO_DIR](#zero_dir) below |
| `-v`, `--version` | `APP_VERSION` | from `src/version.h` | Release version. See [APP_VERSION](#app_version) below. |
| `-p`, `--prev` | `PREV_VERSION` | patch−1 of APP_VERSION | Previous version for sed. See [PREV](#prev) below. |
| `-q`, `--qt` | `QT_PREFIX` | `./qt5-static/` (repo root) | Qt install prefix. Precedence: command line > env > default. Linux dev: default to system qmake if unset. mkrelease-win: host Qt for dotranslations. Use our default (`./qt5-static/`), not system paths. |
| `-m`, `--mxe` | `MXE_PATH` | auto-detect | MXE `usr/bin` path (Windows only). Precedence: **command line** > **env** > both tools in PATH > probe. Probe failure: err and exit. `-m` expects bin dir. |
| `-t`, `--tran` | `DOTRANSLATIONS_SKIP` | — | Turn translations off; skip lrelease. Use prior .qm if fresh. (mkrelease only) |

### APP_VERSION / PREV_VERSION

Both from `src/version.h` and git tag (supports `vN.N.N` or `N.N.N`). Logic:
- **APP_H** = `#define APP_VERSION "X.Y.Z"` (strict)
- **GIT_V** = latest `git describe --tags --abbrev=0` (strip `v`)
- If APP_H == GIT_V: .h not updated → `-p` = GIT_V, `-v` = patch+1
- If APP_H ≠ GIT_V: .h updated → `-v` = APP_H, `-p` = patch−1 of APP_H
- Bad format / missing: `SCRIPT: ERROR: ...` to stderr, exit 1. All scripts use `fbuild.sh`: err, warn, info, notice.

### ZERO_DIR

Directory containing built `zerod` and `zero-cli` (or `.exe` on Windows). A given repo builds either Linux or Windows, not both; do not build different platforms in the same directory. Default `../Zero`; if absent, Linux scripts use `../ZeroLinux`, Windows scripts use `../ZeroWin`. Binaries in `src/` subdir. Override with `-z` or `ZERO_DIR`. Stripping: Linux and Windows scripts strip binaries before packaging; macOS not stripped.

### PREV

Used by `sed` to replace the previous version in `zero-qt-wallet.pro`, `README.md`, and (Linux) `src/scripts/control`. See [APP_VERSION](#app_version) for default logic. macOS: `mkrelease-mac.sh` reads `version.h` only for DMG name.

### Jobs (-j)

`JOBS` = hw.ncpu or 2; `-j$JOBS`. Only `-jN` or `-j N`: `-j4` → `JOBS="${1#-j}"` (strip `-j` prefix); `-j 4` → `JOBS="$2"`. `fbuild.sh` sets `JOBS` (Linux: nproc, macOS: sysctl hw.ncpu, fallback: 2).

### Log capture and failure analysis

mkdev scripts support `-L` or `-L=path` to capture build output. Default: `logs/mkdev-<platform>.log`. On build failure, `build_fail` / `analyze_build_log` prints errors and warnings from the log. Shared: `src/scripts/fbuild.sh`.

### Qt prefix (-q) and system paths

Default `./qt5-static/` uses a single-prefix layout (`bin/`, `translations/`, `lib/` under one tree). System Qt (e.g. Debian `qtbase5-dev`) uses a split layout: binaries in `/usr/bin/`, translations in `/usr/share/qt5/translations/`. Scripts expect `$QT_PREFIX/bin/lrelease` and `$QT_PREFIX/translations/qtbase_*.qm`.

| Script | `-q /usr` works? | Reason |
|--------|------------------|--------|
| mkrelease-win | ✓ | Host Qt only for lrelease; `/usr/bin/lrelease` exists. Qt base merge skipped (no `/usr/translations/`). |
| mkdev-linux | ✓ | Dev build; dynamic linking OK. |
| mkrelease-linux | ✗ | Release requires static Qt; `ldd` check fails on dynamic build. |

Use `./qt5-static/` (our default) for mkrelease-linux and when Qt base translation merge is needed.

---

## Test sequence

**Setup:** Linux host. Current dir = zerowallet repo. For Windows target: `../ZeroWin/src` (zerod.exe, zero-cli.exe). Wine for Phase 5 smoke test: `sudo apt install wine`.

### Phase 1: Static (no deps, ~30 s)

| Step | Command |
|------|---------|
| 1.1 | `shellcheck -s bash src/scripts/*.sh res/libsodium/*.sh` |
| 1.2 | `./src/scripts/mkdev-linux.sh -h` |
| 1.3 | `./src/scripts/mkrelease-linux.sh -h` |
| 1.4 | `./src/scripts/install_mxe.sh -c` |
| 1.5 | `./src/scripts/package-verify.sh -t` |

### Phase 2: Option parsing

| Step | Command |
|------|---------|
| 2.1 | `./src/scripts/mkdev-linux.sh -j 2 -L -c -r -h` |
| 2.2 | `./src/scripts/mkrelease-linux.sh -z ../ZeroWin/src -h` |

### Phase 3: Linux dev build

| Step | Command |
|------|---------|
| 3.1 | `./src/scripts/mkdev-linux.sh` |
| 3.2 | `./zerowallet --help` |
| 3.3 | `./src/scripts/mkdev-linux.sh -c` (clean + rebuild) |
| 3.4 | `./src/scripts/mkdev-linux.sh -L` (with log capture) |

### Phase 4: Windows dev (MXE required)

| Step | Command |
|------|---------|
| 4.1 | `./src/scripts/mkdev-win.sh -h` |
| 4.2 | `./src/scripts/mkdev-win.sh` |

### Phase 5: Release (full deps)

| Step | Command |
|------|---------|
| 5.1 | `./src/scripts/build-qt-static.sh` (one-time; skips if `qt5-static/bin/qmake` exists) |
| 5.2 | `./src/scripts/mkrelease-linux.sh -z ../Zero/src` (Linux release; zerod in ../Zero) |
| 5.3 | `./src/scripts/mkrelease-win.sh -z ../ZeroWin/src` (Windows release) |
| 5.4 | `wine release/zerowallet.exe --help` (Wine smoke test on Linux) |
| 5.5 | `./src/scripts/package-verify.sh -v X.Y.Z` |
| 5.6 | `./src/scripts/signbinaries.sh -v X.Y.Z` |

### Phase 6: macOS (on macOS only)

| Step | Command |
|------|---------|
| 6.1 | `./src/scripts/mkdev-mac.sh -h` |
| 6.2 | `./src/scripts/mkdev-mac.sh` |
| 6.3 | `./src/scripts/mkrelease-mac.sh -v X.Y.Z` |

### One-liner (Phase 1+2)

```bash
shellcheck -s bash src/scripts/*.sh res/libsodium/*.sh && \
./src/scripts/mkdev-linux.sh -h && ./src/scripts/mkrelease-linux.sh -h && \
./src/scripts/install_mxe.sh -c && ./src/scripts/package-verify.sh -t
```

---

## Platform Notes

### Linux

**Dev build:** `./src/scripts/mkdev.sh` or `./src/scripts/mkdev-linux.sh`. Options: `-r` release config, `-j N` jobs, `-L` or `-L=path` capture log to `logs/mkdev-linux.log`. On failure with `-L`, run `analyze_build_log` (errors/warnings). Output: `zerowallet`.

**Release build (local):**

1. Build static Qt (one-time, ~30–60 min): `./src/scripts/build-qt-static.sh`. Output: `qt5-static/` in repo root. **Skips rebuild:** if `qt5-static/bin/qmake` exists, the script exits immediately. Keep `qt5-static/` to avoid re-running the long build.

   **GCC 13+:** If the build fails at qtlocation with `FeatureType` or `uint8_t` errors, see [GCC 13+ (Linux static Qt)](#gcc-13-linux-static-qt).
2. Build zerod: `cd ../Zero && ./zcutil/build.sh -j$(nproc)`.
3. Run mkrelease (defaults: `-v` from `src/version.h`, `-p` = patch−1, `-q` = `./qt5-static/` as QT_PREFIX):

```bash
./src/scripts/mkrelease.sh
# or directly:
./src/scripts/mkrelease-linux.sh
```

### macOS

**Dev build:** `./src/scripts/mkdev-mac.sh`. Uses Homebrew Qt. Options: `-r` `-j N` `-L`. Output: `zerowallet.app` → `open zerowallet.app`.

**Release prerequisites:** `brew install create-dmg qt@5`. zerod built in Zero repo. Default `ZERO_DIR=../Zero/src`; override with `-z` when Zero is elsewhere.

**Tooling:** Qt from Homebrew (`$(brew --prefix qt@5)`). `macdeployqt` copies Qt frameworks/plugins into the app bundle. `create-dmg` builds the DMG. `codesign` signs the app (ad-hoc or Developer ID). `xcrun notarytool` and `xcrun stapler` for notarization.

---

**1. Dev build**

For development. Produces `zerowallet.app` with symlinks to Homebrew Qt; not standalone. Run from build dir.

```bash
make distclean && make
./zerowallet.app/Contents/MacOS/zerowallet
```

Test a Release build (`artifacts/ZeroWallet.app` or DMG) for standalone verification.

---

**2. Release (ad-hoc signing)**

For distribution without notarization. Script: clean → qmake → make → copy zerod/zero-cli into app → macdeployqt → codesign (ad-hoc) → create-dmg. Ad-hoc uses `CODESIGN_IDENTITY=-` or unset.

```bash
./src/scripts/mkrelease-mac.sh -v X.Y.Z
```

Output: `artifacts/macOS-zerowallet-vX.Y.Z.dmg`, `artifacts/ZeroWallet.app`.

**Test before distribute:**
```bash
hdiutil attach artifacts/macOS-zerowallet-vX.Y.Z.dmg -nobrowse -quiet
codesign -dv --verbose=2 "/Volumes/ZeroWallet-vX.Y.Z/ZeroWallet.app"
open "/Volumes/ZeroWallet-vX.Y.Z/ZeroWallet.app"
# If Gatekeeper blocks: right-click → Open. Drag to Applications, verify.
hdiutil detach "/Volumes/ZeroWallet-vX.Y.Z"
```

**User install:** Mount DMG → drag app to Applications → if blocked, right-click → Open.

---

**3. Developer ID + notarization**

For distribution that passes Gatekeeper without user override. Requires Apple Developer account.

**Build and sign:**
```bash
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
./src/scripts/mkrelease-mac.sh -v X.Y.Z
```

**Notarize:**
```bash
# One-time: create keychain profile (app-specific password from appleid.apple.com)
xcrun notarytool store-credentials --apple-id <email> --team-id <id> --password <app-specific-password>

# Submit, wait for approval, staple
xcrun notarytool submit artifacts/macOS-zerowallet-vX.Y.Z.dmg --keychain-profile <profile>
# ... wait ...
xcrun stapler staple artifacts/macOS-zerowallet-vX.Y.Z.dmg
```

**User install:** Mount DMG → drag to Applications. No Gatekeeper override needed.

[Notarizing](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution) · [Developer ID](https://developer.apple.com/developer-id/) · [Gatekeeper](https://developer.apple.com/documentation/security/gatekeeper_and_notarization)

### Windows

**Dev build (cross from Linux):** `./src/scripts/mkdev-win.sh`. Requires [MXE](#mxe) with qtbase, qtwebsockets. Options: `-L` `-m PATH` `-r` release config. Default: CONFIG+=debug (like mkdev-linux/mac). Output: `debug/zerowallet.exe` or `release/zerowallet.exe` (-r).

**Release:** Cross-build from Linux or WSL. Build zerod for Windows: `cd ../ZeroWin && ./zcutil/build-win.sh`. Minimal: `./src/scripts/mkrelease-win.sh -z ../ZeroWin/src`. Host Qt for lrelease: default `./qt5-static/`; override with `-q ./qt5-static` when needed (use our default, not system paths). Override with `-z`, `-v`, `-p`, `-m`, `-q` as needed.

**Test setup (Linux host, Windows target):** Current dir = zerowallet repo. Node binaries: `../ZeroWin/src` (zerod.exe, zero-cli.exe). Test with Wine: `wine debug/zerowallet.exe --help` or `wine release/zerowallet.exe --help`.

#### MXE

MXE (M Cross Environment) for MinGW + static Qt. Build from source only; we do not use prebuilt packages with stale dist support. **MXE precedence:** command line (`-m`/`--mxe`) > environment (`MXE_PATH`) > both tools in PATH > probe (`$HOME/mxe/usr/bin`, `/opt/mxe/usr/bin`). Detection requires both `x86_64-w64-mingw32.static-gcc` (libsodium, wallet) and `x86_64-w64-mingw32.static-qmake-qt5` (wallet). Both `mkdev-win.sh` and `mkrelease-win.sh` use this strategy. Design: `MXE_ROOT=~/mxe`, `MXE_PATH=$MXE_ROOT/usr/bin`; `-m` expects `usr/bin` path.

| Path | Source |
|------|--------|
| `$HOME/mxe/usr/bin` | User build-from-source (default) |
| `/opt/mxe/usr/bin` | System build-from-source ([FHS 3.0 §3.13](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/ch03s13.html): /opt for add-on software) |

**Build from source:** `./src/scripts/install_mxe.sh` (default = full install: deps + clone + make; ~1h+). Or `--deps` for apt only. System-wide: `MXE_ROOT=/opt/mxe ./src/scripts/install_mxe.sh`.

**Project files:** `zero-qt-wallet.pro` is the main project file (Linux, macOS). For MinGW cross-build, scripts generate `zero-qt-wallet-mingw.pro` by stripping precompiled headers (PCH); PCH often causes issues with MinGW cross-compilation. The mingw file is generated on the fly and gitignored.

---

## Signing

### GPG (all platforms)

Run `./src/scripts/signbinaries.sh -v X.Y.Z`; produces `sha256sum-vX.Y.Z.txt` and `*.sig` in `artifacts/`, packaged as `signatures-vX.Y.Z.zip`. Verification: `sha256sum -c sha256sum-vX.Y.Z.txt`; `gpg --verify <file.sig> <file>`. Import key from `public_key.asc` on GitHub. See `res/SIGNATURES_README`.

---

## CI (GitHub Actions)

Workflows [Zero Wallet Linux](.github/workflows/Zero%20Wallet%20Linux.yml) and [Zero Wallet Windows](.github/workflows/Zero%20Wallet%20Windows.yml). **Status: tentative until verified.** Clone Zero, build zerod, run mkrelease scripts, upload artifacts. Update `APP_VERSION` and `PREV_VERSION` in workflow `env` when cutting releases.

**Planned:** Use `build-qt-static.sh` and `install_mxe.sh --check` in CI; add macOS job. Document workflow steps in BUILD.md.

---

## Development

### Script quality

**Bash options:** Scripts use `set -e -u -o pipefail` (exit on error, error on unset var, fail pipeline on any error). CI improvements deferred.

**ShellCheck:** Run `shellcheck src/scripts/*.sh res/**/*.sh` during development to catch quoting, unset vars, logic errors. Not in CI yet.

### Version mismatch

If `src/version.h` does not contain `APP_VERSION`, mkrelease scripts warn (mismatch may be intentional).

### mkdev options

`-h` / `--help` shows usage. `--run` after build: Linux/macOS launch binary; Windows runs `wine ... --help` if wine installed (smoke test). `-c`/`--clean` forces clean/distclean before build (default: incremental; no exit).

### clean vs distclean

| Target | Effect |
|--------|--------|
| `make clean` | Removes object files and executables; keeps Makefile |
| `make distclean` | Also removes Makefile, .qmake.stash; requires `qmake` before next build |

**mkdev:** Linux/mac use `distclean` when `-c`; Windows uses `make clean` plus manual removal of `debug/`, `release/`, `zero-qt-wallet-mingw.pro`, `Makefile` (mingw layout differs). **mkrelease:** Always does full clean (distclean + rm artifacts) before build.

---

## Wine (Windows testing on Linux)

[Wine](https://www.winehq.org/) runs Windows binaries on Linux. After cross-building: `wine debug/zerowallet.exe --help` (or `release/zerowallet.exe`) to verify the binary. Install: `sudo apt install wine`. Wine translates Win32 API calls; useful for quick smoke tests without a Windows VM.

---

## libsodium: Requirements and per-platform review

**Vendored:** We do not commit libsodium source; we download at build time and produce static `.a` in `res/`. We create and maintain the build scripts. Directory structure:

```
res/
├── libsodium.a          # Unix (Linux, macOS)
├── libsodiumd.a         # Windows debug (copy of libsodium.a)
├── liblibsodium.a       # MinGW linker naming
├── liblibsodiumd.a      # MinGW debug
└── libsodium/
    ├── buildlibsodium.sh      # Unix (Linux, macOS)
    ├── buildlibsodium-win.sh  # Windows target (runs on Linux, MXE)
    └── libsodium-${VER}/     # extracted source (Unix and Windows)
```

### Requirements

- **Version:** 1.0.21 (matches Zero depends)
- **Output:** Static `.a` in `res/` (all platforms)
- **Consumers:** qmake links wallet; Zero builds zerod separately
- **Paths:** All under `res/` from repo root. Unix: `res/libsodium.a`. Windows target (build on Linux): same base `libsodium.a` plus `libsodiumd.a`, `liblibsodium.a`, `liblibsodiumd.a` (MinGW linker naming; symlinks to same file)

### Per-platform circumstances

**Linux, macOS:** `res/libsodium/buildlibsodium.sh`

- Invoked by: qmake (libsodium target), mkdev-linux/mac, mkrelease-linux/mac
- Outputs: libsodium.a

**Windows target (runs on Linux):** `res/libsodium/buildlibsodium-win.sh`

- Cross-compile from Linux via MXE; produces MinGW static libs for Windows
- Invoked by: mkdev-win, mkrelease-win (not qmake)
- Outputs: libsodium.a, libsodiumd.a, liblibsodium.a, liblibsodiumd.a

### Current trouble

- **Two scripts:** buildlibsodium.sh (Unix) vs buildlibsodium-win.sh (Windows). Different layout, different artifact names.
- **qmake mismatch:** .pro references buildlibsodium.sh; Windows builds run buildlibsodium-win.sh manually before qmake.
- **Source layout:** Both use `res/libsodium/libsodium-${VER}/`.
- **ZERO_DEPENDS:** Dropped (agreed). Download and build each time.

### Derived solution (current)

**1. Keep separate scripts** — `buildlibsodium.sh` (Unix) and `buildlibsodium-win.sh` (Windows target, runs on Linux)

- Different toolchains: native vs MXE
- Different artifact names: libsodium.a vs liblibsodium.a
- Merging would add platform conditionals and complexity

**2. Keep fbuild-libsodium.sh** — shared version/URL (renamed from libsodium-common.sh)

- Single source of truth; both scripts source it
- Avoids version drift
- **fbuild overlap:** fbuild-libsodium.sh sources fbuild.sh (provides err, notice). Build scripts source only fbuild-libsodium.sh. Overlap is minimal (err only). Pushing libsodium logic into fbuild would pollute it with libsodium specifics. Keep separate.

**3. ZERO_DEPENDS** — limited; full solution deferred

- **Current scope:** Only when Zero is built *first*; copy from Zero's depends. One-way. Does not handle: zerowallet built first, or future rebuilds of either.
- **Full solution (deferred):** Dependency cache — either build order, rebuilds of Zero or zerowallet, shared across both. See § Shared dependency cache.
- Windows implemented; Unix would need host triplet mapping; low priority

**4. Document script roles**

- buildlibsodium-win.sh for Windows; buildlibsodium.sh for Linux/macOS
- qmake libsodium target runs buildlibsodium.sh (Unix only)
- mkrelease-win/mkdev-win invoke buildlibsodium-win.sh explicitly

**5. No change to qmake**

- .pro expects libsodium.a for Unix; Windows build scripts pre-populate liblibsodium.a before qmake
- Changing .pro to platform-specific commands adds fragility for little gain

### Pro/con: ZERO_DEPENDS, separate scripts, common script

| Topic | Pro | Con |
|-------|-----|-----|
| **ZERO_DEPENDS** | Saves ~2–3 min when Zero built first; CI-friendly | One-way only (Zero first); no rebuild handling; Windows only; host triplet hardcoded |
| **Keep separate build scripts** | Different toolchains justify it; clear platform ownership | Two scripts to maintain; qmake references Unix script only |
| **Push more into fbuild-libsodium.sh** | Single source for version, URL, download; less drift | fbuild-libsodium already minimal; build logic (configure, make, copy) is platform-specific; merging would add conditionals |

**Agreed:** Drop ZERO_DEPENDS; minimize buildlibsodium differences; keep fbuild-libsodium.sh for shared logic.

### Simplify: drop ZERO_DEPENDS, download and build each time?

| Approach | Pro | Con |
|----------|-----|-----|
| **Keep ZERO_DEPENDS** | Saves ~2–3 min when Zero built first | One-way only; no rebuild handling; Windows-only; extra complexity |
| **Drop it; build each time** | Simpler; no cross-repo coupling; works in any order | ~2–3 min per libsodium build; duplicate when Zero + zerowallet both built |

**Assessment:** For per-platform repos (zerowalletlinux, zerowalletwin) that build independently, "download and build each time" is simpler and sufficient. ZERO_DEPENDS mainly helps CI that builds Zero then zerowallet in sequence. If we eliminate it, we remove the only cross-repo dependency.

### Without ZERO_DEPENDS: how different would the two scripts be?

If we push all shared logic into fbuild-libsodium.sh (download, extract, configure, make, copy), the remaining platform differences:

| Aspect | Unix | Windows |
|--------|------|---------|
| Extract dir | `libsodium-${VER}/` | `libsodium-${VER}/` |
| Configure | `./configure` | `--host=x86_64-w64-mingw32 CC=... CXX=...` (Windows target, Linux host) |
| Make | `make` (maybe darwin CFLAGS) | `make` |
| Artifacts | Copy `libsodium.a` → `res/` | Copy `libsodium.a` → `res/`, symlink to libsodiumd.a, liblibsodium.a, liblibsodiumd.a |

**Result:** ~15–20 lines of platform-specific logic. Could become one script with `case $(uname -s)` / `$HOST` or two thin wrappers calling shared functions. The toolchain (native vs MXE) and artifact naming (MinGW) are the real differences; the build flow is the same.

### Agreed design

- **REPO_ROOT / script paths:** Each script type resolves paths for its location. `src/scripts` scripts use `SCRIPT_DIR` and `REPO_ROOT` from fbuild. `res/libsodium` scripts derive `REPO_ROOT` from their location and source `$REPO_ROOT/res/libsodium/fbuild-libsodium.sh` (which sources fbuild.sh).
- **No _DEPENDS:** Drop ZERO_DEPENDS. Download and build each time. Simpler; no cross-repo coupling.
- **Minimal buildlibsodium differences:** Push shared logic into fbuild-libsodium.sh. Keep two thin scripts (Unix, Windows) with only toolchain and artifact-naming differences.

### Repo root and script locations

**Current:** Scripts in `res/libsodium/` source `$REPO_ROOT/res/libsodium/fbuild-libsodium.sh` (which sources fbuild.sh). Scripts in `src/scripts/` use `SCRIPT_DIR` and `REPO_ROOT` from fbuild.

---

## Shared dependency cache (Postponed)

**Status:** Design only; no implementation planned. Applies to libsodium, Boost, and Qt.

### Part 1: libsodium

#### Rationale

Today, libsodium is built separately by:

- **Zero** (via `depends/`) for zerod
- **zerowallet** (via `res/libsodium/`) for the wallet

Each build is per-repo, per-platform. Dev and release builds in zerowallet both trigger the same build; Zero and zerowallet never share. That leads to:

- Duplicate builds (Zero + zerowallet, dev + release)
- Extra CI time (~2–3 min per libsodium build)
- Repeated downloads and compile work when switching between Zero and zerowallet

A shared cache lets one build serve Zero, zerowallet, dev, and release, keyed by platform and version.

#### Differentiation

The cache must distinguish:

| Dimension | Values | Example |
|-----------|--------|---------|
| **Platform / host** | Linux, macOS, Windows (MXE) | `x86_64-pc-linux-gnu`, `x86_64-apple-darwin22`, `x86_64-w64-mingw32.static` |
| **Version** | libsodium release | `1.0.21` |

Different hosts produce different `.a` files; different versions must not be mixed.

#### Transparency via symlinks

Build systems (qmake, Zero depends) expect libsodium at fixed paths:

- zerowallet: `res/libsodium.a`, `res/liblibsodium.a`, etc.
- Zero: `depends/$(HOST)/lib/libsodium.a`

The cache should live elsewhere, but consumers should see the usual paths. Symlinks (or copies) in the repo can hide the real location.

#### Approaches

| Approach | Idea | Pros | Cons |
|----------|------|------|------|
| **External cache** | `$LIBSODIUM_CACHE/$VER/$HOST/`; build script checks, builds if missing, symlinks into `res/` | Single source of truth; Zero and zerowallet share | Zero depends not designed for external staging |
| **Zero depends as source** | Build Zero first; zerowallet `ZERO_DEPENDS` copies from Zero | No new cache; already implemented for Windows | Requires Zero built first; zerowallet-only still builds locally |
| **Symlinks from repo** | `res/libsodium.a` → symlink into cache | qmake unchanged | Symlinks in `res/`; Windows symlinks need admin/Developer Mode |
| **Copy instead of symlink** | Same as above but copy | No symlink quirks | Duplicate bytes; cache invalidation manual |

#### Recommended layout (for future use)

```
$LIBSODIUM_CACHE/
└── {version}/
    └── {host}/
        ├── libsodium.a
        ├── libsodiumd.a      # Windows debug (same as release for static)
        ├── liblibsodium.a    # MinGW naming
        └── liblibsodiumd.a
```

Host examples: Linux `x86_64-pc-linux-gnu`, macOS `x86_64-apple-darwin22` / `aarch64-apple-darwin22`, Windows `x86_64-w64-mingw32.static`. Env: `LIBSODIUM_CACHE` defaults to `~/.cache/zerowallet/libsodium` (or `$XDG_CACHE_HOME/zerowallet/libsodium`).

#### Why postpone (libsodium)

1. **Zero depends integration** – Zero’s depends system is self-contained. Teaching it to read/write an external cache would require changes to `depends/` and package rules.
2. **Platform matrix** – Host triplets differ (Zero vs zerowallet, Linux vs macOS). Mapping must be correct for all combinations.
3. **Windows symlinks** – Creating symlinks on Windows often needs elevated rights or Developer Mode; copies are simpler but lose sharing benefits.
4. **Current workaround** – `ZERO_DEPENDS` already avoids duplicate builds when Zero is built first. That covers the main multi-repo case.
5. **CI** – Setting `ZERO_DEPENDS` in workflows is a small change that saves time without a new cache layer.

#### ZERO_DEPENDS (dropped)

Previously: copy from Zero's depends when Zero built first. Dropped per agreed design. Download and build each time.

#### Future steps (libsodium, if implemented)

1. Add `LIBSODIUM_CACHE` support to `buildlibsodium.sh` and `buildlibsodium-win.sh`.
2. Implement “check cache → build if missing → symlink/copy into res/”.
3. Extend Zero depends (or a wrapper) to use the same cache.
4. Document `LIBSODIUM_CACHE` in this section.
5. Add CI use of `ZERO_DEPENDS` as an immediate, low-risk improvement.

---

### Part 2: Boost

**Scope:** Zero only. zerowallet does not use Boost.

#### Current state

- Zero builds Boost via `depends/` (e.g. `depends/x86_64-w64-mingw32/`).
- One configuration per host (release).
- No debug build; no sharing with zerowallet.

#### Similar issue

If Zero supported debug builds, depends would need separate trees (debug vs release) per host. No sharing between configs. Same pattern as libsodium: duplicate builds when iterating between debug and release.

#### Cache layout (hypothetical)

```
$BOOST_CACHE/
└── {version}/
    └── {host}/
        └── {debug|release}/
            └── lib/ include/
```

#### Why postpone

Zero's depends is release-only today. Debug support would require depends changes first. Lower priority than libsodium (Zero↔zerowallet sharing).

---

### Part 3: Qt

**Scope:** zerowallet only. Zero does not use Qt.

#### Current state

- **Linux:** `build-qt-static.sh` builds one static Qt (release) into `qt5-static/`. Shared across dev and release app builds.
- **Windows:** MXE builds static Qt (release). Same.
- **macOS:** Homebrew Qt shared.
- qmake puts app output in `debug/` or `release/`; Qt is not rebuilt when switching.

#### Similar issue

If both debug and release Qt were needed (e.g. debug Qt for stepping into framework code), two full Qt builds (~30–60 min each) with no shared cache. Today: single release Qt suffices.

#### Cache layout (hypothetical)

```
$QT_CACHE/
└── {version}/
    └── {host}/
        └── {debug|release}/
            └── bin/ lib/ include/ ...
```

#### Why postpone

Current setup builds Qt once per platform. Main gain would be sharing across machines (CI, dev boxes) or repos, not debug/release iteration.

---

### Part 4: Summary

| Dependency | Used by | Configs today | Sharing issue |
|------------|---------|---------------|---------------|
| libsodium | Zero, zerowallet | One per host | Zero + zerowallet duplicate; no cache |
| Boost | Zero | Release only | Would duplicate if debug added |
| Qt | zerowallet | Release only | Would duplicate if debug Qt needed |

**Common pattern:** External cache keyed by `{version}/{host}/{config}`; symlinks or copies hide location. All postponed.

