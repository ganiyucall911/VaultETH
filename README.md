# VaultETH

Non-custodial Ethereum Mainnet wallet for iPhone (SwiftUI, iOS 17+, Liquid Glass on iOS 26+).
Multiple local wallets, Keychain-protected recovery phrases, receive QR, send ETH (EIP-1559) with an explicit
review step, and minimal Siri/Shortcuts support.

> **Status: pre-release.** Do not use with meaningful funds until the release gates in `SECURITY.md` are done.
> This code has not yet been compiled on a Mac or run on a device. CI will do the first build and run the tests.

## Build
Requires macOS with a recent Xcode.

    brew install xcodegen
    xcodegen generate --spec project.yml
    open VaultETH.xcodeproj

Run the tests: `xcodebuild test -scheme VaultETH -destination 'platform=iOS Simulator,name=<an iPhone>'`
(or push to GitHub; `.github/workflows/ios.yml` builds and tests on every push).

## Layout
- `VaultETH/Core`: hex/wei/amount math (pure Swift), Keychain vault, Ethereum JSON-RPC, WalletCore engine, store
- `VaultETH/Features`: Home, Wallets (create/import/backup), Send (prepare, review, sign, broadcast), Siri intents
- `Tests/VaultETHTests`: unit tests with independently generated vectors (address derivation, EIP-1559 signing, wei math)
- `docs/REVIEW.md`: security review notes and what changed from the earlier drafts

## Security
Never commit seed phrases, private keys, certificates, provisioning profiles or API secrets.
