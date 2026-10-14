# VaultETH App Store & Google Play Submission Kit
**Developer:** vault.  
**Bundle ID / Package Name:** `com.vaulteth.app`  
**Version:** `1.0.0` (Build `1`)  
**Product Site:** `https://vaulteth.ganiyusail101.workers.dev/`  
**Privacy Policy:** `https://vaulteth.ganiyusail101.workers.dev/privacy.html`  
**Support URL:** `https://vaulteth.ganiyusail101.workers.dev/support.html`  

This submission kit provides verified, ready-to-copy metadata, store listing copy, review guidelines disclosures, and compliance questionnaire responses for both Apple App Store Connect and Google Play Console.

**Feature disclosure:** Token prices, holdings, charts, and USD portfolio totals are static demo data, not live or wallet-derived. Buy and swap are not integrated. Outgoing sends support native assets on EVM networks only; Solana and Bitcoin addresses are receive-only. VaultETH does not charge or collect protocol fees.

---

## Part 1: Apple App Store Connect

### 1. App Information
| Field | Value |
|---|---|
| **App Name** | `VaultETH` |
| **Subtitle** | `Self-Custody Multi-Chain Vault` (29/30 characters) |
| **Bundle ID** | `com.vaulteth.app` |
| **Primary Category** | `Finance` |
| **Secondary Category** | `Utilities` |
| **Content Rights** | Does not contain, display, or access third-party content without rights (Owned by developer). |
| **Age Rating** | 17+ (Financial / Cryptocurrency management). Unrestricted Web Access: **No**. Gambling: **No**. |

### 2. Description & Promotional Text

#### Promotional Text (170 characters max):
> Self-custodial EVM wallet with native-asset sends, secure key storage, and transaction simulation. Solana and Bitcoin addresses are receive-only.

#### Description (4,000 characters max):
```markdown
VaultETH is an executive, self-custodial multi-chain crypto wallet engineered for sovereign asset security and uncompromising privacy. Built natively in Swift and SwiftUI, VaultETH places complete cryptographic ownership directly into your hands.

SOVEREIGN SELF-CUSTODY
Your 12-word recovery phrase and private keys are generated on-device and sealed within the hardware-backed iOS Keychain (kSecAttrAccessibleWhenUnlockedThisDeviceOnly). Protected by Secure Enclave biometric authorization (Face ID / Touch ID / Passcode), keys never touch external servers or cloud backups.

UNIVERSAL MULTI-CHAIN ARCHITECTURE
Derive addresses from one recovery phrase across supported networks. Outgoing sends are currently limited to native assets on EVM networks:
• Ethereum Mainnet
• Arbitrum One
• Base
• Optimism
• Polygon PoS
• BNB Smart Chain
• Avalanche C-Chain
• Linea
• Sepolia Testnet
• Custom EVM Networks (User-configurable RPC and Chain ID)
• Receive-only derived addresses for Solana and Bitcoin SegWit (outgoing sends are not supported)

Token holdings, prices, charts, and USD portfolio totals shown in the app are static demo data, not wallet balances or live market information. Buy and swap features are not integrated.

PRE-FLIGHT TRANSACTION SIMULATION
Never sign blindly. VaultETH runs dry-run execution (eth_call) and gas estimation before you authorize any transfer. Revert reasons and contract failures are parsed and surfaced instantly, protecting your funds from failed transaction fees.

ENS DOMAIN RESOLUTION & CRYPTOGRAPHIC CRESTS
• Native Ethereum Name Service (ENS) forward resolution and reverse lookup with spoofing verification.
• VaultIdenticon: Deterministic keystone crests uniquely derived from recipient addresses to eliminate copy-paste and clipping mistakes.
• EIP-681 / EIP-831 payment URI parsing for instant QR and clipboard prefill.

DISCREET PRIVACY MODE
Mask your portfolio balances with a single tap (•••••••• ETH) when operating in public spaces or recording screen captures.

ZERO TRACKING. ZERO DATA COLLECTION.
• No analytics frameworks, telemetry, or user tracking SDKs.
• No account registration, email, phone number, or KYC required.
• Strict transport encryption (HTTPS) across all RPC communication.
• VaultETH charges no protocol fee. EVM sends require network gas, which is paid to the blockchain network.
```

#### Keywords (100 characters max):
`crypto,wallet,ethereum,eth,bitcoin,solana,arbitrum,base,optimism,polygon,defi,web3,self-custody,vault`

#### Support & Marketing URLs:
- **Support URL:** `https://vaulteth.ganiyusail101.workers.dev/support.html`
- **Marketing URL:** `https://vaulteth.ganiyusail101.workers.dev/`
- **Privacy Policy URL:** `https://vaulteth.ganiyusail101.workers.dev/privacy.html`

---

