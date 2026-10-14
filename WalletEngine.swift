import Foundation
import WalletCore

/// Key generation, import, address validation and transaction signing (via Trust Wallet Core).
/// Private keys are derived on demand from the Keychain-held phrase and never stored or logged.
final class WalletEngine: @unchecked Sendable {
    private let vault = KeychainVault()

    struct PaymentURI: Equatable {
        let recipient: String
        let amountETH: String?
    }

    static func parsePaymentURI(_ raw: String) -> PaymentURI {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var amountETH: String?

        if s.lowercased().hasPrefix("ethereum:") {
            s = String(s.dropFirst("ethereum:".count))
            if s.hasPrefix("//") { s = String(s.dropFirst(2)) }
            if s.lowercased().hasPrefix("pay-") { s = String(s.dropFirst(4)) }

            if let queryIndex = s.firstIndex(of: "?") {
                let queryString = String(s[s.index(after: queryIndex)...])
                s = String(s[..<queryIndex])

                for item in queryString.split(separator: "&") {
                    let pair = item.split(separator: "=", maxSplits: 1)
                    guard pair.count == 2 else { continue }
                    let key = pair[0].lowercased()
                    let val = String(pair[1])
                    if key == "amount" {
                        if (try? ETHAmount.wei(from: val)) != nil {
                            amountETH = val
                        }
                    } else if key == "value" {
                        if let formatted = parseWeiValue(val) {
                            amountETH = formatted
                        }
                    }
                }
            }

            if let atIndex = s.firstIndex(of: "@") {
                s = String(s[..<atIndex])
            }
        }

        return PaymentURI(recipient: s, amountETH: amountETH)
    }

    private static func parseWeiValue(_ val: String) -> String? {
        let v = val.lowercased()
        if v.contains("e") {
            let parts = v.split(separator: "e")
            guard parts.count == 2, let exp = Int(parts[1]), exp == 18 else { return nil }
            let base = String(parts[0])
            if (try? ETHAmount.wei(from: base)) != nil { return base }
            return nil
        }
        guard v.allSatisfy({ $0.isNumber }), !v.isEmpty else { return nil }
        let padded = v.count <= 18 ? String(repeating: "0", count: 19 - v.count) + v : v
        let whole = String(padded.dropLast(18))
        let frac = String(padded.suffix(18)).replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
        let result = frac.isEmpty ? whole : "\(whole).\(frac)"
        return (try? ETHAmount.wei(from: result)) != nil ? result : nil
    }

    static func validateRecipient(_ raw: String) throws -> String {
        var s = parsePaymentURI(raw).recipient
        if s.hasPrefix("0X") {
            s = "0x" + s.dropFirst(2)
        }
        guard s.hasPrefix("0x"), s.count == 42, s.dropFirst(2).allSatisfy({ $0.isHexDigit }) else {
            throw WalletError.invalidAddress
        }
        let body = s.dropFirst(2)
        let mixedCase = body.contains(where: { $0.isUppercase }) && body.contains(where: { $0.isLowercase })
        guard let address = AnyAddress(string: s, coin: .ethereum) else {
            throw mixedCase ? WalletError.invalidChecksum : WalletError.invalidAddress
        }
        if mixedCase && address.description != s { throw WalletError.invalidChecksum }
        if let bytes = Data(vaultHex: s), bytes.allSatisfy({ $0 == 0 }) { throw WalletError.burnAddress }
        return address.description
    }

