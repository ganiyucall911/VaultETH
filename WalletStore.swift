import Foundation

@MainActor
final class WalletStore: ObservableObject {
    @Published private(set) var accounts: [WalletAccount] = []
    @Published var selectedAccountID: UUID?
    @Published private(set) var balanceETH = "—"
    @Published private(set) var isLoadingBalance = false
    @Published var balanceError: String?

    private let engine = WalletEngine()
    private let rpc = EthereumRPC()
    private let defaultsKey = "accounts"        // public metadata only (name + address); secrets stay in Keychain

    var selectedAccount: WalletAccount? { accounts.first { $0.id == selectedAccountID } }

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode([WalletAccount].self, from: data) {
            accounts = saved
            selectedAccountID = saved.first?.id
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
        Task { await refreshBalance() }
    }

    func delete(_ account: WalletAccount) {
        engine.delete(id: account.id)
        accounts.removeAll { $0.id == account.id }
        if selectedAccountID == account.id { selectedAccountID = accounts.first?.id; balanceETH = "—" }
        persist()
    }

    // MARK: - Balance

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
    func send(_ transfer: PreparedTransfer) async throws -> String {
        guard let account = accounts.first(where: { $0.address.lowercased() == transfer.from.lowercased() }) else {
            throw WalletError.keyNotFound
        }
        let raw = try await engine.signTransfer(transfer, accountID: account.id)
        return try await rpc.sendRaw(raw)
    }

    /// Polls for a receipt for about two minutes. Returns nil if still pending.
    func waitForReceipt(hash: String) async -> ReceiptStatus? {
        for _ in 0..<24 {
            if Task.isCancelled { return nil }
            if let status = try? await rpc.receipt(hash: hash) {
                await refreshBalance()
                return status
            }
            try? await Task.sleep(for: .seconds(5))
        }
        return nil
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
}
