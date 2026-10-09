import SwiftUI

struct ENSManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var store: WalletStore

    let account: WalletAccount

    enum ENSMode: Int, CaseIterable, Identifiable {
        case buy = 0
        case importExisting = 1

        var id: Int { rawValue }
        var title: String {
            switch self {
            case .buy: return "Buy .eth Name"
            case .importExisting: return "Import ENS"
            }
        }
    }

    @State private var mode: ENSMode = .buy

    // Buy state
    @State private var searchName = ""
    @State private var isCheckingAvailability = false
    @State private var availabilityStatus: AvailabilityStatus?
    @State private var buyErrorMessage: String?

    // Import state
    @State private var importName = ""
    @State private var isVerifying = false
    @State private var verificationResult: VerificationResult?
    @State private var importErrorMessage: String?

    // Feedback
    @State private var actionSuccessMessage: String?

    enum AvailabilityStatus {
        case available(domain: String, costEth: String, costUsd: String, tier: String)
        case taken(domain: String, owner: String)
        case invalid(reason: String)
    }

    enum VerificationResult {
        case exactMatch(domain: String, address: String)
        case mismatch(domain: String, resolvedAddress: String)
        case notFound(domain: String)
    }

    private var currentLinkedENS: String? {
        account.importedENSName ?? (store.selectedAccountID == account.id ? store.selectedENSName : nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header / Vault Identity Pill
                    vaultIdentityCard

                    // Mode Segmented Picker
                    Picker("ENS Mode", selection: $mode) {
                        ForEach(ENSMode.allCases) { m in
                            Text(m.title).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 4)

                    // Content for Selected Mode
                    if mode == .buy {
                        buySection
                    } else {
                        importSection
                    }

                    // Active Linked Status Card (if an ENS name is already linked)
                    if let linked = currentLinkedENS {
                        currentLinkedCard(linkedName: linked)
                    }

                    // Educational Multi-Chain Feature Grid
                    educationalGrid
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .background(Color.vaultBackground.ignoresSafeArea())
            .navigationTitle("ENS Identity (.eth)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Vault Identity Card

    private var vaultIdentityCard: some View {
        HStack(spacing: 12) {
            VaultIdenticon(address: account.address, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(account.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let ens = currentLinkedENS {
                        Text(ens)
                            .font(.caption2.bold())
                            .foregroundStyle(Color.vaultCyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.vaultCyan.opacity(0.15), in: Capsule())
                    }
                }

                Text(account.address)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()
        }
        .padding(14)
        .vaultGlass(cornerRadius: 16)
    }

    // MARK: - Buy Section

    private var buySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Search & Register a .eth Name")
                    .font(.headline)
                Text("Mint an official ENS domain directly to this vault. Human-readable names replace complex addresses across all supported blockchains.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Search input field
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("yourname", text: $searchName)
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: searchName) { _, _ in
                            availabilityStatus = nil
                            buyErrorMessage = nil
                        }

                    Text(".eth")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.vaultCyan)
                }
                .padding(14)
                .vaultGlass(cornerRadius: 14)

                let normalized = ENSResolver.normalizeENSName(searchName)
                let pricing = ENSResolver.estimateAnnualCost(for: searchName)
                if !searchName.trimmingCharacters(in: .whitespaces).isEmpty {
                    HStack {
                        Text("Est. Base Fee: \(pricing.eth) (\(pricing.usd))")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.vaultCyan)
                        Spacer()
                        Text(pricing.note)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)
                }
            }

            // Check Availability Button
            Button {
                Task { await checkAvailability() }
            } label: {
                HStack {
                    if isCheckingAvailability {
                        ProgressView().tint(.black)
                    } else {
                        Label("Check On-Chain Availability", systemImage: "sparkle.magnifyingglass")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .vaultButton(.prominent)
            .disabled(isCheckingAvailability || searchName.trimmingCharacters(in: .whitespaces).isEmpty)

            // Result Display
            if let status = availabilityStatus {
                switch status {
                case .available(let domain, let costEth, let costUsd, _):
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.vaultEmerald)
                            Text("\(domain) is Available!")
                                .font(.headline)
                                .foregroundStyle(Color.vaultEmerald)
                            Spacer()
                            Text(costEth)
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                        }

                        Text("Registration cost: \(costUsd) per year. Zero platform markup. The domain will be minted as an ERC-721 token directly to your vault address.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button {
                            if let url = ENSResolver.registrationURL(for: domain) {
                                openURL(url)
                            }
                        } label: {
                            Label("Proceed to Official ENS Registrar", systemImage: "arrow.up.right.square.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .vaultButton(.prominent)
                    }
                    .padding(16)
                    .background(Color.vaultEmerald.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.vaultEmerald.opacity(0.35), lineWidth: 1))

                case .taken(let domain, let owner):
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.vaultAmber)
                            Text("\(domain) is Already Taken")
                                .font(.headline)
                                .foregroundStyle(Color.vaultAmber)
                        }
                        Text("Owned by: \(owner)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        if owner.lowercased() == account.address.lowercased() {
                            Text("This domain already resolves to this vault! You can import it using the Import tab.")
                                .font(.footnote)
                                .foregroundStyle(Color.vaultCyan)
                        }
                    }
                    .padding(16)
                    .vaultGlass(cornerRadius: 18)

                case .invalid(let reason):
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding(12)
                }
            }

            if let buyErrorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                    Text(buyErrorMessage).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .padding(18)
        .vaultCard(cornerRadius: 22)
    }

    // MARK: - Import Section

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Import or Link an Existing ENS Name")
                    .font(.headline)
                Text("Already own an ENS domain? Verify on-chain forward resolution to link it as the primary Web3 handle for this vault.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Input field
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "at")
                        .foregroundStyle(Color.vaultCyan)

                    TextField("vitalik.eth", text: $importName)
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: importName) { _, _ in
                            verificationResult = nil
                            importErrorMessage = nil
                            actionSuccessMessage = nil
                        }
                }
                .padding(14)
                .vaultGlass(cornerRadius: 14)

                Text("Enter your .eth name or DNS-linked ENS domain.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            // Verify Button
            Button {
                Task { await verifyAndImport() }
            } label: {
                HStack {
                    if isVerifying {
                        ProgressView().tint(.black)
                    } else {
                        Label("Verify On-Chain & Link", systemImage: "checkmark.shield")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .vaultButton(.prominent)
            .disabled(isVerifying || importName.trimmingCharacters(in: .whitespaces).isEmpty)

            // Result Display
            if let result = verificationResult {
                switch result {
                case .exactMatch(let domain, let address):
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color.vaultEmerald)
                            Text("Ownership Verified!")
                                .font(.headline)
                                .foregroundStyle(Color.vaultEmerald)
                        }

                        Text("\(domain) successfully resolves to this vault's address (\(shortAddress(address))).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button {
                            linkENS(domain)
                        } label: {
                            Label("Set as Vault Display Handle", systemImage: "link")
                                .frame(maxWidth: .infinity)
                        }
                        .vaultButton(.prominent)
                    }
                    .padding(16)
                    .background(Color.vaultEmerald.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.vaultEmerald.opacity(0.35), lineWidth: 1))

                case .mismatch(let domain, let resolved):
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.vaultAmber)
                            Text("Address Mismatch Notice")
                                .font(.headline)
                                .foregroundStyle(Color.vaultAmber)
                        }

                        Text("\(domain) currently resolves on-chain to:")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text(resolved)
                            .font(.caption.monospaced())
                            .foregroundStyle(.primary)

                        Text("This vault's address is \(account.address). You can still bind this name as a display alias, or update the ENS record in the ENS App.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Button {
                            linkENS(domain)
                        } label: {
                            Text("Link Anyway as Display Alias")
                                .frame(maxWidth: .infinity)
                        }
                        .vaultButton(.glass)
                    }
                    .padding(16)
                    .vaultGlass(cornerRadius: 18)

                case .notFound(let domain):
                    HStack(spacing: 8) {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("No on-chain address record found for \(domain). Ensure it is registered and configured.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding(12)
                }
            }

            if let actionSuccessMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.vaultEmerald)
                    Text(actionSuccessMessage).font(.caption.bold()).foregroundStyle(Color.vaultEmerald)
                }
                .padding(.horizontal, 4)
            }

            if let importErrorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                    Text(importErrorMessage).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .padding(18)
        .vaultCard(cornerRadius: 22)
    }

    // MARK: - Currently Linked Card

    private func currentLinkedCard(linkedName: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "link.circle.fill")
                        .foregroundStyle(Color.vaultCyan)
                    Text("Active Linked ENS Domain")
                        .font(.subheadline.bold())
                }
                Spacer()
                Text(linkedName)
                    .font(.subheadline.monospaced().bold())
                    .foregroundStyle(Color.vaultCyan)
            }

            Text("This domain is used in VaultETH to identify this wallet, replacing raw addresses on send/receive flows.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(role: .destructive) {
                    store.setImportedENS(for: account.id, ensName: nil)
                    actionSuccessMessage = "ENS link removed."
                } label: {
                    Label("Unlink ENS", systemImage: "trash")
                        .font(.caption.bold())
                }
                .foregroundStyle(.red)

                Spacer()

                Button {
                    if let url = URL(string: "https://etherscan.io/enslookup-search?search=\(linkedName)") {
                        openURL(url)
                    }
                } label: {
                    Label("View on Etherscan", systemImage: "arrow.up.right")
                        .font(.caption)
                }
                .foregroundStyle(Color.vaultCyan)
            }
        }
        .padding(16)
        .vaultGlass(cornerRadius: 18)
    }

    // MARK: - Educational Feature Grid

    private var educationalGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why Use ENS in VaultETH?")
                .font(.headline)

            VStack(spacing: 10) {
                featureItem(icon: "lock.shield", title: "100% Self-Custodial NFT", desc: "Your .eth domain is an ERC-721 token held inside your Secure Enclave key.")
                featureItem(icon: "network", title: "Multi-Chain Routing", desc: "One memorable handle sends & receives funds across Ethereum, Solana, and Bitcoin.")
                featureItem(icon: "eye.slash", title: "0% Markup", desc: "Zero broker fees. You interact directly with the decentralized Ethereum ENS smart contracts.")
            }
        }
        .padding(16)
        .vaultGlass(cornerRadius: 18)
    }

    private func featureItem(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.vaultCyan)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Actions

    private func checkAvailability() async {
        isCheckingAvailability = true
        buyErrorMessage = nil
        defer { isCheckingAvailability = false }

        let domain = ENSResolver.normalizeENSName(searchName)
        let label = domain.replacingOccurrences(of: ".eth", with: "")

        guard label.count >= 3 else {
            availabilityStatus = .invalid(reason: "ENS names must be at least 3 characters long.")
            return
        }

        do {
            let ethRPC = EthereumRPC(network: .ethereum)
            let resolved = try await ENSResolver.resolve(name: domain, rpc: ethRPC)
            availabilityStatus = .taken(domain: domain, owner: resolved)
        } catch {
            let cost = ENSResolver.estimateAnnualCost(for: label)
            availabilityStatus = .available(domain: domain, costEth: cost.eth, costUsd: cost.usd, tier: cost.note)
        }
    }

    private func verifyAndImport() async {
        isVerifying = true
        importErrorMessage = nil
        defer { isVerifying = false }

        let domain = ENSResolver.normalizeENSName(importName)
        guard !domain.isEmpty, domain != ".eth" else {
            importErrorMessage = "Please enter a valid ENS name."
            return
        }

        do {
            let ethRPC = EthereumRPC(network: .ethereum)
            let resolved = try await ENSResolver.resolve(name: domain, rpc: ethRPC)
            if resolved.lowercased() == account.address.lowercased() {
                verificationResult = .exactMatch(domain: domain, address: resolved)
            } else {
                verificationResult = .mismatch(domain: domain, resolvedAddress: resolved)
            }
        } catch {
            verificationResult = .notFound(domain: domain)
        }
    }

    private func linkENS(_ name: String) {
        store.setImportedENS(for: account.id, ensName: name)
        actionSuccessMessage = "Linked \(name) as vault handle!"
    }

    private func shortAddress(_ addr: String) -> String {
        guard addr.count >= 12 else { return addr }
        return "\(addr.prefix(6))…\(addr.suffix(4))"
    }
}
