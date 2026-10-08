import SwiftUI

/// Shows all transactions sent from the currently selected wallet with filtering and identicons.
struct TransactionHistoryView: View {
    @EnvironmentObject private var store: WalletStore

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case confirmed = "Confirmed"
        case pending = "Pending"
        var id: String { rawValue }
    }

    @State private var selectedFilter: Filter = .all
    @State private var showClearConfirmation = false
    @State private var selectedTx: SentTransaction?

    private var allTransactions: [SentTransaction] {
        guard let addr = store.selectedAccount?.address else { return [] }
        return store.sentTransactions.filter {
            $0.walletAddress.lowercased() == addr.lowercased()
        }
    }

    private var filteredTransactions: [SentTransaction] {
        switch selectedFilter {
        case .all:
            return allTransactions
        case .confirmed:
            return allTransactions.filter { $0.status == .confirmed }
        case .pending:
            return allTransactions.filter { $0.status == .pending }
        }
    }

    var body: some View {
        Group {
            if allTransactions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("No Activity Yet")
                        .font(.title3.bold())
                    Text("Transactions broadcast from this vault will be tracked here in real-time.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        // Filter Pills
                        Picker("Filter", selection: $selectedFilter) {
                            ForEach(Filter.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)

                        // Transaction List Cards
                        ForEach(filteredTransactions) { tx in
                            Button {
                                selectedTx = tx
                            } label: {
                                ModernTxCard(tx: tx)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Copy Hash", systemImage: "doc.on.doc") {
                                    UIPasteboard.general.string = tx.hash
                                }
                                Button("Copy Recipient", systemImage: "wallet.pass") {
                                    UIPasteboard.general.string = tx.toAddress
                                }
                                if let url = URL(string: "https://etherscan.io/tx/\(tx.hash)") {
                                    ShareLink("Share on Etherscan", item: url)
                                }
                                Divider()
                                Button(role: .destructive) {
                                    store.deleteTransaction(id: tx.id)
                                } label: {
                                    Label("Remove from History", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color.vaultBackground.ignoresSafeArea())
        .navigationTitle("Activity")
        .refreshable {
            await store.refreshPendingTransactions()
        }
        .task {
            await store.refreshPendingTransactions()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        Task { await store.refreshPendingTransactions() }
                    } label: {
                        Label("Refresh On-Chain Status", systemImage: "arrow.clockwise")
                    }
                    if !allTransactions.isEmpty {
                        Divider()
                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Label("Clear Local History", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color.vaultCyan)
                }
            }
        }
        .sheet(item: $selectedTx) { tx in
            NavigationStack {
                TransactionDetailSheet(tx: tx)
            }
        }
        .confirmationDialog(
            "Clear activity record for this vault?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Local History", role: .destructive) {
                if let addr = store.selectedAccount?.address {
                    store.clearHistory(for: addr)
                }
            }
        } message: {
            Text("This deletes the cached history on this device only. Past on-chain blockchain records are permanent.")
        }
    }
}

// MARK: - Modern Transaction Card

private struct ModernTxCard: View {
    let tx: SentTransaction

    var body: some View {
        HStack(spacing: 14) {
            VaultIdenticon(address: tx.toAddress, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Sent ETH")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    if let ens = tx.toENSName {
                        Text("(\(ens))")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.vaultCyan)
                    }
                }

                Text(shortAddress(tx.toAddress))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("-\(tx.amountETH) ETH")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    statusBadge
                    Text(tx.date, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(14)
        .vaultGlass(cornerRadius: 16)
    }

    @ViewBuilder private var statusBadge: some View {
        switch tx.status {
        case .pending:
            HStack(spacing: 3) {
                Circle().fill(Color.vaultAmber).frame(width: 5, height: 5)
                Text("Pending").font(.caption2.bold()).foregroundStyle(Color.vaultAmber)
            }
        case .confirmed:
            HStack(spacing: 3) {
                Circle().fill(Color.vaultEmerald).frame(width: 5, height: 5)
                Text("Confirmed").font(.caption2.bold()).foregroundStyle(Color.vaultEmerald)
            }
        case .failed:
            HStack(spacing: 3) {
                Circle().fill(Color.red).frame(width: 5, height: 5)
                Text("Failed").font(.caption2.bold()).foregroundStyle(.red)
            }
        }
    }

    private func shortAddress(_ addr: String) -> String {
        guard addr.count >= 12 else { return addr }
        return "\(addr.prefix(6))…\(addr.suffix(4))"
    }
}

// MARK: - Transaction Detail Sheet

private struct TransactionDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let tx: SentTransaction

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VaultIdenticon(address: tx.toAddress, size: 68, showGlow: true)
                    .padding(.top, 10)

                VStack(spacing: 4) {
                    Text("-\(tx.amountETH) ETH")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(tx.status.rawValue.capitalized)
                        .font(.caption.bold())
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.12), in: Capsule())
                }

                VStack(spacing: 12) {
                    detailItem(title: "Recipient", value: tx.toAddress, monospaced: true)
                    if let ens = tx.toENSName {
                        detailItem(title: "ENS Name", value: ens, monospaced: false)
                    }
                    detailItem(title: "Date & Time", value: tx.date.formatted(date: .long, time: .standard), monospaced: false)
                    detailItem(title: "Transaction Hash", value: tx.hash, monospaced: true)
                }
                .padding(18)
                .vaultGlass(cornerRadius: 18)

                if let url = URL(string: "https://etherscan.io/tx/\(tx.hash)") {
                    Link(destination: url) {
                        Label("Inspect on Etherscan ↗", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .vaultButton(.glass, cornerRadius: 14)
                }
            }
            .padding(20)
        }
        .background(Color.vaultBackground.ignoresSafeArea())
        .navigationTitle("Transaction Record")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var statusColor: Color {
        switch tx.status {
        case .pending: return Color.vaultAmber
        case .confirmed: return Color.vaultEmerald
        case .failed: return Color.red
        }
    }

    private func detailItem(title: String, value: String, monospaced: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(monospaced ? .caption.monospaced() : .caption)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
