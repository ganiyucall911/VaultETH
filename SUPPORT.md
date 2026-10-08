# VaultETH Support

Welcome to the VaultETH support page. VaultETH is a non-custodial, open-source Ethereum wallet for iOS.

---

## Frequently Asked Questions

### 1. What does "non-custodial" mean?
Non-custodial means you, and only you, own and control the cryptographic keys to your Ethereum wallet. VaultETH never has access to your funds, private keys, or recovery phrase.

### 2. Can you recover my wallet if I lose my 12-word recovery phrase?
**No.** Because VaultETH is strictly non-custodial, your recovery phrase is generated directly on your device and stored in the iOS Secure Keychain. It is never sent to any server. If you lose your recovery phrase and delete the app, **no one** (including the developers) can restore your wallet or recover your funds. **Always write down your phrase and store it safely.**

### 3. Does VaultETH charge any fees?
VaultETH charges **zero** fees. 100% of the network fee displayed during transactions is paid directly to the Ethereum network validators for transaction processing.

### 4. What should I do if a transaction is pending for a long time?
Ethereum network congestion can occasionally cause transactions with lower priority fees to wait for confirmation. VaultETH uses real-time EIP-1559 base fee queries plus headroom to prevent stuck transactions. You can tap **Check status** or pull to refresh in the **History** tab to query the latest on-chain receipt from the network.

### 5. Why does VaultETH require Face ID or Passcode?
Face ID, Touch ID, or your device passcode is used by the iOS Keychain to protect your recovery phrase from unauthorized access. Every time you view your phrase or sign a transaction, iOS prompts you to authenticate.

---

## Contact & Bug Reports

- **Issue Tracker:** [GitHub Issues](https://github.com/ganiyucall911/VaultETH/issues)
- **Repository:** [https://github.com/ganiyucall911/VaultETH](https://github.com/ganiyucall911/VaultETH)

When reporting a bug, please include:
- iOS version and iPhone model
- Steps to reproduce the issue
- Expected vs. actual behavior
- *(Never share your private key or recovery phrase in issue reports!)*