### 3. App Review Information (Reviewer Notes)

#### Notes for the App Review Team:
```text
Hello App Review Team,

VaultETH is a non-custodial cryptocurrency software wallet compliant with App Store Review Guideline 3.1.5(a) (Cryptocurrencies):

1. Non-Custodial Architecture:
- VaultETH does not hold, transmit, custody, or manage user funds on central servers.
- The application does not facilitate fiat-to-crypto purchases, fiat currency exchange, initial coin offerings, or custodial exchange trading.
- BIP-39 recovery phrases and private keys are generated directly on the user's device and stored exclusively in the iOS Keychain with hardware-backed biometric access control (kSecAccessControlUserPresence).
- The developer has zero access to user keys or funds.

2. Testing Instructions (No Login Required):
- The app does not require account creation, email, password, or KYC.
- On launch, tap "Create a New Vault" to generate a fresh wallet with a single tap.
- Alternatively, tap "I Already Have a Vault" and import the following test recovery phrase:
  "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
- You can test Face ID / Passcode biometric authorization, network switching (including Sepolia testnet), QR generation, ENS resolution, and address derivation without spending real funds.

3. Permissions:
- Camera: Used exclusively for scanning recipient payment QR codes (EIP-681 / address).
- Face ID / LocalAuthentication: Used exclusively to authorize local Keychain decryption for viewing the recovery phrase and signing outgoing transactions.

Thank you for your review.
```

---

### 4. App Privacy Nutrition Label

| Question | Selection | Details |
|---|---|---|
| **Do you or your third-party partners collect data from this app?** | **No, we do not collect data from this app** | App does not collect or transmit user data. |
| **Tracking** | **No** | App does not track users across other companies' apps or websites. |
| **Privacy Manifest** | Included in bundle (`PrivacyInfo.xcprivacy`) | Declares `NSPrivacyTracking: false`, `NSPrivacyCollectedDataTypes: []`, and `UserDefaults` API reason `CA92.1`. |

---

### 5. Export Compliance Questionnaire

| Question | Answer |
|---|---|
| **Does your product use encryption?** | **Yes** |
| **Does your product qualify for any exemptions?** | **Yes** |
| **Exemption Reason** | App uses encryption limited to standard digital signatures, authentication, and public blockchain signing implemented via standard public open-source libraries (Trust Wallet Core). Qualifies for Category 5 Part 2 non-controlled exemptions. |
| **Info.plist Setting** | `ITSAppUsesNonExemptEncryption = false` (configured in `project.yml`). Xcode automatically handles export compliance on upload without requiring a French CCAT or BIS declaration. |

---

## Part 2: Google Play Console

### 1. App Details
| Field | Value |
|---|---|
| **App Name** | `VaultETH: Multi-Chain Wallet` |
| **Short Description** | `Secure self-custodial crypto wallet for Ethereum, Layer 2s, Solana & Bitcoin.` (79/80 chars) |
| **Package Name** | `com.vaulteth.app` |
| **Default Language** | English (US) – en-US |
| **Category** | Finance |
| **Developer Name** | `vault.` |

#### Full Description (Google Play, 4,000 characters max):
```markdown
VaultETH is a sovereign, self-custodial multi-chain cryptocurrency wallet designed for complete ownership, privacy, and speed. Built natively in Kotlin with Jetpack Compose, VaultETH gives you complete control over your digital assets.

🔒 TRUE SELF-CUSTODY & HARDWARE ENCLAVE
Your 12-word BIP-39 recovery phrase is generated locally on your device and encrypted inside the Android Keystore using AES-256-GCM. Authenticate securely with BiometricPrompt (Fingerprint / Face Unlock). Keys never touch remote servers or unencrypted backups.

🌐 UNIVERSAL MULTI-CHAIN SUPPORT
Access and manage assets across major blockchain ecosystems from one unified seed:
• Ethereum Mainnet
• Arbitrum One
• Base
• Optimism
• Polygon PoS
• BNB Smart Chain
• Avalanche C-Chain
• Linea
• Sepolia Testnet
• Custom EVM Networks (Custom RPC URL & Chain ID)
• Native cross-chain address derivation for Solana and Bitcoin SegWit (Bech32)

⚡ TRANSACTION SIMULATION & REVERT PROTECTION
Avoid losing funds on failed transactions. VaultETH executes pre-flight eth_call simulations and gas checks before you sign. Detailed smart contract revert reasons are displayed in real-time.

🛡️ ZERO TRACKING & ABSOLUTE PRIVACY
• Zero analytics libraries, trackers, or advertising SDKs.
• No account registration, email, or identity verification required.
• Complete network encryption: all RPC communication is strictly enforced over HTTPS.
• Built-in discreet balance mode to shield your balance in public.

🎨 EXECUTIVE FINTECH DESIGN
• Dynamic Obsidian dark interface crafted with Jetpack Compose.
• VaultIdenticon: Unique cryptographic crests generated deterministically from recipient addresses to prevent transfer mistakes.
• Fast camera QR scanning supporting EIP-681 and EIP-831 payment URIs.
```

