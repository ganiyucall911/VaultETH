import Foundation

// MARK: - Multi-Chain Networks

/// Represents any supported blockchain network (EVM mainnets, L2 rollups, testnets, and custom chains).
struct BlockchainNetwork: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    var chainID: UInt64
    var symbol: String
    var decimals: Int
    var rpcEndpoints: [String]
    var blockExplorerURL: String
    var isTestnet: Bool
    var accentColorHex: String

    var chainIDData: Data { Wei.from(chainID) }

    static let ethereum = BlockchainNetwork(
        id: "ethereum",
        name: "Ethereum Mainnet",
        chainID: 1,
        symbol: "ETH",
        decimals: 18,
        rpcEndpoints: [
            "https://ethereum-rpc.publicnode.com",
            "https://cloudflare-eth.com"
        ],
        blockExplorerURL: "https://etherscan.io",
        isTestnet: false,
        accentColorHex: "#627EEA"
    )

    static let arbitrum = BlockchainNetwork(
        id: "arbitrum",
        name: "Arbitrum One",
        chainID: 42161,
        symbol: "ETH",
        decimals: 18,
        rpcEndpoints: [
            "https://arbitrum-one-rpc.publicnode.com",
            "https://arb1.arbitrum.io/rpc"
        ],
        blockExplorerURL: "https://arbiscan.io",
        isTestnet: false,
        accentColorHex: "#28A0F0"
    )

    static let base = BlockchainNetwork(
        id: "base",
        name: "Base",
        chainID: 8453,
        symbol: "ETH",
        decimals: 18,
        rpcEndpoints: [
            "https://base-rpc.publicnode.com",
            "https://mainnet.base.org"
        ],
        blockExplorerURL: "https://basescan.org",
        isTestnet: false,
        accentColorHex: "#0052FF"
    )

    static let optimism = BlockchainNetwork(
        id: "optimism",
        name: "Optimism (OP)",
        chainID: 10,
        symbol: "ETH",
        decimals: 18,
        rpcEndpoints: [
            "https://optimism-rpc.publicnode.com",
            "https://mainnet.optimism.io"
        ],
        blockExplorerURL: "https://optimistic.etherscan.io",
        isTestnet: false,
        accentColorHex: "#FF0420"
    )

    static let polygon = BlockchainNetwork(
        id: "polygon",
        name: "Polygon (PoS)",
        chainID: 137,
        symbol: "POL",
        decimals: 18,
        rpcEndpoints: [
            "https://polygon-bor-rpc.publicnode.com",
            "https://polygon-rpc.com"
        ],
        blockExplorerURL: "https://polygonscan.com",
        isTestnet: false,
        accentColorHex: "#8247E5"
    )

    static let bsc = BlockchainNetwork(
        id: "bsc",
        name: "BNB Smart Chain",
        chainID: 56,
        symbol: "BNB",
        decimals: 18,
        rpcEndpoints: [
            "https://bsc-rpc.publicnode.com",
            "https://binance.llamarpc.com"
        ],
        blockExplorerURL: "https://bscscan.com",
        isTestnet: false,
        accentColorHex: "#F3BA2F"
    )

    static let avalanche = BlockchainNetwork(
        id: "avalanche",
        name: "Avalanche C-Chain",
        chainID: 43114,
        symbol: "AVAX",
        decimals: 18,
        rpcEndpoints: [
            "https://avalanche-c-chain-rpc.publicnode.com",
            "https://api.avax.network/ext/bc/C/rpc"
        ],
        blockExplorerURL: "https://snowtrace.io",
        isTestnet: false,
        accentColorHex: "#E84142"
    )

    static let linea = BlockchainNetwork(
        id: "linea",
        name: "Linea",
        chainID: 59144,
        symbol: "ETH",
        decimals: 18,
        rpcEndpoints: [
            "https://linea-rpc.publicnode.com",
            "https://rpc.linea.build"
        ],
        blockExplorerURL: "https://lineascan.build",
        isTestnet: false,
        accentColorHex: "#121212"
    )

    static let sepolia = BlockchainNetwork(
        id: "sepolia",
        name: "Sepolia Testnet",
        chainID: 11155111,
        symbol: "SepoliaETH",
        decimals: 18,
        rpcEndpoints: [
            "https://ethereum-sepolia-rpc.publicnode.com",
            "https://rpc.sepolia.org"
        ],
        blockExplorerURL: "https://sepolia.etherscan.io",
        isTestnet: true,
        accentColorHex: "#CFB53B"
    )

    static let defaultNetworks: [BlockchainNetwork] = [
        .ethereum,
        .arbitrum,
        .base,
        .optimism,
        .polygon,
        .bsc,
        .avalanche,
        .linea,
        .sepolia
    ]
}

