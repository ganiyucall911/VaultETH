import SwiftUI

// MARK: - Send Entry View

struct SendView: View {
    @Environment(\.dismiss) private var dismiss
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
        if isResolvingENS { return ("Resolving ENS record…", false) }
        if let err = ensError { return (err, true) }
        if let addr = resolvedENSAddress { return ("Resolved: \(shortAddress(addr))", false) }
        guard !s.isEmpty, s.count >= 40, !ENSResolver.looksLikeENS(s) else { return nil }
        do {
            _ = try WalletEngine.validateRecipient(s)
            return ("Valid Ethereum checksum", false)
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
        ScrollView {
            VStack(spacing: 20) {
                // Sender Vault Pill
                if let account = store.selectedAccount {
                    senderVaultCard(account: account)
                }

                // Recipient Section
                recipientCard

                // Amount Section
                amountCard

                // Review Action Button
                reviewButton
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .background(Color.vaultBackground.ignoresSafeArea())
        .navigationTitle("Send ETH")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .onChange(of: recipient) { _, newValue in
            triggerENSResolution(for: newValue)
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView { scanned in
                let parsed = WalletEngine.parsePaymentURI(scanned)
                recipient = parsed.recipient
                if let amt = parsed.amountETH {
                    amount = amt
                }
            }
        }
        .alert("Unable to proceed",
               isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") {}
        } message: { Text(errorMessage ?? "") }
        .sheet(item: Binding(
            get: { prepared.map { IdentifiedTransfer($0, ensName: resolvedENSName) } },
            set: { if $0 == nil { prepared = nil } }
        )) { item in
            NavigationStack {
                ReviewTransferView(transfer: item.transfer, ensName: item.ensName) {
                    prepared = nil
                    recipient = ""
                    amount = ""
                    dismiss()
                }
            }
        }
    }

    // MARK: - Subviews

    private func senderVaultCard(account: WalletAccount) -> some View {
        HStack(spacing: 12) {
            VaultIdenticon(address: account.address, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.subheadline.bold())
                Text("Available: \(store.balanceETH) ETH")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .vaultGlass(cornerRadius: 16)
    }

    private var recipientCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recipient")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack {
                TextField("0x… or name.eth", text: $recipient)
                    .font(.body.monospaced())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                HStack(spacing: 8) {
                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title3)
                            .foregroundStyle(Color.vaultCyan)
                    }

                    Button {
                        if let s = UIPasteboard.general.string {
                            let parsed = WalletEngine.parsePaymentURI(s)
                            recipient = parsed.recipient
                            if let amt = parsed.amountETH { amount = amt }
                        }
                    } label: {
                        Text("Paste")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.vaultCardSurface, in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                    }
                }
            }
            .padding(14)
            .vaultGlass(cornerRadius: 16)

            // Recipient Identification Badge
            if !effectiveRecipient.isEmpty && effectiveRecipient.hasPrefix("0x") && effectiveRecipient.count == 42 {
                HStack(spacing: 10) {
                    VaultIdenticon(address: effectiveRecipient, size: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        if let ens = resolvedENSName {
                            Text(ens).font(.caption.bold()).foregroundStyle(Color.vaultCyan)
                        }
                        Text(effectiveRecipient).font(.caption2.monospaced()).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .vaultGlass(cornerRadius: 12)
            }

            if let hint = recipientHint {
                Label(hint.text, systemImage: hint.isError ? "exclamationmark.circle" : "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(hint.isError ? Color.red : Color.vaultEmerald)
            }
        }
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amount")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                HStack {
                    TextField("0.0", text: $amount)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .keyboardType(.decimalPad)

                    Text("ETH")
                        .font(.title3.bold())
                        .foregroundStyle(Color.vaultCyan)
                }

                // Amount Presets
                HStack(spacing: 8) {
                    presetButton(title: "25%", factor: 0.25)
                    presetButton(title: "50%", factor: 0.50)
                    presetButton(title: "75%", factor: 0.75)
                    presetButton(title: "Max", factor: 1.0)
                }
            }
            .padding(18)
            .vaultGlass(cornerRadius: 18)