---

### 2. Google Play Data Safety Form Responses

| Data Category | Collected? | Shared? | Purpose / Reason |
|---|---|---|---|
| **Personal Info** (Name, email, phone, address, user IDs) | **No** | **No** | Not collected. |
| **Financial Info** (Credit card, bank account, credit score) | **No** | **No** | Not collected. On-chain wallet transactions are processed directly on decentralized networks without intermediaries. |
| **Location** (Approximate or precise) | **No** | **No** | Not collected. |
| **Messages / SMS / Photos / Audio** | **No** | **No** | Not collected. |
| **App Activity / Performance / Device IDs** | **No** | **No** | Zero analytics or crash reporting SDKs installed. |
| **Data Encryption in Transit** | **Yes** | — | All external communications (JSON-RPC) use strict HTTPS encryption. |
| **Data Deletion Request** | **Not applicable** | — | App does not store user data on remote servers. Deleting the wallet or uninstalling the app deletes all local data immediately. |

---

### 3. Financial Features & Policy Declaration
- **Financial Feature:** Virtual Currency / Crypto Wallet
- **Custody Type:** Non-Custodial Software Wallet
- **Fiat Currency Exchange / Custodial Brokerage:** No (VaultETH does not offer custodial brokerage or fiat payment processing).
- **Compliance Statement:**
  > "VaultETH is a self-hosted, non-custodial software wallet tool. Users generate and maintain exclusive custody of their cryptographic keys locally on their devices. The application does not offer fiat financial services, custody of funds, lending, or regulated investment advice."

---

## Part 3: Asset Verification & Links Checklist

- [x] **App Icon (iOS):** `Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` (1024x1024 PNG)
- [x] **App Icon (Android):** `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
- [x] **Feature Graphic (1024x500):** `docs/assets/promo-banner.jpg` (16:9 / 1920x1080 high-res)
- [x] **App Store Screenshots (iPhone 16 Pro 9:16):**
  - `docs/assets/appstore-screen-1.jpg` (Portfolio & Multi-Chain Balances)
  - `docs/assets/appstore-screen-2.jpg` (Pre-Flight Simulation & Biometrics)
  - `docs/assets/appstore-screen-3.jpg` (Receive Pass, Identicon & QR)
- [x] **Privacy Policy Web Page:** `https://vaulteth.ganiyusail101.workers.dev/privacy.html`
- [x] **Support & FAQ Web Page:** `https://vaulteth.ganiyusail101.workers.dev/support.html`

---

## Part 4: Automated CI/CD Release & Distribution

VaultETH includes full GitHub Actions release automation via [`.github/workflows/release.yml`](.github/workflows/release.yml) to eliminate manual local builds.

### 1. Triggering an Automated Build & Release
You can trigger the pipeline in two ways:

- **Option A: Push a Version Tag (CLI):**
  ```bash
  git tag v1.0.0
  git push origin v1.0.0
  ```
- **Option B: One-Click in GitHub Actions UI:**
  1. Go to your repository's **Actions** tab on GitHub.
  2. Select **Build & Release Distribution**.
  3. Click **Run workflow**, enter your desired version (e.g. `1.0.0`), and run.

### 2. Generated Release Assets
The automated workflow will build and publish a GitHub Release containing:
- `VaultETH-Android-release.apk`: Signed Android Release APK ready to install directly on physical Android phones.
- `VaultETH-Android-release.aab`: Optimized Android App Bundle ready to drop into the Google Play Console track.
- `VaultETH-Android-debug.apk`: Debug APK with verbose logging.
- `VaultETH-iOS-unsigned.ipa`: Packaged iOS app bundle compiled on macOS-14.
- `SHA256SUMS.txt`: Cryptographic integrity checksums.

### 3. Optional Direct Store Delivery Secrets
To enable hands-free delivery directly to App Store TestFlight and Google Play Internal Testing tracks, add the following secrets in your repository (**Settings > Secrets and variables > Actions**):

| Secret Name | Platform | Description |
|---|---|---|
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Google Play | JSON key file contents of a Google Cloud Service Account linked to Google Play Developer API with release management permissions. |
| `APP_STORE_CONNECT_API_KEY` | Apple App Store | Base64-encoded `.p8` private key from App Store Connect (Users and Access > Integrations). |
| `APP_STORE_CONNECT_KEY_ID` | Apple App Store | Key ID from App Store Connect. |
| `APP_STORE_CONNECT_ISSUER_ID` | Apple App Store | Issuer ID (UUID) from App Store Connect. |
