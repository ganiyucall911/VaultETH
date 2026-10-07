import SwiftUI

struct SendView: View {
    @EnvironmentObject private var store: WalletStore
    @State private var recipient = ""
    @State private var amount = ""
    @State private var isPreparing = false
    @State private var prepared: PreparedTransfer?
    @State private var errorMessage: String?

    /// Non-nil when the recipient field contains something that looks like an address but is invalid.
    private var recipientHint: String? {
        let s = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, s.count >= 40 else { return nil }
        do {
            _ = try WalletEngine.validateRecipient(s)
            return nil      // valid — no hint needed
        } catch {
            return (error as? WalletError)?.errorDescription
        }
    }

    private var amountHint: String? {
        let s = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        do { _ = try ETHAmount.wei(from: s) } catch { return WalletError.invalidAmount.errorDescription }
        return nil
    }

    var body: some View {
        Form {
            Section("From") {
                Text(store.selectedAccount?.address ?? "No wallet")
                    .font(.caption.monospaced()).lineLimit(1).truncationMode(.middle)
                Text("Balance: \(store.balanceETH)").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Recipient") {
                TextField("0x…", text: $recipient)
                    .font(.body.monospaced())
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Paste", systemImage: "doc.on.clipboard") {
                    if let s = UIPasteboard.general.string { recipient = s.trimmingCharacters(in: .whitespacesAndNewlines) }
                }
                if let hint = recipientHint {
                    Text(hint).font(.caption).foregroundStyle(.red)
                }
            }
            Section("Amount") {
                HStack {
                    TextField("0.0", text: $amount).keyboardType(.decimalPad)
                    Text("ETH").foregroundStyle(.secondary)
                }
                if let hint = amountHint {
                    Text(hint).font(.caption).foregroundStyle(.red)
                }
            }
            Section {
                Button {
                    Task { await review() }
                } label: {
                    if isPreparing { ProgressView() } else { Text("Review transaction") }
                }
                .disabled(isPreparing || recipient.isEmpty || amount.isEmpty || store.selectedAccount == nil)
            } footer: {
                Text("Ethereum Mainnet only. You will confirm the exact amount, recipient and maximum fee before anything is signed.")
            }
        }
        .navigationTitle("Send ETH")
        .alert("Cannot continue", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") {}
        } message: { Text(errorMessage ?? "") }
        .sheet(item: Binding(get: { prepared.map(IdentifiedTransfer.init) }, set: { if $0 == nil { prepared = nil } })) { item in
            ReviewTransferView(transfer: item.transfer) {
                prepared = nil; recipient = ""; amount = ""
            }
        }
    }

    private func review() async {
        isPreparing = true
        defer { isPreparing = false }
        do { prepared = try await store.prepareTransfer(to: recipient, amountText: amount) }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct IdentifiedTransfer: Identifiable {
    let transfer: PreparedTransfer
    var id: String { transfer.from + transfer.to + transfer.nonce.vaultHexPlain + transfer.valueWei.vaultHexPlain }
    init(_ t: PreparedTransfer) { transfer = t }
}

struct ReviewTransferView: View {
    @EnvironmentObject private var store: WalletStore
    let transfer: PreparedTransfer
    let onClose: () -> Void

    private enum Phase { case review, sending, sent(hash: String, status: ReceiptStatus?), failed(String) }
    @State private var phase: Phase = .review
    @State private var receiptTask: Task<Void, Never>?

    private var isSending: Bool { if case .sending = phase { return true } else { return false } }

    var body: some View {
        NavigationStack {
            Form {
                Section("You send") {
                    Text(ETHAmount.format(wei: transfer.valueWei) + " ETH").font(.title2.bold())
                }
                Section("To") {
                    Text(transfer.to).font(.callout.monospaced()).textSelection(.enabled)
                    if transfer.recipientIsContract {
                        Label("This address is a smart contract. Only continue if you trust it.",
                              systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                }
                Section("Network fee (maximum)") {
                    Text(ETHAmount.format(wei: transfer.fee.maxFeeWei) + " ETH")
                    Text("Total at most: " + ETHAmount.format(wei: transfer.maxTotalWei) + " ETH")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("The final fee is usually lower. Transactions cannot be reversed.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section { statusView }
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(closeLabel) { receiptTask?.cancel(); onClose() }.disabled(isSending)
                }
            }
        }
        .interactiveDismissDisabled(isSending)
    }

    private var closeLabel: String {
        if case .sent = phase { return "Done" } else { return "Cancel" }
    }

    @ViewBuilder private var statusView: some View {
        switch phase {
        case .review:
            Button("Confirm and send") { Task { await send() } }.buttonStyle(.borderedProminent)
        case .sending:
            HStack { ProgressView(); Text("Authenticating and sending…") }
        case .sent(let hash, let status):
            VStack(alignment: .leading, spacing: 8) {
                switch status {
                case .some(.success): Label("Confirmed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                case .some(.failed): Label("Failed on-chain", systemImage: "xmark.octagon.fill").foregroundStyle(.red)
                case .none: Label("Sent. Waiting for confirmation…", systemImage: "clock")
                }
                Text(hash).font(.caption.monospaced()).textSelection(.enabled)
                if let url = URL(string: "https://etherscan.io/tx/\(hash)") { Link("View on Etherscan", destination: url) }
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                Button("Try again") { phase = .review }
            }
        }
    }

    private func send() async {
        phase = .sending
        do {
            let hash = try await store.send(transfer)
            phase = .sent(hash: hash, status: nil)
            receiptTask = Task {
                let status = await store.waitForReceipt(hash: hash)
                if !Task.isCancelled {
                    phase = .sent(hash: hash, status: status)
                }
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
