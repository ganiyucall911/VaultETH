# VaultETH
**Universal Self-Custodial Multi-Chain Wallet**  
*Executive non-custodial crypto vault by **vault.***

[![iOS CI](https://github.com/ganiyucall911/VaultETH/actions/workflows/ios.yml/badge.svg)](https://github.com/ganiyucall911/VaultETH/actions/workflows/ios.yml)
[![Android CI](https://github.com/ganiyucall911/VaultETH/actions/workflows/android.yml/badge.svg)](https://github.com/ganiyucall911/VaultETH/actions/workflows/android.yml)

[![Pages](https://github.com/ganiyucall911/VaultETH/actions/workflows/pages/pages-build-deployment/badge.svg)](https://ganiyucall911.github.io/VaultETH/)
[![Cloudflare](https://img.shields.io/badge/Cloudflare-vaulteth-F38020?logo=cloudflare&logoColor=white)](https://vaulteth.ganiyusail101.workers.dev)

VaultETH is an executive, self-custodial multi-chain wallet engineered for sovereign asset ownership and uncompromising privacy. Built natively for **iOS (SwiftUI, iOS 17+)** and **Android (Jetpack Compose, Android 8.0+)**, VaultETH enables seamless management of multi-chain assets from a single 12-word master seed phrase.

---

## Supported Blockchain Networks

- **Ethereum Mainnet** (Chain ID: 1)
- **Arbitrum One** (Chain ID: 42161)
- **Base** (Chain ID: 8453)
- **Optimism** (Chain ID: 10)
- **Polygon PoS** (Chain ID: 137)
- **BNB Smart Chain** (Chain ID: 56)
- **Avalanche C-Chain** (Chain ID: 43114)
- **Linea** (Chain ID: 59144)
- **Sepolia Testnet** (Chain ID: 11155111)
- **Custom EVM Networks** (User-configurable RPC URL and Chain ID)
- **Cross-Chain Derived Addresses**: Native deposit derivation for **Solana** (Ed25519) and **Bitcoin SegWit** (BIP-84 Bech32)

Outgoing sends are currently supported only for native assets on the listed EVM networks. Solana and Bitcoin addresses are derived for receiving deposits only; VaultETH cannot sign or broadcast Solana or Bitcoin transactions. ERC-20/token transfers are not currently supported.

## Demo Data and Unavailable Features

The token list, holdings, USD prices, percentage changes, charts, and portfolio total shown in the apps are static demo data. They are not live market data and are not read from your wallet. The separate native-currency balance is queried from the selected EVM network.

Buy and swap are not integrated and cannot submit purchases or swaps. Their screens are marked as coming soon. VaultETH does not charge or collect a protocol fee; sends are single native-asset transactions to the recipient, and the displayed outlay is the transfer amount plus the estimated network gas fee.

---

## Core Architecture & Features

1. **Hardware-Backed Key Protection**
   - **iOS:** Stored in the iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` and gated by device-owner authentication (Face ID / Touch ID / passcode).
   - **Android:** Encrypted via `EncryptedSharedPreferences` backed by the Android Keystore (`AES256_GCM` and `AES256_SIV`) with `BiometricPrompt` authorization.
   - Cloud backup is strictly disabled (`allowBackup="false"`, no iCloud sync).
   - In-memory key buffers are zeroed out via `resetBytes` immediately after use.

2. **Pre-Flight Transaction Simulation**
   - Executes dry-run `eth_call` and gas limit estimation prior to user authorization.
   - Parses standard ABI revert reasons (`Error(string)`) so failed contract calls are caught before spending gas.

3. **EVM Native-Asset Transaction Signing**
   - Dynamic dual-mode gas estimation supporting modern EIP-1559 base fees + priority tips and graceful fallback to `eth_gasPrice` for BNB Chain and legacy networks.
   - Dynamic biometric authentication prompts indicating target asset (`"Authorize sending BNB"`, `"Authorize sending POL"`).

4. **ENS & Payment Intelligence**
   - Native Ethereum Name Service (ENS) forward resolution and reverse lookup with spoofing verification.
   - Full support for EIP-681 and EIP-831 payment URIs (`ethereum:0x...?value=...` or `?amount=...`) for instant recipient and amount prefill.
   - Visual `VaultIdenticon` keystone crests derived deterministically from public addresses to prevent transfer clipping mistakes.

5. **Discreet Privacy & Zero Telemetry**
   - One-tap discreet balance masking (`•••••••• ETH`) for public environments.
   - **Zero** analytics SDKs, trackers, third-party advertising, or remote telemetry.
   - All external RPC communication strictly enforces TLS/HTTPS transport encryption.

6. **Release Signing**
   - Release signing uses repository secrets only. Configure `ANDROID_RELEASE_KEYSTORE_BASE64`, `ANDROID_RELEASE_KEYSTORE_PASSWORD`, `ANDROID_RELEASE_KEY_ALIAS`, and `ANDROID_RELEASE_KEY_PASSWORD` to produce signed Android release artifacts.
   - Without signing secrets, the release workflow publishes explicitly named unsigned Android artifacts. Google Play deployment additionally requires `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`. The iOS workflow produces an unsigned IPA; signing and App Store distribution are not configured.

---

## Build & Testing

### iOS (Xcode 15 / 16, macOS 14+)

Requires macOS with Xcode installed.

```bash
# 1. Install XcodeGen if needed
brew install xcodegen

# 2. Generate Xcode project from spec
xcodegen generate --spec project.yml

# 3. Open in Xcode
open VaultETH.xcodeproj

# 4. Run tests via CLI
xcodebuild test -scheme VaultETH -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

*Continuous Integration:* Verified on GitHub Actions using `macos-14` and Xcode 16.

### Android (Android Studio / Gradle, JDK 17)

Requires Java 17 and Android SDK.

```bash
cd android

# Run unit test suite
./gradlew testDebugUnitTest

# Assemble debug APK
./gradlew assembleDebug
```

*Continuous Integration:* Verified on GitHub Actions using Ubuntu and Temurin JDK 17.

---

## Project Layout

```text
├── Assets.xcassets/          # App icon (1024x1024) and visual assets
├── project.yml               # XcodeGen project specification (single source of truth)
├── PrivacyInfo.xcprivacy     # Apple privacy manifest (CA92.1 required reason)
├── *.swift                   # Native iOS Swift & SwiftUI application source files
│   ├── VaultETHApp.swift     # App entry point
│   ├── RootView.swift        # 4-tab cockpit & sheet orchestration
│   ├── Models.swift          # Multi-chain network definitions & transaction models
│   ├── WalletEngine.swift    # TrustWalletCore signing & derivation
│   ├── WalletStore.swift     # State management & balance polling
│   ├── EthereumRPC.swift     # JSON-RPC client & simulation engine
│   ├── KeychainVault.swift   # Secure Enclave keychain storage
│   ├── VaultIdenticon.swift  # Deterministic cryptographic crest generator
│   ├── SendView.swift        # Send flow, presets & pre-flight verification
│   ├── WalletsView.swift     # Vault management & recovery phrase view
│   └── ENSResolver.swift     # ENS forward and reverse resolution
├── android/                  # Native Android application
│   └── app/src/main/java/com/vaulteth/app/
│       ├── ui/               # Jetpack Compose UI screens & navigation
│       ├── crypto/           # BouncyCastle BIP-39 & transaction signing
│       └── storage/          # Android Keystore encrypted storage
├── docs/                     # Interactive web showcase & documentation
│   ├── index.html            # Web showcase & interactive mobile wallet simulator
│   ├── privacy.html          # Standalone privacy policy page
│   ├── support.html          # Standalone support and FAQ page
│   ├── _headers              # Cloudflare Pages security & caching headers
│   └── assets/               # Marketing banners and App Store screenshot mockups
├── wrangler.toml             # Cloudflare Pages deployment configuration
├── SUBMISSION_KIT.md         # Complete App Store Connect & Google Play metadata and questionnaires
├── APP_STORE_CHECKLIST.md    # Pre-flight App Store checklist and guidelines
├── PRIVACY_POLICY.md         # Repository privacy policy
├── SUPPORT.md                # Non-custodial support and FAQ guide
└── SECURITY.md               # Security release gates and disclosures
```

---

## Store Submission & Compliance

- **App Store Connect & Google Play Console:** See [`SUBMISSION_KIT.md`](SUBMISSION_KIT.md) for full descriptions, keywords, Guideline 3.1.5(a) reviewer notes, Data Safety responses, and Export Compliance declarations (`ITSAppUsesNonExemptEncryption = false`).
- **Checklist:** Track administrative and release requirements in [`APP_STORE_CHECKLIST.md`](APP_STORE_CHECKLIST.md).

---

## Security Notice

- VaultETH is strictly a self-custodial software wallet. The developers have no access to your funds, passwords, or recovery phrases.
- **Never commit seed phrases, private keys, keystores (`*.jks`, `*.keystore`), certificates, or API secrets.** Strict `.gitignore` rules prevent sensitive artifacts from being tracked.
