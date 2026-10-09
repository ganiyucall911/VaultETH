package com.vaulteth.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.vaulteth.app.core.*
import com.vaulteth.app.ui.screens.*
import com.vaulteth.app.ui.theme.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.math.BigInteger

class VaultViewModel(private val secureVault: SecureVault) : ViewModel() {

    private val _wallets = MutableStateFlow<List<VaultWallet>>(emptyList())
    val wallets = _wallets.asStateFlow()

    private val _selectedWalletId = MutableStateFlow<String?>(null)
    val selectedWalletId = _selectedWalletId.asStateFlow()

    private val _selectedNetwork = MutableStateFlow<BlockchainNetwork>(BlockchainNetwork.Ethereum)
    val selectedNetwork = _selectedNetwork.asStateFlow()

    private val _balance = MutableStateFlow("0.0000")
    val balance = _balance.asStateFlow()

    private val _isLoadingBalance = MutableStateFlow(false)
    val isLoadingBalance = _isLoadingBalance.asStateFlow()

    private val _transactions = MutableStateFlow<List<SentTransaction>>(emptyList())
    val transactions = _transactions.asStateFlow()

    init {
        loadData()
    }

    private fun loadData() {
        val loadedWallets = secureVault.loadWallets()
        val loadedNetworkId = secureVault.getSelectedNetworkId()
        val foundNetwork = BlockchainNetwork.AllBuiltIn.find { it.id == loadedNetworkId } ?: BlockchainNetwork.Ethereum
        _selectedNetwork.value = foundNetwork
        _transactions.value = secureVault.loadTransactions()

        if (loadedWallets.isEmpty()) {
            // Create default sovereign vault
            createWallet("Primary Vault")
        } else {
            _wallets.value = loadedWallets
            val savedSelectedId = secureVault.getSelectedWalletId()
            val initialId = if (loadedWallets.any { it.id == savedSelectedId }) savedSelectedId else loadedWallets.first().id
            _selectedWalletId.value = initialId
            refreshBalance()
        }
    }

    fun selectWallet(wallet: VaultWallet) {
        _selectedWalletId.value = wallet.id
        secureVault.setSelectedWalletId(wallet.id)
        refreshBalance()
    }

    fun selectNetwork(network: BlockchainNetwork) {
        _selectedNetwork.value = network
        secureVault.setSelectedNetworkId(network.id)
        refreshBalance()
    }

    fun createWallet(name: String) {
        viewModelScope.launch {
            val words = WalletEngine.generateMnemonic()
            val seed = WalletEngine.mnemonicToSeed(words)
            val evm = WalletEngine.deriveEVMAddress(seed)
            val solana = WalletEngine.deriveSolanaAddress(seed)
            val btc = WalletEngine.deriveBitcoinAddress(seed)

            val newWallet = VaultWallet(
                name = name,
                address = evm.second,
                solanaAddress = solana,
                bitcoinAddress = btc
            )
            secureVault.saveMnemonic(newWallet.id, words)

            val updated = _wallets.value + newWallet
            _wallets.value = updated
            secureVault.saveWallets(updated)
            selectWallet(newWallet)
        }
    }

    fun importWallet(name: String, words: List<String>) {
        viewModelScope.launch {
            val seed = WalletEngine.mnemonicToSeed(words)
            val evm = WalletEngine.deriveEVMAddress(seed)
            val solana = WalletEngine.deriveSolanaAddress(seed)
            val btc = WalletEngine.deriveBitcoinAddress(seed)

            val newWallet = VaultWallet(
                name = name,
                address = evm.second,
                solanaAddress = solana,
                bitcoinAddress = btc,
                isBackedUp = true
            )
            secureVault.saveMnemonic(newWallet.id, words)

            val updated = _wallets.value + newWallet
            _wallets.value = updated
            secureVault.saveWallets(updated)
            selectWallet(newWallet)
        }
    }

    fun getMnemonic(wallet: VaultWallet): List<String>? {
        return secureVault.getMnemonic(wallet.id)
    }

    fun setImportedEns(walletId: String, ensName: String?) {
        val normalized = ensName?.trim()?.lowercase()?.ifBlank { null }
        val updated = _wallets.value.map { w ->
            if (w.id == walletId) {
                w.copy(importedEnsName = normalized)
            } else {
                w
            }
        }
        _wallets.value = updated
        secureVault.saveWallets(updated)
    }