    static func normalize(mnemonic: String) -> String {
        mnemonic.lowercased().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    static func address(forMnemonic mnemonic: String) -> String? {
        let phrase = normalize(mnemonic: mnemonic)
        guard Mnemonic.isValid(mnemonic: phrase),
              let wallet = HDWallet(mnemonic: phrase, passphrase: "") else { return nil }
        return wallet.getAddressForCoin(coin: .ethereum)
    }

    func createWallet(name: String) async throws -> (account: WalletAccount, mnemonic: String) {
        guard let wallet = HDWallet(strength: 128, passphrase: "") else { throw WalletError.walletCreationFailed }
        let phrase = wallet.mnemonic
        let evmAddress = wallet.getAddressForCoin(coin: .ethereum)
        let solanaAddress = wallet.getAddressForCoin(coin: .solana)
        let bitcoinAddress = wallet.getAddressForCoin(coin: .bitcoin)

        let account = WalletAccount(
            id: UUID(),
            name: name,
            address: evmAddress,
            solanaAddress: solanaAddress,
            bitcoinAddress: bitcoinAddress,
            backedUp: false
        )
        try await vault.save(phrase, id: account.id)
        return (account, phrase)
    }

    func importWallet(name: String, mnemonic: String, existingAddresses: [String]) async throws -> WalletAccount {
        let phrase = Self.normalize(mnemonic: mnemonic)
        guard let wallet = HDWallet(mnemonic: phrase, passphrase: "") else { throw WalletError.invalidMnemonic }
        let evmAddress = wallet.getAddressForCoin(coin: .ethereum)
        guard !existingAddresses.contains(where: { $0.lowercased() == evmAddress.lowercased() }) else {
            throw WalletError.duplicateWallet
        }
        let solanaAddress = wallet.getAddressForCoin(coin: .solana)
        let bitcoinAddress = wallet.getAddressForCoin(coin: .bitcoin)

        let account = WalletAccount(
            id: UUID(),
            name: name,
            address: evmAddress,
            solanaAddress: solanaAddress,
            bitcoinAddress: bitcoinAddress,
            backedUp: true
        )
        try await vault.save(phrase, id: account.id)
        return account
    }

    func revealMnemonic(id: UUID) async throws -> String {
        try await vault.load(id: id, reason: "Reveal your VaultETH recovery phrase")
    }

    func delete(id: UUID) { vault.delete(id: id) }

    func signTransfer(_ transfer: PreparedTransfer, accountID: UUID) async throws -> String {
        let mnemonicData = try await vault.loadData(id: accountID, reason: "Authorize sending \(transfer.symbol ?? "ETH")")
        defer { mnemonicData.resetBytes(in: 0..<mnemonicData.count) }
        guard let phrase = String(data: mnemonicData, encoding: .utf8) else { throw WalletError.keyNotFound }
        guard let wallet = HDWallet(mnemonic: phrase, passphrase: "") else { throw WalletError.keyNotFound }
        guard wallet.getAddressForCoin(coin: .ethereum).lowercased() == transfer.from.lowercased() else {
            throw WalletError.addressMismatch
        }
        let key = wallet.getKeyForCoin(coin: .ethereum)
        var keyData = key.data
        defer { keyData.resetBytes(in: 0..<keyData.count) }
        return try Self.sign(transfer, privateKey: keyData)
    }

    static func sign(_ transfer: PreparedTransfer, privateKey: Data) throws -> String {
        var mutableKey = privateKey
        defer { mutableKey.resetBytes(in: 0..<mutableKey.count) }
        let input = EthereumSigningInput.with {
            $0.chainID = Data(Wei.normalize(transfer.chainID))
            $0.nonce = Data(Wei.normalize(transfer.nonce))
            $0.txMode = .enveloped
            $0.gasLimit = Data(Wei.normalize(transfer.fee.gasLimit))
            $0.maxFeePerGas = Data(Wei.normalize(transfer.fee.maxFeePerGas))
            $0.maxInclusionFeePerGas = Data(Wei.normalize(transfer.fee.maxPriorityFeePerGas))
            $0.toAddress = transfer.to
            $0.privateKey = mutableKey
            $0.transaction = EthereumTransaction.with {
                $0.transfer = EthereumTransaction.Transfer.with { $0.amount = Data(Wei.normalize(transfer.valueWei)) }
            }
        }
        let output: EthereumSigningOutput = AnySigner.sign(input: input, coin: .ethereum)
        guard !output.encoded.isEmpty else { throw WalletError.signingFailed }
        return output.encoded.vaultHex0x
    }
}
