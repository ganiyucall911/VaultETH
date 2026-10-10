import Foundation

@MainActor
final class WalletStore: ObservableObject {
    @Published private(set) var accounts: [WalletAccount] = []
    @Published var selectedAccountID: UUID?
    @Published private(set) var balanceETH = "—"
    @Published private(set) var isLoadingBalance = false
    @Published var balanceError: String?
    @Published private(set) var selectedENSName: String?
    @Published private(set) var sentTransactions: [SentTransaction] = []
    @Published var tokens: [TokenAsset] = TokenAsset.defaultAssets

    var totalPortfolioUSD: Double {
        tokens.reduce(0) { $0 + $1.fiatValueUSD }
    }

    var formattedTotalPortfolioUSD: String {
        String(format: "$%.2f", totalPortfolioUSD)
    }

    // Multi-Chain State
    @Published var selectedNetwork: BlockchainNetwork = .ethereum {
        didSet {
            rpc = EthereumRPC(network: selectedNetwork)
            UserDefaults.standard.set(selectedNetwork.id, forKey: selectedNetworkKey)
        }
    }
    @Published var customNetworks: [BlockchainNetwork] = []

    private let engine = WalletEngine()
    private var rpc = EthereumRPC(network: .ethereum)

    private let defaultsKey = "accounts"
    private let historyKey  = "sentTransactions"
    private let selectedNetworkKey = "selectedNetworkID"
    private let customNetworksKey = "customNetworks"

    var supportedNetworks: [BlockchainNetwork] {
        BlockchainNetwork.defaultNetworks + customNetworks
    }

