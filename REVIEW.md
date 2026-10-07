# Review notes

## What was merged
Base: `VaultETH-LATEST` (newer, SwiftUI + WalletCore, Keychain, Siri). Taken from `VaultETH-complete-GitHub-upload`
(older): backup-confirmation flow when creating a wallet, `SecureVault` use of a Keychain access-control context,
visible error messages, QR error-correction level. Everything else was rewritten, formatted and tested.

## Bugs fixed (would not compile or would misbehave)
| Where | Problem | Fix |
|---|---|---|
| `ETHAmount.wei` | invalid signature (`-> Data throws`), `&Decimal(256)` temporaries, `NSDecimalNumber(data:)` does not exist; floating-point formatting | exact integer digit arithmetic, tested |
| `WalletEngine` | `HDWallet(strength:)` is failable but was force-used; `getKeyForCoin(.ethereum)` is missing the `coin:` label | guarded, labelled |
| `WalletStore` | `try!` on create/import: any Keychain or auth failure crashed the app | async throwing API, errors shown in UI |
| `EthereumRPC.transactionReceipt` | decoded a receipt object as a String, so status was always nil | proper object decoding |
| `EthereumRPC.buildFeeQuote` | max fee = tip = gas price (overpays, wrong EIP-1559 semantics); fixed 21000 gas | base fee x2 + tip; `eth_estimateGas` |
| `Package.swift`/`project.yml` | missing `WalletCoreSwiftProtobuf` product, needed by the signing proto types | added; Package.swift dropped (XcodeGen is the single source of truth) |
| `RootView` (older) | unbalanced brace in the backup button | rewritten |
| Intents | `static var title` is rejected under Swift 6 strict concurrency; shortcuts lacked `shortTitle`/icon | `static let`, full shortcut definitions |
| `PrivacyInfo.xcprivacy` | app uses UserDefaults but declared no required-reason API (App Store rejection risk) | declared CA92.1 |
| Keychain reads | ran on the main thread and used deprecated `kSecUseAuthenticationUI` | background task + `LAContext` |

## Send flow (new)
Validate recipient (EIP-55 checksum, zero-address block) -> exact amount -> require chainId == 1 -> fresh balance, nonce,
fee quote, contract check -> review screen (recipient, amount, maximum fee, total, contract warning) -> Face ID/passcode
on key load -> verify derived address equals the sending wallet -> sign (EIP-1559) -> broadcast -> poll for receipt.
The review screen cannot be dismissed while sending, to avoid double sends.

## Remaining risks (not solved here)
- Swift `String` cannot be zeroed: the recovery phrase lives in memory briefly while signing or revealing.
- Public RPC providers see the user's IP and address, and their data (balance, nonce, fees) is trusted, not verified.
- Sends to contracts are allowed with a warning only; no simulation, no ERC-20, no ENS, no approvals handling.
- A Keychain item with user-presence protection is deleted if the device passcode is removed: backup is essential.
- Imported wallets are marked "backed up" (the user already has the phrase). Deleting a wallet warns when not backed up.
- No replace-by-fee / cancel, no custom gas, no multi-chain.
- Not compiled here (no Xcode available). tree-sitter syntax checks pass, wei math and the signing/derivation vectors
  were generated independently in Python, but the first real build happens in CI. Expect small API-level fixes.
