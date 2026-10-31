# TODO

Open work on the Zerowallet desktop wallet. Each item, active or postponed, carries what is needed to do it.

---

## Active

v4.1.0 ships after Zero v4.1.0-rc1 and packages that tag's `zerod`. Order: Proving parameters tests, Release content, Release signing and packaging, then BUILD "Release builds" with `-z` pointing at the Zero tree at that tag, and the smoke test below. After the v4.1.0 tag, tag the current `master` as `archive/master-2025` and set `master` to `v4.1.0`; `master` shares no history with the release line, so a merge is not used.

### Upstream ports (`upstream-port`)

- Smoke test the release build against an isolated Zero node, from the Zero tree: `./contrib/ops-validate.sh cold zerowallet keep --wallet=PATH` with a disposable wallet copy; start the wallet with `--no-embedded --conf /tmp/zero-ops-validate/zero.conf`; check connection, new addresses, and error dialogs without sending; `./contrib/ops-validate.sh stop`.

### Version upgrades

- nlohmann/json: 3.6.1 → 3.12.0; single header, low risk.
- Nayuki QR-Code: unversioned → v1.8.0 (replace 6 files with 2; update .pro).
- Qt: **5.15.18** in static release — no bump unless critical; 5.15.19 commercial-only.

### Release signing and packaging

Sign every release on every platform and validate each with the verify commands in BUILD "Signing", using the same keys and methods as Zero v4.1.0. macOS: release with a Developer ID identity, then notarize and staple the DMG. Windows: design Authenticode on the Linux host with `osslsigncode` for `zerowallet.exe`, `zerod.exe`, `zero-cli.exe`, and decide whether the WiX MSI (`mkwininstaller.ps1`, built on a Windows host) ships. Linux: decide whether the `.deb` gets a package signature. All: choose the release GPG key for `signbinaries.sh` and publish its fingerprint. Write release notes per version, as the Zero node does in `doc/release-notes/`.

### Proving parameters

Zerowallet fetches the files `zerod` loads as Zero's `zcutil/fetch-params.sh` does (Zero TODO "Parameter acquisition"): same files, source, parts, sizes, and SHA-256 digests (`kParamFiles` in `connection.cpp`). Specific to the wallet:

- Existing files: size checked at every start; SHA-256 checked once, then stamped in the wallet settings (`params/verified/NAME`: size and modification time).
- Download: both parts are written to `NAME.dl` and hashed as data arrives; `NAME.dl` replaces `NAME` only with the expected size and SHA-256. An unverified or wrong-size file is first moved to `NAME.bad`.
- Before downloading: the parameter directory must be writable and have room for the files plus 64 MB.
- Failures: a 60 s stall, a network or HTTP error, or a failed check retries twice after 5 s; after that, and on a write or rename failure, the user chooses Retry or Cancel. Cancel leaves the download to the next start.
- The DMG does not bundle the files. Each step is logged to `zero-qt-wallet.log` in the wallet's application data directory.

Validate on each platform. The commands are for macOS and a dev build; the parameter directory is `~/.zcash-params` on Linux and `%APPDATA%\ZcashParams` on Windows (`zcashParamsDir()` in `connection.cpp`).

**Setup.** `HOME=/tmp/zw-test` moves the parameter directory and `zero.conf` under `/tmp/zw-test`. The log and the stamps stay in the real account: the log in `~/Library/Application Support/zero-qt-wallet-org/zero-qt-wallet/`, the stamps in the preferences domain `com.zero-qt-wallet-org.zero-qt-wallet` as `params.verified.NAME` with `.params` written `·params`. A link reports its target's modification time, so links to the node's stamped files pass without a hash unless the stamps are deleted. A `zero.conf` that the wallet generates uses the mainnet ports, RPC 23811 and P2P 23801, and collides with a node running on this machine; write one on unused ports, without listening, first. A dev build has no `zerod` in the app, so tests 2 to 7 end at `Can't find zerod`; test 8 uses the release build, which has it. Run in bash from the repository root:

