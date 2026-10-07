# Security

VaultETH is non-custodial. Recovery phrases are stored only in the iOS Keychain (this-device-only, user-presence
protected) and are never logged, uploaded, or written to UserDefaults. Only wallet names and public addresses are
stored in UserDefaults.

## Release gates (all required before real funds)
1. Build and unit tests pass in CI; manual test on at least two physical devices (Face ID and passcode-only).
2. Create, back up, delete, reinstall, import: verify the same address and a working signature on clean devices.
3. Send a tiny mainnet transaction from a throwaway wallet; compare hash, nonce, fee and recipient on a block explorer.
4. Independent mobile and blockchain security review of signing, key handling and the RPC layer.
5. Dependency review of Trust Wallet Core (pinned at 4.2.9).
6. Decide on ERC-20, ENS and contract-interaction support; add transaction simulation before enabling contract calls.

## Known limitations
See `docs/REVIEW.md`.
