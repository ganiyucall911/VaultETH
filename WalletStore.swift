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

    private let engine = WalletEngine()
    private let rpc = EthereumRPC()
    private let defaultsKey = "accounts"           // public metadata only (name + address); secrets stay in Keychain
    private let historyKey  = "sentTransactions"   // sent-transaction history (no secrets)

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

    func select(_ account: WalletAccount) {
        selectedAccountID = account.id
        balanceETH = "—"
        selectedENSName = nil
        Task {
            await refreshBalance()
            await refreshENS()
        }
    }

    func delete(_ account: WalletAccount) {
        engine.delete(id: account.id)
        accounts.removeAll { $0.id == account.id }
        if selectedAccountID == account.id {
            selectedAccountID = accounts.first?.id
            balanceETH = "—"
            selectedENSName = nil
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
            guard account.id == selectedAccountID else { return }      // user switched wallets mid-request
            balanceETH = ETHAmount.format(wei: wei) + " ETH"
            balanceError = nil
        } catch {
            balanceError = error.localizedDescription
        }
    }

    func refreshENS() async {
        guard let account = selectedAccount else { selectedENSName = nil; return }
        do {
            let ens = try await ENSResolver.resolveAddress(account.address, rpc: rpc)
            guard account.id == selectedAccountID else { return }
            selectedENSName = ens
        } catch {
            guard account.id == selectedAccountID else { return }
            selectedENSName = nil
        }
    }

    // MARK: - Sending

    /// Validates everything and builds the exact transaction the user will review. Nothing is signed here.
    func prepareTransfer(to rawRecipient: String, amountText: String) async throws -> PreparedTransfer {
        guard let account = selectedAccount else { throw WalletError.keyNotFound }
        let recipient = try WalletEngine.validateRecipient(rawRecipient)
        let value = try ETHAmount.wei(from: amountText)

        guard Wei.compare(try await rpc.chainID(), EthereumRPC.mainnetChainID) == .orderedSame else {
            throw WalletError.wrongNetwork
        }
        let balance = try await rpc.balance(address: account.address)
        let nonce = try await rpc.nonce(address: account.address)
        let fee = try await rpc.feeQuote(from: account.address, to: recipient, value: value)
        let isContract = try await rpc.isContract(address: recipient)

        let transfer = PreparedTransfer(from: account.address, to: recipient, valueWei: value, nonce: nonce,
                                        chainID: EthereumRPC.mainnetChainID, fee: fee, recipientIsContract: isContract)
        guard Wei.compare(balance, transfer.maxTotalWei) != .orderedAscending else {
            throw WalletError.insufficientBalance
        }
        return transfer
    }

    /// Signs (after Face ID / passcode) and broadcasts. Returns the transaction hash.
    /// Pass `ensName` when the user typed an ENS name so it appears in history.
    func send(_ transfer: PreparedTransfer, ensName: String? = nil) async throws -> String {
        guard let account = accounts.first(where: { $0.address.lowercased() == transfer.from.lowercased() }) else {
            throw WalletError.keyNotFound
        }
        let raw = try await engine.signTransfer(transfer, accountID: account.id)
        let hash = try await rpc.sendRaw(raw)
        recordSent(transfer, hash: hash, ensName: ensName)
        return hash
    }

    /// Polls for a receipt for about two minutes. Returns nil if still pending after that.
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

    // MARK: - Transaction history

    private func recordSent(_ transfer: PreparedTransfer, hash: String, ensName: String?) {
        let tx = SentTransaction(
            id: UUID(),
            walletAddress: transfer.from,
            toAddress: transfer.to,
            toENSName: ensName,
            amountETH: ETHAmount.format(wei: transfer.valueWei),
            hash: hash,
            date: Date(),
            status: .pending)
        sentTransactions.insert(tx, at: 0)
        persistHistory()
    }

    func updateTransactionStatus(hash: String, status: SentTransaction.TxStatus) {
        guard let i = sentTransactions.firstIndex(where: { $0.hash == hash }) else { return }
        sentTransactions[i].status = status
        persistHistory()
    }

    /// Checks the on-chain receipt status for any currently pending transactions.
    func refreshPendingTransactions() async {
        let pending = sentTransactions.filter { $0.status == .pending }
        guard !pending.isEmpty else { return }
        for tx in pending {
            if let status = try? await rpc.receipt(hash: tx.hash) {
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
