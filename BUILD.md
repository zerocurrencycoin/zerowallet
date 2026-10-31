# Build and Release Guide

How to build zerowallet for development and release on Linux, macOS, and Windows. Scripts are in `src/scripts/`; run them from the repository root. The mkdev and mkrelease scripts print their options with `-h`.

| Target | Build host | Qt | Dev build | Release build | Release artifact |
|--------|------------|----|-----------|---------------|------------------|
| Linux | Linux | System Qt (dev); static Qt or system Qt (release) | `mkdev-linux.sh` | `mkrelease-linux.sh` | `linux-zerowallet-vX.Y.Z.tgz` and `.deb` |
| macOS | macOS | Homebrew `qt@5` | `mkdev-mac.sh` | `mkrelease-mac.sh` | `macOS-zerowallet-vX.Y.Z.dmg` (`-T`: also `.tgz`) |
| Windows | Linux (or WSL), cross-build | MXE static Qt | `mkdev-win.sh` | `mkrelease-win.sh` | `Windows-zerowallet-vX.Y.Z.zip` |

`mkdev.sh` and `mkrelease.sh` dispatch to the script for the host (on Linux, the Linux target). Validated: Linux and Windows, dev and release; macOS arm64, dev and release (Qt 5.15.18).

---

## One-time setup

Downloads and builds needed once per machine.

| Target | Setup |
|--------|-------|
| Linux dev | `sudo apt install build-essential qtbase5-dev qtbase5-dev-tools libqt5websockets5-dev libqt5svg5-dev`; `mkdev-linux.sh` names any that are missing |
| Linux release | Static Qt: `./src/scripts/build-qt-static.sh` downloads the Qt 5.15.18 source (about 633 MB) and builds it into `qt5-static/`; or pass an existing static Qt with `-q PATH`; or release with system Qt (`-S`) and skip this |
| macOS | `brew install qt@5 create-dmg` |
| Windows | `./src/scripts/install_mxe.sh` clones MXE to `~/mxe` and builds `qtbase` and `qtwebsockets` for `x86_64-w64-mingw32.static` (1 to 4 hours); `--deps` installs only the host packages, `--check` verifies `gcc` and `qmake-qt5`. Other MXE locations: `-m PATH` or `MXE_PATH` |
| Release, all | `zerod` and `zero-cli` (`.exe` for Windows) built for the target, in `ZERO_DIR` (below); build them per the Zero node's BUILD_ZERO "Linux", "macOS", or "Windows" |

MXE host packages (`install_mxe.sh --deps`): autoconf automake bison bzip2 flex g++ g++-multilib gettext git gperf libc6-dev-i386 libgdk-pixbuf2.0-dev libltdl-dev libssl-dev libtool-bin make openssl p7zip-full patch perl pkg-config python3-mako python3-setuptools ruby sed unzip wget xz-utils zstd. Windows release packaging also needs `zip`; `mkdev-win.sh -R` needs `wine`.

`./src/scripts/qt-report.sh` prints the Qt setup the scripts will find on this host.

Vendored, built by the scripts: libsodium 1.0.21 (`res/`), nlohmann/json 3.6.1 (`src/3rdparty/`), SingleApplication 3.6.0 (`singleapplication/`). The scripts check the target of `res/libsodium.a` (`file(1)` on its first member: ELF or Mach-O for Linux and macOS, COFF for Windows) and rebuild it when it is missing or built for the other target; `buildlibsodium-win.sh` downloads the source only when no tarball is cached.

---

## Dev builds

```bash
./src/scripts/mkdev.sh            # Linux or macOS host target
./src/scripts/mkdev-win.sh        # Windows target, on Linux
```

| Script | Output | Run |
|--------|--------|-----|
| `mkdev-linux.sh` | `zerowallet` in the repository root | `./zerowallet` |
| `mkdev-mac.sh` | `ZeroWallet.app` in the repository root, linked to Homebrew Qt, not standalone | `open ZeroWallet.app` |
| `mkdev-win.sh` | `debug/zerowallet.exe` or `release/zerowallet.exe` | `wine debug/zerowallet.exe`, or `-R` |

Dev builds are debug by default and need no `zerod`. qmake writes `Makefile` in the repository root and objects to `bin/` (`debug/` or `release/` for the Windows target); both are gitignored. Dev builds reuse them; `-c` cleans first. The Windows target builds from `zero-qt-wallet-mingw.pro`, which the scripts generate from `zero-qt-wallet.pro` and remove on `-c`.