```bash
P="/tmp/zw-test/Library/Application Support/ZcashParams"   # test parameter directory
R="$HOME/Library/Application Support/ZcashParams"          # the node's verified files
C="/tmp/zw-test/Library/Application Support/Zero"
LOG="$HOME/Library/Application Support/zero-qt-wallet-org/zero-qt-wallet/zero-qt-wallet.log"
DOM=com.zero-qt-wallet-org.zero-qt-wallet
defaults export $DOM /tmp/zw-prefs-backup.plist            # once, before the first test
mkdir -p "$P" "$C"
printf 'server=1\nrpcuser=zero\nrpcpassword=test\nrpcport=18999\nport=18998\nlisten=0\n' > "$C/zero.conf"
unstamp() { for f in sapling-output sapling-spend sprout-groth16; do defaults delete $DOM "params.verified.$f·params" 2>/dev/null; done; }
run() { HOME=/tmp/zw-test ./ZeroWallet.app/Contents/MacOS/ZeroWallet; }
tail -n 0 -f "$LOG"                                        # in a second terminal
```

Each test: `unstamp`, the setup commands, `run`, compare the new log lines with Expected, quit the wallet.

| Test | Setup | Expected log and files |
|------|-------|------------------------|
| 1. Build | `mkdev-mac.sh`, `mkdev-linux.sh`, `mkdev-win.sh` | Exit 0, no warnings |
| 2. Files present | `ln -sf "$R"/*.params "$P"/`; `run`, quit, then `run` again without `unstamp` | First start: `Checking` and `Verified` per file. Second start: neither; no download |
| 3. One small file | `head -c 1000000 "$R/sapling-output.params" > "$P/t" && mv -f "$P/t" "$P/sapling-output.params"` (replaces the link, not the node's file) | `moving it to sapling-output.params.bad`; queue holds only `sapling-output.params`; parts 1 and 2 (part 2 empty); `Verified`; `All Downloads done` |
| 4. First run | `mv -n "$P" "$P.t3" && mkdir "$P"`; downloads 741 MiB | All three files downloaded; `All Downloads done`; `shasum -a 256 "$P"/*.params` matches `kParamFiles` |
| 5. Corrupt file | After test 3: `python3 -c 'import sys;f=open(sys.argv[1],"r+b");f.seek(1000);b=f.read(1);f.seek(1000);f.write(bytes([b[0]^1]))' "$P/sapling-output.params"` | `failed its SHA-256 check`; moved to `.bad`; downloaded again; `Verified` |
| 6. No network | Setup of test 3. Retry count: `HOME=/tmp/zw-test sandbox-exec -p '(version 1)(allow default)(deny network-outbound)' ./ZeroWallet.app/Contents/MacOS/ZeroWallet` in place of `run`. Network back: `run` with Wi-Fi off, which also cuts a running node off from its peers; Wi-Fi on at the dialog, then Retry | `Host download.z.cash not found`; `Retrying in 5 s` twice; Retry or Cancel. Retry with the network back: `Verified`. Cancel: "The proving parameters are incomplete"; the next start downloads. No `.dl` file left |
| 7. Read-only directory | Setup of test 3, then `chmod a-w "$P"`; afterwards `chmod u+w "$P"` | `Cannot create or write the parameter directory` with Retry or Cancel; no new `.bad`, no `.dl` |
| 8. `zerod` start | After test 4, with the release build: `HOME=/tmp/zw-test artifacts/ZeroWallet.app/Contents/MacOS/ZeroWallet`; `pgrep -fl zerod` while it runs and after quitting | `Starting embedded zerod`, then a connection; `pgrep` lists the test node beside any mainnet node, and only the mainnet node after quitting. The test node syncs mainnet into `/tmp/zw-test` until the wallet quits |

Passed on macOS arm64: tests 1 to 5, 7, and 6 without the network-back Retry and Cancel; test 4 took 250 s. Open: test 6 network back, test 8, Linux, Windows.

**Durations.** Measured on macOS arm64 at about 3.1 MB/s from `download.z.cash`, from the timestamps in `zero-qt-wallet.log`; downloads scale with bandwidth, hashing with disk and CPU.

| Step | Time |
|------|------|
| First-start SHA-256 of the three files (test 2) | 3 s, nearly all `sprout-groth16.params` |
| Later starts with stamps (test 2) | under 1 s |
| `sapling-spend.params` download, 47,958,396 bytes | 15 s |
| `sapling-output.params` download, 3,592,860 bytes (tests 3, 5) | 1 to 2 s |
| `sprout-groth16.params` download, 725,523,612 bytes, part 1 and part 2 | 233 s: 168 s and 65 s |
| All three from an empty directory (test 4) | 250 s |
| No network to the Retry or Cancel dialog (test 6) | 10 s: three attempts 5 s apart |

**Cleanup.** `chmod u+w "$P"`; `trash /tmp/zw-test`; `defaults import $DOM /tmp/zw-prefs-backup.plist` restores the domain as it was before the tests, stamps included; without it the installed wallet hashes each unstamped file once at its next start.

Where parameter handling lives, for `zerod` and the wallet together, is decided after v4.1.0 (Zero TODO "Parameter acquisition"); the wallet download stays until then.

### Release content

Before the v4.1.0 tag, check each tracked document against the documentation map in README, and remove from the repository those that are not part of the release; removed files stay in git history.

### Build / cross-reference

- Review safewallet/SevenSeas build script fixes separately from P0 ports.
- Verify ZERO_DIR layout: mkrelease default `../Zero/src` vs platform output dirs.

---

## Postponed backlog

No scheduled work; promote an item to Active when its trigger occurs.

| ID | Item | Trigger | Notes |
|----|------|---------|-------|
| **POST-RPC** | One RPC entry point, `Connection::doRPCEx(payload, onSuccess, RpcErrorPolicy)` with policies `ShowDialog`, `Ignore`, `Custom` | Next large `connection.cpp` refactor | Today four wrappers sit over `doRPC`: `doRPCWithDefaultErrorHandling` (dialog), `doRPCIgnoreError`, `doRPCIgnoreErrorSafe` (poll paths), and `doRPCSoftDataContinue` (soft status for `getalldata`). `invokeRpcCallbackSafe` (`connection.cpp`: null check and `catch (...)` around success callbacks) serves `doRPCIgnoreErrorSafe` and the main `getinfo` in `getInfoThenRefresh`; fold it into `doRPCEx` as a `SafeCallback` policy and add no further wrapper before then |
| **POST-WIF** | Transparent-key import sends the wrong arguments: `importTPrivKey` (`rpc.cpp`) calls `importprivkey` with `[key, "yes"]` or `[key, "no"]`, but `importprivkey` (`src/wallet/rpcdump.cpp` in Zero) takes `privkey`, `label`, `rescan` and reads `rescan` as a JSON boolean, so `"yes"`/`"no"` becomes the address label and `rescan` stays at its default, true. Fix in `importTPrivKey`: `{"params", { addr.toStdString(), "", rescan }}` | Before advertising WIF import, or when a user reports a slow import | Exposure: File, Import Private Key with transparent keys (lines not starting `SK` or `secret`; `doImport` in `mainwindow.cpp` sends them one at a time and means to rescan only after the last). Each key not already in the wallet gets a label `yes` or `no` and a rescan from genesis holding the wallet lock; N new keys mean N full rescans, and the wallet waits on each (no RPC transfer timeout in `connection.cpp`) while its status polls queue. Keys and funds are imported correctly; the cost is time and wrong labels. Shielded keys (`z_importkey`, where `yes`/`no` is the rescan argument) are not affected. Test: import two new transparent keys on a synced node; `debug.log` shows one `ScanForWalletTransactions` run, and both addresses have an empty label |
| **POST-ZBOARD** | z-board.net bulletin board (Help menu): posts by shielded transaction and memo (`postToZBoard` in `mainwindow.cpp`, `zboard.ui`); topics from plain-HTTP `http://z-board.net/listTopics` (`getZboardTopics` in `rpc.cpp`) | Disable it, or HTTPS or a mirror if the service still exists | Third-party service, possibly gone; topics come over plain HTTP |
| **POST-TLS** | TLS between wallet and `zerod` | A remote-RPC requirement | Same-host `127.0.0.1` today |
| **POST-CRED** | RPC credentials in `QSettings` in plain text (`settings.cpp`) | Credential storage review | OS keychain or encryption |
| **POST-DOCKER** | Docker `ubuntu:16.04` → `24.04`; OpenSSL 1.0.2r → 1.1.1w | CI image refresh | `src/scripts/docker/Dockerfile` only |
| **POST-UI** | Market data tab, translation upstream merge, Midnight theme | Product request | Cosmetic, from safewallet |
| **POST-MXE** | Prebuilt MXE image; MXE with only the modules the wallet links; 32-bit and ARM64 Windows targets | Windows release builds become frequent, or a user asks for another Windows target | `install_mxe.sh` builds `qtbase` and `qtwebsockets` for `x86_64-w64-mingw32.static` into `~/mxe` in 1 to 4 hours on first run |
| **POST-BATCH** | `doBatchRPC` completion timeout | Reports of hanging exports | The completion timer polls forever when a reply is lost |
| **POST-NAME** | Rename `ezcashd` to `embeddedZerod` | A cleanup change | Cosmetic; the binary is already `zerod` |
| **POST-SEND** | `getAllBalances` guards in the send tab: `updateFromCombo` and `maxAmountChecked` have them; `setDefaultPayFrom`, `inputComboTextChanged`, and `confirmTx` do not | Defense in depth | Those three run only after `updateFromCombo` filled the combo, and `balancesReady()` gates the first send; each guard is one line |
| **POST-RECUR** | Recurring payments: `Schedule::YEAR` pays every 5 minutes and is labelled "Every 5 mins" (`getNextPaymentDate` and `schedule_desc` in `src/recurring.cpp`; the yearly line is commented out beside it) | After v4.1.0, which ships it unchanged; or a decision to keep or remove the feature | The feature comes from zec-qt-wallet: the wallet schedules sends itself, stores them in `recurringpayments.json`, and sends a single due payment at a refresh without asking; with several due it asks to pay the latest, all, or none. Payments run only while the wallet is open; the node sees ordinary sends. The 5-minute test value arrived with the 2019 fork commit and is also in safewallet and PirateWallet-Lite; SilentDragon and SevenSeas label it "Every Year". Fix: `addYears(1)` and the label `year`; saved yearly schedules then pay yearly. Evaluate: whether unattended scheduled sends belong in a privacy wallet, since a fixed schedule links payments by timing; test a yearly payment shows a next date one year ahead |
| **POST-LOGS** | Rotate or prune build logs in `logs/` | Disk use becomes a problem | A full `build-qt-static` log is about 30 MB |
| **POST-RESUME** | Resume an interrupted parameter download instead of restarting the file | Users on slow or unreliable connections report repeated downloads | Today a network failure deletes `NAME.dl` and the retry fetches the whole file again (the largest file is 692 MiB). To resume: on a retryable network failure keep `NAME.dl`; before the retry, re-hash its bytes into a fresh `QCryptographicHash` (a local read); request the rest of the current part with `Range: bytes=OFFSET-`, where OFFSET is the size of `NAME.dl`, less the part 1 size when in part 2 (from part 1's `Content-Range` or downloaded length); accept HTTP 206, and on 200 restart the part from its start. Keep the final size and SHA-256 check. Tests: interrupt the network during part 1 and during part 2 of `sprout-groth16.params`; each retry continues from the bytes already written and the file still verifies |
| **POST-QTSMALL** | Smaller static Qt for Linux release builds | Linux release build time or CI download size becomes a problem | Linux only: the macOS release bundles Homebrew `qt@5` with `macdeployqt`, and Windows builds Qt in MXE. `build-qt-static.sh` downloads the full Qt 5.15.18 source (`qt-everywhere-opensource-src-5.15.18.tar.xz`, about 633 MB) and builds it static into `qt5-static/`. The wallet links five modules (`QT += core gui network widgets websockets` in `zero-qt-wallet.pro`), all in `qtbase` and `qtwebsockets`. Branch `wallet-smallqt` (commit `4e922c2`) has two untested scripts, each with its own output directory, beside a generated `Makefile` and a draft `CHANGELOG.md` that do not belong in the build: `build-qt-static-modular.sh` (`-f` full rebuild, `-j N`) downloads only `qtbase` (about 49 MB) and `qtwebsockets` (about 234 KB) from `download.qt.io/archive/qt/5.15/5.15.18/submodules/` and installs to `qt5-static-modular/install`; `build-qt-static-skip-extra.sh` (`-f`, `-u` to reuse the extracted tree, `-j N`) uses the full tarball and `-skip`s every other module, installing to `qt5-static-skip/install`. Validate each on Linux: `<prefix>/bin/qmake -v`; `libQt5Core.a` and `libQt5WebSockets.a` in `<prefix>/lib`; `mkrelease-linux.sh -q <prefix>`; `ldd zerowallet` lists no `libQt5` library; record download size and build time. Fold the faster one into `build-qt-static.sh`, or delete the branch |

### Deprioritized

- Mobile companion over WebSocket: UI removed; no work planned.
