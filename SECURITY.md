# Security Policy & Architecture

VaultETH is a self-custody multi-chain vault designed with zero trust principles and local-first cryptographic security.

---

## 1. Cryptographic Key Architecture & Storage

- **Hardware-Backed Protection:** Recovery phrases (BIP-39 mnemonics) are stored exclusively in the iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` and `.userPresence` access control. They are never backed up to iCloud and cannot migrate across devices.
- **Biometric Gating:** Reading sensitive key material requires explicit biometric authentication (Face ID, Touch ID, or device passcode) on every operation.
- **Zeroization in Memory:**
  - In `KeychainVault.swift`, raw mnemonic byte buffers are zeroed (`resetBytes(in:)`) immediately upon ingestion and upon retrieval.
  - In `WalletEngine.swift`, derived private key byte arrays are zeroed with `defer { keyData.resetBytes(in:) }` as soon as transaction signing completes.
- **No Disk Leakage:** Secrets are never written to `UserDefaults`, CoreData, SQLite, or application caches. Only public addresses, wallet labels, and transaction history are persisted in standard local storage.

---

## 2. Network Transport & RPC Hardening

- **Mandatory TLS Encryption:** Both iOS and Android JSON-RPC engines enforce HTTPS (`https://`) across all production node endpoints. Plain HTTP is strictly forbidden and rejected at runtime, except for local development addresses (`localhost` / `127.0.0.1`).
- **Endpoint Failover:** Multi-endpoint fallback automatically reroutes requests if a public RPC provider experiences rate limiting (HTTP 429), timeouts, or synchronization lag.
- **Sanitized Logging:** Node error messages and diagnostic logs sanitize host paths and request URLs to ensure third-party API keys or query tokens are never logged or leaked to system logs.

---

## 3. Pre-Flight Transaction Simulation & Contract Safety

- **Simulation Gate:** Every transaction is simulated on-chain via `eth_call` and gas estimation prior to requesting biometric user authorization.
- **Revert Prevention:** If the node detects an execution failure, the ABI revert reason (`Error(string)`) is parsed and decoded. The authorization button is locked to prevent users from burning non-refundable gas fees on transactions guaranteed to revert.
- **Smart Contract Warnings:** Recipient addresses are inspected via `eth_getCode`. Verified contracts display an amber advisory warning users to confirm the contract accepts direct native transfers.

---

## 4. Release Gates & Verification

| Gate | Status | Verification |
|---|---|---|
| **Automated CI Workflows** | ✅ Active | GitHub Actions runs unit tests on macOS-14 for iOS and Ubuntu for Android on every push/PR. |
| **Brace & AST Depth Audits** | ✅ Passed | Python AST and bracket depth validation across all 22 Swift files and 15 Kotlin files with zero balance errors. |
| **App-Switcher Privacy** | ✅ Active | Sensitive screens wipe seed phrase views immediately when the app enters the background. |
| **Privacy Manifest** | ✅ Compliant | `PrivacyInfo.xcprivacy` declares zero user tracking and zero third-party telemetry. |

---

## Reporting Vulnerabilities

If you discover a security vulnerability in VaultETH, please open a private security advisory on GitHub or email the development team at `security@vaulteth.app`.