    var selectedAccount: WalletAccount? { accounts.first { $0.id == selectedAccountID } }

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode([WalletAccount].self, from: data) {
            accounts = saved
            selectedAccountID = saved.first?.id
        }
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let saved = try? JSONDecoder().decode([SentTransaction].self, from: data) {
            sentTransactions = saved
        }
        if let customData = UserDefaults.standard.data(forKey: customNetworksKey),
           let savedCustom = try? JSONDecoder().decode([BlockchainNetwork].self, from: customData) {
            customNetworks = savedCustom
        }
        if let savedNetID = UserDefaults.standard.string(forKey: selectedNetworkKey),
           let match = (BlockchainNetwork.defaultNetworks + customNetworks).first(where: { $0.id == savedNetID }) {
            selectedNetwork = match
            rpc = EthereumRPC(network: match)
        }
    }

    // MARK: - Network Selection & Custom Chains

    func selectNetwork(_ network: BlockchainNetwork) {
        selectedNetwork = network
        rpc = EthereumRPC(network: network)
        balanceETH = "—"
        Task {
            await refreshBalance()
            if network.chainID == 1 {
                await refreshENS()
            } else {
                selectedENSName = nil
            }
            await refreshPendingTransactions()
        }
    }

    func addCustomNetwork(name: String, chainID: UInt64, symbol: String, rpcURL: String, explorerURL: String) {
        let net = BlockchainNetwork(
            id: "custom-\(chainID)",
            name: name,
            chainID: chainID,
            symbol: symbol.uppercased(),
            decimals: 18,
            rpcEndpoints: [rpcURL],
            blockExplorerURL: explorerURL.isEmpty ? "https://etherscan.io" : explorerURL,
            isTestnet: false,
            accentColorHex: "#00F0FF"
        )
        customNetworks.append(net)
        if let data = try? JSONEncoder().encode(customNetworks) {
            UserDefaults.standard.set(data, forKey: customNetworksKey)
        }
        selectNetwork(net)
    }

    // MARK: - Wallets

    func createWallet(name: String) async throws -> CreatedWallet {
        let created = try await engine.createWallet(name: name)
        add(created.account)
        return CreatedWallet(account: created.account, mnemonic: created.mnemonic)
    }

    func importWallet(name: String, mnemonic: String) async throws {
        let account = try await engine.importWallet(name: name, mnemonic: mnemonic,
                                                    existingAddresses: accounts.map(\.address))
        add(account)
    }

    func revealMnemonic(for id: UUID) async throws -> String { try await engine.revealMnemonic(id: id) }

    func markBackedUp(_ id: UUID) { update(id) { $0.backedUp = true } }
    func rename(_ account: WalletAccount, to name: String) { update(account.id) { $0.name = name } }

    /// Sets or clears an imported/linked ENS domain for the given wallet account.
    func setImportedENS(for id: UUID, ensName: String?) {
        update(id) { $0.importedENSName = ensName }
        if selectedAccountID == id {
            selectedENSName = ensName
            if ensName == nil && selectedNetwork.chainID == 1 {
                Task { await refreshENS() }
            }
        }
    }

    func select(_ account: WalletAccount) {
        selectedAccountID = account.id
        balanceETH = "—"
        selectedENSName = account.importedENSName
        Task {
            await refreshBalance()
            if selectedNetwork.chainID == 1 || account.importedENSName == nil {
                await refreshENS()
            }
        }
    }

    func delete(_ account: WalletAccount) {
        engine.delete(id: account.id)
        accounts.removeAll { $0.id == account.id }
        if selectedAccountID == account.id {
            selectedAccountID = accounts.first?.id
            balanceETH = "—"
            selectedENSName = accounts.first?.importedENSName
        }
        persist()
    }

    // MARK: - Balance & ENS

    func refreshBalance() async {
        guard let account = selectedAccount else { return }
        isLoadingBalance = true
        defer { isLoadingBalance = false }
        do {
            let wei = try await rpc.balance(address: account.address)
            guard account.id == selectedAccountID else { return }
            balanceETH = "\(ETHAmount.format(wei: wei)) \(selectedNetwork.symbol)"
            balanceError = nil
        } catch {
            balanceError = error.localizedDescription
        }
    }

    func refreshENS() async {
        guard let account = selectedAccount else { selectedENSName = nil; return }
        // If user explicitly imported/linked an ENS domain, prioritize it
        if let imported = account.importedENSName, !imported.isEmpty {
            selectedENSName = imported
            return
        }
        guard selectedNetwork.chainID == 1 else {
            selectedENSName = nil
            return
        }
        do {
            let ensRPC = EthereumRPC(network: .ethereum)
            let ens = try await ENSResolver.resolveAddress(account.address, rpc: ensRPC)
            guard account.id == selectedAccountID else { return }
            selectedENSName = ens
        } catch {
            guard account.id == selectedAccountID else { return }
            selectedENSName = nil
        }
    }

    // MARK: - Sending

    /// Prepares a transaction on the currently selected blockchain network.
    func prepareTransfer(to rawRecipient: String, amountText: String) async throws -> PreparedTransfer {
        guard let account = selectedAccount else { throw WalletError.keyNotFound }
        let recipient = try WalletEngine.validateRecipient(rawRecipient)
        let value = try ETHAmount.wei(from: amountText)

        let targetChainIDData = selectedNetwork.chainIDData
        let nodeChainID = try await rpc.chainID()
        guard Wei.compare(nodeChainID, targetChainIDData) == .orderedSame else {
            throw WalletError.wrongNetwork
        }

        let balance = try await rpc.balance(address: account.address)
        let nonce = try await rpc.nonce(address: account.address)
        let fee = try await rpc.feeQuote(from: account.address, to: recipient, value: value)
        let isContract = try await rpc.isContract(address: recipient)

        let transfer = PreparedTransfer(from: account.address, to: recipient, valueWei: value, nonce: nonce,
                                        chainID: targetChainIDData, fee: fee, recipientIsContract: isContract)
        guard Wei.compare(balance, transfer.maxTotalWei) != .orderedAscending else {
            throw WalletError.insufficientBalance
        }
        return transfer
    }

    /// Signs and broadcasts across the selected blockchain.
    func send(_ transfer: PreparedTransfer, ensName: String? = nil) async throws -> String {
        guard let account = accounts.first(where: { $0.address.lowercased() == transfer.from.lowercased() }) else {
            throw WalletError.keyNotFound
        }
        let raw = try await engine.signTransfer(transfer, accountID: account.id)
        let hash = try await rpc.sendRaw(raw)
        recordSent(transfer, hash: hash, ensName: ensName)
        return hash
    }

    /// Polls for receipt on the network where the transaction was broadcast.
    func waitForReceipt(hash: String) async -> ReceiptStatus? {
        for _ in 0..<24 {
            if Task.isCancelled { return nil }
            if let status = try? await rpc.receipt(hash: hash) {
                await refreshBalance()
                updateTransactionStatus(hash: hash,
                                        status: status == .success ? .confirmed : .failed)
                return status
            }
            try? await Task.sleep(for: .seconds(5))
        }
        return nil
    }

    // MARK: - Transaction History

    private func recordSent(_ transfer: PreparedTransfer, hash: String, ensName: String?) {
        let tx = SentTransaction(
            id: UUID(),
            walletAddress: transfer.from,
            toAddress: transfer.to,
            toENSName: ensName,
            amountETH: ETHAmount.format(wei: transfer.valueWei),
            hash: hash,
            date: Date(),
            status: .pending,
            networkID: selectedNetwork.id,
            networkName: selectedNetwork.name,
            symbol: selectedNetwork.symbol,
            blockExplorerURL: selectedNetwork.blockExplorerURL
        )
        sentTransactions.insert(tx, at: 0)
        persistHistory()
    }

    func updateTransactionStatus(hash: String, status: SentTransaction.TxStatus) {
        guard let i = sentTransactions.firstIndex(where: { $0.hash == hash }) else { return }
        sentTransactions[i].status = status
        persistHistory()
    }

    func refreshPendingTransactions() async {
        let pending = sentTransactions.filter { $0.status == .pending }
        guard !pending.isEmpty else { return }
        for tx in pending {
            let txRPC: EthereumRPC
            if let netID = tx.networkID, let net = supportedNetworks.first(where: { $0.id == netID }) {
                txRPC = EthereumRPC(network: net)
            } else {
                txRPC = rpc
            }
            if let status = try? await txRPC.receipt(hash: tx.hash) {
                updateTransactionStatus(hash: tx.hash,
                                        status: status == .success ? .confirmed : .failed)
            }
        }
        await refreshBalance()
    }

    func deleteTransaction(id: UUID) {
        sentTransactions.removeAll { $0.id == id }
        persistHistory()
    }

    func clearHistory(for address: String) {
        sentTransactions.removeAll { $0.walletAddress.lowercased() == address.lowercased() }
        persistHistory()
    }

    // MARK: - Persistence

    private func add(_ account: WalletAccount) {
        accounts.append(account)
        selectedAccountID = account.id
        balanceETH = "—"
        persist()
        Task { await refreshBalance() }
    }

    private func update(_ id: UUID, _ change: (inout WalletAccount) -> Void) {
        guard let i = accounts.firstIndex(where: { $0.id == id }) else { return }
        change(&accounts[i])
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(accounts) { UserDefaults.standard.set(data, forKey: defaultsKey) }
    }

    private func persistHistory() {
        if let data = try? JSONEncoder().encode(sentTransactions) { UserDefaults.standard.set(data, forKey: historyKey) }
    }
}