    fun refreshBalance() {
        val currentWallet = _wallets.value.find { it.id == _selectedWalletId.value } ?: return
        val currentNet = _selectedNetwork.value

        viewModelScope.launch {
            _isLoadingBalance.value = true
            try {
                val rpc = EthereumRPC(currentNet)
                val wei = rpc.getBalance(currentWallet.address)
                _balance.value = WalletEngine.weiToEth(wei)
            } catch (_: Exception) {
                // Keep last known balance if network glitch
            } finally {
                _isLoadingBalance.value = false
            }
        }
    }

    fun sendTransaction(recipient: String, amountEth: String, onResult: (Boolean, String) -> Unit) {
        val currentWallet = _wallets.value.find { it.id == _selectedWalletId.value }
        if (currentWallet == null) {
            onResult(false, "No active vault selected")
            return
        }
        val words = secureVault.getMnemonic(currentWallet.id)
        if (words == null) {
            onResult(false, "Vault private keys not accessible")
            return
        }

        viewModelScope.launch {
            try {
                val rpc = EthereumRPC(_selectedNetwork.value)
                var resolvedTo = recipient
                if (recipient.endsWith(".eth", ignoreCase = true)) {
                    val resolved = rpc.resolveENS(recipient) ?: throw RuntimeException("Could not resolve ENS name")
                    resolvedTo = resolved
                }

                val seed = WalletEngine.mnemonicToSeed(words)
                val evm = WalletEngine.deriveEVMAddress(seed)
                val privKey = evm.first

                val nonce = rpc.getTransactionCount(currentWallet.address)
                val valueWei = WalletEngine.ethToWei(amountEth) ?: throw RuntimeException("Invalid amount")
                val gasLimit = BigInteger.valueOf(21000L)

                val signedTx = if (_selectedNetwork.value.id == "bsc") {
                    // BSC uses legacy EIP-155
                    val gasPrice = rpc.getGasPrice()
                    WalletEngine.signLegacy(
                        chainId = _selectedNetwork.value.chainId,
                        nonce = nonce,
                        gasPrice = gasPrice,
                        gasLimit = gasLimit,
                        to = resolvedTo,
                        value = valueWei,
                        data = ByteArray(0),
                        privateKey = privKey
                    )
                } else {
                    // Standard EVM EIP-1559
                    val baseFee = rpc.getLatestBaseFee() ?: BigInteger.valueOf(20_000_000_000L)
                    val priorityFee = rpc.getMaxPriorityFeePerGas()
                    val maxFee = baseFee.multiply(BigInteger.valueOf(2)).add(priorityFee)
                    WalletEngine.signEIP1559(
                        chainId = _selectedNetwork.value.chainId,
                        nonce = nonce,
                        maxPriorityFeePerGas = priorityFee,
                        maxFeePerGas = maxFee,
                        gasLimit = gasLimit,
                        to = resolvedTo,
                        value = valueWei,
                        data = ByteArray(0),
                        privateKey = privKey
                    )
                }

                val txHash = rpc.sendRawTransaction(signedTx)
                val newTx = SentTransaction(
                    hash = txHash,
                    recipient = resolvedTo,
                    amount = amountEth,
                    networkName = _selectedNetwork.value.name,
                    status = TransactionStatus.PENDING
                )
                val updatedTxs = listOf(newTx) + _transactions.value
                _transactions.value = updatedTxs
                secureVault.saveTransactions(updatedTxs)

                refreshBalance()
                onResult(true, txHash)
            } catch (e: Exception) {
                onResult(false, e.message ?: "Transaction broadcast failed")
            }
        }
    }

    fun clearHistory() {
        _transactions.value = emptyList()
        secureVault.saveTransactions(emptyList())
    }
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val secureVault = SecureVault(applicationContext)

        setContent {
            VaultETHTheme {
                val viewModel: VaultViewModel = remember { VaultViewModel(secureVault) }
                VaultApp(viewModel = viewModel)
            }
        }
    }
}

enum class NavigationTab(val title: String, val icon: ImageVector) {
    VAULT("Vault", Icons.Default.Shield),
    WALLETS("Wallets", Icons.Default.AccountBalanceWallet),
    ACTIVITY("Activity", Icons.Default.History),
    SETTINGS("Settings", Icons.Default.Settings)
}

