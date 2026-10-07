import SwiftUI

/// Shows all transactions sent from the currently selected wallet.
struct TransactionHistoryView: View {
    @EnvironmentObject private var store: WalletStore

    private var transactions: [SentTransaction] {
        guard let addr = store.selectedAccount?.address else { return [] }
        return store.sentTransactions.filter {
            $0.walletAddress.lowercased() == addr.lowercased()
        }
    }

    var body: some View {
        Group {
            if transactions.isEmpty {
                ContentUnavailableView(
                    "No Transactions",
                    systemImage: "arrow.up.right.circle",
                    description: Text("Transactions sent from this wallet appear here.")
                )
            } else {
                List(transactions) { tx in
                    TxRow(tx: tx)
                        .contextMenu {
                            Button("Copy transaction hash", systemImage: "doc.on.doc") {
                                UIPasteboard.general.string = tx.hash
                            }
                            Button("Copy recipient address", systemImage: "wallet.pass") {
                                UIPasteboard.general.string = tx.toAddress
                            }
                            if let url = URL(string: "https://etherscan.io/tx/\(tx.hash)") {
                                ShareLink("Share on Etherscan", item: url)
                            }
                        }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("History")
    }
}

// MARK: - Transaction Row

private struct TxRow: View {
    let tx: SentTransaction

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                statusIcon.font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tx.amountETH + " ETH").font(.headline)
                    if let ens = tx.toENSName {
                        Text(ens).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text(tx.toAddress)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(tx.date, style: .date).font(.caption).foregroundStyle(.secondary)
                    Text(tx.date, style: .time).font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                if let url = URL(string: "https://etherscan.io/tx/\(tx.hash)") {
                    Link("Etherscan ↗", destination: url).font(.caption)
                }
                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(statusColor.opacity(0.12), in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var statusIcon: some View {
        switch tx.status {
        case .pending:   Image(systemName: "clock.fill").foregroundStyle(.orange)
        case .confirmed: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:    Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
        }
    }

    private var statusLabel: String {
        switch tx.status {
        case .pending: return "Pending"
        case .confirmed: return "Confirmed"
        case .failed: return "Failed"
        }
    }

    private var statusColor: Color {
        switch tx.status {
        case .pending: return .orange
        case .confirmed: return .green
        case .failed: return .red
        }
    }
}
