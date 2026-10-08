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

## Fourth pass: Brand Identity, UI/UX Overhaul & App Icon (session 4)
| Area | Enhancement | Technical Details |
|---|---|---|
| **Concept of Identity** | **VaultIdenticon (Cryptographic Crests)** | Replaced generic circular avatars and legacy blockies with a pure SwiftUI generative cryptographic crest (`VaultIdenticon.swift`). Deterministically renders a bespoke interlocking Vault 'V' keystone chevron with orbital rings, micro-nodes, and a signature prismatic gradient aura derived from the address hex. |
| **Design System** | **Liquid Glass 2.0 & Tokens** | Enhanced `LiquidGlass.swift` with semantic color tokens (`vaultBackground`, `vaultCardSurface`, `vaultCyan`, `vaultViolet`, `vaultAmber`, `vaultEmerald`), titanium specular borders (`.vaultGlass`), `.vaultCard` elevated containers, and `.vaultButton` spring haptic styles. |
| **App Icon** | **Bespoke Vault 'V' Keystone Emblem** | Replaced generic token motifs with a 100% original, proprietary 1024x1024 icon (`Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`). Features an architectural, sculptural 'V' vault keystone crafted from brushed dark titanium and frosted smoked glass with an internal radiant cyan/champagne-gold aperture over obsidian calibration rings. Does not imitate any cryptocurrency token or existing app. |
| **Information Architecture** | **Modern 4-Tab Cockpit** | Reorganized navigation into 4 primary hubs: `Vault` (Home), `Wallets`, `Activity` (History), and `Settings`. Integrated direct `Send`, `Receive`, `Scan`, and `Copy` quick actions directly into the Home hero card. |
| **Privacy UX** | **Discreet Balance Mode** | Added discreet mode toggle (`eye` / `eye.slash`) in the navigation bar to mask balances (`•••••••• ETH`) with smooth spring animations when in public or recording screencasts. |
| **Send Experience** | **Cockpit Flow & Presets** | Redesigned `SendView` with sender crest, interactive amount preset pills (`25%`, `50%`, `75%`, `Max`), instant recipient `VaultIdenticon` verification preview, and a biometric authentication review sheet. |
| **Receive Experience** | **Digital Vault Pass** | Redesigned `ReceiveView` into an executive cryptographic pass featuring a high-contrast QR frame, centered identicon, one-tap copy with toast feedback, and iOS native `ShareLink`. |
| **Wallets Management** | **Glass Vault Cards** | Upgraded `WalletsView` from standard list rows to luxury glass vault cards with live identicons, active state badges, backup indicators, and a 2-column numbered capsule grid in `RecoveryPhraseView`. |
| **Activity Feed** | **Activity Hub & Filters** | Added segmented status filtering (`All`, `Confirmed`, `Pending`) in `TransactionHistoryView`, with recipient identicons, live status beacons, and a dedicated transaction detail modal sheet. |
| **Onboarding** | **Sovereign Welcome Screen** | Revamped `WelcomeView` with floating glowing diamond motif, key pillar disclosures (Secure Enclave, zero tracking, direct on-chain), and prominent creation actions. |

## Fifth pass: Universal Multi-Chain Architecture (session 5)
| Area | Enhancement | Technical Details |
|---|---|---|
| **Multi-Chain Networks** | **`BlockchainNetwork` Engine** | Introduced first-class multi-chain definitions for Ethereum Mainnet (1), Arbitrum One (42161), Base (8453), Optimism (10), Polygon PoS (137), BNB Smart Chain (56), Avalanche C-Chain (43114), Linea (59144), Sepolia Testnet (11155111), plus custom EVM network addition. |
| **RPC Client** | **Dynamic Multi-Chain JSON-RPC** | Enhanced `EthereumRPC.swift` to dynamically instantiate with any `BlockchainNetwork`. Implemented resilient dual-model gas estimation supporting modern EIP-1559 base fee queries and graceful fallback to `eth_gasPrice` for BNB Chain and legacy EVM networks. |
| **Cross-Chain Derivation** | **EVM, Solana & Bitcoin** | Updated `WalletEngine` to derive native addresses for EVM (all chains), Solana (`wallet.getAddressForCoin(coin: .solana)`), and Bitcoin SegWit (`wallet.getAddressForCoin(coin: .bitcoin)`) from a single 12-word seed phrase. |
| **Network Selector UI** | **Interactive Network Pill & Sheet** | Added interactive network beacon button to `HomeView` header and `NetworkPickerSheet` allowing one-tap switching between all supported chains and instant adding of custom RPC networks. |
| **Multi-Chain Receive** | **Segmented Digital Vault Pass** | Redesigned `ReceiveView` with a segmented control to toggle between EVM Chains, Solana, and Bitcoin, generating live respective QR codes and copy actions. |
| **Dynamic Sending & History** | **Multi-Chain Execution** | Updated `SendView` and `TransactionHistoryView` to adapt symbols (`ETH`, `BNB`, `POL`, `AVAX`), validate against target network chain ID, and deep-link directly to each network's official block explorer (Basescan, Arbiscan, Polygonscan, BscScan, Snowtrace, Etherscan). |

## Remaining risks
- Swift `String` cannot be zeroed: the recovery phrase lives in memory briefly while signing or revealing.
- Public RPC providers see the user's IP and address, and their data (balance, nonce, fees) is trusted, not verified.
- Sends to contracts are allowed with a warning only; no simulation, no ERC-20, no approvals handling.
- A Keychain item with user-presence protection is deleted if the device passcode is removed: backup is essential.
- Imported wallets are marked "backed up" (the user already has the phrase). Deleting a wallet warns when not backed up.
- Non-EVM chains (Solana, Bitcoin) currently support address derivation and receiving; outgoing broadcast is enabled for all EVM chains.
- Native build and UI tests run in Xcode / macOS; pure logic and unit vectors verified.

