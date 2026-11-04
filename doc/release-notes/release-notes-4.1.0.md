# Zerowallet v4.1.0

Tag `v4.1.0`. Desktop wallet for Zero; the release archives bundle `zerod` and `zero-cli` from Zero v4.1.0.

## Summary

Update to v4.0.0: the wallet checks and downloads the proving parameters `zerod` needs, polls the node less and rides out busy periods without error dialogs, fixes crashes, and bundles Zero v4.1.0.

## Upgrade actions

- Back up `wallet.zero` in the Zero data directory before upgrading.
- Quit the wallet, and with it the `zerod` it started, before installing.
- macOS: the app is ad-hoc signed, without a Developer ID signature or notarization. On first launch, Control-click ZeroWallet, choose Open, and confirm.

## Proving parameters

- Before starting `zerod`, the wallet checks `sapling-spend.params`, `sapling-output.params`, and `sprout-groth16.params` in `~/.zcash-params`, `~/Library/Application Support/ZcashParams`, or `%APPDATA%\ZcashParams`: the size at every start, the SHA-256 once per file until the file changes.
- A missing, wrong-size, or corrupt file is moved to `NAME.bad` and downloaded from `download.z.cash` in two parts; it replaces the old file only with the expected size and SHA-256. All three come to about 741 MiB; at 3.1 MB/s the first run takes about 4 minutes.
- A failed download retries twice after 5 s, then offers Retry or Cancel. The directory must be writable and have room for the files plus 64 MB.

## Node connection

- The wallet polls `zerod` every 30 s (10 s before) and requests the last 7 days of history, at most 50 transactions per refresh.
- While `zerod` is busy (startup, witness rebuild, a full RPC queue, or error -34 from `getalldata`), the wallet keeps showing the last data instead of an error.

## Fixes

- Crashes: the View All Addresses table before balances arrive, and a missing or malformed recurring-payments file.
- `zero:` payment URIs: amount and memo are decoded as standard URL query values (`amt` or `amount`; `memo`, `msg`, or `message`).
- Memos are shown as plain text in the memo dialog and the transaction list tooltip.
- Private key export includes transparent addresses that hold funds outside the default account, and lists keys that could not be exported.
- Send details are no longer printed to the console.

## Known issues

- Recurring payments: the schedule "Every 5 mins" sends the payment every 5 minutes without asking while the wallet runs. Do not use it.
- Importing transparent private keys rescans the chain once per new key and labels each address "yes" or "no"; keys and funds import correctly.
- macOS: the bundled `zerod` needs macOS 15; on older macOS the app starts but `zerod` does not.

## Compatibility

- macOS 15 or newer on Apple silicon; Linux on Ubuntu 24.04 or newer; Windows 64-bit.

## Verify download

- Check each archive against `SHA256SUMS`: `sha256sum --ignore-missing -c SHA256SUMS` on Linux, `shasum -a 256 --ignore-missing -c SHA256SUMS` on macOS, `Get-FileHash -Algorithm SHA256 <file>` on Windows.