enum class ActiveScreen {
    HOME,
    SEND,
    RECEIVE
}

@Composable
fun VaultApp(viewModel: VaultViewModel) {
    var currentTab by remember { mutableStateOf(NavigationTab.VAULT) }
    var activeScreen by remember { mutableStateOf(ActiveScreen.HOME) }

    val wallets by viewModel.wallets.collectAsState()
    val selectedWalletId by viewModel.selectedWalletId.collectAsState()
    val selectedNetwork by viewModel.selectedNetwork.collectAsState()
    val balance by viewModel.balance.collectAsState()
    val isLoadingBalance by viewModel.isLoadingBalance.collectAsState()
    val transactions by viewModel.transactions.collectAsState()

    val currentWallet = wallets.find { it.id == selectedWalletId }

    Scaffold(
        containerColor = VaultBackground,
        bottomBar = {
            if (activeScreen == ActiveScreen.HOME) {
                NavigationBar(
                    containerColor = VaultSurface,
                    contentColor = VaultCyan
                ) {
                    NavigationTab.values().forEach { tab ->
                        val isSelected = currentTab == tab
                        NavigationBarItem(
                            selected = isSelected,
                            onClick = { currentTab = tab },
                            icon = { Icon(imageVector = tab.icon, contentDescription = tab.title) },
                            label = { Text(tab.title) },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = Color.Black,
                                selectedTextColor = VaultCyan,
                                indicatorColor = VaultCyan,
                                unselectedIconColor = VaultTextMuted,
                                unselectedTextColor = VaultTextMuted
                            )
                        )
                    }
                }
            }
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            when (activeScreen) {
                ActiveScreen.SEND -> {
                    SendScreen(
                        wallet = currentWallet,
                        network = selectedNetwork,
                        balance = balance,
                        onBack = { activeScreen = ActiveScreen.HOME },
                        onOpenScanner = { /* Scanner activity launch */ },
                        onSendTransaction = { recipient, amount, onComplete ->
                            viewModel.sendTransaction(recipient, amount, onComplete)
                        }
                    )
                }
                ActiveScreen.RECEIVE -> {
                    ReceiveScreen(
                        wallet = currentWallet,
                        onBack = { activeScreen = ActiveScreen.HOME }
                    )
                }
                ActiveScreen.HOME -> {
                    when (currentTab) {
                        NavigationTab.VAULT -> {
                            VaultHomeScreen(
                                wallet = currentWallet,
                                selectedNetwork = selectedNetwork,
                                balance = balance,
                                isLoadingBalance = isLoadingBalance,
                                recentTransactions = transactions,
                                onSelectNetwork = { viewModel.selectNetwork(it) },
                                onRefresh = { viewModel.refreshBalance() },
                                onNavigateToSend = { activeScreen = ActiveScreen.SEND },
                                onNavigateToReceive = { activeScreen = ActiveScreen.RECEIVE },
                                onNavigateToScan = { activeScreen = ActiveScreen.SEND },
                                onNavigateToWallets = { currentTab = NavigationTab.WALLETS }
                            )
                        }
                        NavigationTab.WALLETS -> {
                            WalletsScreen(
                                wallets = wallets,
                                selectedWalletId = selectedWalletId,
                                onSelectWallet = { viewModel.selectWallet(it) },
                                onCreateWallet = { viewModel.createWallet("Vault #${wallets.size + 1}") },
                                onImportWallet = { name, words -> viewModel.importWallet(name, words) },
                                onDeleteWallet = { /* Delete handler */ },
                                onViewMnemonic = { viewModel.getMnemonic(it) },
                                onSetImportedEns = { walletId, ensName -> viewModel.setImportedEns(walletId, ensName) }
                            )
                        }
                        NavigationTab.ACTIVITY -> {
                            ActivityScreen(
                                transactions = transactions,
                                selectedNetwork = selectedNetwork,
                                onClearHistory = { viewModel.clearHistory() }
                            )
                        }
                        NavigationTab.SETTINGS -> {
                            SettingsScreen(selectedNetwork = selectedNetwork)
                        }
                    }
                }
            }
        }
    }
}
