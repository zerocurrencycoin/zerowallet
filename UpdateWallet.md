# UpdateWallet — Project Documentation

Project document for history, directions, design decisions, planning, issue tracking, futures and wants. **Wallet-specific:** bundling zerod, invoking zerod, zerowallet UI and build — not general Zero node information. Covers everything [README](README.md) and [BUILD](BUILD.md) do not.

**Document references:** General — zerowallet [README](README.md), Zero full node [README](https://github.com/zerocurrencycoin/zero) (repo root), Zero project UpdateZero.md (repo root). Other references point to specific sections or subsections for a particular item (e.g. BUILD §macOS App Signing and Distribution).

**Document structure:** User-facing (README, BUILD) = current state only; no future plans. Project (UpdateWallet, Zero's Subsidy, UpdateZero) = status, plans, futures. Do not reference project docs from user-facing docs.

---

## Branch

- **Main line**: `zerowallet-merge`. Future work: branch from and merge into `zerowallet-merge`.

---

## History

### Repository Fork Chain

```
ZcashFoundation/zecwallet (original)
    ↓
MyHush/SilentDragon (major fork)
    ↓
Fair-Exchange/safewallet (SAFE coin port)
    ↓
zerocurrencycoin/zerowallet (Zero coin port)
```

### ZecWallet Platform Transition (February 21, 2020)

ZecWallet completely rewrote from Qt/C++ to Electron/TypeScript in commit `487707a`.

**Qt/C++ Era (Original Architecture)**
- **Last Qt version:** `v0.6.10` (April 2019)
- **Final Qt commit:** `48bef60` - "Fix access violation" (April 18, 2019)
- **Common ancestor with zerowallet:** `48bef601de79df7a3d215f07c24e16eba79b9640`

**Transition Event**
- **February 21, 2020:** Commit `487707a` - "Electron (#220)"
- **Scope:** 357 files changed, 45,636 additions, 66,081 deletions
- **Result:** Complete platform replacement

**Electron Era (Current Architecture)**
- **First Electron release:** `v0.9.0` (March 2020)
- **Current version:** `v1.8.7` (April 2023)
- **Total commits since transition:** 351 commits
- **Architecture:** Electron/TypeScript web application

**Divergence Analysis**

```
zecwallet v0.6.10 (Apr 2019, Qt/C++) ← LAST COMPATIBLE VERSION
    ↓ [351 commits divergence]
zecwallet v1.8.7 (Electron) ← INCOMPATIBLE ARCHITECTURE

zerowallet v2.0.0 (Qt/C++) ← CAN'T UPDATE FROM MODERN ZECWALLET
    ↑ [19 commits ahead]
safewallet/master ← BEST UPDATE SOURCE
    ↑ [197 commits ahead]
SilentDragon/master ← ALTERNATE UPDATE SOURCE
```

**zerowallet CANNOT pull updates from zecwallet v0.9.0 onwards** due to incompatible architectures, different build systems, zero code overlap. The upstream fork chain (safewallet ← SilentDragon) remains the update source; they kept Qt/C++.

### SingleApplication (Single-Instance, URI Forwarding)

**Source:** [itay-grudev/SingleApplication](https://github.com/itay-grudev/SingleApplication) — replacement for QtSingleApplication for Qt 5/6.

**Setup:** Vendored in `singleapplication/`. Build: `include(singleapplication/singleapplication.pri)` in `zero-qt-wallet.pro`. Core files: `singleapplication.{h,cpp}`, `singleapplication_p.{h,cpp}`, `SingleApplication` (convenience header), `singleapplication.pri`.

**Reasons for vendoring (not submodule):**
- Build uses Qt `.pri` only; upstream CMake, examples, `.github/` are unused.
- Vendoring pins the exact version; submodule updates can break the build.
- Simpler for contributors: no `git submodule init/update`.
- Upstream fork chain (SilentDragon, Safewallet) all vendor SingleApplication.

**Usage:** `SingleApplication a(argc, argv, true)` — allow secondary instances. Secondary: `a.sendMessage(uri)` then `a.exit(0)`. Primary: `receivedMessage` → `payZcashURI(uri)`. Enables: single instance, raise existing window, forward payment URIs from second launch.

**Version:** Newer than Safewallet/SilentDragon (2015–2023 license, `userData` param, `SendMode`). Upstream files in `.gitignore`: `.github/`, `examples/`, `CMakeLists.txt`, etc. — not needed for build.

### Zero / Zcash Divergence (Advice)

Zero still has full P2P alert code (alertkeys.h, sendalert.cpp, alert_tests.cpp). Zcash removed it Aug 2025. **Advice:** This belongs in a Zero full node document (e.g. Subsidy.md §15.5 or UpdateZero), not in zerowallet docs. Retain here only if needed for wallet–zerod interface context.

### Subsidy.md (Zero Full Node Repo)

**Subsidy.md** in Zero full node repo root — project document (like UpdateWallet). Documents block subsidy, halving, founders reward (7.5%), zeronode payments (20–40%), consensus constants. **§15 Addresses and Keys in Code** — wallet-relevant:
- §15.3 **ZeroWallet donation address** — `zerowallet/src/settings.cpp:490, 568`
- §15.6 Wallet address creation (RPCs `getnewaddress`, `z_getnewaddress`)

---

## Prior Contributors (About Dialog)

<!-- Search "prior contributors" to find and clear/update when needed. -->

Cryptoforge, Martin, OleksandrBlack, miodrag, Duke Leto, David Mercer, Aditya Kulkarni

---

## Design Decisions / Documented Behavior

### Context Menu: Copy / Delete Address (Settings > Wallet Config)

**Location:** Settings → Wallet Config tab → Consolidation Addresses table (column "Sapling Address").

**Usage:** Right-click (or Control-click) on a row. Context menu: **Copy Address** (clipboard), **Delete Address** (remove from list).

**Code:** `mainwindow.cpp` lines 600–620, `customContextMenuRequested` on `consolidationAddressTable`.

### Edit Menu / Writing Tools (macOS)

macOS injects items into the Edit menu ("Start Dictation", "Emoji & Symbols", "Writing Tools" submenu). These are system menus, not ZeroWallet. App Edit menu items: Address Book, Recurring Payments, Settings. No app change needed; document for users if confusion arises.

### File Dialog Default Directory (Refactor Candidate)

`QStandardPaths::writableLocation(QStandardPaths::HomeLocation)` at 5 call sites. Centralizing would simplify future changes (e.g. switch default to Documents). Low priority.

| File | Line | Usage |
|------|------|-------|
| `src/mainwindow.cpp` | 1168 | Export transactions |
| `src/mainwindow.cpp` | 1206 | Backup wallet.zero |
| `src/mainwindow.cpp` | 1251 | Export private keys |
| `src/addressbook.cpp` | 156 | Import Address Book |
| `src/connection.cpp` | 164 | Choose data directory |

**Proposed helper:** `defaultFileDialogDir()` returning `QStandardPaths::writableLocation(QStandardPaths::HomeLocation)`.

### zerod Features: Document and Test Coverage

| Feature | zerod config / RPC | zerowallet code | Test coverage |
|---------|--------------------|-----------------|---------------|
| **rescan** | `rescan=1` in zero.conf; restart zerod | `rpc.cpp` remove rescan after use; `mainwindow.cpp` import keys with rescan; `connection.cpp` rescan detection | Manual: import key, external zerod restart |
| **reindex** | `reindex=1` in zero.conf; restart zerod | `rpc.cpp` remove reindex after use; Settings Reindex button writes to conf, restarts wallet | Manual: Settings → Reindex, restart |
| **deletetx** | `deletetx=1` in zero.conf | `mainwindow.cpp` 734–747 toggle; `connection.cpp` 670, 707; `settings.cpp` 144, 243 | Manual: Settings → Wallet Config |
| **consolidation** | `consolidation=1`, `consolidationtxfee`, `consolidationaddresses` | `mainwindow.cpp` 543–635, 753–764; `connection.cpp` 206–208, 673–682; `settings.ui` 306, 323, 404 | Manual: enable consolidation, set fee, add addresses |
| **Custom fields** | consolidation addresses list | `settings.consolidationAddressTable`; `ConsolodationAddressModel`; context menu Copy/Delete | Manual: add/remove addresses |
| **shield change** | zerod behavior | `websockets.cpp` 688: TODO Respect autoshield change setting | Not implemented |

**Gaps:** No automated tests. Shield change setting not wired. Rescan/reindex require zerod restart; external zerod needs manual `-rescan`/`-reindex`.

**Zero test and doc support:** Zero repo ([zerocurrencycoin/Zero](https://github.com/zerocurrencycoin/Zero)) has `doc/`, `contrib/`, `qa/`. `zerod -?` lists command-line options. Sample configs: `contrib/zero.conf`, `contrib/debian/examples/zero.conf`. Reindex, rescan, deletetx, consolidation are zerod config options; Zero's own test coverage and documentation for these live in the Zero repo (e.g. `qa/` RPC tests, UpdateZero.md if present). zerowallet does not duplicate Zero's option docs; consult Zero for authoritative behavior and tests.

---

## zerowallet GitHub Issues

[zerowallet issues](https://github.com/zerocurrencycoin/zerowallet/issues)

### #1 — can't generate new shielded address

**Flow:** Receive tab → z-addr dropdown → if none exist, `addNewZaddr()` → RPC `z_getnewaddress` to zerod.

**If fixed:** zerod running, Sapling active (block > 492850 mainnet). Test: Receive tab → New shielded address → address in dropdown.

**If not fixed:** Likely zerod or connection (RPC timeout, auth). Isolate with `zero-cli z_getnewaddress`.

### #2 — Windows app keeps syncing for days, no information

**Flow:** Sync from zerod (`getblockchaininfo`); wallet shows "Your node is still syncing", may hide balances.

**If fixed:** Sync depends on zerod, network, disk. Test: fresh install → connect → wait. If stuck: zerod `-reindex`, peers, disk. Windows: antivirus, firewall, path.

**Test:** Run zerod standalone; if it syncs, wallet follows. Compare Linux/macOS vs Windows.

---

## Upstream Update Strategy

### Current Status

| Item | Value |
|------|-------|
| **Common ancestor with safewallet** | `6ec2115e94d61082466c8d1004be9333b0a7e1ab` |
| zerowallet | 19 commits ahead |
| safewallet | 197 commits ahead |

### Key Changes in zerowallet

**Zero-Specific Modifications (Commit `f3bf68c`)** — Major rebranding from SAFE to Zero affecting 83 files:
- **Branding:** Logo, CSS themes, translations, icons
- **Configuration:** Network settings, RPC parameters
- **UI:** Labels, dialogs, node management (zeronodes vs safenodes)
- **Build:** Scripts, packaging, release workflows

**Recent Improvements (19 commits since fork)**
1. UI Fixes: Balance view updates, tab improvements
2. Features: DeleteTx, Consolidation settings, new RPC methods
3. Development: version bumps
4. Dependencies: libsodium 1.0.21 update

### Safewallet Upstream Improvements (197 commits)

**Critical Security & Stability**
- Address validation fixes for private key export
- Parameter download improvements (ZCash params to home directory)
- Build system enhancements for cross-platform compatibility
- Memory management improvements
- Websocket stability fixes

**New Features**
- Theme system enhancements (Midnight theme, better CSS)
- Transaction handling improvements
- Multi-language support expansions
- Market data integration
- Mobile app connectivity improvements

**SilentDragon Upstream (Active Development)**
- TLS support for hushd connections
- Translation system improvements
- Security enhancements
- Performance optimizations

### Cherry-Picks (Verify Commits Exist)

```bash
git remote add safewallet https://github.com/Fair-Exchange/safewallet.git
git remote add silentdragon https://github.com/MyHush/SilentDragon.git

# Security
git cherry-pick 30899ac  # listunspent for private key export
git cherry-pick 37e7905  # ZCash params download fix

# Stability
git cherry-pick 82aa00a  # handle empty lists on unspent queries
git cherry-pick 2339993  # address null results order

# Build
git cherry-pick b9f1ea3  # account for spaces in application path
```

### Merge Conflict Strategy

1. **Branding Files** (High conflict): CSS themes, logos, icons — Solution: Manual merge keeping Zero branding
2. **Configuration** (Medium conflict): Network parameters, RPC settings — Solution: Zero-specific values take precedence
3. **UI Labels** (Medium conflict): Node management, currency names — Solution: Zero terminology preferred
4. **Build Scripts** (Low conflict): Release workflows, packaging — Solution: Merge improvements, adapt paths

### Automated Merge Process

```bash
git checkout -b upstream-integration
git merge safewallet/master

# Resolve conflicts systematically:
# 1. Accept upstream for security/stability
# 2. Keep Zero branding in UI/config
# 3. Merge build improvements
# 4. Test thoroughly
```

### Selective Merging (Medium Priority)

**Theme System Updates:** Merge midnight theme and CSS improvements; keep Zero branding intact.

**Translation System:** Merge improved translation handling; update build scripts; maintain Zero-specific language files.

### Feature Integration (Low Priority)

**Market Data Integration:** Evaluate need for market tab; adapt to Zero-specific requirements; test with Zero network endpoints.

**Mobile Connectivity:** Optional, off by default — do not auto-start websockets on app launch; only when user opens Connect Mobile. Wormhole considered broken until verified with Zero mobile apps. AnyIPv4 accepts any host; for same-LAN-only, would need subnet filtering on peer address.

### Upstream Gaps (Not Yet Documented Elsewhere)

- RPC logging in safewallet/SilentDragon
- Alert system deprecation in upstream
- zerowallet-specific divergence notes beyond branding

---

## Cross-Compilation (Linux → Windows)

### Overview

Guidance for cross-compiling zerowallet from Linux to Windows targets: research findings, build environment setup, troubleshooting.

### Current Build Status

**Working Components**
- MinGW Cross-Compiler: `x86_64-w64-mingw32-gcc` (GCC 13-win32) installed
- libsodium: Successfully built for Windows target (3.7MB static library)
- Project Configuration: Qt project files configured for Windows cross-compilation
- WSL Environment: Full Linux development environment with Qt5 development tools

**Missing Components**
- Windows Qt5 Libraries: No static Qt5 libraries available for MinGW target
- Cross-Compilation Toolchain: Complete environment (MXE) not installed

### Build Error Analysis

**Primary Issue**
```
make[1]: *** No rule to make target '/usr/lib/x86_64-linux-gnu/libQt5Widgets.a', needed by 'release/zerowallet.exe'. Stop.
```

**Root Cause:** Build system attempts to link Linux Qt5 libraries when building Windows executable.

**Technical Details:**
- Qt project configured with `win32-g++` spec
- Makefile generated correctly for Windows target
- libsodium cross-compiled successfully
- Missing Windows-compatible Qt5 static libraries

### Cross-Compilation Solutions

#### Option 1: MXE (M Cross Environment) — RECOMMENDED

MXE provides a complete cross-compilation environment for Windows targets.

**Installation**
```bash
git clone https://github.com/mxe/mxe.git /opt/mxe
cd /opt/mxe
make -j$(nproc) MXE_TARGETS=x86_64-w64-mingw32.static qtbase qtwebsockets
export PATH="/opt/mxe/usr/bin:$PATH"
```

**Configuration**
```bash
cd /home/devl/zerowallet
x86_64-w64-mingw32.static-qmake-qt5 zero-qt-wallet-mingw.pro CONFIG+=release
make -j$(nproc)
```

**Advantages:** Complete, tested environment; static linking; used by zerowallet's official build scripts; includes all necessary Windows libraries.

**Requirements:** ~4GB disk space; 2-4 hours initial compilation; build dependencies (autoconf, automake, etc.)

#### Option 2: Native Windows Build

**Visual Studio**
```batch
git clone https://github.com/zerocurrencycoin/zerowallet.git
cd zerowallet
c:\Qt5\bin\qmake.exe zero-qt-wallet.pro -spec win32-msvc CONFIG+=release
nmake
```

**Windows MinGW**
```batch
git clone https://github.com/zerocurrencycoin/zerowallet.git
cd zerowallet
qmake zero-qt-wallet.pro -spec win32-g++ CONFIG+=release
mingw32-make
```

**Advantages:** Native toolchain compatibility; faster initial setup. **Disadvantages:** Requires Windows development environment; cannot leverage Linux workflow.

#### Option 3: Custom Qt5 Cross-Build

```bash
wget https://download.qt.io/archive/qt/5.15/5.15.18/single/qt-everywhere-opensource-src-5.15.18.tar.xz
tar xf qt-everywhere-opensource-src-5.15.18.tar.xz
cd qt-everywhere-opensource-src-5.15.18
./configure -static -prefix /opt/qt5-mingw \
    -xplatform win32-g++ \
    -device-option CROSS_COMPILE=x86_64-w64-mingw32- \
    -nomake examples -nomake tests \
    -opensource -confirm-license
make -j$(nproc)
make install
```

**Advantages:** Complete control over Qt configuration. **Disadvantages:** 4-8 hours; complex; high failure rate without expertise.

### Current Environment Assessment

**Available Tools**
```
/usr/bin/x86_64-w64-mingw32-gcc, g++, ar, ld, strip, windres
/usr/bin/qmake, /usr/lib/qt5/bin/qmake
libqt5websockets5-dev, qt5-qmake
```

**libsodium Status**
- `res/libsodium.a` — Static library (MinGW .a; use buildlibsodium-win.sh for Windows)
- `res/libsodium/win/libsodium-1.0.21/` — Windows cross-compiled source

### Implementation Recommendations

**Immediate Solution: MXE Installation** — Priority: High; Effort: Medium (4-6 hours); Success Rate: High (95%+)

```bash
# Step 1: Install build dependencies
sudo apt-get install -y autoconf automake autopoint bash bison bzip2 flex g++ \
    g++-multilib gettext git gperf intltool libc6-dev-i386 libgdk-pixbuf2.0-dev \
    libltdl-dev libssl-dev libtool-bin libxml-parser-perl lzip make openssl \
    p7zip-full patch perl python3 ruby sed unzip wget xz-utils

# Step 2: Clone and build MXE
git clone https://github.com/mxe/mxe.git /opt/mxe
cd /opt/mxe
make -j$(nproc) MXE_TARGETS=x86_64-w64-mingw32.static qtbase qtwebsockets

# Step 3: Build zerowallet
export PATH="/opt/mxe/usr/bin:$PATH"
cd /home/devl/zerowallet
x86_64-w64-mingw32.static-qmake-qt5 zero-qt-wallet-mingw.pro CONFIG+=release
make -j$(nproc)
```

**Alternative: Docker-Based Build**
```bash
docker build -t zerowallet-builder src/scripts/docker/
docker run -v $(pwd):/workspace zerowallet-builder bash -c "
    cd /workspace
    x86_64-w64-mingw32.static-qmake-qt5 zero-qt-wallet-mingw.pro CONFIG+=release
    make -j\$(nproc)
"
```

### Build Script Integration

**Linux/Windows Cross-Build:** `src/scripts/mkrelease.sh` — Requires `MXE_PATH`; builds both targets; creates distribution packages.

**Unified Build:** `src/scripts/dounifiedbuild.ps1` — PowerShell orchestration; SSH-based remote building; creates installers (.msi, .deb, .dmg).

**Environment Variables**
```bash
export MXE_PATH="/opt/mxe/usr/bin"
export QT_STATIC="/opt/mxe/usr/x86_64-w64-mingw32.static"
export ZERO_DIR="/path/to/zero/src"
```

### Testing and Validation

**Build Verification**
```bash
file release/zerowallet.exe
# Expected: PE32+ executable (console) x86-64, for MS Windows

x86_64-w64-mingw32-objdump -p release/zerowallet.exe | grep "DLL Name"
# Should show minimal Windows system DLLs only (static linking)

x86_64-w64-mingw32-strip release/zerowallet.exe
```

**Runtime Testing**
```bash
sudo apt-get install wine
wine release/zerowallet.exe --help

mkdir -p release/zerowallet-v$APP_VERSION
cp release/zerowallet.exe release/zerowallet-v$APP_VERSION/
cp README.md LICENSE release/zerowallet-v$APP_VERSION/
zip -r Windows-zerowallet-v$APP_VERSION.zip release/zerowallet-v$APP_VERSION/
```

### Troubleshooting

| Issue | Solution |
|-------|----------|
| `cannot find -lQt5Widgets` | `export PKG_CONFIG_PATH="/opt/mxe/usr/x86_64-w64-mingw32.static/lib/pkgconfig"` |
| `undefined reference to sodium_*` | `cd res/libsodium && rm -f ../libsodium.a && ./buildlibsodium-win.sh` |
| `windres: can't open file 'application.qrc'` | Verify resource files accessible; `x86_64-w64-mingw32-windres --version` |
| Precompiled header issues | `CONFIG -= precompile_header` in mingw.pro (already done) |

**macOS PCH:** `__OPTIMIZE__ predefined macro was enabled in PCH file but is currently disabled` — PCH built with different CONFIG (debug vs release). Fix: `./src/scripts/mkdev.sh -c -L`. See [BUILD](BUILD.md) §Troubleshooting.

### Performance Considerations

**Build Times:** MXE Initial Setup 2-4 hours; zerowallet 5-10 min; libsodium 2-3 min.

**Resource Requirements:** 4-6GB disk; 4GB+ memory; multi-core beneficial.

### Future Improvements

**Automation:** Pre-built MXE containers; 32-bit Windows, ARM64 support.

**Optimization:** Minimal MXE (only required Qt modules); Windows-specific static analysis; security hardening.

### References

- [MXE (M Cross Environment)](https://mxe.cc/)
- [Qt Cross-Compilation](https://doc.qt.io/qt-5/configure-options.html)
- [MinGW-w64](http://mingw-w64.org/)
- [ZeroWallet Build Scripts](src/scripts/)
- [libsodium](https://libsodium.gitbook.io/)

**Conclusion:** MXE (Option 1) is strongly recommended. Proven compatibility, static linking, active maintenance, integration with existing build scripts. Investment in MXE setup pays off with reliable, automated Windows builds.

---

## Wallet / zerod Flow

- First connect: `refreshAddresses()` → `getnewaddress` when no t-addrs; `addNewZaddr()` when user selects z-addr and none exist
- zerod default datadir: `~/.zero/`
- No doc on zerowallet ↔ zerod connection flow

---

## RPC Debug Logging

- RPC logs commented out in `src/connection.cpp` (lines 751–752)
- Other `qDebug` in websockets.cpp, turnstile.cpp, mainwindow.cpp, rpc.cpp, connection.cpp, recurring.cpp, settings.cpp — no audit or policy
- Workaround: `QT_LOGGING_RULES="*.debug=false"`
- Rationale (Bitcoin PR #7692 analogy) only in code comment

---

## How zerod Gets Bundled

zerod built separately, copied into zerowallet package. No submodule. `ZERO_DIR` = pre-built binaries.

Local default: `../Zero/src`. CI plans: ~/Work/ZK/CI/README.md.

**build.sh / build-win.sh** (in Zero repo, not zerowallet):
- **Linux:** `./zcutil/build.sh` — builds zerod and zero-cli into `zero_linux/src/`
- **Windows:** `./zcutil/build-win.sh` — cross-builds zerod.exe and zero-cli.exe into `zero_win/src/`
- `-jN` is optional; omit to use auto-detected jobs. Other flags (e.g. `--disable-mining`) go before make args.

**mkrelease scripts:**

| Script | Platform | Use |
|--------|----------|-----|
| `mkrelease.sh` | Linux + Windows | Needs `QT_STATIC`, `ZERO_DIR`, `APP_VERSION`, `PREV_VERSION`. Defaults: `ZERO_DIR=../Zero/src`, `MXE_PATH=$HOME/mxe/usr/bin`. |
| `mkrelease-linux.sh` | Linux | Produces `artifacts/linux-zerowallet-v$APP_VERSION.tar.gz` and `.deb`. Options: `-z`, `-v`, `-p`, `-q`, `-d` (debug: system Qt). |
| `mkrelease-win.sh` | Windows | Produces `artifacts/Windows-zerowallet-v$APP_VERSION.zip`. Defaults: `ZERO_DIR=../Zero/src`, `MXE_PATH=$HOME/mxe/usr/bin`. |
| `mkrelease-mac.sh` | macOS | Defaults: `ZERO_DIR=../Zero/src`, `QT_STATIC=$(brew --prefix qt@5)`. Builds zerowallet, copies zerod/zero-cli into app bundle, macdeployqt, ad-hoc signs, creates DMG. See [BUILD](BUILD.md) §macOS App Signing and Distribution for Developer ID and notarization. |

**Versions and sizes:** APP_VERSION inferred from `src/version.h` (or git when unchanged); `-v` optional. mkrelease-mac echoes zerod size when copying; compare artifact zerod size to `ZERO_DIR/zerod` to verify correct source.

**Stripping:** Strip by default; `-S`/`--no-strip` to skip (larger artifacts). Linux: host `strip` for zerowallet, zerod, zero-cli. Windows: `x86_64-w64-mingw32.static-strip` when MXE provides it; else warn and skip. macOS: no strip (BUILD.md). **Revisit:** Consider adding macOS strip (and `-S` to skip) once code signing and Developer ID are in place; strip would run before signing.

**ZERO_DIR:** Directory containing built zerod and zero-cli binaries. Not the Zero source tree. Expected: `zerod` and `zero-cli` (Linux/macOS) or `zerod.exe` and `zero-cli.exe` (Windows). Override with `-z` or `ZERO_DIR`.

---

## Build / Environment Notes

- libsodium 1.0.18 URL 404; 1.0.21 used
- macOS: Homebrew Qt (`/opt/homebrew/opt/qt@5`)
- No doc on `CONFIG(release): DEFINES += QT_NO_DEBUG_OUTPUT`
- zerod as runtime dependency — not documented in cross-compilation
- zerowallet-specific build notes — CROSS was cross-compilation only

---

## Version Upgrade Plan

| Package | Plan Current | Target | Verified Current | Notes |
|---------|---------------|--------|------------------|-------|
| libsodium | 1.0.18 | 1.0.21 | **1.0.21** | Done. Plan "current" stale. |
| nlohmann/json | 3.6.1 | 3.12.0 | 3.6.1 | Single-header; 3.12.0 backward-compatible; deprecations only (4.0 prep). |
| SingleApplication | 3.0.14 | 3.5.4 | 3.0.14 | Usage unchanged in 3.5.x. Submodule or copy. |
| Qt | 5.9.1 | 5.15.17 | 5.15.18 | Target 5.15.17 (last open-source). |
| Docker | ubuntu:16.04 | ubuntu:24.04 | ubuntu:16.04 | `src/scripts/docker/Dockerfile`. |
| OpenSSL | 1.0.2r | 1.1.1w | 1.0.2r | Dockerfile only. 1.0.2 EOL. 1.1.1 API changes; Qt static build may need `-openssl-linked`. |
| Nayuki QR-Code | (blank) | v1.8.0 | unversioned (~v1.0–1.4) | zerowallet has 6 files; v1.8.0 unified (qrcodegen.hpp/cpp). API identical. Replace 6 with 2, update .pro and include. |

### Discrepancies

- **libsodium:** Plan says 1.0.18; repo is 1.0.21.
- **Qt:** Target 5.15.17; cherry-pick 5.15.19 (commercial-only) fixes if needed.
- **Travis:** Obsoleted. Removed `.travis.yml`.

---

## Detected Errors and Mismatches

### zerowallet

| Location | Issue | Severity |
|----------|-------|----------|
| ~~`src/connection.cpp:116-123`~~ | ~~Memory leak~~ Fixed: `randomPassword()` now uses `std::string` (RAII) | — |
| ~~`src/connection.cpp:119`~~ | ~~Buffer index~~ Fixed: `charsetLen = sizeof(charset) - 1` | — |
| `src/websockets.cpp:28` | WebSocket binds `QHostAddress::AnyIPv4`; mobile is separate device so LocalHost would block it | — |
| ~~`src/connection.cpp:115`~~ | ~~Password length 10~~ Fixed: 20 chars, expanded charset (alphanum + `!@#$%^&*()_+-=[]{}|\:;"'<>?,./~`) | — |
| `src/settings.cpp:242-243` | RPC credentials stored plain text | Medium |
| `src/rpc.cpp:1538` | HTTP instead of HTTPS for external API calls | Medium |
| `res/libsodium` | Build scripts referenced 1.0.18 URL (404); 1.0.21 used | Low |
| Version upgrade plan | Plan "current" for libsodium was 1.0.18; repo already 1.0.21 | Low |

**signbinaries:** Covered in [BUILD](BUILD.md) §GPG Signatures. Script `src/scripts/signbinaries.sh` auto-detects: uses `sha256sum` on Linux, `shasum -a 256` on macOS. Run from `artifacts/`.

**WebSocket binding:** Single listen in `websockets.cpp:28` — `WSServer` for mobile "Direct Connection" on port 8237 (hardcoded, `mainwindow.cpp:180`). Address: `QHostAddress::AnyIPv4` (accepts connections from any IP, not just same LAN). LocalHost would block mobile entirely (mobile is a separate device; LocalHost only allows same-machine processes). To restrict to same LAN, would need subnet filtering on peer address. **Recommendation:** Mobile connect optional, off by default — do not auto-start websockets on app launch; only start when user explicitly opens Connect Mobile dialog. **Wormhole relay:** When user checks "Allow connections over the internet via ZeroWallet wormhole", desktop connects to `wss://wormhole.zecqtwallet.com:443` and registers a code; mobile can connect via relay when not on same LAN. **Wormhole status:** Consider broken until verified working with Zero mobile apps. **Once connected, phone does:** getInfo (balances), getTransactions, sendTx — companion app proxies through desktop wallet to zerod.

**Weak password:** `randomPassword()` generates RPC password when wallet creates `zero.conf` (`connection.cpp:197`). Used for zerod RPC auth (`rpcuser=zero`, `rpcpassword=<generated>`). zerod reads from config; no separate zerod password strategy. Fixed: now 20 chars, charset includes `!@#$%^&*()_+-=[]{}|\:;"'<>?,./~`.

**Plain text credentials:** `settings.cpp:241-242` stores `rpcuser`/`rpcpassword` in `QSettings` (macOS: `~/Library/Preferences` plist). **Upstream (safewallet):** Same pattern — `QSettings` for rpcuser/rpcpassword. **Recommendation:** Use OS credential store (Keychain, libsecret) or encrypt before storage; upstream has no fix to cherry-pick.

**HTTP:** Only `rpc.cpp:1537` — `http://z-board.net/listTopics` (ZBoard topics fetch). CoinGecko and GitHub use HTTPS. **Upstream:** safewallet uses HTTPS for explorer/price URLs. **Risk:** HTTP-only is acceptable when traffic stays on same desktop (local RPC, local fetches). Real issue when used across the internet (e.g. remote RPC, relayed traffic) — no confidentiality or integrity. **Recommendation:** Switch to HTTPS if z-board.net supports it; else document risk or make fetch optional.

**randomPassword RAII (implemented):** `std::string` vs `std::unique_ptr<char[]>` — both avoid leaks. `std::string` is simpler: no manual allocation, no explicit delete, idiomatic C++. `std::unique_ptr<char[]>` gives explicit RAII over a raw buffer but adds boilerplate. Recommendation: `std::string` (chosen).

**Tests:** Unit test `randomPassword()` — length 20, charset coverage, no null in output, no leak (valgrind/sanitizers). System test: create zero.conf, verify zerod accepts generated credentials.

### Zero Full Node (from Subsidy.md §11.1)

| Location | Issue |
|----------|-------|
| `src/amount.h` | `MAX_MONEY = 16.95M ZER`; Zero total supply ~25.6M ZER exceeds this; validation uses per-subsidy `MoneyRange` only |
| Zero Subsidy.md §11.3 | `338665500000000<?>` wrong founders value; see Subsidy.md, UpdateZero §4.6 |
| Zero `README.md` | "Stable supply is 3888 ZER, after first halfing" — ambiguous; 3888 ≈ daily emission (720×5.4), not total supply |
| Zero `doc/tor.md` | `"subver" : "/MagicBean:1.0.0/"` — legacy; Zero uses Ambrym |

### Cross-Reference Mismatches

| Doc | Mismatch |
|-----|----------|
| mkrelease scripts | `zero_linux/src/` vs `zero_win/src/` output dirs; default `../Zero/src` assumes single build — verify layout matches |

### Dependency Repos (~/Work/ZK)

| Repo | Path | Version | Notes |
|------|------|---------|-------|
| QR-Code-generator | `QR-Code-generator` | v1.8.0 | Diff done. zerowallet ≈ v1.0–1.4 era. |
| nlohmann/json | `json` | v3.12.0 | `git fetch --tags && git checkout v3.12.0`. Single header. |
| SingleApplication | `SingleApplication` | v3.5.4 | Compare with zerowallet `singleapplication/`. |
| libsodium | `libsodium` | 1.0.21-RELEASE | Build uses tarball; repo for reference. |

**Others (not cloned):** OpenSSL — tarball for Docker. Qt — tarball (5.15.17); too large to clone.

### Update, Download, Build

**Update (vendored libs):**

| Lib | Action |
|-----|--------|
| nlohmann/json | Copy `~/Work/ZK/json/single_include/nlohmann/json.hpp` → `src/3rdparty/json/json.hpp`. |
| SingleApplication | Replace `singleapplication/` with `~/Work/ZK/SingleApplication` contents (or submodule). |
| Nayuki QR | Replace `src/3rdparty/qrcode/*` with `~/Work/ZK/QR-Code-generator/cpp/qrcodegen.hpp` and `qrcodegen.cpp`; update .pro and precompiled.h. |
| libsodium | Already 1.0.21. Build scripts use tarball. |

**Download (tarballs):**

| Dep | URL |
|-----|-----|
| Qt 5.15.17 | https://download.qt.io/archive/qt/5.15/5.15.17/single/qt-everywhere-opensource-src-5.15.17.tar.xz |
| libsodium 1.0.21 | https://download.libsodium.org/libsodium/releases/libsodium-1.0.21.tar.gz |
| OpenSSL 1.1.1w | https://www.openssl.org/source/openssl-1.1.1w.tar.gz |

**Build:**
```bash
# macOS (Homebrew Qt)
export PATH="/opt/homebrew/opt/qt@5/bin:$PATH"
qmake zero-qt-wallet.pro CONFIG+=release
make

# Or mkrelease (Linux/Windows cross)
./src/scripts/mkrelease.sh   # defaults: ZERO_DIR=../Zero/src, MXE_PATH=$HOME/mxe/usr/bin
```

### System Install (brew, pyenv, pip)

No package-manager installs for library upgrades — all vendored. For builds: **macOS:** `brew install qt@5`. **Linux:** `apt-get install` deps. **Windows (MXE):** MXE provides Qt. **Docker:** Dockerfile `apt-get` and tarballs.

**Python (zerowallet):** Build dependencies only; no runtime, no tests. (1) `install_mxe.sh --deps`: apt-installs `python3-mako`, `python3-setuptools` (Python 3). (2) `src/scripts/docker/Dockerfile` (ubuntu:16.04): apt-installs `python` (→ python2 on that base) and `ruby` for Qt/MXE build. Zero full node RPC tests use system Python; zerowallet does not. No zerowallet Python scripts.

### Risk / Effort

| Item | Risk | Effort |
|------|------|--------|
| nlohmann/json 3.12 | Low | Low |
| SingleApplication 3.5.4 | Low | Low |
| Qt 5.15.17 | Medium | Medium |
| ubuntu-18.04→24.04 | Low | Low |
| actions v1/v2→v4 | Medium | Low–medium |
| Docker ubuntu:16→24 | High | High |
| OpenSSL 1.0.2→1.1.1 | Medium | Medium |
| Nayuki QR v1.8.0 | Low | Low |

### Qt 5.15.19 Cherry-Pick (Review)

5.15.19 (May 2025) is commercial-only; ~105 fixes vs 5.15.18. Open-source stays on 5.15.18. To apply selected fixes: (1) Review Qt Customer Portal changelog or [qt.io blog](https://qt.io/blog/commercial-lts-qt-5.15.19-released); prioritize security and zerowallet modules. (2) Check [qt5.git](https://code.qt.io/cgit/qt/qt5.git/) `5.15` or `tqtc/lts-5.15` for backports. (3) Cherry-pick to local Qt 5.15.18 build. High effort; only for critical fixes.

---

## UI / UX Completed (macOS DMG Testing 2026-02)

- ~~Save transactions: File dialog default to Documents~~
- ~~Backup wallet.zero: File dialog default to Documents~~
- ~~Help / About dialogs: setWindowFlags(Qt::Window)~~
- ~~Addresses with 0 balance: include in addressBalances, balancesOverview~~
- ~~Import Address Book, Choose data directory: proper default paths~~

---

## Security Vulnerability Report

### High Severity

1. ~~**Memory leak**~~ Fixed: `randomPassword()` uses `std::string` (RAII).
2. ~~**Buffer index**~~ Fixed: `charsetLen = sizeof(charset) - 1`.
3. **WebSocket binding** (`src/websockets.cpp:28`): Listens on AnyIPv4. LocalHost not applicable (mobile is separate device). Mobile connect now optional, off by default.

### Medium Severity

4. ~~**Weak password**~~ Fixed: 20 chars, expanded charset.
5. **Credentials plain text** (`src/settings.cpp:242-243`): Encrypt or use OS credential store
6. **HTTP** (`src/rpc.cpp:1538`): Acceptable risk on same desktop; real issue across internet. Switch to HTTPS for external APIs.

### Immediate Actions

1. ~~Fix memory leak~~ Done
2. ~~Fix buffer index~~ Done
3. ~~Mobile connect off by default~~ Done
4. ~~Increase password length~~ Done
5. HTTPS for external APIs (z-board.net)

---

## Futures and Wants

### From Upstream (Selective Merge)

- Theme system (Midnight, CSS) — keep Zero branding
- Translation improvements
- Market data — evaluate for Zero
- Mobile connectivity — test with Zero mobile apps

### From Upstream (SilentDragon)

- TLS for zerod connections
- Translation system
- Security, performance

### Cross-Compilation

- Pre-built MXE containers
- 32-bit Windows, ARM64 support

### Tooling

- **Cursor configuration:** See UpdateZero §2.1. Both repos have `.cursor/rules/mainline-branches.mdc`. Zero has CLAUDE.md. Full issue list documented; resolution postponed.

---

## Testing Checklist

Run before release. zerod must be running and synced (or testnet). Prereq: fresh or existing `~/.zero/` (or `~/Library/Application Support/zero` on macOS).

### Recent Fixes (Priority)

| # | Test | Pass |
|---|------|------|
| 1 | **Addresses with 0 balance:** Receive tab → addresses with zero balance appear in dropdown and balances overview | |
| 2 | **File dialogs:** Export transactions, Backup wallet.zero, Export private keys → default dir is Home (or Documents per platform) | |
| 3 | **Help / About:** Dialogs open as proper windows (not tool windows); can move, minimize | |
| 4 | **Import Address Book / Choose data dir:** File dialog opens with correct default path | |
| 5 | **First run (zero.conf):** Wallet creates `zero.conf` with `rpcuser=zero`, `rpcpassword` 20 chars; zerod accepts credentials | |
| 6 | **Mobile connect:** Off by default; Connect Mobile not opened until user explicitly opens it | |
| 7 | **Single instance:** Second launch → primary window raised; payment URI forwarded if passed as arg | |

### Major Functionality

| # | Test | Pass |
|---|------|------|
| 8 | **Connect:** zerod running → wallet connects; status shows synced or syncing | |
| 9 | **Receive:** New shielded address → `z_getnewaddress` succeeds; address in dropdown | |
| 10 | **Send:** Send tab → enter amount, address, memo → send succeeds | |
| 11 | **Settings:** Wallet Config, Consolidation addresses → add, copy, delete (context menu) | |
| 12 | **Address Book:** Add, edit, delete entries | |
| 13 | **Recurring:** Create recurring payment; list shows entry | |
| 14 | **Backup:** Backup wallet.zero → file saved | |
| 15 | **Turnstile:** If shown, completes without hang | |
| 16 | **DeleteTx:** Settings → DeleteTx option; transaction delete works | |
| 17 | **QR payment URI:** Open `zero:...` URI → primary window handles; payment prefilled | |
