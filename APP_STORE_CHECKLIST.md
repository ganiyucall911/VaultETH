# App Store checklist
- [ ] Apple Developer signing configured
- [x] Privacy manifest declares UserDefaults access (reason CA92.1); no tracking, no collected data
- [ ] Privacy policy and support URLs supplied (RPC providers see the user's IP and public address: disclose)
- [ ] Export compliance: the app uses cryptography (signing). Answer the encryption questions and set `ITSAppUsesNonExemptEncryption` accordingly
- [ ] App Review: cryptocurrency wallet guidelines (organisation account may be required for crypto apps)
- [ ] iOS 17 through current OS device testing; Liquid Glass on iOS 26+, fallback on older
- [ ] Recovery, import, delete, reinstall tested
- [ ] Transaction signing independently reviewed
- [ ] TestFlight beta completed before mainnet release
