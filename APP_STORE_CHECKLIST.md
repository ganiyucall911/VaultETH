# App Store Submission Checklist & Guide

This document tracks all App Store submission requirements for VaultETH, distinguishing between repository configurations (already implemented) and App Store Connect administrative steps (required by the account owner).

---

## 1. Repository & Code Readiness (✅ Completed in Codebase)

| Requirement | Status | Implementation Details |
|---|---|---|
| **Privacy Manifest** | ✅ Ready | [`PrivacyInfo.xcprivacy`](file:///home/runner/work/VaultETH/VaultETH/PrivacyInfo.xcprivacy) declares `NSPrivacyTracking: false`, `NSPrivacyCollectedDataTypes: []`, and `UserDefaults` API reason `CA92.1`. Explicitly included in `project.yml` resources build phase. |
| **Biometric Usage Description** | ✅ Ready | `NSFaceIDUsageDescription` configured in `project.yml`: *"VaultETH uses Face ID to protect your recovery phrase and to authorize sending ETH."* |
| **Camera Usage Description** | ✅ Ready | `NSCameraUsageDescription` configured in `project.yml`: *"VaultETH uses your camera to scan Ethereum address and ENS payment QR codes."* |
| **Export Compliance Flag** | ✅ Ready | `ITSAppUsesNonExemptEncryption: false` configured in `project.yml`. The app only uses standard, publicly available signing libraries (Trust Wallet Core). |
| **App Store Icon** | ✅ Ready | Asset catalog [`Assets.xcassets/AppIcon.appiconset`](file:///home/runner/work/VaultETH/VaultETH/Assets.xcassets/AppIcon.appiconset) configured with universal 1024x1024 icon and registered in `project.yml`. |
| **Privacy Policy** | ✅ Ready | [`PRIVACY_POLICY.md`](file:///home/runner/work/VaultETH/VaultETH/PRIVACY_POLICY.md) drafted, disclosing non-custodial architecture and third-party RPC node logging (IP address and public wallet address). Linked directly in [`SettingsView`](file:///home/runner/work/VaultETH/VaultETH/RootView.swift). |
| **Support & FAQ Document** | ✅ Ready | [`SUPPORT.md`](file:///home/runner/work/VaultETH/VaultETH/SUPPORT.md) drafted with key recovery warnings, non-custodial FAQ, and issue tracker links. Linked directly in [`SettingsView`](file:///home/runner/work/VaultETH/VaultETH/RootView.swift). |
| **App-Switcher Privacy** | ✅ Ready | Recovery phrase is wiped immediately upon leaving foreground ([`RecoveryPhraseView`](file:///home/runner/work/VaultETH/VaultETH/WalletsView.swift)) to prevent leakage into the iOS multitasking snapshot. |
| **Memory Security** | ✅ Ready | Mnemonic buffers are zeroed out via `resetBytes` immediately after saving to Keychain ([`KeychainVault`](file:///home/runner/work/VaultETH/VaultETH/KeychainVault.swift)). |

---

## 2. App Store Connect & Developer Setup (👉 User Action Items)

### A. Apple Developer Account
- [ ] **Developer / Organization Name:** `vault.`
- [ ] **Account Type:** Apple requires an **Organization** account for apps facilitating cryptocurrency transactions (App Store Review Guideline 3.1.5(a)). Ensure your enrollment is under an organization/business entity.
- [ ] **Bundle Identifier:** Ensure `com.vaulteth.app` is registered under your Team ID in the Apple Developer Certificates, Identifiers & Profiles portal.
- [ ] **Code Signing:** Set your Apple Development/Distribution Team ID in Xcode.

### B. App Store Connect Metadata
- [ ] **App Name:** `VaultETH`
- [ ] **Subtitle:** *Self-Custody Multi-Chain Vault* (under 30 characters)
- [ ] **Category:** Primary: `Finance` | Secondary: `Utilities`
- [ ] **Privacy Policy URL:** `https://ganiyucall911.github.io/VaultETH/privacy.html` (Standalone product page by `vault.`)
- [ ] **Support URL:** `https://ganiyucall911.github.io/VaultETH/support.html` (Standalone product page by `vault.`)
- [ ] **Marketing URL (Optional):** `https://ganiyucall911.github.io/VaultETH/`

### C. App Store Questionnaires
- [ ] **App Privacy Details:**
  - Select *"No, we do not collect data from this app"*.
  - (The privacy manifest covers local `UserDefaults` usage).
- [ ] **Export Compliance Questions:**
  - *"Does your app use encryption?"* → **Yes**
  - *"Does your app qualify for any exemptions?"* → **Yes** (Standard digital signatures / authentication).
  - With `ITSAppUsesNonExemptEncryption = false` set in `project.yml`, Xcode automatically handles this on build upload.
- [ ] **Age Rating:**
  - Complete the questionnaire. Crypto wallets typically receive a 17+ or Unrestricted Web Access rating depending on jurisdiction.

### D. Screenshots Required
- [ ] **6.7" Display (iPhone 15 / 16 Pro Max):** 1290 x 2796 pixels (at least 3 screenshots: Home balance card, Send with QR scan/ENS, and Receive address/QR).
- [ ] **6.5" Display (iPhone 11 Pro Max / XS Max):** 1242 x 2688 pixels.

---

## 3. Pre-Release Verification & Testing

- [ ] **Physical Device Testing:**
  - Biometric prompts (Face ID / Touch ID / Passcode) on key creation, key reveal, and transaction signing.
  - Camera permission prompt when tapping "Scan" in Send screen.
  - Create wallet → write down phrase → delete wallet → import phrase → verify identical derived address.
- [ ] **TestFlight Beta:**
  - Distribute build to internal TestFlight testers.
  - Perform a small test send on Ethereum Mainnet from a throwaway funded wallet.
  - Verify receipt polling and transaction status updates in the History tab.
