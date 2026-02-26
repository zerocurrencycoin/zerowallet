# Build and Release Guide

Build and release workflow for zerowallet. Supports local builds, with [GitHub Actions](.github/workflows/) on n the roadmap. Platforms: Linux, macOS, Windows.

## Quick Start

**System prerequisites:**

- **Linux:** `sudo apt install build-essential qtbase5-dev qtbase5-dev-tools libqt5websockets5-dev`
- **macOS:** `brew install create-dmg qt@5`
- **Windows:** Cross-build from Linux; see [Windows](#windows) below.

Build zerod in the Zero repo root, then run the platform mkrelease script. See [ZERO_DIR](#zero_dir) and [Platform Notes](#platform-notes).

---

## Dependencies

| Component | Version / Source | Notes |
|-----------|------------------|-------|
| Qt | 5.15.18 or later | See [Qt](#qt). |
| zerod | - | Built from [Zero](https://github.com/zerocurrencycoin/zero); Binaries in `ZERO_DIR` |
| libsodium | 1.0.21 | Vendored in `res/` |
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

---

## Script Reference

### src/scripts inventory

| File | Purpose |
|------|---------|
| `fbuild.sh` | Shared build helpers: paths, logging, log_capture, build_fail, resolve_zero_dir, detect_mxe, resolve_qt, version helpers, parse_mkdev_args |
| `mkdev.sh` | Wrapper: runs mkdev-linux, mkdev-mac, or mkdev-win per platform |
| `mkdev-linux.sh` | Linux dev build. Output: `zerowallet`. `-h` `-r` `-j N` `-L` `-q` `--run` `--clean` |
| `mkdev-mac.sh` | macOS dev build. Output: `zerowallet.app`. `-h` `-r` `-j N` `-L` `-q` `--run` `--clean` |
| `mkdev-win.sh` | Linux→Win dev (MXE). Output: `debug/` or `release/zerowallet.exe` (-r). `-h` `-L` `-m` `-r` `--run` `--clean` |
| `mkrelease.sh` | Wrapper: runs mkrelease-linux, mkrelease-mac, or mkrelease-win per platform |
| `mkrelease-linux.sh` | Linux release. Output: `artifacts/linux-zerowallet-vX.Y.Z.tar.gz`, `.deb` |
| `mkrelease-mac.sh` | macOS release. Output: `artifacts/macOS-zerowallet-vX.Y.Z.dmg` |
| `mkrelease-win.sh` | Linux→Win release (MXE). Output: `artifacts/Windows-zerowallet-vX.Y.Z.zip` |
| `mkrelease-linuxwin.sh` | Linux host only: Linux + Windows in one run. **Deprecated:** use mkrelease-linux and mkrelease-win separately. |
| `build-qt-static.sh` | Linux: static Qt in `qt5-static/` (one-time) |
| `dotranslations.sh` | Qt lrelease for translations (requires QT_PREFIX) |
| `install_mxe.sh` | MXE: default = full install; `--deps` apt only; `--check` verify. System-wide: `MXE_ROOT=/opt/mxe` |
| `signbinaries.sh` | GPG signatures and sha256sums. `-v X.Y.Z` |
| `control` | Debian package control template |
| `desktopentry` | Desktop entry for Linux .deb |


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
| `mkrelease-linuxwin.sh` | Linux+Win | Both (deprecated) |
| `build-qt-static.sh` | Linux | `qt5-static/` |
| `signbinaries.sh` | any | GPG signatures |

### Unified Arguments

| Flag | Env | Default | Description |
|------|-----|---------|-------------|
| `-z`, `--zero` | `ZERO_DIR` | `../Zero/src` or `../ZeroLinux/src`/`../ZeroWin/src` if absent | Directory with zerod binaries; see [ZERO_DIR](#zero_dir) below |
| `--zerolinux`, `--zerowin` | `ZERO_DIR_LINUX`, `ZERO_DIR_WIN` | — | (mkrelease-linuxwin only) Override Linux/Windows zerod dirs |
| `-v`, `--version` | `APP_VERSION` | from `src/version.h` | Release version. See [APP_VERSION](#app_version) below. |
| `-p`, `--prev` | `PREV_VERSION` | patch−1 of APP_VERSION | Previous version for sed. See [PREV](#prev) below. |
| `-q`, `--qt` | `QT_PREFIX` | `./qt5-static/` (repo root) | Qt install prefix |
| `-m`, `--mxe` | `MXE_PATH` | auto-detect | MXE `usr/bin` path (Windows only). `-m` expects bin dir. `MXE_ROOT` for install path (e.g. `/opt/mxe`). |

### APP_VERSION / PREV_VERSION

Both from `src/version.h` and git tag (supports `vN.N.N` or `N.N.N`). Logic:
- **APP_H** = `#define APP_VERSION "X.Y.Z"` (strict)
- **GIT_V** = latest `git describe --tags --abbrev=0` (strip `v`)
- If APP_H == GIT_V: .h not updated → `-p` = GIT_V, `-v` = patch+1
- If APP_H ≠ GIT_V: .h updated → `-v` = APP_H, `-p` = patch−1 of APP_H
- Bad format / missing: `SCRIPT: ERROR: ...` to stderr, exit 1. All scripts use `fbuild.sh`: err, warn, info, notice.

### ZERO_DIR

Directory containing built `zerod` and `zero-cli` (or `.exe` on Windows). A given repo builds either Linux or Windows, not both; do not build different platforms in the same directory. Default `../Zero`; if absent, Linux scripts use `../ZeroLinux`, Windows scripts use `../ZeroWin`. Binaries in `src/` subdir. Override with `-z` or `ZERO_DIR`. For mkrelease-linuxwin use `--zerolinux` and `--zerowin`. Stripping: Linux and Windows scripts strip binaries before packaging; macOS not stripped.

### PREV

Used by `sed` to replace the previous version in `zero-qt-wallet.pro`, `README.md`, and (Linux) `src/scripts/control`. See [APP_VERSION](#app_version) for default logic. macOS: `mkrelease-mac.sh` reads `version.h` only for DMG name.

### Jobs (-j)

`JOBS` = hw.ncpu or 2; `-j$JOBS`. Only `-jN` or `-j N`: `-j4` → `JOBS="${1#-j}"` (strip `-j` prefix); `-j 4` → `JOBS="$2"`. `fbuild.sh` sets `JOBS` (Linux: nproc, macOS: sysctl hw.ncpu, fallback: 2).

### Log capture and failure analysis

mkdev scripts support `-L` or `-L=path` to capture build output. Default: `logs/mkdev-<platform>.log`. On build failure, `build_fail` / `analyze_build_log` prints errors and warnings from the log. Shared: `src/scripts/fbuild.sh`.

---

## Platform Notes

### Linux

**Dev build:** `./src/scripts/mkdev.sh` or `./src/scripts/mkdev-linux.sh`. Options: `-r` release config, `-j N` jobs, `-L` or `-L=path` capture log to `logs/mkdev-linux.log`. On failure with `-L`, run `analyze_build_log` (errors/warnings). Output: `zerowallet`.

**Release build (local):**

1. Build static Qt (one-time, ~30–60 min): `./src/scripts/build-qt-static.sh`. Output: `qt5-static/` in repo root.
2. Build zerod: `cd ../Zero && ./zcutil/build.sh -j$(nproc)`.
3. Run mkrelease (defaults: `-v` from `src/version.h`, `-p` = patch−1, `-q` = `./qt5-static/` as QT_PREFIX):

```bash
./src/scripts/mkrelease.sh
# or directly:
./src/scripts/mkrelease-linux.sh
```

**mkrelease-linuxwin** (deprecated): Builds Linux and Windows in one run. Confusing: requires two Zero builds in separate dirs, inlines both phases instead of calling mkrelease-linux and mkrelease-win, and mixes platform-specific logic. Run `mkrelease-linux.sh` and `mkrelease-win.sh` separately.

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

**Release:** Cross-build from Linux or WSL. Build zerod: `cd ../Zero && ./zcutil/build-win.sh`. Minimal: `./src/scripts/mkrelease-win.sh`. Override with `-z`, `-v`, `-p`, `-m` as needed.

#### MXE

MXE (M Cross Environment) for MinGW + static Qt. Build from source only; we do not use prebuilt packages with stale dist support. Scripts auto-detect MXE in (first match): `$HOME/mxe/usr/bin`, `/opt/mxe/usr/bin`. Override with `-m` or `MXE_PATH`. Design: `MXE_ROOT=~/mxe`, `MXE_PATH=$MXE_ROOT/usr/bin`; `-m` expects `usr/bin` path.

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

`-h` / `--help` shows usage. `--run` after build: Linux/macOS launch binary; Windows runs `wine ... --help` if wine installed (smoke test). `--clean` removes platform-specific build outputs and exits (Linux: zerowallet, bin/; macOS: zerowallet.app, ZeroWallet.app; Windows: debug/, release/, mingw files).

---

## Wine (Windows testing on Linux)

[Wine](https://www.winehq.org/) runs Windows binaries on Linux. After cross-building: `wine debug/zerowallet.exe --help` (or `release/zerowallet.exe`) to verify the binary. Install: `sudo apt install wine`. Wine translates Win32 API calls; useful for quick smoke tests without a Windows VM.

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

