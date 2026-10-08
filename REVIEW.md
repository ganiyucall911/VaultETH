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

## Second pass fixes (session 2)
| Where | Problem | Fix |
|---|---|------|
| `project.yml` | `SWIFT_VERSION: "5.0"` — too old for modern concurrency features used throughout the codebase | bumped to `"5.9"` |
| `project.yml` | `PrivacyInfo.xcprivacy` was excluded from the app target's sources; it must be bundled as a resource for App Store review | added as an explicit `buildPhase: resources` entry |
| `project.yml` | Missing `ITSAppUsesNonExemptEncryption` key — required for all apps using cryptography to pass App Store export-compliance | set to `false` (the signing is done by Trust Wallet Core, a library; the app itself does not implement its own encryption algorithms) |
| `project.yml` | `.antigravity/` directory not excluded from source scanning | excluded |
| `WalletsView` (`RecoveryPhraseView`) | Recovery phrase remained visible in the iOS app-switcher snapshot when shown immediately after wallet creation (`initialMnemonic != nil`) | removed the `initialMnemonic == nil` guard; phrase is now always cleared on foreground loss |
| `SendView` (`ReviewTransferView`) | Receipt-polling `Task` ran for up to 2 minutes after the user dismissed the review sheet | stored polling task in `@State receiptTask`; cancelled on sheet close |
| `Wei.multiply` | Accumulator used `[Int]` — technically safe on 64-bit iOS but misleading; product of many UInt8 pairs would overflow on 32-bit | changed accumulator and carry to `UInt64` |
| `KeychainVault.saveSync` | Intermediate `Data(mnemonic.utf8)` buffer remained in process memory after `SecItemAdd` | call `mnemonicData.resetBytes(in:)` immediately after saving |
| `SettingsView` | No refresh button, no RPC endpoint disclosure, only a bare version string | added refresh balance button, listed both RPC providers with a privacy note, added build number |
| `HomeView` | No way to switch wallets without leaving the Home tab | added a toolbar `Menu` wallet switcher (only shown when >1 wallet exists) |
| `SendView` | No real-time validation feedback while typing | added `recipientHint` and `amountHint` computed properties that show red captions when the input looks wrong |

## Third pass features & fixes (session 3)
| Where | Problem | Fix |
|---|---|---|
| `project.yml` | Missing `NSCameraUsageDescription` — app would immediately crash when requesting camera access, and would fail App Store review | Added `NSCameraUsageDescription: VaultETH uses your camera to scan Ethereum address and ENS payment QR codes.` |
| `QRScannerView` | No UI controls to dismiss sheet or toggle flashlight in dark environments; no visual framing guide | Added close ("X") button, torch toggle button (with state reset on exit), and viewfinder reticle frame |
| `WalletEngine` | QR scans and clipboard text containing payment URIs (`ethereum:0x...?value=...` or `?amount=...`) failed validation or lost amount data | Added `parsePaymentURI` supporting EIP-681 / EIP-831 (`ethereum:`, `pay-`, `@chainId`, `value` in wei/scientific notation, `amount` in ETH); automatically fills both recipient and amount on scan/paste |
| `ENSResolver` | Names shorter than 7 chars (`a.eth`, `ab.eth`) or prefixed URIs were rejected; no reverse resolution to identify wallet owner's ENS | Lowered minimum length check to 4 chars; implemented reverse resolution (`resolveAddress`) with ABI string decoder and strict forward-verification check against spoofing |
| `RootView` (`HomeView`) | Wallet ENS name was not surfaced on the balance card | Displays resolved ENS name badge above wallet address; refreshes ENS on pull-to-refresh |
| `WalletStore` | Transactions remained in `.pending` state indefinitely if app closed before receipt arrived; no way to manage or clear history | Added `refreshPendingTransactions()`, `deleteTransaction(id:)`, and `clearHistory(for:)` |
| `TransactionHistoryView` | History list was static without pull-to-refresh, status polling, or ability to remove records | Added `.refreshable`, automatic `.task` status check, swipe-to-delete, and toolbar menu to check status or clear wallet history |
| `ENSAndHistoryTests.swift` | Lack of test coverage for ENS resolution helpers and transaction history serialization | Created comprehensive test suite verifying `looksLikeENS`, `decodeABIString`, `namehash("")`, and `SentTransaction` Codable |

## Remaining risks
- Swift `String` cannot be zeroed: the recovery phrase lives in memory briefly while signing or revealing.
- Public RPC providers see the user's IP and address, and their data (balance, nonce, fees) is trusted, not verified.
- Sends to contracts are allowed with a warning only; no simulation, no ERC-20, no approvals handling.
- A Keychain item with user-presence protection is deleted if the device passcode is removed: backup is essential.
- Imported wallets are marked "backed up" (the user already has the phrase). Deleting a wallet warns when not backed up.
- No replace-by-fee / cancel, no custom gas, no multi-chain.
- Native build and UI tests run in Xcode / macOS; pure logic and unit vectors verified.