| Flag | Env | Effect |
|------|-----|--------|
| `-c`, `--clean` | `MKDEV_CLEAN` | Clean before building |
| `-r`, `--release` | `CONFIG` | `CONFIG+=release` |
| `-j N`, `--jobs N` | `JOBS` | Parallel make jobs |
| `-L`, `--log` | `LOG_FILE` | Log path |
| `-R`, `--run` | `RUN_AFTER_BUILD` | Run the binary after the build |
| `-m`, `--mxe` | `MXE_PATH` | MXE `usr/bin` (Windows target) |
| `-C`, `--check` | `MKDEV_CHECK_ONLY` | Windows target: check MXE, `make`, and the project file, then exit |

---

## Release builds

A release build cleans the tree (`make distclean`, `.qmake.stash`), builds release, copies `zerod` and `zero-cli` from `ZERO_DIR` into the package, strips the packaged binaries, and writes the artifact to `artifacts/`. X.Y.Z is the version in `src/version.h`, the single version source; `-v X.Y.Z` writes it first.

| Flag | Env | Default | Effect |
|------|-----|---------|--------|
| `-z`, `--zero` | `ZERO_DIR` | `../Zero/src` | Directory with `zerod` and `zero-cli`; when missing or empty, `../ZeroLinux/src`, `../ZeroMac/src`, or `../ZeroWin/src` by target |
| `-v`, `--version` | `APP_VERSION` | `src/version.h` | Release version; written to `version.h` |
| `-q`, `--qt` | `QT_PREFIX` | per target | Qt prefix |
| `-S`, `--systemqt` | `USE_SYSTEM_QT` | off | Linux: link system Qt dynamically |
| `-P`, `--nostrip` | -- | strip | Keep symbols in the packaged binaries; originals in `ZERO_DIR` are never changed |
| `-N`, `--no-sign` | -- | `CODESIGN_IDENTITY` or ad-hoc | macOS: ad-hoc signature |
| `-t`, `--translate` | `RUN_TRANSLATIONS` | off | Rebuild `res/*.qm` from `.ts` before packaging, with `lrelease` from `-q`, `qt5-static/`, or `qtbase5-dev-tools` |
| `-T`, `--tgz` | `MAKE_TGZ` | off | macOS: also write a `.tgz` of the app |
| `-m`, `--mxe` | `MXE_PATH` | `~/mxe/usr/bin` | Windows target |
| `-j`, `--jobs` | `JOBS` | `min(CPUs, 4)` | Parallel make jobs; `JOBS` overrides `-j` |
| `-L`, `--log` | `LOG_FILE` | timestamped | Log path |

Environment variables override flags. Each archive holds `README.md` beside the binaries.

`./src/scripts/package-verify.sh -v X.Y.Z` checks that the release archives for that version hold the expected files; `--linux`, `--mac`, or `--windows PATH` checks one archive. `mkrelease-win.sh` runs it on its zip.

### Linux

```bash
./src/scripts/mkrelease-linux.sh          # static Qt from qt5-static/ or -q
./src/scripts/mkrelease-linux.sh -S       # system Qt
```

The `.tgz` holds `zerowallet`, `zerod`, `zero-cli`. With static Qt the script refuses a binary that links Qt dynamically. Check a binary with `file zerowallet` (stripped or not) and `ldd zerowallet`: a static build lists no `libQt5` library; a system-Qt build lists exactly `libQt5Core`, `libQt5Gui`, `libQt5Network`, `libQt5WebSockets`, `libQt5Widgets`, the five modules in `QT +=` of `zero-qt-wallet.pro`.

### macOS

```bash
./src/scripts/mkrelease-mac.sh
```

Steps: build, copy `zerod` and `zero-cli` into `ZeroWallet.app/Contents/MacOS/`, `macdeployqt` (copies the Qt frameworks into the app), strip, `codesign`, move the app to `artifacts/`, `create-dmg`. The script prints the signing mode and the DMG format and size (UDZO is compressed). Without `CODESIGN_IDENTITY` the signature is ad-hoc: the app runs, but Gatekeeper on another Mac blocks it until the user opens it with right-click, Open.

Developer ID release, which Gatekeeper accepts without user override (Apple Developer account required):