// MARK: - Wallet Account

/// Public multi-chain wallet metadata. Secrets never live here (see KeychainVault).
struct WalletAccount: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    let address: String          // Primary EVM address (shared across all EVM chains)
    var solanaAddress: String?   // Derived Solana address from same seed
    var bitcoinAddress: String?  // Derived Bitcoin SegWit (Bech32) address from same seed
    var backedUp: Bool
    var importedENSName: String? // User-linked or imported ENS domain

    init(id: UUID, name: String, address: String, solanaAddress: String? = nil, bitcoinAddress: String? = nil, backedUp: Bool, importedENSName: String? = nil) {
        self.id = id
        self.name = name
        self.address = address
        self.solanaAddress = solanaAddress
        self.bitcoinAddress = bitcoinAddress
        self.backedUp = backedUp
        self.importedENSName = importedENSName
    }
}

struct CreatedWallet: Identifiable {
    var id: UUID { account.id }
    let account: WalletAccount
    let mnemonic: String
}

// MARK: - Transaction Preparation & Fees

struct FeeQuote: Sendable {
    let gasLimit: Data
    let maxFeePerGas: Data
    let maxPriorityFeePerGas: Data
    /// Worst-case fee in wei = gasLimit × maxFeePerGas.
    var maxFeeWei: Data { Wei.multiply(gasLimit, maxFeePerGas) }
}

// MARK: - Transaction Simulation

/// Result of pre-flight on-chain simulation and risk analysis before signing or broadcast.
struct TransactionSimulation: Codable, Hashable, Sendable {
    enum Status: String, Codable, Sendable {
        case success = "Simulation Succeeded"
        case warning = "Simulation Warning"
        case revert  = "Execution Reverts"
    }

    let status: Status
    let isSuccess: Bool
    let revertReason: String?
    let gasEstimated: UInt64
    let assetChangeDescription: String
    let warnings: [String]

    var statusColorHex: String {
        switch status {
        case .success: return "#10B981"
        case .warning: return "#F59E0B"
        case .revert:  return "#EF4444"
        }
    }
}

// MARK: - Protocol Revenue & Monetization

/// Platform routing & monetization configuration.
/// Allows the wallet operator to configure an optional protocol fee (seen or unseen) routed to their treasury wallet.
struct ProtocolFeeConfig: Codable, Sendable, Equatable {
    var isEnabled: Bool
    var treasuryAddress: String
    var feeBasisPoints: Int // e.g. 15 = 0.15%, 25 = 0.25%
    var isTransparent: Bool // true: itemized "Vault Protocol Fee"; false: consolidated into network fee
    var totalCollectedWei: Data

    static let `default` = ProtocolFeeConfig(
        isEnabled: true,
        treasuryAddress: "0x71C836067b457008E901F04bA0A9C348882C7539",
        feeBasisPoints: 15,
        isTransparent: true,
        totalCollectedWei: Data()
    )
}

struct PreparedTransfer: Sendable {
    let from: String
    let to: String
    let valueWei: Data
    let nonce: Data
    let chainID: Data
    let fee: FeeQuote
    let recipientIsContract: Bool
    var simulation: TransactionSimulation?
    var protocolFeeWei: Data
    var treasuryAddress: String?
    var isProtocolFeeTransparent: Bool
    var symbol: String?

