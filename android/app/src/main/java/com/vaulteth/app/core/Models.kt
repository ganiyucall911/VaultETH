package com.vaulteth.app.core

import java.math.BigDecimal
import java.math.BigInteger

enum class TransactionStatus {
    PENDING,
    CONFIRMED,
    FAILED
}

data class SentTransaction(
    val id: String = java.util.UUID.randomUUID().toString(),
    val hash: String,
    val recipient: String,
    val amount: String,
    val networkName: String,
    val timestamp: Long = System.currentTimeMillis(),
    val status: TransactionStatus = TransactionStatus.PENDING
)

data class VaultWallet(
    val id: String = java.util.UUID.randomUUID().toString(),
    val name: String,
    val address: String,
    val solanaAddress: String = "",
    val bitcoinAddress: String = "",
    val isBackedUp: Boolean = false,
    val createdAt: Long = System.currentTimeMillis()
)

data class PaymentURI(
    val recipient: String,
    val amountEth: String? = null,
    val valueWei: BigInteger? = null,
    val chainId: Long? = null
)

data class BlockchainNetwork(
    val id: String,
    val name: String,
    val chainId: Long,
    val symbol: String,
    val rpcUrls: List<String>,
    val explorerTxUrl: String,
    val explorerAddressUrl: String,
    val accentHex: Long,
    val isTestnet: Boolean = false,
    val isCustom: Boolean = false
) {
    companion object {
        val Ethereum = BlockchainNetwork(
            id = "ethereum",
            name = "Ethereum Mainnet",
            chainId = 1L,
            symbol = "ETH",
            rpcUrls = listOf(
                "https://ethereum-rpc.publicnode.com",
                "https://cloudflare-eth.com"
            ),
            explorerTxUrl = "https://etherscan.io/tx/",
            explorerAddressUrl = "https://etherscan.io/address/",
            accentHex = 0xFF627EEA
        )

        val Arbitrum = BlockchainNetwork(
            id = "arbitrum",
            name = "Arbitrum One",
            chainId = 42161L,
            symbol = "ETH",
            rpcUrls = listOf(
                "https://arb1.arbitrum.io/rpc",
                "https://arbitrum-one-rpc.publicnode.com"
            ),
            explorerTxUrl = "https://arbiscan.io/tx/",
            explorerAddressUrl = "https://arbiscan.io/address/",
            accentHex = 0xFF28A0F0
        )

        val Base = BlockchainNetwork(
            id = "base",
            name = "Base",
            chainId = 8453L,
            symbol = "ETH",
            rpcUrls = listOf(
                "https://mainnet.base.org",
                "https://base-rpc.publicnode.com"
            ),
            explorerTxUrl = "https://basescan.org/tx/",
            explorerAddressUrl = "https://basescan.org/address/",
            accentHex = 0xFF0052FF
        )

        val Optimism = BlockchainNetwork(
            id = "optimism",
            name = "Optimism",
            chainId = 10L,
            symbol = "ETH",
            rpcUrls = listOf(
                "https://mainnet.optimism.io",
                "https://optimism-rpc.publicnode.com"
            ),
            explorerTxUrl = "https://optimistic.etherscan.io/tx/",
            explorerAddressUrl = "https://optimistic.etherscan.io/address/",
            accentHex = 0xFFFF0420
        )

        val Polygon = BlockchainNetwork(
            id = "polygon",
            name = "Polygon PoS",
            chainId = 137L,
            symbol = "POL",
            rpcUrls = listOf(
                "https://polygon-bor-rpc.publicnode.com",
                "https://polygon-rpc.com"
            ),
            explorerTxUrl = "https://polygonscan.com/tx/",
            explorerAddressUrl = "https://polygonscan.com/address/",
            accentHex = 0xFF8247E5
        )

        val Bsc = BlockchainNetwork(
            id = "bsc",
            name = "BNB Smart Chain",
            chainId = 56L,
            symbol = "BNB",
            rpcUrls = listOf(
                "https://bsc-rpc.publicnode.com",
                "https://binance.llamarpc.com"
            ),
            explorerTxUrl = "https://bscscan.com/tx/",
            explorerAddressUrl = "https://bscscan.com/address/",
            accentHex = 0xFFF3BA2F
        )

        val Avalanche = BlockchainNetwork(
            id = "avalanche",
            name = "Avalanche C-Chain",
            chainId = 43114L,
            symbol = "AVAX",
            rpcUrls = listOf(
                "https://avalanche-c-chain-rpc.publicnode.com",
                "https://api.avax.network/ext/bc/C/rpc"
            ),
            explorerTxUrl = "https://snowtrace.io/tx/",
            explorerAddressUrl = "https://snowtrace.io/address/",
            accentHex = 0xFFE84142
        )

        val Linea = BlockchainNetwork(
            id = "linea",
            name = "Linea",
            chainId = 59144L,
            symbol = "ETH",
            rpcUrls = listOf(
                "https://rpc.linea.build",
                "https://linea-rpc.publicnode.com"
            ),
            explorerTxUrl = "https://lineascan.build/tx/",
            explorerAddressUrl = "https://lineascan.build/address/",
            accentHex = 0xFF121212
        )

        val Sepolia = BlockchainNetwork(
            id = "sepolia",
            name = "Sepolia Testnet",
            chainId = 11155111L,
            symbol = "SepoliaETH",
            rpcUrls = listOf(
                "https://ethereum-sepolia-rpc.publicnode.com",
                "https://rpc.sepolia.org"
            ),
            explorerTxUrl = "https://sepolia.etherscan.io/tx/",
            explorerAddressUrl = "https://sepolia.etherscan.io/address/",
            accentHex = 0xFF9E9E9E,
            isTestnet = true
        )

        val AllBuiltIn: List<BlockchainNetwork> = listOf(
            Ethereum,
            Arbitrum,
            Base,
            Optimism,
            Polygon,
            Bsc,
            Avalanche,
            Linea,
            Sepolia
        )
    }
}