            if let hint = amountHint {
                Text(hint).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private func presetButton(title: String, factor: Double) -> some View {
        Button {
            guard let bal = Double(store.balanceETH), bal > 0 else { return }
            let computed = max(0.0, factor == 1.0 ? max(0.0, bal - 0.001) : bal * factor)
            amount = String(format: "%.4f", computed).replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
            if amount.hasSuffix(".") { amount.removeLast() }
        } label: {
            Text(title)
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var reviewButton: some View {
        Button {
            Task { await review() }
        } label: {
            HStack {
                if isPreparing {
                    ProgressView().tint(.black)
                } else {
                    Text("Review Transaction")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .vaultButton(.prominent)
        .disabled(isPreparing || recipient.isEmpty || amount.isEmpty
                  || store.selectedAccount == nil || isResolvingENS)
        .padding(.top, 12)
    }

    private func shortAddress(_ addr: String) -> String {
        guard addr.count >= 12 else { return addr }
        return "\(addr.prefix(6))…\(addr.suffix(4))"
    }

    // MARK: - ENS resolution

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
                ensError = (error as? WalletError)?.errorDescription ?? "ENS lookup failed"
                isResolvingENS = false
            }
        }
    }

    // MARK: - Prepare

    private func review() async {
        isPreparing = true
        defer { isPreparing = false }
        do {
            var targetRecipient = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
            if ENSResolver.looksLikeENS(targetRecipient) {
                if let resolved = resolvedENSAddress {
                    targetRecipient = resolved
                } else {
                    let addr = try await ENSResolver.resolve(name: targetRecipient, rpc: EthereumRPC())
                    resolvedENSAddress = addr
                    resolvedENSName = targetRecipient
                    targetRecipient = addr
                }
            } else {
                targetRecipient = effectiveRecipient
            }
            prepared = try await store.prepareTransfer(to: targetRecipient, amountText: amount)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Identified transfer wrapper

private struct IdentifiedTransfer: Identifiable {
    let transfer: PreparedTransfer
    let ensName: String?
    var id: String {
        transfer.from + transfer.to + transfer.nonce.vaultHexPlain + transfer.valueWei.vaultHexPlain
    }
    init(_ t: PreparedTransfer, ensName: String? = nil) { transfer = t; self.ensName = ensName }
}

// MARK: - Review & Send Sheet

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
        ScrollView {
            VStack(spacing: 20) {
                // Direction Visualizer
                HStack(spacing: 16) {
                    VStack(spacing: 6) {
                        VaultIdenticon(address: transfer.from, size: 48)
                        Text("You").font(.caption2.bold()).foregroundStyle(.secondary)
                    }

                    Image(systemName: "arrow.right")
                        .font(.title2)
                        .foregroundStyle(Color.vaultCyan)
                        .frame(maxWidth: .infinity)

                    VStack(spacing: 6) {
                        VaultIdenticon(address: transfer.to, size: 48)
                        Text(ensName ?? "Recipient").font(.caption2.bold()).foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .vaultCard(cornerRadius: 22)

                // Transfer Details Card
                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("Sending Amount")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(ETHAmount.format(wei: transfer.valueWei) + " ETH")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }

                    Divider()

                    VStack(spacing: 10) {
                        detailRow(title: "To Address", value: transfer.to, isMonospace: true)
                        if let ens = ensName {
                            detailRow(title: "ENS Domain", value: ens, isMonospace: false)
                        }
                        detailRow(title: "Max Network Fee", value: ETHAmount.format(wei: transfer.fee.maxFeeWei) + " ETH", isMonospace: true)
                        detailRow(title: "Max Total Outlay", value: ETHAmount.format(wei: transfer.maxTotalWei) + " ETH", isMonospace: true)
                    }
                }
                .padding(20)
                .vaultGlass(cornerRadius: 20)

                if transfer.recipientIsContract {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.vaultAmber)
                        Text("Recipient is an Ethereum smart contract. Verify it can receive plain ETH.").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .vaultGlass(cornerRadius: 14)
                }

                // Action / Status
                statusSection
            }
            .padding(20)
        }
        .background(Color.vaultBackground.ignoresSafeArea())
        .navigationTitle("Confirm Transfer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(closeLabel) { receiptTask?.cancel(); onClose() }.disabled(isSending)
            }
        }
        .interactiveDismissDisabled(isSending)
    }

    private func detailRow(title: String, value: String, isMonospace: Bool) -> some View {
        HStack {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(isMonospace ? .caption.monospaced() : .caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var closeLabel: String {
        if case .sent = phase { return "Done" } else { return "Cancel" }
    }

    @ViewBuilder private var statusSection: some View {
        switch phase {
        case .review:
            Button {
                Task { await send() }
            } label: {
                Label("Authorize with Biometrics", systemImage: "faceid")
                    .frame(maxWidth: .infinity)
            }
            .vaultButton(.prominent)

        case .sending:
            HStack(spacing: 12) {
                ProgressView().tint(.white)
                Text("Signing with Key Enclave & Broadcasting…").font(.subheadline)
            }
            .padding(16)
            .vaultGlass(cornerRadius: 16)

        case .sent(let hash, let status):
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    switch status {
                    case .some(.success):
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.vaultEmerald)
                        Text("Confirmed on Ethereum").font(.headline).foregroundStyle(Color.vaultEmerald)
                    case .some(.failed):
                        Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
                        Text("Failed On-Chain").font(.headline).foregroundStyle(.red)
                    case .none:
                        ProgressView().controlSize(.small)
                        Text("Broadcasted • Polling Receipt…").font(.headline).foregroundStyle(Color.vaultCyan)
                    }
                }

                Text(hash).font(.caption2.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)

                if let url = URL(string: "https://etherscan.io/tx/\(hash)") {
                    Link("View on Etherscan ↗", destination: url)
                        .font(.caption.bold())
                        .foregroundStyle(Color.vaultCyan)
                }

                Button("Done", action: onClose)
                    .vaultButton(.prominent)
            }
            .padding(20)
            .vaultCard(cornerRadius: 20)

        case .failed(let message):
            VStack(spacing: 12) {
                Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                Button("Try Again") { phase = .review }
                    .vaultButton(.glass)
            }
            .padding(16)
            .vaultGlass(cornerRadius: 16)
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
