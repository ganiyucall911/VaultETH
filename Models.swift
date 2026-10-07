import Foundation

/// Public wallet metadata only. Secrets never live here (see KeychainVault).
struct WalletAccount: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    let address: String
    var backedUp: Bool
}

struct CreatedWallet: Identifiable {
    var id: UUID { account.id }
    let account: WalletAccount
    let mnemonic: String
}

struct FeeQuote: Sendable {
    let gasLimit: Data
    let maxFeePerGas: Data
    let maxPriorityFeePerGas: Data
    /// Worst-case fee in wei = gasLimit × maxFeePerGas.
    var maxFeeWei: Data { Wei.multiply(gasLimit, maxFeePerGas) }
}

struct PreparedTransfer: Sendable {
    let from: String
    let to: String
    let valueWei: Data
    let nonce: Data
    let chainID: Data
    let fee: FeeQuote
    let recipientIsContract: Bool
    var maxTotalWei: Data { Wei.add(valueWei, fee.maxFeeWei) }
}

enum ReceiptStatus: Sendable { case success, failed }

// MARK: - Transaction history

/// A record of a broadcast transaction, persisted in UserDefaults alongside wallet metadata.
/// Private keys are never stored here.
struct SentTransaction: Identifiable, Codable, Sendable {
    let id: UUID
    let walletAddress: String       // sender (checksummed)
    let toAddress: String           // recipient (checksummed)
    let toENSName: String?          // ENS name if the user typed one, e.g. "vitalik.eth"
    let amountETH: String           // human-readable ETH amount
    let hash: String                // 0x-prefixed transaction hash
    let date: Date
    var status: TxStatus

    enum TxStatus: String, Codable, Sendable {
        case pending, confirmed, failed
    }
}

// MARK: - Errors

enum WalletError: LocalizedError, Equatable {
    case invalidAddress, invalidChecksum, burnAddress, invalidAmount, wrongNetwork, insufficientBalance
    case signingFailed, addressMismatch, rpcFailure(String), rpcMalformedResult
    case keyNotFound, authenticationUnavailable, authenticationFailed, keychain(Int32)
    case invalidMnemonic, duplicateWallet, walletCreationFailed
    case ensNotFound

    var errorDescription: String? {
        switch self {
        case .invalidAddress:          return "That is not a valid Ethereum address."
        case .invalidChecksum:         return "The address checksum is wrong. Check for typos."
        case .burnAddress:             return "Sending to the zero address would destroy your funds."
        case .invalidAmount:           return "Enter a valid positive ETH amount (up to 18 decimals)."
        case .wrongNetwork:            return "The network is not Ethereum Mainnet. Nothing was signed."
        case .insufficientBalance:     return "Insufficient ETH for the amount plus the maximum network fee."
        case .signingFailed:           return "Transaction signing failed."
        case .addressMismatch:         return "The signing key does not match this wallet. Nothing was sent."
        case .rpcFailure(let m):       return "Network error: \(m)"
        case .rpcMalformedResult:      return "The network returned an unexpected response."
        case .keyNotFound:             return "Wallet key material was not found on this device."
        case .authenticationUnavailable: return "Set a device passcode to protect your wallet."
        case .authenticationFailed:    return "Authentication was cancelled or failed."
        case .keychain(let s):         return "Secure storage error (\(s))."
        case .invalidMnemonic:         return "That recovery phrase is not valid."
        case .duplicateWallet:         return "This wallet is already added."
        case .walletCreationFailed:    return "The wallet could not be created."
        case .ensNotFound:             return "That ENS name is not registered or has no address record."
        }
    }
}