    var maxTotalWei: Data {
        let baseTotal = Wei.add(valueWei, fee.maxFeeWei)
        return protocolFeeWei.isEmpty ? baseTotal : Wei.add(baseTotal, protocolFeeWei)
    }

    init(from: String,
         to: String,
         valueWei: Data,
         nonce: Data,
         chainID: Data,
         fee: FeeQuote,
         recipientIsContract: Bool,
         simulation: TransactionSimulation? = nil,
         protocolFeeWei: Data = Data(),
         treasuryAddress: String? = nil,
         isProtocolFeeTransparent: Bool = true,
         symbol: String? = "ETH") {
        self.from = from
        self.to = to
        self.valueWei = valueWei
        self.nonce = nonce
        self.chainID = chainID
        self.fee = fee
        self.recipientIsContract = recipientIsContract
        self.simulation = simulation
        self.protocolFeeWei = protocolFeeWei
        self.treasuryAddress = treasuryAddress
        self.isProtocolFeeTransparent = isProtocolFeeTransparent
        self.symbol = symbol
    }
}

enum ReceiptStatus: Sendable { case success, failed }

// MARK: - Transaction History

/// A record of a broadcast transaction across any supported blockchain.
struct SentTransaction: Identifiable, Codable, Sendable {
    let id: UUID
    let walletAddress: String       // sender (checksummed)
    let toAddress: String           // recipient (checksummed)
    let toENSName: String?          // ENS name if resolved
    let amountETH: String           // formatted amount string
    let hash: String                // transaction hash
    let date: Date
    var status: TxStatus
    var networkID: String?          // e.g. "ethereum", "arbitrum", "base", "polygon"
    var networkName: String?        // e.g. "Base", "Arbitrum One"
    var symbol: String?             // e.g. "ETH", "BNB", "POL", "AVAX"
    var blockExplorerURL: String?   // explorer base URL for deep linking

    enum TxStatus: String, Codable, Sendable {
        case pending, confirmed, failed
    }

    init(id: UUID,
         walletAddress: String,
         toAddress: String,
         toENSName: String?,
         amountETH: String,
         hash: String,
         date: Date,
         status: TxStatus,
         networkID: String? = "ethereum",
         networkName: String? = "Ethereum",
         symbol: String? = "ETH",
         blockExplorerURL: String? = "https://etherscan.io") {
        self.id = id
        self.walletAddress = walletAddress
        self.toAddress = toAddress
        self.toENSName = toENSName
        self.amountETH = amountETH
        self.hash = hash
        self.date = date
        self.status = status
        self.networkID = networkID
        self.networkName = networkName
        self.symbol = symbol
        self.blockExplorerURL = blockExplorerURL
    }
}

// MARK: - Errors

enum WalletError: LocalizedError, Equatable {
    case invalidAddress, invalidChecksum, burnAddress, invalidAmount, wrongNetwork, insufficientBalance
    case signingFailed, addressMismatch, rpcFailure(String), rpcMalformedResult
    case keyNotFound, authenticationUnavailable, authenticationFailed, keychain(Int32)
    case invalidMnemonic, duplicateWallet, walletCreationFailed
    case ensNotFound, invalidNetwork(String), simulationReverted(String)

