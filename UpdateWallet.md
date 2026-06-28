# UpdateWallet — Project Documentation

Project document for history, directions, design decisions, planning, issue tracking, futures and wants. **Wallet-specific:** bundling zerod, invoking zerod, zerowallet UI and build — not general Zero node information. Covers everything [README](README.md) and [BUILD](BUILD.md) do not.

**Document references:** General — zerowallet [README](README.md), Zero full node [README](https://github.com/zerocurrencycoin/zero) (repo root), Zero project UpdateZero.md (repo root). Canonical chain/coin/ops reference: **Zero repo ZeroCoin.md**. Scope and content policy: §Scope and document policy below.

**Document structure:** User-facing (README, BUILD) = current state only; no future plans. Project (UpdateWallet, Zero’s Subsidy, UpdateZero) = status, plans, futures. Do not reference project docs from user-facing docs.

**Content policy:** Prefer moving content to user-facing docs unless undecided, controversial, sensitive to coin perceptions, or commercial. See §Content policy below. Active items from this document: [TODO](TODO.md).

**Quick find:** [Zcash proving parameters (params download)](#zcash-proving-parameters-params-download) · [Error handling and crash prevention](#error-handling-and-crash-prevention) · [Remaining upstream fixes (STAB, P1, P2)](#remaining-upstream-fixes-stab-p1-p2) · [macOS release: sign, strip, DMG gotchas and fixes](#macos-release-pitfalls-and-solutions) · [Release message handler and qDebug](#release-message-handler-and-qdebug) · [Linux Qt packaging and modules](#linux-qt-packaging-options-and-modules)

---

## Scope and document policy

*Merged from SCOPE.md. Zerowallet-only; not part of Zero repo or UpdateZero.*

### Zero vs zerowallet

| Concern | Zero (full node repo) | zerowallet (this repo) |
|--------|------------------------|-------------------------|
| **Scope** | zerod, zero-cli; chain consensus; mining; subsidy; zeronodes. | Desktop wallet UI; bundles zerod; build and release of wallet + bundled node. |
| **Goals** | Network rules, block reward, halving, consensus upgrades, node/pool operator support. | Reliable wallet builds (Linux, macOS, Windows); clear docs for install and build; no duplicate chain authority. |
| **Docs** | Subsidy.md, UpdateZero.md, README, doc/. Single reference: ZeroCoin.md (Zero repo). | README.md, BUILD.md (user-facing); UpdateWallet.md (project). |
| **TODO / issues** | Zero repo TODO and issue list. | This repo TODO.md. Wallet build, UI, security, deps; references Zero for node behavior. |

**Rule:** zerowallet does not define or override chain rules. It consumes zerod from ZERO_DIR and documents how to build/release the wallet. Chain economics and subsidy live in the Zero repo (Subsidy.md; ZeroCoin.md).

### Content policy: user-facing vs project-internal

**Default:** Prefer moving content into user-facing docs (README, BUILD.md; for chain/coin, Zero repo ZeroCoin.md).

**Keep content project-internal** (UpdateWallet, Zero’s UpdateZero/Subsidy) when it is: undecided; controversial; sensitive to coin perceptions; commercial.

**User-facing:** Current state, install/build steps, script reference, operational how-to. No future promises unless released.

**Project docs:** History, plans, futures, detected errors, version upgrade plan, risk/effort. Do not reference project docs from README or BUILD except via a “For contributors” link.

### Reference documents

| Where | Document | Role |
|-------|----------|------|
| Zero repo | ZeroCoin.md | Single reference for chain, coin, ops. Authoritative for external audiences (miners, pools, exchanges, DEX). |
| zerowallet | UpdateWallet.md | This file; project doc; links to Zero for chain/coin. |

---

## For review: items delegated to other docs/repos

*Copy of the end-group sent to Zero repo UpdateZero.md for routing. Merge of group at the end for review.*

- **→ ZeroCoin.md (Zero repo):** Consolidate history, consensus params, subsidy, halving, zeronodes, supply, ops; MAX_MONEY vs supply; “3888 ZER” clarification.
- **→ Subsidy.md (Zero repo):** §11.3 founders value fix.
- **→ README.md (Zero repo):** Clarify “Stable supply is 3888 ZER” (total supply vs emission rate).
- **→ doc/tor.md (Zero repo):** subver MagicBean → Ambrym.
- **→ zerowallet:** No transfer; zerowallet scope unchanged.

---

## Branch

- **Main line**: `zerowallet-merge`. Experimental upstream ports: `upstream-port` (build/validate before commit).

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

**Reasons for vendoring:**
- Build uses Qt `.pri` only; upstream CMake, examples, `.github/` are unused.
- Vendoring pins the exact version; submodule updates can break the build.
- Simpler for contributors: no `git submodule init/update`.
- Upstream fork chain (SilentDragon, Safewallet) all vendor SingleApplication.

**Usage:** `SingleApplication a(argc, argv, true)` — allow secondary instances. Secondary: `a.sendMessage(uri)` then `a.exit(0)`. Primary: `receivedMessage` → `payZcashURI(uri)`. Enables: single instance, raise existing window, forward payment URIs from second launch.

**Version:** Newer than Safewallet/SilentDragon (2015–2023 license, `userData` param, `SendMode`). Upstream files in `.gitignore`: `.github/`, `examples/`, `CMakeLists.txt`, etc. — not needed for build.

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

macOS injects items into the Edit menu ("Start Dictation", "Emoji & Symbols", "Writing Tools" submenu). These are system menus, not ZeroWallet. App Edit menu items: Address Book, Recurring Payments, Settings.

### File Dialog Default Directory (Refactor Candidate)

`QStandardPaths::writableLocation(QStandardPaths::HomeLocation)` at 5 call sites. Centralizing would simplify future changes (e.g. switch default to Documents).

| File | Line | Usage |
|------|------|-------|
| `src/mainwindow.cpp` | 1168 | Export transactions |
| `src/mainwindow.cpp` | 1206 | Backup wallet.zero |
| `src/mainwindow.cpp` | 1251 | Export private keys |
| `src/addressbook.cpp` | 156 | Import Address Book |
| `src/connection.cpp` | 164 | Choose data directory |

**Proposed helper:** `defaultFileDialogDir()` returning `QStandardPaths::writableLocation(QStandardPaths::HomeLocation)`.

### Payment URI (`zero:`) parsing

**Code:** `Settings::parseURI()` in `settings.cpp` (ported from safewallet `ef8b97a` / [zecwallet #204](https://github.com/ZcashFoundation/zecwallet/issues/204)).

**Format:** `zero:<address>?amt=<amount>&memo=<payload>` (also `amount`, `msg`, `message` for amount/memo keys). Address is extracted with the same regex as before; the query string uses **`QUrlQuery`**, not manual `split("&")` / `split("=")`.

**Base64 memos:** Shielded memos are often base64 (with `=` padding). The old parser split on every `=`, which broke memos or rejected the whole URI. `QUrlQuery` treats only the first `=` per pair as the separator, so **base64 and percent-encoded memo values are supported**.

**Query keys (case-sensitive):** Lookup uses `QUrlQuery::hasQueryItem` / `queryItemValue` with **literal** key names: `amt`, `amount`, `memo`, `msg`, `message`. Unlike the pre-`QUrlQuery` code, keys are **not** lowercased before match — `Memo=` or `AMT=` will not match. Use lowercase keys in URIs (normal for Zcash-style payment URIs).

**Errors vs silence:**

| Situation | Old behavior | Current behavior |
|-----------|--------------|------------------|
| Unknown query key (e.g. `label=foo`) | Ignored | Ignored |
| Malformed pair without `=` | **`ans.error` set; whole URI fails** | Qt/`QUrlQuery` skips; address (+ other valid keys) may still parse |
| Memo with `=` inside value | Often failed or truncated | Parsed correctly |
| Address-only `zero:…` (no `?`) | OK | OK (`?` stripped only when present) |

**Display:** `paymentURIPretty()` still runs `QUrl::fromPercentEncoding` on memo for display; `queryItemValue` already returns decoded text from `parseURI`.

**Consumers:** Second-instance URI forwarding (`SingleApplication`), send/receive prefill, transaction memos containing `zero:…`, request dialog.

**Related security:** Memo **HTML phishing** is separate — `QMessageBox` uses `Qt::PlainText` and tooltips use `toHtmlEscaped()` (`mainwindow.cpp`, `txtablemodel.cpp`).

### Zcash proving parameters (params download)

Single reference for param files, search paths, download behavior, Pirate/SevenSeas comparison, and open questions. **Cryptography runs in zerod**, not the Qt wallet.

#### Who loads what

| Component | Loads params for proving? | Role |
|-----------|---------------------------|------|
| **zerod** | **Yes** — Sprout + Sapling at startup (`ZC_LoadParams` / `pzcashParams`) | Shielded verify/prove; exits with error if files missing |
| **zerowallet** | **No** | Preflight: `verifyParams()` → optional `downloadParams()` → then start/connect zerod |
| **zero-cli** | Same as zerod when run standalone | Uses node param dir |

Wallet download success does **not** guarantee zerod finds files unless both use the **same directory** (default: user home — see below).

#### Required files (all five)

| File | Size (approx.) | Source URL |
|------|----------------|------------|
| `sapling-spend.params` | ~48 MB | `https://z.cash/downloads/sapling-spend.params` |
| `sapling-output.params` | ~3 MB | `https://z.cash/downloads/sapling-output.params` |
| `sprout-proving.key` | ~910 MB | `https://z.cash/downloads/sprout-proving.key` |
| `sprout-verifying.key` | ~1.5 KB | `https://z.cash/downloads/sprout-verifying.key` |
| `sprout-groth16.params` | ~3.6 MB | `https://z.cash/downloads/sprout-groth16.params` |

All Qt wallets in the fork chain download from **z.cash** only (no IPFS/mirror in wallet code). **PirateOcean** node ships `zcutil/fetch-params.sh` / `fetch-params.bat` / NSIS installer with **wget + optional IPFS** fallback — wallet does not use that script.

#### Directory paths (platform)

| OS | Runtime dir (`ZC_GetParamsDir` — PirateOcean / Zcash lineage) | Wallet `zcashParamsDir()` (`connection.cpp`) |
|----|----------------------------------------------------------------|-----------------------------------------------|
| Linux | `~/.zcash-params` | `~/.zcash-params` — **same** |
| macOS | `~/Library/Application Support/ZcashParams` | `~/Library/Application Support/ZcashParams` — **same** |
| Windows | `%APPDATA%\ZcashParams` | `%APPDATA%\ZcashParams` (via `AppDataLocation/../../ZcashParams`) — **same** |

Wallet creates the directory if missing before download. **No `-paramsdir`** is passed when starting embedded zerod (`connection.cpp` 398–405).

#### Search path: zerod vs zerowallet

| Layer | Where it looks | zerowallet today | safewallet | SevenSeas (Pirate Qt) |
|-------|----------------|------------------|------------|------------------------|
| **zerod** | `ZC_GetParamsDir()` only (PirateOcean: `util.cpp` `ZC_GetBaseParamsDir`) — **home paths above**; no cwd/DMG fallback in PirateOcean | Same as Zero lineage (confirm in Zero repo) | safecoind comment says keep in sync with wallet DMG paths — **node may search more** | komodod/pirated — home only |
| **Wallet `verifyParams()`** | Gates first connect | **Home only** — all 5 files must exist | Home **or** cwd `..` / `../safecoin` / `/Applications/.../MacOS` / `./safewallet.app/...` — **sapling only** for bundle paths (`4d48322`) | Home only — all 5 files |
| **Wallet `downloadParams()`** | Target write dir | Always **`zcashParamsDir()`** (home) | Always home (`37e7905`) | Always home |
| **Release bundle** | Beside binary | **Not bundled** (`mkrelease-mac.sh` has no params copy) | `mkmacdmg.sh` copies sapling `.params` into `Contents/MacOS/` | No bundle copy in SevenSeas scripts |

**Gap:** safewallet `verifyParams()` can return true when sapling files sit in `Contents/MacOS/` but **sprout** files are only in home — and zerod still needs all five under `ZC_GetParamsDir()`. Bundle-only sapling does not fully satisfy zerod unless sprout is also present in home or node searches beside binary.

**Embedded zerod cwd:** On Linux/macOS, `QProcess::start(zerod)` does **not** set working directory to `Contents/MacOS` (Windows sets cwd to app dir). Inherited cwd is whatever launched ZeroWallet — so “params beside binary” only helps if **zerod** implements cwd-relative search, not wallet `verifyParams()`.

#### First-connect flow (zerowallet)

```
doAutoConnect()
  → verifyParams() [home, 5 files]
  → if false: downloadParams() [z.cash → home, .part rename]
  → autoDetectZcashConf() / start embedded zerod
  → zerod: ZC_LoadParams() from ZC_GetParamsDir()
```

PirateOcean error if node files missing (`init.cpp`): *“Cannot find the starter Zcash network parameters…”* pointing at `ZC_GetParamsDir()` and `fetch-params.sh`.

#### Pirate / SevenSeas settings (wallet — not node)

**SevenSeas** (`~/Work/ZK/ZKs/SevenSeas`) is the Pirate-chain Qt wallet; **PirateOcean** is the full node. Params behavior matches zerowallet (home download, 5 files, same URLs). **First-run `PIRATE.conf`** differs from zerowallet `zero.conf`:

| Key | zerowallet | SevenSeas |
|-----|------------|-----------|
| `deletetx` / retention | `1`, `keeptxnum=1`, `keeptxfornblocks=1` | — |
| `consolidation` | `1`, fee, addresses UI | — |
| `rpcallow` | — | `127.0.0.1` |
| `addressindex` | — | — |
| `rpcworkqueue` | `256` | — |
| Params UI / settings | None — automatic on connect | None — same |

SevenSeas has **no** Settings entries for params path, DeleteTx, or consolidation. Operator `deletetx` for Pirate is **manual** in `PIRATE.conf` (community docs), same pattern as noted in §DeleteTx.

**PirateOcean node** (for release/ops, not wallet port): `zcutil/fetch-params.sh`, Windows NSIS `install.nsi`, and `fetch-params.bat` all target the same home `ZcashParams` / `.zcash-params` paths as the wallets.

#### Open questions (params — decide before STAB-4 / release work)

1. **macOS DMG:** Bundle all five params beside `zerod`, bundle sapling-only, or rely on first-run download only? safewallet bundles **sapling only** in `mkmacdmg.sh`.
2. **Wallet ↔ node coordination:** If params are bundled in `.app/Contents/MacOS/`, should wallet **copy** them to home on first run, or should embedded zerod get **`-paramsdir=<MacOS>`**?
3. **Zero node search path:** Does zerod (Zero repo) search cwd / binary dir like safewallet’s comment implies for safecoind? PirateOcean does **not** — wallet DMG fallbacks are useless without matching node code.
4. **verifyParams strictness:** zerowallet requires all 5 in home; safewallet accepts sapling-only beside bundle. Align with download list or relax gate?
5. **Offline / mirror:** Wallet only uses HTTPS z.cash; no resume UX beyond `.part` files. Use Pirate-style IPFS fallback or ship params in tarball?
6. **Sprout still required?** All five still downloaded though Sprout is legacy; zerod still loads sprout keys at startup in PirateOcean.
7. **Symlinks:** `verifyParams()` uses `QFile(...).exists()` for param files; `QFile::exists()` (STAB-2) applies to **zerod binary** lookup, not params today.

#### Wallet upstream scope (params)

| Action | Priority | Notes |
|--------|----------|-------|
| Keep home-only **download** (`37e7905`) | Done | Already true |
| Port safewallet multi-path `verifyParams()` (STAB-4) | **Low / defer** | Does not fix zerod without node + release coordination |
| Bundle params in `mkrelease-mac.sh` | **Zero release** | With zerod search or wallet copy/`-paramsdir` |
| Pass `-paramsdir` to embedded zerod | **Design decision** | Only if bundling beside binary |

See also §Remaining upstream fixes (STAB, P1, P2).

### Error handling and crash prevention

How the wallet avoids crashes from RPC/network/JSON failures, what upstream fixed, and what remains on `upstream-port`.

#### Defense layers (architecture)

| Layer | Mechanism | Location |
|-------|-----------|----------|
| **RPC transport** | `doRPC` / `doRPCWithDefaultErrorHandling` / `doRPCIgnoreError` | `connection.cpp`, `connection.h` |
| **Shutdown** | `shutdownInProgress` skips late callbacks | `Connection::doRPC`, `doBatchRPC` |
| **Batch RPC** | Empty `responses` on network/parse failure; timer waits for all replies | `connection.h` `doBatchRPC` |
| **Optional RPC** | `doRPCIgnoreError` — failure → **no success callback** (silent) | Daemon tab polls, export address fetch |
| **User RPC** | `doRPCWithDefaultErrorHandling` — shows `showTxError` | Send, import, export key dump |
| **External HTTP** | `try` / `catch (...)` around JSON parse | `refreshZECPrice`, ZBoard fetch |
| **Null data guards** | `conn == nullptr`, `getAllBalances() != nullptr` before dereference | `rpc.cpp`, `mainwindow.cpp`, `viewalladdresses.cpp` |
| **JSON typing** | nlohmann `json::parse(..., nullptr, false)` + `is_discarded()` | RPC replies, price API |

**Crash pattern:** callbacks that call `reply["field"].get<T>()` without guards when `result` is null, wrong shape, or missing fields.

#### RPC failure scenarios and handling (reference)

**`doRPC` core** (`connection.cpp`) — all wrappers use this:

| Situation | `cb` (success) | `ne` (error handler) | Typical wrapper |
|-----------|----------------|----------------------|-----------------|
| Network failure (refused, timeout, TLS) | Not called | Called | Show or ignore per wrapper |
| HTTP body not JSON / not object | Not called | Called | Same |
| HTTP 200, JSON-RPC `"error": {...}` | Not called | Called | Same |
| HTTP 200, valid `"result"` | Called with `result` | Not called | — |
| `shutdownInProgress` | Not called | Not called | — |

**`doRPCWithDefaultErrorHandling`** — user-initiated RPC (send, import, single-key export, `getinfo` connect path with custom `ne` elsewhere):

- On failure: `showTxError` with RPC message or `QNetworkReply` string.
- Success `cb` only on valid result.
- **Use when:** user must know something failed.

**`doRPCIgnoreError`** — background / optional / multi-path aggregation:

- On failure: silent (no dialog).
- Success `cb` may never run; UI stays stale.
- **Use when:** polling daemon tab, export address **list** fetch (T/Z/U), migration status.
- **Still needs:** null/shape checks or `try/catch` inside `cb` — ignoring transport errors does not make `result` safe to `.get<>()`.

**`doBatchRPC`** (`connection.h`) — parallel posts, timer until `responses.size() == totalSize`:

| Situation | Behavior today | Risk |
|-----------|----------------|------|
| `payloads.isEmpty()` | Returns immediately; **no `cb`** | Export handles via empty-path counter (KEY-1) |
| Per-item network error | Stores `json::object()` for that key | Export skips non-string key with log |
| Per-item JSON-RPC error | Stores `parsed["result"]` (may be null) | `.get<string>()` can throw if not guarded |
| Reply never arrives | Timer loops forever | Hang (export stall) |
| Duplicate parse logic | Does not use fixed `doRPC` | JSON-RPC error not filtered like `doRPC` |

**Phased hardening plan (decided):**

| Phase | What | When |
|-------|------|------|
| **Now (done)** | `doRPC` return + JSON-RPC error gate; `checkForUpdate` catch; KEY-1 TZU export; critical `getAllBalances` guards | `upstream-port` |
| **Next** | STAB-1/2; `doRPCIgnoreErrorSafe` on poll RPCs; `doBatchRPC` JSON-RPC error gate | **Done** (`upstream-port`) |
| **Soon** | `doBatchRPC` batch timeout; optional `getinfo` main-path try/catch | |
| **Later** | Unified `Connection::doRPCEx(payload, onSuccess, RpcErrorPolicy)` | See §Postponed backlog |

**Unified approach (target):** one implementation (`doRPC`), policy enum `{ ShowDialog, Ignore, Custom }`, optional `safeResult` helper for callbacks. **Pragmatic:** keep three wrappers as thin facades over `doRPC` until phase 4; do not block STAB/ daemon fixes on full unification.

#### Private-key export: T `[""]` and path U

**T — `getaddressesbyaccount` with `params: [""]`:** **Certain for Zero.** zerod help text and your CLI: omitted params → error; `""` = default account. zerowallet used `[""]` before KEY-1. safewallet `8febf47` (omit params) is **wrong for Zero** — do not merge.

**Path U — real or hypothetical?**

| Category | Notes |
|----------|--------|
| **Not a race** | TZU runs sequentially; U compares after T completes. |
| **Not empty-wallet behavior** | Fresh wallet: all paths `[]` — normal, no U notice. |
| **Real but uncommon** | t-addr has UTXOs in `listunspent` but not listed under `getaddressesbyaccount ""` — e.g. `importprivkey` via CLI to a **non-default account**, WIF import with wrong RPC args (see P2-wif), restored `wallet.zero` from older tooling, addresses funded before rescan/account labeling settled. |
| **Why keep U** | Low cost when empty; prevents **silent incomplete export** in those cases; notice only when U-only addrs exist. |
| **Not for** | Sprout/chain archaeology, parallel RPC bugs, or minconf `-2` vs `0` on empty wallet (unproven). |

#### `ezcashd` vs `ezerod` naming

| | |
|--|--|
| **Binary** | `zerod` / `zerod.exe` |
| **Code** | `QProcess* ezcashd`, `setEZcashd`, `getEZcashD` — zecwallet lineage |
| **Recommendation** | **Keep `ezcashd` for now** on `upstream-port`. Rename to `embeddedZerod` / `zerodProcess` is clarity-only, wide diff (`connection.cpp`, `rpc.h`, comments), no functional gain. Optional dedicated cleanup PR later; not mixed with STAB/security ports. |

#### P2-wif (`cd4832d`) — reasons deferred

`importTPrivKey` today passes `(privkey, rescan?"yes":"no")` as `importprivkey` params — second arg is **account label**, not rescan (`rpc.cpp` 296–301).

| Reason to defer | Detail |
|-----------------|--------|
| **Import path unclear** | `doImport` treats non-`SK`/`secret` lines as t-keys (`mainwindow.cpp` 993–997) — may be WIF or other formats; fix assumes WIF → `importprivkey` with `""` account. |
| **Rescan semantics** | safewallet `cd4832d` drops rescan from RPC call (`{ privkey, "" }` only); wallet still sets `rescan` flag on **last** key in batch — behavior change needs test plan. |
| **Low exposure** | Settings paste-import is uncommon vs receive/send; wrong import mis-labels keys but may not crash. |
| **When to fix** | Before advertising “import WIF from clipboard” or if QA hits import failures. One-line RPC param fix + manual test. |

#### `getAllBalances` guards — sendtab

| Site | Guard? | OK? |
|------|--------|-----|
| `updateFromCombo` | Yes (202–203) | **Yes** — gates combo population |
| `maxAmountChecked` | Yes (463) | **Yes** |
| `setDefaultPayFrom` / `inputComboTextChanged` / `confirmTx` | No | **OK for now** — only run after combo filled from `updateFromCombo` / user selection; `balancesReady()` gates first-time send. Optional one-line guards = defense in depth, not critical. |

#### z-board

Legacy **Zcash-era bulletin board** (Help → z-board.net): post short messages via shielded tx + memo to forum addresses (`mainwindow.cpp` `postToZBoard`, `zboard.ui`). Fetches topics over **HTTP** `http://z-board.net/listTopics` (`rpc.cpp` 1611). Third-party service; may be dead or untrusted today. Documented as postponed: HTTPS or disable (`TODO.md`, §Detected Errors). Unrelated to export/RPC hardening.

#### Upstream crash fixes (safewallet) vs zerowallet

| Commit | Area | Fix | zerowallet |
|--------|------|-----|------------|
| `9549801` | `checkForUpdate` | `catch (const std::exception&)` before `catch (...)` | **Done** |
| `86c8c58` | theme/currency `e.what()` | Skip — zerowallet uses `catch (...)` without `what()` | **Skip** |
| KEY-1 / `82aa00a` / `2339993` | TZU export | **Done** |
| `09e25c9` | Receive tab balances | **Done** (+ other guards) |
| safewallet daemon try/catch | `getnodeinfo` | `doRPCIgnoreErrorSafe` on poll RPCs | **Done** |

#### Local gaps (remaining)

| Issue | Status |
|-------|--------|
| `doRPC` parse/error gate | **Done** |
| Daemon tab / poll RPCs | **Done** — `doRPCIgnoreErrorSafe` |
| `doBatchRPC` JSON-RPC error on batch items | **Done** |
| `doBatchRPC` timeout | **Postponed** |
| `getInfoThenRefresh` main `getinfo` success cb | Optional try/catch |
| sendtab extra guards | Optional |

#### Port priority (crash prevention)

1. ~~STAB-1 + STAB-2~~ **Done**  
2. ~~P1-daemon / `doRPCIgnoreErrorSafe`~~ **Done**  
3. ~~`doBatchRPC` error filtering~~ **Done**  
4. Optional: `getinfo` main path, sendtab guards  
5. See §Postponed backlog: P2-wif, unified `doRPCEx`, z-board

### Remaining upstream fixes (STAB, P1, P2)

Status on branch `upstream-port` unless noted. Build/run before commit.

#### P0 (next)

| ID | Commits | Files | What | Status |
|----|---------|-------|------|--------|
| **KEY-1** | `8febf47`, `fb07f35`, `82aa00a`, `2339993` (ideas) | `rpc.cpp` | **3-path TZU `getAllPrivKeys`:** T `getaddressesbyaccount` **`[""]`** (required by zerod), Z `z_listaddresses`, U `listunspent` `0` for addrs not on T; sequential TZU; `doRPCIgnoreError`; U recovery notice | **Done** on `upstream-port` |

#### P1 — stability and hardening

| ID | Commit | File(s) | What | zerowallet today | Port action |
|----|--------|---------|------|------------------|-------------|
| **STAB-1** | `5652c56` | `connection.cpp` | `start(prog, QStringList())` all platforms | **Done** |
| **STAB-2** | `f9bb79d` | `connection.cpp` | `QFile::exists` for zerod binary | **Done** |
| **STAB-3** | `37e7905` | `connection.cpp` | Download params to user home only; drop `/usr/share` fallback | Home-only `zcashParamsDir()`; no `/usr/share` | **Done** |
| **STAB-4** | `4d48322`+ | `connection.cpp` (safewallet) | DMG/cwd sapling lookup in `verifyParams()` | Home-only, all 5 files | **Defer** — see §Zcash proving parameters |
| **P1-mem** | `9549801` | `rpc.cpp` | `checkForUpdate`: catch `std::exception` before `catch (...)` | **Done** (`upstream-port`) | — |
| **P1-exc** | `86c8c58` | `mainwindow.cpp` | Theme/currency: do not call `e.what()` | Uses `catch (...)` without `what()` | **Skip** |
| **P1-rpc** | (local) | `connection.cpp` | `return` after bad parse; skip `cb` on JSON-RPC `error` | **Done** — safewallet **same bug** (`isNull` then `cb`, no return) | — |
| **P1-daemon** | (local) | `connection.cpp`, `rpc.cpp` | `doRPCIgnoreErrorSafe` — try/catch + null guard on poll callbacks | **Done** |

#### P2 — UX and import

| ID | Commit | File(s) | What | zerowallet today | Port action |
|----|--------|---------|------|------------------|-------------|
| **P2-sync** | `b9f1ea3` | `connection.cpp` | After RPC connect: delay **3s→5s** before `doRPCSetConnection`; loading poll **6s→10s** | Success path: **no** delay before `doRPCSetConnection` (478); poll **1s** (505) | **Optional** — different from safewallet; evaluate if splash/RPC races occur |
| **P2-send** | `5c06218` | `mainwindow.cpp`, `mainwindow.ui`, `rpc.cpp` | Hide **Send** until fully synced or tx confirmed | `lblSyncWarning` only (`rpc.cpp` 796–797); Send stays enabled | **Optional UX** — reduces unsynced sends |
| **P2-wif** | `cd4832d` | `rpc.cpp` | `importprivkey` account `""` | Wrong RPC shape | **Postponed** — POST-WIF |

#### Not in STAB table (do not confuse)

- **`b9f1ea3` is not STAB-1** — timer delays only, not spaces-in-path.
- **SEC-1, SEC-2** — merged (memo phishing, `QUrlQuery`).
- **DeleteTx `1`/`1` vs zerod `200`/`10000`** — zerowallet product choice, not safewallet port; see §DeleteTx.

#### Suggested port order

1. **KEY-1** (P0) — functional gap for export  
2. **STAB-1** + **STAB-2** (P1) — daemon launch reliability  
3. **P2-wif** — if import-from-clipboard is in test plan  
4. **P1-mem** / **P1-exc** — quick hardening  
5. **P2-sync** / **P2-send** — only if QA shows race or user confusion  
6. Params **release/node** decisions (§ open questions) — parallel track in Zero repo, not wallet STAB-4

#### Validation tied to remaining fixes

| Fix | Test |
|-----|------|
| KEY-1 | Wallet with unlabeled/imported funded t-addr: export includes it via U + notice; fresh empty wallet: all RPCs `[]`, export empty, no notice |
| STAB-1 | Install under path with spaces; embedded zerod starts |
| STAB-2 | Broken symlink at `zerod` path → clean “not found” (not false positive) |
| P2-wif | Import WIF via Settings; key appears in default account; rescan behavior as expected |
| P2-send | While `verificationprogress` &lt; 99.9%, Send hidden (if ported) |
| Params | Fresh machine: wallet downloads 5 files to home; embedded zerod starts without param error |

### zerod Features: Document and Test Coverage

| Feature | zerod config / RPC | zerowallet code | Test coverage |
|---------|--------------------|-----------------|---------------|
| **rescan** | `rescan=1` in zero.conf; restart zerod | `rpc.cpp` remove rescan after use; `mainwindow.cpp` import keys with rescan; `connection.cpp` rescan detection | Manual: import key, external zerod restart |
| **reindex** | `reindex=1` in zero.conf; restart zerod | `rpc.cpp` remove reindex after use; Settings Reindex button writes to conf, restarts wallet | Manual: Settings → Reindex, restart |
| **deletetx** | `deletetx=1` (+ `keeptxnum`, `keeptxfornblocks`) in zero.conf | `mainwindow.cpp` 732–747 toggle; `connection.cpp` 201–203 (first-run defaults), 667–668; `settings.ui` chkDeleteTx | Manual: Settings → Wallet Config → enable; restart embedded zerod. **Not** a wallet UI to delete one transaction — zerod prunes old wallet data. See §DeleteTx and §lblSyncWarning below. |
| **consolidation** | `consolidation=1`, `consolidationtxfee`, `consolidationaddresses` | `mainwindow.cpp` 543–635, 753–764; `connection.cpp` 206–208, 673–682; `settings.ui` 306, 323, 404 | Manual: enable consolidation, set fee, add addresses |
| **Custom fields** | consolidation addresses list | `settings.consolidationAddressTable`; `ConsolodationAddressModel`; context menu Copy/Delete | Manual: add/remove addresses |
| **shield change** | zerod behavior | `websockets.cpp` 688: TODO Respect autoshield change setting | Not implemented |

**Gaps:** No automated tests. Shield change setting not wired. Rescan/reindex require zerod restart; external zerod needs manual `-rescan`/`-reindex`.

**Zero test and doc support:** Zero repo ([zerocurrencycoin/Zero](https://github.com/zerocurrencycoin/Zero)) has `doc/`, `contrib/`, `qa/`. `zerod -?` lists command-line options. Sample configs: `contrib/zero.conf`, `contrib/debian/examples/zero.conf`. Reindex, rescan, deletetx, consolidation are zerod config options; Zero's own test coverage and documentation for these live in the Zero repo (e.g. `qa/` RPC tests, UpdateZero.md if present). zerowallet does not duplicate Zero's option docs; consult Zero for authoritative behavior and tests.

### DeleteTx (zerod feature, wallet toggle)

**What it is:** A **zerod** wallet-maintenance option (Komodo/Zero lineage, Zero v3.1.0+), not a “delete this transaction” button in the GUI.

When `deletetx=1`, zerod periodically removes old spent notes/TXOs and outgoing transactions whose inputs are gone, shrinking `wallet.zero` and improving performance. Companion options:

| Option | zerowallet first-run default | Typical production (Zero/Pirate docs) |
|--------|------------------------------|----------------------------------------|
| `deletetx` | `1` | `1` |
| `keeptxnum` | `1` since wallet added feature (2020) | **200** (zerod default if omitted); Pirate ops often **1000** |
| `keeptxfornblocks` | `1` since wallet added feature (2020) | **10000** (zerod default if omitted) |

**History (this repo):** Commit `05f935b` (Cryptoforge, 2020-11-12, “update settings to include DeleteTx and Consolidation”) added `deletetx=1`, `keeptxnum=1`, `keeptxfornblocks=1` to first-run `zero.conf` and the Settings toggle (which writes the same `1`/`1` values). Before that, autogenerated conf had no DeleteTx keys. **200 / 10000 never appeared in zerowallet source** — they are documented in [Zero v3.1.0 release notes](https://github.com/zerocurrencycoin/Zero/releases/tag/v3.1.0) as zerod daemon defaults when options are omitted, and in Komodo/Hush/Pirate operator guides. Wallet chose `1`/`1` deliberately (minimal retention); consider aligning with zerod defaults in a future change.

**Wallet role:** On first `zero.conf` creation (`connection.cpp`), zerowallet writes the defaults above. Settings → Wallet Config → **Enable DeleteTx** adds/removes `deletetx=1` in `zero.conf` (embedded zerod only). Requires zerod restart to take effect. No per-tx delete in the transactions table.

**Upstream:** safewallet and SevenSeas do **not** expose DeleteTx in their autogenerated confs. Pirate community docs recommend `deletetx=1` manually in `PIRATE.conf`. Zero is the authority.

### lblSyncWarning

Red labels on **Send** and **Receive** tabs (`mainwindow.ui`: `lblSyncWarning`, `lblSyncWarningReceive`):

> “Your node is still syncing, balances may not be updated”

Toggled in `rpc.cpp` `getInfoThenRefresh()` when `verificationprogress < 0.999` (`lblSyncWarning->setVisible(isSyncing)`). Hidden on startup in `mainwindow.cpp`. Informs the user that balances may be stale while IBD/sync is in progress — distinct from DeleteTx.

### Autogenerated `.conf` comparison (first-run wizard)

| Key | zerowallet `zero.conf` | safewallet `safecoin.conf` | SevenSeas `PIRATE.conf` |
|-----|------------------------|----------------------------|---------------------------|
| Path | `~/.zero/zero.conf` (platform variants) | `~/.safecoin/safecoin.conf` | `~/.komodo/PIRATE/PIRATE.conf` |
| `server` | `1` | `1` | `1` |
| `rpcuser` | `zero` | `safecoin` | `sevenseas` |
| `rpcpassword` | random 20 chars | random | random |
| `rpcport` | `23811` | `8771` | `45453` |
| P2P `port` | — | `8770` | — (daemon CLI args on embed) |
| `rpcworkqueue` | `256` | `256` | — |
| `txindex` | `1` | `1` | `1` |
| `addressindex` | — | `1` | — |
| `deletetx` / retention | `1`, `keeptxnum=1`, `keeptxfornblocks=1` | — | — |
| `consolidation` | `1`, `consolidationtxfee=10000` | — | — |
| `fastsync` | disabled in UI | optional from wizard | — |
| `rpcallow` / bind | — | — | `rpcallow=127.0.0.1` |
| `datadir` / `proxy` | optional from wizard | optional | optional |

All three download Sapling/Sprout params from `z.cash` into the user home params dir (`~/.zcash-params` on Linux).

**RPC deployment (decision):** Postpone TLS/HTTPS for wallet↔zerod. Recommended model: wallet and zerod on the **same machine**, RPC to `127.0.0.1` only. Document in user-facing README when remote RPC is discouraged.

---

## macOS release: pitfalls and solutions

Summary of issues we hit with macOS build, sign, strip, and DMG, what we did, and how to avoid or debug them. Script: `src/scripts/mkrelease-mac.sh`. User-facing flow: [BUILD](BUILD.md) §macOS App Signing and Distribution. Troubleshooting table: BUILD §Troubleshooting.

### Signing

| Problem | Cause | Solution / current state |
|--------|--------|---------------------------|
| **EXC_BAD_ACCESS (Code Signature Invalid)** on launch | App bundle was unsigned. macOS enforces signature for running GUI apps. | **Always sign.** Script runs `codesign` in all cases. Use **ad-hoc** when no Developer ID: `-N` or unset `CODESIGN_IDENTITY` → `codesign --sign "-"`. For distribution: set `CODESIGN_IDENTITY="Developer ID Application: …"` and notarize (BUILD §Developer ID + notarization). |
| Unclear whether build used ad-hoc or identity | — | Script prints `Signing (ad-hoc)` or `Signing (identity: …)` before running codesign. |

**Mitigation:** Never skip signing for the built app. `SKIP_SIGN` is only for special cases and still results in ad-hoc (identity `-`).

### Stripping

| Problem | Cause | Solution / current state |
|--------|--------|---------------------------|
| **DMG / app very large** (e.g. 24MB+ DMG, zerod ~13MB) | zerod from `ZERO_DIR` may be debug or unstripped; on Linux stripped zerod is a couple MB. | Script strips `ZeroWallet`, `zerod`, and `zero-cli` inside the app bundle by default. Use **`-P` / `--nostrip`** only to keep symbols for debugging. For smaller DMG, build zerod in Zero repo as **release + strip** so the binary copied into the app is already small. |
| Need symbols for crash debugging | Default is strip. | Run mkrelease with `-P`; artifacts are larger but symbols remain. |

**Mitigation:** Document in BUILD that "if DMG is unexpectedly large, ensure zerod in ZERO_DIR was built release and stripped." Script prints DMG format and size (e.g. `DMG: UDZO, 24MB`) so format (UDZO = compressed) and size are visible.

### DMG (create-dmg / hdiutil)

| Problem | Cause | Solution / current state |
|--------|--------|---------------------------|
| **hdiutil: convert failed - File exists** | `hdiutil convert` does not overwrite the output file. Leftover DMG or temp from a previous run. | Script **removes** `artifacts/macOS-zerowallet-v*.dmg` and `artifacts/rw.*.macOS-zerowallet-v*.dmg` **twice**: once at start (with other cleanup), once **immediately before** create-dmg. No manual rm needed in normal runs. |
| **create-dmg very noisy** (Creating disk image…, Mounting…, Will sleep for 2 seconds…, etc.) | create-dmg and hdiutil print progress to stdout/stderr. | **Quieter by default:** script uses `--hdiutil-quiet` and redirects create-dmg stdout to `/dev/null`. On failure, **re-run with `CREATE_DMG_VERBOSE=1 ./src/scripts/mkrelease-mac.sh`** to see full hdiutil/create-dmg output. Documented in BUILD §Troubleshooting. |
| **"hdiutil does not support internet-enable"** | Informational; internet-enable was removed in macOS 10.15. | Harmless; DMG is still built. Can appear on stderr even with `--hdiutil-quiet`. |
| **Unclear if DMG is compressed** / suspicious size | Need to confirm format (UDZO = zlib compressed). | After create-dmg, script runs `hdiutil imageinfo` and prints one line: `DMG: UDZO, N MB`. If format is not UDZO, something is wrong. |
| **App missing if create-dmg fails** | Previously create-dmg was run before moving the app to artifacts. | Script **moves app to `artifacts/` first**, then runs create-dmg. If create-dmg fails, `artifacts/ZeroWallet.app` is still there. |
| **Temp rw.*.dmg left behind on failure** | create-dmg creates read-write temp images. | Script does **not** promote or keep rw.* on success; cleanup on next run. On failure, leave rw.* for inspection; next run removes them. |

**Mitigation:** BUILD §Troubleshooting row for "DMG not created / create-dmg fails" points to `CREATE_DMG_VERBOSE=1` and "File exists".

### Other macOS build / dev

| Problem | Cause | Solution / current state |
|--------|--------|---------------------------|
| **PlugIns / ln failure in .pro** (e.g. "No such file or directory" for PlugIns) | qmake expanded `$$TARGET.app` to empty in some contexts, so path to app bundle was wrong. | **Use literal `ZeroWallet.app`** in `zero-qt-wallet.pro` for PlugIns path and clean-app-deploy (not `$$TARGET.app`). See BUILD §Troubleshooting for PCH. |
| **PCH: __OPTIMIZE__ predefined macro was enabled in PCH file but is currently disabled** | PCH built with one CONFIG (debug vs release), then build switched. | Clean and rebuild: `./src/scripts/mkdev.sh -c -L`. Documented in BUILD §Troubleshooting. |

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

**Branch for experimental ports:** `upstream-port` off main line. Merge only after build + validation checklist. No commit until mkdev/mkrelease succeeds locally.

**Reference clones:** `~/Work/ZK/ZKs/safewallet`, `SilentDragon`, `SevenSeas` (Pirate Qt wallet).

### Current Status

| Item | Value |
|------|-------|
| **Common ancestor with safewallet** | `6ec2115e94d61082466c8d1004be9333b0a7e1ab` |
| safewallet ahead of ancestor | ~310 commits (many SAFE branding) |
| SevenSeas vs safewallet merge-base | `2bd0b47` (shared zecwallet-era history) |

### Priority (Jun 2026)

| Priority | Area | Source |
|----------|------|--------|
| **P0** | Memo phishing (`PlainText` + `toHtmlEscaped`), payment URI `QUrlQuery` | **Done** on `upstream-port` — see §Payment URI (`zero:`) parsing |
| **P0** | Private-key export: 3-path `getAllPrivKeys` + empty-list handling | safewallet `8febf47`, `30899ac`, `82aa00a` — §Remaining upstream fixes |
| **P1** | Daemon launch: spaces in path, `QFile::exists` symlinks | STAB-1, STAB-2 — §Remaining upstream fixes |
| **P1** | Params: home download done; bundle/search → Zero node + release | §Zcash proving parameters (open questions) |
| **P1** | Memory/exception hardening | P1-mem, P1-exc — §Remaining upstream fixes |
| **P2** | Sync poll delays, hide Send until synced, WIF import | P2-sync, P2-send, P2-wif — §Remaining upstream fixes |
| **Review** | Build/cross-compile fixes | safewallet + SevenSeas build scripts; separate review |
| **Postponed** | See §Postponed backlog | WIF import, unified RPC, z-board, infra, UI |
| **Deprioritized** | Mobile / WebSocket (deprecated path) | See §Mobile and WebSocket |

### Postponed backlog (no scheduled work)

Organized by area. Track here and in [TODO](TODO.md); do not mix into active upstream-port unless explicitly promoted.

| ID | Item | Trigger to revisit | Notes |
|----|------|-------------------|--------|
| **POST-RPC** | Unified `Connection::doRPCEx` / `RpcErrorPolicy` enum | Next large `connection.cpp` refactor | Phase 4; keep `doRPCWithDefaultErrorHandling` / `doRPCIgnoreError` / `doRPCIgnoreErrorSafe` as thin wrappers until then |
| **POST-WIF** | P2-wif `cd4832d` — `importprivkey` `{ key, "" }` not rescan as 2nd arg | QA on Settings paste-import or WIF docs | `importTPrivKey` in `rpc.cpp`; batch rescan semantics need test plan — §P2-wif |
| **POST-ZBOARD** | z-board.net HTTP API + post UI | Disable feature, or HTTPS/mirror if service still exists | Help → z-board.net; `getZboardTopics` HTTP `listTopics`; MITM risk — §z-board |
| **POST-TLS** | TLS/HTTPS wallet↔zerod | Remote RPC requirement | Use same-host `127.0.0.1` today |
| **POST-CRED** | Plain-text RPC creds in `QSettings` | Security audit | OS keychain / encrypt |
| **POST-DOCKER** | Docker `ubuntu:16.04` → `24.04`; OpenSSL 1.0.2 → 1.1.1 | CI image refresh | `src/scripts/docker/Dockerfile` |
| **POST-UI** | Market data tab; translation upstream merge; Midnight theme | Product request | safewallet-only cosmetics |
| **POST-PARAMS** | macOS param bundle / `-paramsdir` / STAB-4 | Zero release + zerod search path decision | §Zcash proving parameters |
| **POST-BATCH** | `doBatchRPC` completion timeout | Export hang reports | Timer polls forever if reply lost |
| **POST-NAME** | Rename `ezcashd` → `embeddedZerod` | Dedicated cleanup PR | Cosmetic; binary already `zerod` |
| **POST-SEND** | Extra `getAllBalances` guards on sendtab | Defense in depth only | Low risk today — §getAllBalances guards |

### Private-key export: 3-path vs 2-path

**2-path (SevenSeas / old zerowallet):** `getaddressesbyaccount` `[""]` + `z_listaddresses` only.

1. **T** — `getaddressesbyaccount` with **`params: [""]`** only (zerod **rejects** omitted params; safewallet `8febf47` omit-params is wrong for Zero)
2. **Z** — `z_listaddresses` → `z_exportkey`
3. **U** — `listunspent` with **`minconf: 0`** (same as `getTransparentUnspent`). Runs **after** T so only t-addrs **not** in T are exported; logger + dialog **only if** U finds such addrs.

Sequential TZU; `doRPCIgnoreError` on address fetches; empty paths still advance counter; failed key dumps skipped with log.

**Fresh / empty wallet:** On a brand-new wallet (no t/z addrs, no UTXOs, no keys yet), all three RPCs legitimately return `[]` — that is not a minconf or TZU bug. Export finishes with an empty key list and **no** U notice. Re-test U recovery on a wallet that has funded t-addrs visible in `listunspent` but missing from `getaddressesbyaccount ""` (e.g. after import without account label).

**Zero RPC note:** `getaddressesbyaccount` **without** params errors on zerod; must pass `[""]` for the default account (safewallet `8febf47` omit-params does not apply).

### Spaces in application path (why Linux/Windows, not macOS today)

safewallet `5652c56`: `ezcashd->start(program, QStringList())` instead of `start(program)`.

On **Qt 5**, the single-argument `QProcess::start(const QString &command)` parses `command` as a **shell command line** (splits on spaces). If the app lives under a path like `/Applications/My Wallet/zerowallet.app/.../zerod`, the path can be split incorrectly. The two-argument form `start(program, QStringList())` executes `program` directly with no shell parsing.

**macOS today:** Typical `.app` bundles use `Contents/MacOS/zerod` with no spaces in the executable path; risk is lower but the fix is still correct for installs under `Application Support/...` with spaces. **Windows:** `setWorkingDirectory` + `start(program, QStringList())` — **STAB-1 done** (`connection.cpp`).

### How to review upstream commits before merge

```bash
# In zerowallet, with remotes:
git remote add safewallet https://github.com/Fair-Exchange/safewallet.git  # once
git fetch safewallet

# Show patch for one commit (prefer over blind cherry-pick):
git show safewallet/master:<path>   # e.g. src/rpc.cpp
git diff HEAD safewallet/master -- src/rpc.cpp src/mainwindow.cpp

# Commits since fork (filter noise):
git log --oneline 6ec2115..safewallet/master --no-merges -- src/rpc.cpp src/connection.cpp src/mainwindow.cpp src/settings.cpp src/txtablemodel.cpp

# Compare with Pirate wallet (SevenSeas):
git -C ~/Work/ZK/ZKs/safewallet fetch ../SevenSeas master:sevenseas/master
git log --oneline sevenseas/master..safewallet/master --no-merges | head
```

**Workflow:** (1) Visual review in editor (§Reviewing upstream commits in VS Code/Cursor). (2) Apply on `upstream-port`. (3) **Build and run** before any commit. (4) Validation checklist. (5) One commit per logical fix.

### Reviewing upstream commits in VS Code / Cursor

| Goal | Tool | How |
|------|------|-----|
| Browse upstream history | **GitLens** | Repositories → `safewallet` remote → Commits on `safewallet/master`; click commit for per-file diff. |
| Graph + cherry-pick | **Git Graph** | View graph → right-click commit → Cherry Pick; or `git cherry-pick -n <sha>` for no-commit apply. |
| Compare branches | Built-in | Command Palette → **Git: Compare References…** → `HEAD` vs `safewallet/master`. |
| Upstream file at tip | GitLens / `git show` | `git show safewallet/master:src/rpc.cpp` in editor; split with local file. |
| Inspect before commit | `cherry-pick -n` | Patch in Source Control view; build; then commit or `cherry-pick --abort`. |
| Merge conflicts | **Merge Editor** | Only if merging; 3-pane resolve. Prefer `-n` cherry-picks here. |

### Private keys: export, import, WIF

| Topic | Convenience | Accuracy | Security |
|-------|-------------|----------|----------|
| **Export all keys** | One dialog | **TZU 3-path** (T `[""]`, Z, U); U-only addrs get notice | Plaintext in dialog/file — user must protect output |
| **Import paste** | Multi-line | `importTPrivKey` uses 2nd param as **account**, not rescan — WIF/rescan wrong | High risk; clipboard exposure |
| **WIF** | Interop with other wallets | Fix: `importprivkey` + `""` account (safewallet `cd4832d`) — **P2** | Treat like seed phrase |

### Recommended ports (manual; do not blind cherry-pick series)

| ID | Commits / source | Files | Notes |
|----|------------------|-------|-------|
| SEC-1 | SevenSeas `f9c7206` or safewallet `212b0e4` | `mainwindow.cpp`, `txtablemodel.cpp` | **Merged** — `PlainText`, `toHtmlEscaped` |
| SEC-2 | safewallet `ef8b97a` | `settings.cpp` | **Merged** — `QUrlQuery`; see §Payment URI (`zero:`) parsing |
| KEY-1 | safewallet bundle | `rpc.cpp`, maybe `connection.h` | Full `getAllPrivKeys` 3-path |
| STAB-1 | `5652c56` | `connection.cpp` | `start(prog, QStringList())` all platforms |
| STAB-2 | `f9bb79d` | `connection.cpp` | `QFile::exists` for daemon binary |
| STAB-3 | `37e7905` | `connection.cpp` | Confirm no `/usr/share` fallback (likely already) |
| STAB-4 | `4d48322`+ | `connection.cpp` (safewallet) | **Low priority for wallet** — DMG/cwd lookup targets **zerod** proving; see §Zcash params. Wallet only downloads to home. |

**Not** `b9f1ea3` in the “spaces” slot — that commit only increases RPC poll timers (3s→5s, 6s→10s).

### Validation after each port

| Check | How |
|-------|-----|
| Build | `./src/scripts/mkdev.sh` or platform mkrelease |
| Connect | Embedded zerod starts; RPC to `127.0.0.1` |
| Sync warning | `lblSyncWarning` visible while `verificationprogress` &lt; 99.9% |
| Export keys | All t- and z-addrs listed; include unlabeled t-addr case |
| Payment URI | `zero:…?memo=` with **base64** memo (contains `=`); lowercase keys only; malformed extra params must not fail whole URI |
| Memo dialog | HTML in memo displays as plain text |
| Params | Fresh install: wallet downloads to `~/.zcash-params` (or macOS `ZcashParams`); **zerod** must find same files at runtime — test embedded start, not wallet-only paths |
| Path with spaces | Install under directory with space; embedded zerod starts (after STAB-1) |
| Regression | Testing Checklist §Recent Fixes + §Major Functionality |

### Merge Conflict Strategy

1. **Branding** (CSS, logos, `.ts`) — keep Zero; do not take upstream branding commits.
2. **Configuration** — Zero ports, RPC 23811, `zero.conf` keys.
3. **UI labels** — zeronodes, ZER, Zero terminology.
4. **Build scripts** — merge improvements; adapt `ZERO_DIR`, artifact names.

### Mobile and WebSocket (deprecated)

**History:** zecwallet Qt (~2019) shipped a phone **companion**: local WebSocket on port 8237, optional **wormhole** relay (`wormhole.zecqtwallet.com`) so a phone could proxy balances, tx list, and sends via the desktop node. Inherited by SilentDragon/safewallet; modern Zcash mobile uses **Electron/light clients**, not this protocol.

**Why deprioritized:** No Zero mobile app; wormhole is third-party Zcash infrastructure; `AnyIPv4` listener adds attack surface without benefit.

**Now:** Connect Mobile **removed from UI** (Apps menu gone; Validate Address under Edit). `websockets.cpp` still built but **unreachable**. May delete later; QtWebSockets link dependency remains until then.

### Glossary (upstream / Pirate UI)

| Term | Meaning |
|------|---------|
| **WIF** | Wallet Import Format — base58 private key (`5`/`K`/`L`…). See §Private keys: export, import, WIF. |
| **NTZ** | **Notarization** (Komodo): `getinfo` fields `notarized`, `notarizedhash`, `notarizedtxid` — cross-chain notarization to KMD. SevenSeas **hushd/zerod tab** shows these (`a8b4a76`). **Not in zerowallet** (Zero may expose via `getinfo` but UI does not). |
| **netinfo** | SevenSeas `getnetworkinfo` RPC for P2P connection details on daemon tab (`c773131`). zerowallet daemon tab uses different `getinfo` fields only. |

### Midnight theme (safewallet only — reference)

safewallet `res/css/midnight.css` (Charles Sharpe, MIT): flat dark Qt stylesheet — background `#111`, text `#fff`, inputs `#222`, gold focus border `#9d8400`, gradient tabs. Selected in Settings theme dropdown (`midnight`). zerowallet has `zero`, `matrix`, `light`, `blue`, `dark`, etc., but **not** Midnight. Preview: open `~/Work/ZK/ZKs/safewallet/res/css/midnight.css` or run safewallet and select Midnight in settings.

### Automated merge (not recommended wholesale)

```bash
git checkout upstream-port
# Prefer file-scoped manual ports (table above), not:
# git merge safewallet/master
```

### Upstream Gaps

- RPC logging in safewallet/SilentDragon
- zerowallet-specific: DeleteTx `1`/`1` defaults vs zerod `200`/`10000`, consolidation UI, zeronode tab

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
cp README.md release/zerowallet-v$APP_VERSION/
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

**Conclusion:** MXE (Option 1) is recommended: proven compatibility, static linking, integration with existing build scripts.

---

## Wallet / zerod Flow

- First connect: `refreshAddresses()` → `getnewaddress` when no t-addrs; `addNewZaddr()` when user selects z-addr and none exist
- zerod default datadir: `~/.zero/`

---

## Release message handler and qDebug

**Location:** `src/main.cpp`, inside `Application::main()`, guarded by `#ifndef QT_DEBUG`.

**What it does:** In release builds only, a custom `qInstallMessageHandler` is installed that (1) drops all `QtDebugMsg` (so every `qDebug()` is silent), and (2) drops `QtWarningMsg` whose text contains `QNetworkReply::` or `QIODevice::` (Qt network layer noise). All other messages (warnings, critical, fatal) are passed through to the previous handler or to stderr.

**Justification:** Same idea as Bitcoin Core PR #7692 — debug logs are for developers, not for end users. Shipped builds should not clutter the console with "Loading locale", "Downloading ... to ...", RPC payloads, or Qt’s internal network warnings. In debug builds (`QT_DEBUG` defined) the handler is not installed, so all qDebug and warnings appear as usual.

**Commented-out calls:** Low-value messages are left in source as commented-out so the next developer can re-enable them. In `main.cpp`: a "Loading locale" qDebug after `installTranslator`. In `connection.cpp`: download URL, "Can't find zerod at", file error string, and RPC payload lines (751–752). Uncomment as needed for debugging.

**Re-enabling output:** (1) Build with debug (qmake without `CONFIG+=release` / with `CONFIG+=debug`) so `QT_DEBUG` is defined and the handler is not used. (2) Or at runtime: `QT_LOGGING_RULES="*.debug=true"`. (3) Or uncomment specific qDebug lines in source.

**Other qDebug:** Still active in source (and suppressed at runtime in release by the handler) in websockets.cpp, turnstile.cpp, mainwindow.cpp, rpc.cpp, recurring.cpp, settings.cpp.

---

## How zerod Gets Bundled

zerod built separately, copied into zerowallet package. **ZERO_DIR** = directory containing built zerod/zero-cli (or .exe); default `../Zero/src`. Zero repo build: Linux `./zcutil/build.sh` → `zero_linux/src/`; Windows `./zcutil/build-win.sh` → `zero_win/src/`. Scripts use **QT_PREFIX** (not QT_STATIC) for Qt path in mkdev/mkrelease. For script reference, flags (`-z`, `-v`, `-p`, `-q`, `-P`/`-N`, `-m`, `-L`), APP_VERSION/PREV, stripping, signing, and platform notes see [BUILD](BUILD.md) §Script Reference, §Unified Arguments, §ZERO_DIR, §APP_VERSION, §PREV, §Platform Notes. CI plans: ~/Work/ZK/CI/README.md.

---

## Linux Qt: packaging options and modules

### Why macOS uses Homebrew Qt (dynamic) and Linux uses static

**macOS:** We use Homebrew Qt (dynamic link at build time). **macdeployqt** copies the Qt frameworks and plugins *into* the app bundle, so the shipped DMG is self-contained; the user does not install Qt. Effectively we bundle Qt with the app.

**Linux:** Qt does not ship an official “linuxdeployqt.” Options:

| Approach | Pros | Cons |
|----------|------|------|
| **Static Qt (what we do)** | Single binary (plus zerod/zero-cli) runs on many distros; no system Qt or version matrix. One-time cost: build Qt from source (`build-qt-static.sh`). | Long one-time build (~30–60 min); must rebuild Qt when upgrading. |
| **Dynamic + system .deb** (e.g. `qtbase5-dev`, `libqt5websockets5-dev`) | No Qt build; use system packages for dev. | For *release* we would either require the user to install Qt (bad UX, version/distro matrix) or ship a binary that breaks on other distros. Not used for release. |
| **Dynamic + bundle** (e.g. **linuxdeploy** + **linuxdeploy-plugin-qt**; AppImage) | Similar idea to macdeployqt: copy Qt libs into an app dir, fix rpaths; can produce AppImage. | Different workflow and tooling; more moving parts. We chose static for simpler artifacts (tarball + .deb) and broad compatibility. |

So: **Mac = dynamic build, Qt bundled into .app via macdeployqt. Linux = static build, no bundling step.**

### Qt modules we use

From `zero-qt-wallet.pro`: `QT += core gui network`, then `QT += widgets` and `QT += websockets`. So the Qt modules (and the libraries we actually link) are:

| Module | Qt library | Use in zerowallet |
|--------|------------|-------------------|
| core | Qt5Core | Base types, event loop, QSettings, etc. |
| gui | Qt5Gui | Painting, fonts, images, OpenGL abstraction. |
| network | Qt5Network | QNetworkAccessManager, RPC HTTP, param downloads. |
| widgets | Qt5Widgets | UI (windows, dialogs, buttons, tables). |
| websockets | Qt5WebSockets | Legacy mobile path (deprecated; see §Mobile) |

We do *not* use (and `build-qt-static.sh` skips or does not enable): webengine, Qt Quick/QML (beyond what widgets may pull), Qt Multimedia, Qt SQL, etc. MXE build uses `qtbase qtwebsockets` only. SingleApplication is vendored (not a Qt module).

### Qt versions in Ubuntu (apt)

Distro packages are used for **dev** (`mkdev.sh`); **release** uses static Qt from `build-qt-static.sh` (5.15.18). We can build zerowallet with Qt 5.15.3 or 5.15.13 (and 5.15.18).

| Ubuntu | Qt 5 (apt) | Qt 6 (apt) | Notes |
|--------|------------|------------|-------|
| **22.04 (Jammy)** | **5.15.3** (`qtbase5-dev` 5.15.3+dfsg-2, source `qtbase-opensource-src`) | — | Qt5 in universe. |
| **24.04 (Noble)** | **5.15.13** (`qtbase5-dev` 5.15.13+dfsg-1ubuntu1) | 6.4.2 (`qt6-base`) | Qt5 still in repos; Qt6 is default. |

Dev install (either release): `sudo apt install build-essential qtbase5-dev qtbase5-dev-tools libqt5websockets5-dev`. Release build uses static Qt from source (see Linux Qt build below), not these packages.

### Linux Qt build (release)

**Prerequisites (dev):** `sudo apt install build-essential qtbase5-dev qtbase5-dev-tools libqt5websockets5-dev` — for `mkdev.sh` only; release uses static Qt, not system packages.

**Release: static Qt or system Qt.** Default is **static Qt** (built in-repo or pointed to with `-q`). Script: `src/scripts/build-qt-static.sh`. Run once per repo (or per machine); creates `qt5-static/` in repo root. Default `QT_PREFIX` for Linux release is `$REPO_ROOT/qt5-static`; override with `-q /path`. Alternatively use **system Qt** (installed via package manager, not built in repo) with `-S`/`--systemqt` or `USE_SYSTEM_QT=1`; then the release binary is dynamically linked and the static-link check is skipped. If `qmake` is not found at `QT_PREFIX` (or on PATH for `-S`), mkrelease-linux fails with a clear error.

**build-qt-static.sh:** Downloads Qt 5.15.18 source from [download.qt.io](https://download.qt.io/archive/qt/5.15/5.15.18/single/qt-everywhere-opensource-src-5.15.18.tar.xz) (~633MB), extracts, configures with `-static -release -prefix $REPO_ROOT/qt5-static -skip webengine -nomake tools -nomake tests -nomake examples`, builds (~30–60 min), installs into `qt5-static/`. The tarball may extract to `qt-everywhere-opensource-src-5.15.18` or `qt-everywhere-src-5.15.18`; the script handles both. On GCC 13+ apply `res/patches/qt-gcc13.diff` (qtlocation) if present; script does this automatically.

**Only the five Qt libs zerowallet needs (Core, Gui, Network, WebSockets, Widgets):**  
- **Download only those:** Qt provides modular source at `https://download.qt.io/archive/qt/5.15/5.15.18/submodules/`: **qtbase** (Core, Gui, Network, Widgets) ~49MB tar.xz and **qtwebsockets** ~234KB tar.xz. So you can download ~50MB instead of the full ~633MB single tarball. Building from these requires a different flow: build and install qtbase first, then build qtwebsockets against that prefix (e.g. `configure -qtbase $PREFIX`); the current script does not support this modular download/build.  
- **Build only those (same download):** When using the full single tarball, you can add more `-skip` options to configure so only qtbase and qtwebsockets (and their deps) are built, e.g. `-skip webengine -skip qt3d -skip qtdeclarative -skip qtmultimedia -skip qtlocation -skip qtdoc …` (and already `-nomake tools -nomake tests -nomake examples`). That reduces build time and install size; download size stays ~633MB. The current script only uses `-skip webengine`; extending it with more `-skip` is possible.

**Practice scripts and how to test**

Two scripts in `src/scripts/` let you try modular download and skip-extra build without changing the main `qt5-static/` output:

1. **Modular download + build** — `build-qt-static-modular.sh`  
   Downloads only qtbase (~49MB) and qtwebsockets (~234KB) from Qt’s submodules, builds qtbase then qtwebsockets, installs to `qt5-static-modular/install`.  
   - Run: `./src/scripts/build-qt-static-modular.sh` (optionally `-f` to force full rebuild, `-j N` for parallel jobs).  
   - Test: After it finishes, run `./qt5-static-modular/install/bin/qmake -v` and check that `libQt5Core.a`, `libQt5WebSockets.a` exist under `qt5-static-modular/install/lib`. Then build zerowallet against it: `./src/scripts/mkrelease-linux.sh -q $(pwd)/qt5-static-modular/install` (on a Linux host). The resulting binary should link statically to Qt (no `libQt5*` in `ldd zerowallet`).

2. **Single tarball with extra -skip (build only qtbase + qtwebsockets)** — `build-qt-static-skip-extra.sh`  
   Downloads the full single tarball (~633MB), extracts, then configures with many `-skip` so only qtbase and qtwebsockets are built. Output: `qt5-static-skip/install`.  
   - Run: `./src/scripts/build-qt-static-skip-extra.sh` (first run downloads and extracts then builds). Use `-u` to skip download/extract and only reconfigure+build (e.g. after changing skip list). Use `-f` to force full re-run.  
   - Test: Same as above: `qt5-static-skip/install/bin/qmake -v`, check for `libQt5Core.a` and `libQt5WebSockets.a`, then `mkrelease-linux.sh -q $(pwd)/qt5-static-skip/install` and verify `ldd zerowallet` has no Qt libs.

Both scripts use a separate output dir so they do not overwrite `qt5-static/` from the main build-qt-static.sh.

**Release flow:** Build zerod: `cd ../Zero && ./zcutil/build.sh`. Then either (1) static Qt: if `qt5-static/` does not exist, run `./src/scripts/build-qt-static.sh`, then `./src/scripts/mkrelease-linux.sh` (or `-q /path/to/qt5-static` to use another prefix); or (2) system Qt: `./src/scripts/mkrelease-linux.sh -S` (no build-qt-static needed). Version comes from `version.h` (and git); to pin use `-v X.Y.Z -p X.Y.(Z-1)`.

**Output:** `artifacts/linux-zerowallet-vX.Y.Z.tgz` (staged in `bin/tgz/linux-zerowallet-vX.Y.Z/`), `artifacts/linux-zerowallet-vX.Y.Z.deb` (staged in `bin/deb/zerowallet-vX.Y.Z/`: DEBIAN/control, usr/local/bin/, README.md, pixmaps, .desktop). Binaries stripped unless `-P`. Package verification: `./src/scripts/package-verify.sh --linux artifacts/linux-zerowallet-vX.Y.Z.tgz`.

---

## Build / Environment Notes

- libsodium 1.0.18 URL 404; 1.0.21 used. Qt and ZERO_DIR: see [BUILD](BUILD.md) §Dependencies, §Qt, §ZERO_DIR.

---

## Version Upgrade Plan

| Package | Plan Current | Target | **Repo actual** | Notes |
|---------|---------------|--------|-----------------|-------|
| libsodium | 1.0.18 | 1.0.21 | **1.0.21** | Done. `fbuild-libsodium.sh`, vendored `res/libsodium.a`. |
| nlohmann/json | 3.6.1 | 3.12.0 | 3.6.1 | Single-header; low-risk bump. |
| SingleApplication | 3.0.14 | 3.5.4 | 3.0.14 | Vendored copy. |
| Qt | 5.9.1 | 5.15.17+ | **5.15.18** | Release: `build-qt-static.sh` → `qt5-static/`. Dev: system Qt 5.15.3–5.15.13 OK. APP_VERSION **4.0.0** (`version.h`) is wallet release, not Qt version. |
| Docker | ubuntu:16.04 | ubuntu:24.04 | ubuntu:16.04 | **Postponed** — see §Postponed. |
| OpenSSL | 1.0.2r | 1.1.1w | 1.0.2r | Dockerfile only; postponed with Docker bump. |
| Nayuki QR | (blank) | v1.8.0 | unversioned | Replace 6 files with 2 when upgraded. |

### Discrepancies (resolved vs doc)

- **libsodium:** Repo at 1.0.21 — no open question; scripts and `BUILD.md` agree.
- **Qt:** Static release builds **5.15.18** from tarball. Last open-source LTS line is 5.15.18; 5.15.19 is commercial-only (cherry-pick only if critical — §Qt 5.15.19 Cherry-Pick). No need to change Qt version for current release unless a security fix requires it.
- **Travis:** Removed `.travis.yml`.

---

## Detected Errors and Mismatches

### zerowallet

| Location | Issue | Severity |
|----------|-------|----------|
| ~~`src/connection.cpp:116-123`~~ | ~~Memory leak~~ Fixed: `randomPassword()` now uses `std::string` (RAII) | — |
| ~~`src/connection.cpp:119`~~ | ~~Buffer index~~ Fixed: `charsetLen = sizeof(charset) - 1` | — |
| ~~`src/websockets.cpp:28`~~ | ~~Mobile WebSocket~~ Deprecated; UI removed (§Mobile) | — |
| ~~`src/connection.cpp:115`~~ | ~~Password length 10~~ Fixed: 20 chars, expanded charset (alphanum + `!@#$%^&*()_+-=[]{}|\:;"'<>?,./~`) | — |
| `src/settings.cpp:242-243` | RPC credentials stored plain text | Medium |
| `src/rpc.cpp:1538` | HTTP instead of HTTPS for external API calls | Medium |
| `res/libsodium` | Build scripts referenced 1.0.18 URL (404); 1.0.21 used | Low |
| Version upgrade plan | Plan "current" for libsodium was 1.0.18; repo already 1.0.21 | Low |

**signbinaries:** See [BUILD](BUILD.md) §GPG Signatures. `signbinaries.sh` auto-detects (sha256sum / shasum -a 256); run from `artifacts/`.

**Weak password:** `randomPassword()` generates RPC password when wallet creates `zero.conf` (`connection.cpp:197`). Used for zerod RPC auth (`rpcuser=zero`, `rpcpassword=<generated>`). zerod reads from config; no separate zerod password strategy. Fixed: now 20 chars, charset includes `!@#$%^&*()_+-=[]{}|\:;"'<>?,./~`.

**Plain text credentials:** `settings.cpp:241-242` stores `rpcuser`/`rpcpassword` in `QSettings` (macOS: `~/Library/Preferences` plist). **Upstream (safewallet):** Same pattern — `QSettings` for rpcuser/rpcpassword. **Recommendation:** Use OS credential store (Keychain, libsecret) or encrypt before storage; upstream has no fix to cherry-pick.

**HTTP:** Only `rpc.cpp` — `http://z-board.net/listTopics` (ZBoard). CoinGecko and GitHub use HTTPS. **TLS for zerod RPC:** postponed; use same-machine `127.0.0.1` (see §Autogenerated `.conf` comparison). **z-board:** document risk or disable if HTTPS unavailable.

**randomPassword RAII (implemented):** `std::string` vs `std::unique_ptr<char[]>` — both avoid leaks. `std::string` is simpler: no manual allocation, no explicit delete, idiomatic C++. `std::unique_ptr<char[]>` gives explicit RAII over a raw buffer but adds boilerplate. Recommendation: `std::string` (chosen).

**Tests:** Unit test `randomPassword()` — length 20, charset coverage, no null in output, no leak (valgrind/sanitizers). System test: create zero.conf, verify zerod accepts generated credentials.

### Zero Full Node (for Zero repo triage)

**Transfer done:** Content merged into Zero repo **UpdateZero.md** (§4.6 triage column, §10–12); **ZeroCoin.md** created in Zero repo. You may remove from zerowallet: CHANGELOG.md, SCOPE.md, UpdateZero-insert.md, ZERO_TODO.md, ZeroChain.md, ZeroCoin-for-Zero-repo.md, ZeroCoin.md (and optionally UpdateZero-merge.md, ZeroCoin-Zero-repo-consolidated.md).

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

**Build:** See [BUILD](BUILD.md) §Quick Start and §Platform Notes (Linux, macOS, Windows). mkrelease: `./src/scripts/mkrelease.sh` or platform-specific `mkrelease-{linux,mac,win}.sh`.

### System Install (brew, pyenv, pip)

No package-manager installs for library upgrades — all vendored. For build prerequisites see [BUILD](BUILD.md) §Dependencies and §Qt. Docker: `src/scripts/docker/Dockerfile`.

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
3. ~~**WebSocket binding**~~ Mobile UI removed; code unreachable (see §Mobile). Revisit if QtWebSockets can be dropped from build.

### Medium Severity

4. ~~**Weak password**~~ Fixed: 20 chars, expanded charset.
5. **Credentials plain text** (`src/settings.cpp:242-243`): Encrypt or use OS credential store
6. **HTTP** (`src/rpc.cpp:1538`): Acceptable risk on same desktop; real issue across internet. Switch to HTTPS for external APIs.

### Immediate Actions

1. ~~Fix memory leak~~ Done
2. ~~Fix buffer index~~ Done
3. ~~Mobile connect~~ UI removed
4. ~~Increase password length~~ Done
5. HTTPS for external APIs (z-board.net)

---

## Futures and Wants

### From Upstream (Selective Merge)

- Theme system (Midnight, CSS) — keep Zero branding
- Translation improvements
- Market data — evaluate for Zero

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
| 6 | **Single instance:** Second launch → primary window raised; payment URI forwarded if passed as arg | |

### Major Functionality

| # | Test | Pass |
|---|------|------|
| 7 | **Connect:** zerod running → wallet connects; status shows synced or syncing | |
| 8 | **Receive:** New shielded address → `z_getnewaddress` succeeds; address in dropdown | |
| 9 | **Send:** Send tab → enter amount, address, memo → send succeeds | |
| 10 | **Settings:** Wallet Config, Consolidation addresses → add, copy, delete (context menu) | |
| 11 | **Address Book:** Add, edit, delete entries | |
| 12 | **Recurring:** Create recurring payment; list shows entry | |
| 13 | **Backup:** Backup wallet.zero → file saved | |
| 14 | **Turnstile:** If shown, completes without hang | |
| 15 | **DeleteTx:** Settings → Enable DeleteTx; restart embedded zerod; verify pruning (not per-tx GUI). Note `keeptxnum`/`keeptxfornblocks` in `zero.conf`. | |
| 16 | **QR payment URI:** `zero:…` with `amt` and base64 `memo`; unknown query keys ignored; open from second instance or OS handler | |