```bash
export CODESIGN_IDENTITY="Developer ID Application: Name (TEAM_ID)"
./src/scripts/mkrelease-mac.sh
xcrun notarytool store-credentials <profile> --apple-id <email> --team-id <id> --password <app-specific-password>   # once
xcrun notarytool submit artifacts/macOS-zerowallet-vX.Y.Z.dmg --keychain-profile <profile> --wait
xcrun stapler staple artifacts/macOS-zerowallet-vX.Y.Z.dmg
```

Test before distributing:

```bash
hdiutil attach artifacts/macOS-zerowallet-vX.Y.Z.dmg -nobrowse -quiet
codesign -dv --verbose=2 "/Volumes/ZeroWallet-vX.Y.Z/ZeroWallet.app"
open "/Volumes/ZeroWallet-vX.Y.Z/ZeroWallet.app"
hdiutil detach "/Volumes/ZeroWallet-vX.Y.Z"
```

### Windows

```bash
./src/scripts/mkrelease-win.sh -m ~/mxe/usr/bin
```

The zip holds `zerowallet.exe`, `zerod.exe`, `zero-cli.exe`. `-t` refreshes translations on the Linux host before the MXE build.

---

## Signing

| Platform | What is signed | How | Verify |
|----------|----------------|-----|--------|
| All | Each release archive | `./src/scripts/signbinaries.sh [-v X.Y.Z]` writes `sha256sum-vX.Y.Z.txt` and a detached GPG `.sig` per archive in `artifacts/`, packed as `signatures-vX.Y.Z.zip` | `sha256sum -c sha256sum-vX.Y.Z.txt` (`shasum -a 256 -c` on macOS); `gpg --verify <file>.sig <file>` |
| macOS | `ZeroWallet.app`, including `zerod` and `zero-cli` | `codesign` in `mkrelease-mac.sh`: Developer ID with `CODESIGN_IDENTITY`, otherwise ad-hoc | `codesign --verify --strict ZeroWallet.app`; `spctl --assess --type execute -v ZeroWallet.app` |
| Windows | Nothing | No Authenticode signature | -- |
| Linux | Nothing beyond GPG | Unsigned `.tgz` and `.deb` | -- |


---

## Logs and debug output

Every dev, release, and `build-qt-static.sh` run writes `logs/<script>-<YYYYMMDD-HHMMSS>.log` with all output, and prints `Log: <path>` first; `-L PATH` sets another path, `-L` alone uses `logs/<script>.log`. `logs/` is gitignored and never pruned; a full `build-qt-static.sh` log is about 30 MB.

Release builds install a message handler (`Application::main()` in `src/main.cpp`, under `#ifndef QT_DEBUG`) that drops `qDebug()` output and selected warnings; dev builds, which are debug, keep them, and `QT_LOGGING_RULES="*.debug=true"` enables them at run time. The wallet writes `zero-qt-wallet.log` in the platform application data directory (`QStandardPaths::AppDataLocation`). `std::cout` output bypasses the handler.

---

## Troubleshooting

| Symptom | Target | Fix |
|---------|--------|-----|
| `__OPTIMIZE__ predefined macro was enabled in PCH file but is currently disabled` | macOS | The precompiled header was built with the other CONFIG (debug or release): `./src/scripts/mkdev.sh -c` |
| `The macosx platform SDK has been changed from version X to version Y`, then `sdk.mk: *** ^. Stop.` | macOS | Xcode was updated; Qt keeps the SDK version in `.qmake.stash`, which `make distclean` leaves: `./src/scripts/mkdev-mac.sh -c` (release builds always remove it) |
| `create-dmg` exits nonzero after "Resource busy" during unmount | macOS | A create-dmg unmount race. `create-dmg` 1.2.3 stops after 5 detach attempts and leaves `artifacts/rw.<pid>.<name>.dmg` attached; `mkrelease-mac.sh` then detaches it (forced after two tries), compresses it to the UDZO DMG, and warns. An image still attached from an interrupted run is detached at the start of the next run. The DMG is accepted when `hdiutil imageinfo` reads it |
| No DMG | macOS | The app is already in `artifacts/ZeroWallet.app`. Rerun with `CREATE_DMG_VERBOSE=1` for the full create-dmg output; check disk space and remove a leftover `artifacts/macOS-zerowallet-v*.dmg` |
| DMG of 20 MB or more | macOS | `zerod` in `ZERO_DIR` is a debug build; the script strips the packaged copy unless `-P` |
| Wrong-target libsodium | All | The scripts rebuild `res/libsodium.a` for the target with a warning; no action needed |