    var errorDescription: String? {
        switch self {
        case .invalidAddress:          return "That is not a valid address."
        case .invalidChecksum:         return "The address checksum is wrong. Check for typos."
        case .burnAddress:             return "Sending to the zero address would destroy your funds."
        case .invalidAmount:           return "Enter a valid positive amount (up to 18 decimals)."
        case .wrongNetwork:            return "Network mismatch. Broadcast rejected for safety."
        case .insufficientBalance:     return "Insufficient balance for this transfer plus the estimated network gas fee."
        case .signingFailed:           return "Transaction signing failed."
        case .addressMismatch:         return "The signing key does not match this wallet. Nothing was sent."
        case .rpcFailure(let m):       return "Network error: \(m)"
        case .rpcMalformedResult:      return "The node returned an unexpected response."
        case .keyNotFound:             return "Wallet key material was not found on this device."
        case .authenticationUnavailable: return "Set a device passcode to protect your wallet."
        case .authenticationFailed:    return "Authentication was cancelled or failed."
        case .keychain(let s):         return "Secure storage error (\(s))."
        case .invalidMnemonic:         return "That recovery phrase is not valid."
        case .duplicateWallet:         return "This wallet is already added."
        case .walletCreationFailed:    return "The wallet could not be created."
        case .ensNotFound:             return "That ENS name is not registered or has no address record."
        case .invalidNetwork(let n):   return "Invalid or unsupported network: \(n)"
        case .simulationReverted(let r): return "Transaction simulation reverted: \(r)"
        }
    }
}

// MARK: - Tokens & Asset Holdings

/// Represents an individual cryptocurrency / token held across supported networks.
struct TokenAsset: Identifiable, Hashable, Sendable {
    let id: String
    let symbol: String
    let name: String
    let networkID: String
    let networkName: String
    let priceUSD: Double
    let change24h: Double
    var balance: Double
    let accentHex: String

    var fiatValueUSD: Double { balance * priceUSD }

    var formattedPrice: String {
        if priceUSD >= 1.0 {
            return String(format: "$%.2f", priceUSD)
        } else {
            return String(format: "$%.4f", priceUSD)
        }
    }

    var formattedChange: String {
        let prefix = change24h >= 0 ? "+" : ""
        return String(format: "%@%.2f%%", prefix, change24h)
    }

    var formattedHolding: String {
        return String(format: "%.4f %@", balance, symbol)
    }

    var formattedFiat: String {
        return String(format: "$%.2f", fiatValueUSD)
    }

    static let defaultAssets: [TokenAsset] = [
        TokenAsset(id: "eth", symbol: "ETH", name: "Ethereum", networkID: "ethereum", networkName: "Ethereum Mainnet", priceUSD: 3485.20, change24h: 4.82, balance: 4.8250, accentHex: "#627EEA"),
        TokenAsset(id: "btc", symbol: "BTC", name: "Bitcoin", networkID: "bitcoin", networkName: "Bitcoin SegWit", priceUSD: 64120.00, change24h: 2.15, balance: 0.1850, accentHex: "#F7931A"),
        TokenAsset(id: "sol", symbol: "SOL", name: "Solana", networkID: "solana", networkName: "Solana Native", priceUSD: 152.40, change24h: 6.38, balance: 24.50, accentHex: "#14F195"),
        TokenAsset(id: "usdc", symbol: "USDC", name: "USD Coin", networkID: "ethereum", networkName: "Ethereum", priceUSD: 1.00, change24h: 0.00, balance: 1430.00, accentHex: "#2775CA"),
        TokenAsset(id: "arb", symbol: "ARB", name: "Arbitrum", networkID: "arbitrum", networkName: "Arbitrum One", priceUSD: 1.18, change24h: 3.20, balance: 850.00, accentHex: "#28A0F0"),
        TokenAsset(id: "op", symbol: "OP", name: "Optimism", networkID: "optimism", networkName: "Optimism", priceUSD: 1.85, change24h: -1.45, balance: 420.00, accentHex: "#FF0420"),
        TokenAsset(id: "pol", symbol: "POL", name: "Polygon", networkID: "polygon", networkName: "Polygon PoS", priceUSD: 0.42, change24h: 1.12, balance: 1250.00, accentHex: "#8247E5"),
        TokenAsset(id: "bnb", symbol: "BNB", name: "BNB", networkID: "bsc", networkName: "BNB Smart Chain", priceUSD: 585.30, change24h: 0.88, balance: 2.10, accentHex: "#F3BA2F")
    ]
}
