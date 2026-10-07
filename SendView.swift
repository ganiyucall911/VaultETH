import SwiftUI

// MARK: - Send Entry View

struct SendView: View {
    @EnvironmentObject private var store: WalletStore
    @State private var recipient = ""
    @State private var amount = ""
    @State private var isPreparing = false
    @State private var prepared: PreparedTransfer?
    @State private var errorMessage: String?

    // QR scanner
    @State private var showScanner = false

    // ENS resolution
    @State private var ensTask: Task<Void, Never>?
    @State private var resolvedENSAddress: String?
    @State private var resolvedENSName: String?
    @State private var isResolvingENS = false
    @State private var ensError: String?

    /// The address that will actually be submitted — either the ENS-resolved one or the typed one.
    private var effectiveRecipient: String { resolvedENSAddress ?? recipient }

    /// Inline hint shown below the recipient field (format / checksum errors, ENS status).
    private var recipientHint: (text: String, isError: Bool)? {
        let s = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
        if isResolvingENS { return ("Resolving ENS name…", false) }
        if let err = ensError { return (err, true) }
        if let addr = resolvedENSAddress { return ("→ \(addr)", false) }
        guard !s.isEmpty, s.count >= 40, !ENSResolver.looksLikeENS(s) else { return nil }
        do {
            _ = try WalletEngine.validateRecipient(s)
            return nil
        } catch {
            return ((error as? WalletError)?.errorDescription ?? "Invalid address", true)
        }
    }

    /// Inline hint shown below the amount field.
    private var amountHint: String? {
        let s = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        do { _ = try ETHAmount.wei(from: s); return nil }
        catch { return WalletError.invalidAmount.errorDescription }
    }

    var body: some View {
        Form {
            Section("From") {
                Text(store.selectedAccount?.address ?? "No wallet")
                    .font(.caption.monospaced()).lineLimit(1).truncationMode(.middle)
                Text("Balance: \(store.balanceETH)").font(.footnote).foregroundStyle(.secondary)
            }

            Section("Recipient") {
                HStack {
                    TextField("0x… or name.eth", text: $recipient)
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Scan", systemImage: "qrcode.viewfinder") { showScanner = true }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                }
                Button("Paste", systemImage: "doc.on.clipboard") {
                    if let s = UIPasteboard.general.string {
                        recipient = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                if let hint = recipientHint {
                    Label(hint.text, systemImage: hint.isError ? "exclamationmark.circle" : "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(hint.isError ? Color.red : Color.green)
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
                .disabled(isPreparing || recipient.isEmpty || amount.isEmpty
                          || store.selectedAccount == nil || isResolvingENS)
            } footer: {
                Text("Ethereum Mainnet only. You will confirm the exact amount, recipient and maximum fee before anything is signed.")
            }
        }
        .navigationTitle("Send ETH")
        // ENS resolution — debounced 600 ms
        .onChange(of: recipient) { _, newValue in
            triggerENSResolution(for: newValue)
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView { scanned in
                recipient = scanned.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        .alert("Cannot continue",
               isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") {}
        } message: { Text(errorMessage ?? "") }
        .sheet(item: Binding(
            get: { prepared.map { IdentifiedTransfer($0, ensName: resolvedENSName) } },
            set: { if $0 == nil { prepared = nil } }
        )) { item in
            ReviewTransferView(transfer: item.transfer, ensName: item.ensName) {
                prepared = nil; recipient = ""; amount = ""
            }
        }
    }

    // MARK: ENS resolution

    private func triggerENSResolution(for raw: String) {
        ensTask?.cancel()
        resolvedENSAddress = nil
        resolvedENSName = nil
        ensError = nil
        isResolvingENS = false
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ENSResolver.looksLikeENS(trimmed) else { return }
        isResolvingENS = true
        let rpc = EthereumRPC()
        ensTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(600))
                let addr = try await ENSResolver.resolve(name: trimmed, rpc: rpc)
                resolvedENSAddress = addr
                resolvedENSName = trimmed
                isResolvingENS = false
            } catch is CancellationError {
                isResolvingENS = false
            } catch {
                ensError = (error as? WalletError)?.errorDescription ?? "ENS resolution failed"
                isResolvingENS = false
            }
        }
    }

    // MARK: Prepare

    private func review() async {
        isPreparing = true
        defer { isPreparing = false }
        do { prepared = try await store.prepareTransfer(to: effectiveRecipient, amountText: amount) }
        catch { errorMessage = error.localizedDescription }
    }
}

// MARK: - Identified transfer (sheet item wrapper)

private struct IdentifiedTransfer: Identifiable {
    let transfer: PreparedTransfer
    let ensName: String?
    var id: String {
        transfer.from + transfer.to + transfer.nonce.vaultHexPlain + transfer.valueWei.vaultHexPlain
    }
    init(_ t: PreparedTransfer, ensName: String? = nil) { transfer = t; self.ensName = ensName }
}

// MARK: - Review & send sheet

struct ReviewTransferView: View {
    @EnvironmentObject private var store: WalletStore
    let transfer: PreparedTransfer
    let ensName: String?
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
                    if let ens = ensName {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ens).font(.callout.bold())
                            Text(transfer.to).font(.caption.monospaced())
                                .foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    } else {
                        Text(transfer.to).font(.callout.monospaced()).textSelection(.enabled)
                    }
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
                case .some(.success):
                    Label("Confirmed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                case .some(.failed):
                    Label("Failed on-chain", systemImage: "xmark.octagon.fill").foregroundStyle(.red)
                case .none:
                    Label("Sent. Waiting for confirmation…", systemImage: "clock")
                }
                Text(hash).font(.caption.monospaced()).textSelection(.enabled)
                if let url = URL(string: "https://etherscan.io/tx/\(hash)") {
                    Link("View on Etherscan", destination: url)
                }
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
            let hash = try await store.send(transfer, ensName: ensName)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            phase = .sent(hash: hash, status: nil)
            receiptTask = Task { @MainActor in
                let status = await store.waitForReceipt(hash: hash)
                if !Task.isCancelled {
                    phase = .sent(hash: hash, status: status)
                }
            }
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            phase = .failed(error.localizedDescription)
        }
    }
}
