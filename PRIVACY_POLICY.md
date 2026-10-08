# Privacy Policy for VaultETH

**Last Updated:** October 8, 2026

VaultETH ("we", "our", or "the app") is an open-source, non-custodial Ethereum wallet application for iOS. Your privacy and financial self-sovereignty are fundamental design principles of VaultETH.

---

## 1. Summary

- **Zero Personal Data Collected:** We do not collect, store, transmit, or sell your personal information, name, email address, phone number, location, or device identifiers.
- **Zero Analytics or Tracking:** VaultETH contains no analytics SDKs, tracking frameworks, advertising libraries, or telemetry.
- **Non-Custodial Architecture:** Your recovery phrase (seed phrase) and private keys never leave your device. We have no access to your funds and cannot recover or reset your recovery phrase if lost.

---

## 2. On-Device Key Storage & Security

- **Local Keychain Storage:** Your BIP-39 recovery phrases are stored exclusively in the iOS Keychain on your local device.
- **Hardware-Backed Protection:** Key items are stored with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` and protected by `kSecAccessControlUserPresence` (Face ID, Touch ID, or device passcode).
- **No Cloud Backup:** Keys and recovery phrases are explicitly flagged not to sync with iCloud Keychain or unencrypted device backups.
- **Memory Hygiene:** Mnemonic buffers in memory are wiped immediately after saving to Keychain.

---

## 3. Third-Party Network Services (RPC Providers)

To display balances, gas fee estimates, and broadcast transactions to Ethereum Mainnet, VaultETH connects to public Ethereum JSON-RPC nodes:

- **Primary Provider:** PublicNode (`https://ethereum-rpc.publicnode.com`)
- **Fallback Provider:** Cloudflare Ethereum Gateway (`https://cloudflare-eth.com`)

### What RPC Providers See:
When the app communicates with these nodes over standard HTTPS:
1. **IP Address:** The node provider sees your device's IP address, as required by the TCP/IP and HTTP protocols.
2. **Public Ethereum Address:** The node provider receives the public address being queried (e.g. for `eth_getBalance` or `eth_getTransactionCount`).
3. **Signed Transactions:** When sending funds, the raw signed transaction hex is sent via `eth_sendRawTransaction`.

*Note: RPC providers never receive your private keys or recovery phrase. You can verify network traffic by inspecting our open-source codebase.*

---

## 4. Local Data Stored on Device

VaultETH stores minimal, non-sensitive preferences locally on your device via iOS `UserDefaults`:
- Wallet metadata (user-assigned wallet names and public Ethereum addresses).
- Local history of sent transactions (transaction hash, recipient address, amount, date, status).
- Backed-up confirmation status flags.

This data is used solely to operate the app locally and can be deleted at any time by deleting the wallet or uninstalling the app.

---

## 5. Public Blockchain Notice

Transactions sent via VaultETH are broadcast to the decentralized Ethereum public network. Once confirmed on-chain, transaction details (sender address, recipient address, amount, gas fees, and transaction hash) are permanent, immutable, and publicly visible to anyone on the Ethereum blockchain.

---

## 6. Children's Privacy

VaultETH does not knowingly collect or solicit any personal information from children under 13.

---

## 7. Contact & Support

If you have questions regarding this Privacy Policy or VaultETH's security architecture, you may contact us via:
- **GitHub Repository:** [https://github.com/ganiyucall911/VaultETH](https://github.com/ganiyucall911/VaultETH)
- **Support Issues:** [https://github.com/ganiyucall911/VaultETH/issues](https://github.com/ganiyucall911/VaultETH/issues)
