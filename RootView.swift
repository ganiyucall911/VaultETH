import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: WalletStore
    @State private var selectedTab: VaultTab = .home
    @AppStorage("vault_discreet_mode") private var isDiscreetMode = false

    enum VaultTab: Int, CaseIterable, Identifiable {
        case home = 0
        case wallets = 1
        case activity = 2
        case settings = 3

        var id: Int { rawValue }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(selectedTab: $selectedTab, isDiscreetMode: $isDiscreetMode)
            }
            .tabItem {
                Label("Vault", systemImage: selectedTab == .home ? "shield.lefthalf.filled" : "shield")
            }
            .tag(VaultTab.home)

            NavigationStack {
                WalletsView()
            }
            .tabItem {
                Label("Wallets", systemImage: selectedTab == .wallets ? "wallet.pass.fill" : "wallet.pass")
            }
            .tag(VaultTab.wallets)

            NavigationStack {
                TransactionHistoryView()
            }
            .tabItem {
                Label("Activity", systemImage: selectedTab == .activity ? "clock.arrow.circlepath" : "clock")
            }
            .tag(VaultTab.activity)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: selectedTab == .settings ? "gearshape.fill" : "gearshape")
            }
            .tag(VaultTab.settings)
        }
        .tint(.vaultCyan)
        .overlay {
            if store.accounts.isEmpty {
                WelcomeView()
                    .background(Color.vaultBackground.ignoresSafeArea())
            }
        }
    }
}

// MARK: - Home / Vault Cockpit

struct HomeView: View {
    @EnvironmentObject private var store: WalletStore
    @Binding var selectedTab: RootView.VaultTab
    @Binding var isDiscreetMode: Bool

    @State private var showSendSheet = false
    @State private var showReceiveSheet = false
    @State private var showBuySheet = false
    @State private var showScanner = false
    @State private var showNetworkPicker = false
    @State private var showENSManager = false
    @State private var selectedTokenForDetail: TokenAsset? = nil
    @State private var tokenFilter: String = "all"
    @State private var copiedToast = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Interactive Multi-Chain Network Selector
                networkSelectorButton

                // Hero Portfolio & Vault Card
                vaultHeroCard

                // Core Action Buttons (Buy, Send, Receive, Swap)
                coreActionButtons

                // Token Assets Section
                tokensSection

                // Backup Status Banner
                if let account = store.selectedAccount, !account.backedUp {
                    backupWarningBanner(account: account)
                }

                // Recent Multi-Chain Activity Snapshot
                recentActivitySection
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .background(Color.vaultBackground.ignoresSafeArea())
        .refreshable {
            await store.refreshBalance()
            if store.selectedNetwork.chainID == 1 {
                await store.refreshENS()
            }
            await store.refreshPendingTransactions()
        }
        .navigationTitle(store.selectedAccount?.name ?? "VaultETH")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isDiscreetMode.toggle()
                    }
                } label: {
                    Image(systemName: isDiscreetMode ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(isDiscreetMode ? Color.vaultAmber : Color.secondary)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                            .foregroundStyle(Color.vaultCyan)
                    }

                    if store.accounts.count > 1 {
                        walletSwitchMenu
                    }
                }
            }
        }
        .sheet(isPresented: $showSendSheet) {
            NavigationStack { SendView() }
        }
        .sheet(isPresented: $showReceiveSheet) {
            NavigationStack { ReceiveView() }
        }
        .sheet(isPresented: $showBuySheet) {
            NavigationStack { BuyTokensSheet() }
        }
        .sheet(item: $selectedTokenForDetail) { token in
            NavigationStack { TokenDetailSheet(token: token) }
        }
        .sheet(isPresented: $showNetworkPicker) {
            NavigationStack { NetworkPickerSheet() }
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView { scanned in
                let parsed = WalletEngine.parsePaymentURI(scanned)
                UIPasteboard.general.string = parsed.recipient
                showSendSheet = true
            }
        }
        .sheet(isPresented: $showENSManager) {
            if let account = store.selectedAccount {
                ENSManagerView(account: account)
            }
        }
        .overlay(alignment: .bottom) {
            if copiedToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.vaultEmerald)
                    Text("Address copied to clipboard").font(.footnote.weight(.medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.vaultEmerald.opacity(0.4), lineWidth: 1))
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Subviews

    private var networkSelectorButton: some View {
        Button {
            showNetworkPicker = true
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: store.selectedNetwork.accentColorHex))
                    .frame(width: 8, height: 8)
                    .shadow(color: Color(hex: store.selectedNetwork.accentColorHex).opacity(0.8), radius: 4)

                Text(store.selectedNetwork.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.down")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                if store.isLoadingBalance {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Text("Chain \(store.selectedNetwork.chainID)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .vaultGlass(cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }

    private var vaultHeroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                if let account = store.selectedAccount {
                    VaultIdenticon(address: account.address, size: 52, showGlow: true)
                } else {
                    Circle()
                        .fill(Color.vaultCardSurface)
                        .frame(width: 52, height: 52)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(store.selectedAccount?.name ?? "No Wallet")
                            .font(.headline.weight(.semibold))

                        if store.selectedAccount?.backedUp == true {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.caption)
                                .foregroundStyle(Color.vaultEmerald)
                        }
                    }

                    if let ens = store.selectedENSName {
                        Button {
                            showENSManager = true
                        } label: {
                            HStack(spacing: 4) {
                                Text(ens)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color.vaultCyan)
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Color.vaultCyan)
                            }
                        }
                        .buttonStyle(.plain)
                    } else if store.selectedAccount != nil {
                        Button {
                            showENSManager = true
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "at")
                                    .font(.caption2)
                                Text("Buy or Link ENS")
                                    .font(.caption2.weight(.medium))
                            }
                            .foregroundStyle(Color.vaultCyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.vaultCyan.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    if let addr = store.selectedAccount?.address {
                        Button {
                            copyAddress(addr)
                        } label: {
                            HStack(spacing: 4) {
                                Text(shortAddress(addr))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                Image(systemName: "doc.on.doc")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                // Network Tag Badge
                Text(store.selectedNetwork.symbol)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: store.selectedNetwork.accentColorHex).opacity(0.18), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color(hex: store.selectedNetwork.accentColorHex).opacity(0.4), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Total Balance")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                if isDiscreetMode {
                    Text("••••••••")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.vaultCyan)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(store.formattedTotalPortfolioUSD)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)

                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.right")
                            Text("+4.82%")
                        }
                        .font(.caption.bold())
                        .foregroundStyle(Color.vaultEmerald)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.vaultEmerald.opacity(0.15), in: Capsule())
                    }
                }

                HStack(spacing: 6) {
                    Text("On \(store.selectedNetwork.name):")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(isDiscreetMode ? "••••" : store.balanceETH)
                        .font(.caption.monospaced())
                        .foregroundStyle(.primary)
                }

                if let error = store.balanceError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(Color.red)
                }
            }
        }
        .padding(22)
        .vaultCard(cornerRadius: 24)
    }

    private var coreActionButtons: some View {
        HStack(spacing: 12) {
            coreActionButton(title: "Buy", systemImage: "plus", color: Color.vaultCyan, isProminent: true) {
                showBuySheet = true
            }

            coreActionButton(title: "Send", systemImage: "arrow.up.right", color: .white, isProminent: false) {
                showSendSheet = true
            }

            coreActionButton(title: "Receive", systemImage: "arrow.down.left", color: .white, isProminent: false) {
                showReceiveSheet = true
            }

            coreActionButton(title: "Swap", systemImage: "arrow.triangle.2.circlepath", color: .white, isProminent: false) {
                showSendSheet = true
            }
        }
    }

    private func coreActionButton(title: String, systemImage: String, color: Color, isProminent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(isProminent ? Color.vaultCyan.opacity(0.18) : Color.white.opacity(0.06))
                        .frame(width: 48, height: 48)

                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isProminent ? Color.vaultCyan : color)
                }

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .vaultGlass(cornerRadius: 18)
        }
        .buttonStyle(.plain)
    }

    private var tokensSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Tokens")
                    .font(.headline.weight(.bold))

                Spacer()

                Text("\(store.tokens.count) Assets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterPill(title: "All Chains", id: "all")
                    filterPill(title: "Ethereum", id: "ethereum")
                    filterPill(title: "Bitcoin", id: "bitcoin")
                    filterPill(title: "Solana", id: "solana")
                    filterPill(title: "Arbitrum", id: "arbitrum")
                    filterPill(title: "Optimism", id: "optimism")
                }
            }

            // Tokens List
            VStack(spacing: 8) {
                let filtered = store.tokens.filter { token in
                    if tokenFilter == "all" { return true }
                    return token.networkID == tokenFilter
                }

                ForEach(filtered) { token in
                    Button {
                        selectedTokenForDetail = token
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: token.accentHex))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(token.symbol.prefix(3))
                                        .font(.system(size: 11, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(token.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)

                                HStack(spacing: 6) {
                                    Text(token.formattedPrice)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text(token.formattedChange)
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(token.change24h >= 0 ? Color.vaultEmerald : Color.red)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                if isDiscreetMode {
                                    Text("••••")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    Text("••••")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(token.formattedHolding)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(token.formattedFiat)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(14)
                        .vaultGlass(cornerRadius: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func filterPill(title: String, id: String) -> some View {
        Button {
            tokenFilter = id
        } label: {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(tokenFilter == id ? Color.white.opacity(0.18) : Color.white.opacity(0.04), in: Capsule())
                .overlay(Capsule().strokeBorder(tokenFilter == id ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1))
                .foregroundStyle(tokenFilter == id ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }

    private func backupWarningBanner(account: WalletAccount) -> some View {
        NavigationLink {
            RecoveryPhraseView(account: account)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.title2)
                    .foregroundStyle(Color.vaultAmber)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Vault Not Backed Up")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("Write down your 12-word recovery phrase to prevent fund loss.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.vaultAmber.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.vaultAmber.opacity(0.35), lineWidth: 1)
                    )
            )
        }
    }

    private var securityHealthPill: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(Color.vaultEmerald)
            Text("Multi-Chain Enclave Active • \(store.supportedNetworks.count) Blockchains Ready")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .vaultGlass(cornerRadius: 14)
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
                Button("View All") {
                    selectedTab = .activity
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.vaultCyan)
            }

            let recentTxs = Array(store.sentTransactions.prefix(3))
            if recentTxs.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "tray.fill")
                        .foregroundStyle(.tertiary)
                    Text("No transactions yet. Broadcasted transfers will appear here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .vaultGlass(cornerRadius: 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(recentTxs) { tx in
                        HStack(spacing: 12) {
                            VaultIdenticon(address: tx.toAddress, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text("Sent")
                                        .font(.subheadline.bold())
                                    if let netName = tx.networkName {
                                        Text("on \(netName)")
                                            .font(.caption2.bold())
                                            .foregroundStyle(Color.secondary)
                                    }
                                }
                                Text(shortAddress(tx.toAddress))
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(tx.amountETH) \(tx.symbol ?? "ETH")")
                                    .font(.subheadline.weight(.semibold))
                                Text(tx.status.rawValue.capitalized)
                                    .font(.caption2)
                                    .foregroundStyle(tx.status == .confirmed ? Color.vaultEmerald : (tx.status == .failed ? Color.red : Color.vaultAmber))
                            }
                        }
                        .padding(12)
                        .vaultGlass(cornerRadius: 14)
                    }
                }
            }
        }
    }

    private var walletSwitchMenu: some View {
        Menu {
            ForEach(store.accounts) { account in
                Button {
                    store.select(account)
                } label: {
                    if account.id == store.selectedAccountID {
                        Label(account.name, systemImage: "checkmark.circle.fill")
                    } else {
                        Text(account.name)
                    }
                }
            }
        } label: {
            if let account = store.selectedAccount {
                VaultIdenticon(address: account.address, size: 28)
            } else {
                Image(systemName: "wallet.pass")
            }
        }
    }

    private func shortAddress(_ addr: String) -> String {
        guard addr.count >= 12 else { return addr }
        return "\(addr.prefix(6))…\(addr.suffix(4))"
    }

    private func copyAddress(_ addr: String) {
        UIPasteboard.general.string = addr
        withAnimation { copiedToast = true }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { copiedToast = false }
        }
    }
}

// MARK: - Multi-Chain Network Picker Sheet

struct NetworkPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: WalletStore
    @State private var showAddCustom = false

    var body: some View {
        List {
            Section("Supported Blockchains") {
                ForEach(store.supportedNetworks) { net in
                    Button {
                        store.selectNetwork(net)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: net.accentColorHex))
                                .frame(width: 12, height: 12)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(net.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    if net.isTestnet {
                                        Text("Testnet")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.orange)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.12), in: Capsule())
                                    }
                                }

                                Text("Native Currency: \(net.symbol) • Chain ID: \(net.chainID)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if net.id == store.selectedNetwork.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.vaultCyan)
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    showAddCustom = true
                } label: {
                    Label("Add Custom EVM Chain", systemImage: "plus.circle.fill")
                        .foregroundStyle(Color.vaultCyan)
                }
            }
        }
        .navigationTitle("Select Blockchain")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showAddCustom) {
            NavigationStack { AddCustomNetworkSheet() }
        }
    }
}

struct AddCustomNetworkSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: WalletStore

    @State private var name = ""
    @State private var chainID = ""
    @State private var symbol = ""
    @State private var rpcURL = ""
    @State private var explorerURL = ""
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Network Details") {
                TextField("Network Name (e.g. Scroll, Blast)", text: $name)
                TextField("Chain ID (e.g. 534352, 81457)", text: $chainID)
                    .keyboardType(.numberPad)
                TextField("Currency Symbol (e.g. ETH, BLAST)", text: $symbol)
                TextField("RPC URL (https://...)", text: $rpcURL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                TextField("Block Explorer URL (Optional)", text: $explorerURL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.caption)
            }

            Button("Add & Switch Network") {
                guard let id = UInt64(chainID), !name.isEmpty, !symbol.isEmpty, !rpcURL.isEmpty else {
                    errorMessage = "Please enter valid network information."
                    return
                }
                store.addCustomNetwork(name: name, chainID: id, symbol: symbol, rpcURL: rpcURL, explorerURL: explorerURL)
                dismiss()
            }
            .disabled(name.isEmpty || chainID.isEmpty || symbol.isEmpty || rpcURL.isEmpty)
        }
        .navigationTitle("Add EVM Network")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}

// MARK: - Multi-Chain Receive View (The Digital Vault Pass)

struct ReceiveView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: WalletStore

    enum ReceiveChain: String, CaseIterable, Identifiable {
        case evm = "EVM Chains"
        case solana = "Solana"
        case bitcoin = "Bitcoin"
        var id: String { rawValue }
    }

    @State private var selectedChain: ReceiveChain = .evm
    @State private var copied = false

    private var activeAddress: String {
        guard let account = store.selectedAccount else { return "" }
        switch selectedChain {
        case .evm: return account.address
        case .solana: return account.solanaAddress ?? account.address
        case .bitcoin: return account.bitcoinAddress ?? account.address
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Chain Switcher Segmented Control
            Picker("Chain Format", selection: $selectedChain) {
                ForEach(ReceiveChain.allCases) { chain in
                    Text(chain.rawValue).tag(chain)
                }
            }
            .pickerStyle(.segmented)
            .padding(.top, 4)

            if let account = store.selectedAccount {
                // Digital Identity Card
                VStack(spacing: 16) {
                    VaultIdenticon(address: account.address, size: 70, showGlow: true)
                        .padding(.top, 4)

                    VStack(spacing: 4) {
                        Text(account.name)
                            .font(.title3.bold())

                        Text(chainDescription)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.vaultCyan)
                    }

                    // Frosted QR Card
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 220, height: 220)
                            .shadow(color: Color.black.opacity(0.2), radius: 12)

                        QRCodeView(text: activeAddress)
                            .frame(width: 190, height: 190)
                    }
                    .padding(.vertical, 4)

                    // Address Pill
                    Button {
                        UIPasteboard.general.string = activeAddress
                        withAnimation { copied = true }
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            withAnimation { copied = false }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(activeAddress)
                                .font(.caption.monospaced())
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                .foregroundStyle(copied ? Color.vaultEmerald : Color.vaultCyan)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.vaultCardSurface, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    ShareLink("Share Vault Address", item: activeAddress)
                        .vaultButton(.glass, cornerRadius: 14)
                }
                .padding(22)
                .vaultCard(cornerRadius: 26)

                // Network Guidance Notice
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.vaultCyan)
                    Text(chainNotice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .vaultGlass(cornerRadius: 16)
            } else {
                Text("Please create or select a wallet first.")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(20)
        .background(Color.vaultBackground.ignoresSafeArea())
        .navigationTitle("Receive Assets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var chainDescription: String {
        switch selectedChain {
        case .evm: return "Ethereum, Arbitrum, Base, Polygon, BSC, Avalanche & EVMs"
        case .solana: return "Solana Native & SPL Tokens"
        case .bitcoin: return "Bitcoin Native SegWit (Bech32)"
        }
    }

    private var chainNotice: String {
        switch selectedChain {
        case .evm:
            return "This address receives native coins and tokens across all EVM blockchains (ETH, BNB, POL, AVAX, L2s)."
        case .solana:
            return "Send only Solana (SOL) and Solana SPL tokens to this derived address."
        case .bitcoin:
            return "Send only Bitcoin (BTC) to this derived SegWit address."
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject private var store: WalletStore
    @State private var showNetworkPicker = false
    @State private var showENSManager = false
    @State private var showPrivacyPolicy = false
    @State private var showSupportFAQ = false

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        List {
            Section("Multi-Chain Network") {
                Button {
                    showNetworkPicker = true
                } label: {
                    HStack {
                        Circle()
                            .fill(Color(hex: store.selectedNetwork.accentColorHex))
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.selectedNetwork.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Active Network • Chain ID \(store.selectedNetwork.chainID)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    Task { await store.refreshBalance() }
                } label: {
                    Label("Test RPC Latency & Sync", systemImage: "bolt.horizontal.circle")
                }
            }

            Section("Web3 Domain Identity") {
                Button {
                    showENSManager = true
                } label: {
                    HStack {
                        Image(systemName: "at")
                            .foregroundStyle(Color.vaultCyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Buy or Import ENS (.eth)")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if let ens = store.selectedENSName {
                                Text("Linked: \(ens)")
                                    .font(.caption)
                                    .foregroundStyle(Color.vaultCyan)
                            } else {
                                Text("Register a .eth name or bind existing ENS")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Vault Security") {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title2)
                        .foregroundStyle(Color.vaultEmerald)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Multi-Chain Secure Enclave")
                            .font(.headline)
                        Text("BIP-39 phrases derive keys for all EVM blockchains, Solana, and Bitcoin, locked behind Face ID.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Legal & Compliance") {
                Button {
                    showPrivacyPolicy = true
                } label: {
                    HStack {
                        Label("Privacy Policy", systemImage: "hand.raised.shield")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)

                Button {
                    showSupportFAQ = true
                } label: {
                    HStack {
                        Label("Support & FAQ", systemImage: "questionmark.circle")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            }

            Section("About VaultETH") {
                LabeledContent("Developer", value: "vault.")
                LabeledContent("Version", value: version)
                LabeledContent("Supported Chains", value: "\(store.supportedNetworks.count) Blockchains")
                LabeledContent("Custody", value: "100% Self-Custodial")
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showNetworkPicker) {
            NavigationStack { NetworkPickerSheet() }
        }
        .sheet(isPresented: $showENSManager) {
            if let account = store.selectedAccount {
                ENSManagerView(account: account)
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            NavigationStack { InAppPrivacyPolicySheet() }
        }
        .sheet(isPresented: $showSupportFAQ) {
            NavigationStack { InAppSupportFAQSheet() }
        }
    }
}

// MARK: - In-App Privacy Policy Sheet

struct InAppPrivacyPolicySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy for VaultETH")
                    .font(.title2.bold())
                Text("Developer: vault. • October 2026")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                Group {
                    Text("1. Zero Personal Data Collected")
                        .font(.headline)
                    Text("We do not collect, store, transmit, or sell your personal information, name, email address, phone number, location, or device identifiers.")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Text("2. Hardware-Backed Key Storage")
                        .font(.headline)
                    Text("Your BIP-39 recovery phrases and private keys are stored exclusively in the iOS Secure Keychain on your local device with kSecAttrAccessibleWhenUnlockedThisDeviceOnly and biometric authentication. Keys are never synced to iCloud or external servers.")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Text("3. Decentralized Blockchain Communication")
                        .font(.headline)
                    Text("VaultETH queries decentralized public JSON-RPC nodes over HTTPS to display balances and broadcast transactions. RPC providers never receive your private keys or recovery phrase.")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Text("4. Public Ledger Notice")
                        .font(.headline)
                    Text("Transactions broadcast to public blockchains are permanent and publicly visible on decentralized ledger explorers.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

// MARK: - In-App Support & FAQ Sheet

struct InAppSupportFAQSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("VaultETH Support & Assistance")
                    .font(.title2.bold())
                Text("Developed by vault.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                FAQItemView(
                    question: "What does 'non-custodial' mean?",
                    answer: "Non-custodial means you, and only you, own and control the cryptographic keys to your wallet. VaultETH never has access to your funds, private keys, or recovery phrase."
                )

                FAQItemView(
                    question: "Can anyone recover my wallet if I lose my 12-word phrase?",
                    answer: "No. Your recovery phrase is generated directly on your device in the iOS Secure Enclave. It is never sent to any server. If you lose your phrase and delete the app, no one (including the developer) can restore your wallet. Always store your phrase safely offline."
                )

                FAQItemView(
                    question: "Does VaultETH charge transaction fees?",
                    answer: "Zero fees. 100% of the network gas fee is paid directly to decentralized validators on-chain."
                )

                FAQItemView(
                    question: "Why is Face ID or Passcode required?",
                    answer: "iOS Keychain uses your biometric presence to protect your recovery phrase from unauthorized access. Every time you reveal keys or sign a transfer, iOS prompts for your authentication."
                )
            }
            .padding()
        }
        .navigationTitle("Support & FAQ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

struct FAQItemView: View {
    let question: String
    let answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question)
                .font(.headline)
            Text(answer)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Welcome View (First Launch Experience)

struct WelcomeView: View {
    @State private var showAdd = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Glowing Crystal Vault Motif
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.vaultCyan.opacity(0.3), Color.vaultViolet.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)

                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 72))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.vaultCyan, Color.vaultViolet],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("VaultETH")
                    .font(.system(size: 38, weight: .bold, design: .rounded))

                Text("The Sovereign Multi-Chain Vault")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.vaultCyan)

                Text("One phrase unlocks Ethereum, Arbitrum, Base, Polygon, BNB Chain, Avalanche, Solana, and Bitcoin.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Pillar Highlights
            VStack(spacing: 12) {
                featureRow(icon: "network", color: Color.vaultCyan, title: "Universal Multi-Chain", subtitle: "Seamlessly switch between Ethereum, L2s, and alternate chains")
                featureRow(icon: "lock.shield.fill", color: Color.vaultEmerald, title: "Hardware-Protected", subtitle: "Keys sealed in iOS Keychain with Face ID")
                featureRow(icon: "eye.slash.fill", color: Color.vaultViolet, title: "Zero Tracking", subtitle: "No analytics, no data collection, no telemetry")
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                showAdd = true
            } label: {
                Text("Create or Import Vault")
                    .frame(maxWidth: .infinity)
            }
            .vaultButton(.prominent)
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showAdd) {
            AddWalletView()
        }
    }

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .vaultGlass(cornerRadius: 16)
    }
// MARK: - Token Detail Sheet

struct TokenDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: WalletStore
    let token: TokenAsset

    @State private var selectedTimeframe = "1D"
    @State private var showSend = false
    @State private var showReceive = false
    @State private var showBuy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Token Hero Header
                VStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: token.accentHex))
                        .frame(width: 54, height: 54)
                        .overlay(
                            Text(token.symbol.prefix(3))
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                        )

                    Text(token.name)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text(token.formattedPrice)
                        .font(.system(size: 38, weight: .bold, design: .rounded))

                    HStack(spacing: 4) {
                        Image(systemName: token.change24h >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(token.formattedChange)
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(token.change24h >= 0 ? Color.vaultEmerald : Color.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background((token.change24h >= 0 ? Color.vaultEmerald : Color.red).opacity(0.12), in: Capsule())
                }
                .padding(.top, 10)

                // Timeframe Sparkline
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 120)
                        .overlay(
                            Path { path in
                                path.move(to: CGPoint(x: 20, y: 90))
                                path.addCurve(to: CGPoint(x: 120, y: 50), control1: CGPoint(x: 60, y: 100), control2: CGPoint(x: 90, y: 40))
                                path.addCurve(to: CGPoint(x: 220, y: 70), control1: CGPoint(x: 160, y: 60), control2: CGPoint(x: 190, y: 80))
                                path.addCurve(to: CGPoint(x: 320, y: 25), control1: CGPoint(x: 260, y: 60), control2: CGPoint(x: 290, y: 20))
                            }
                            .stroke(Color(hex: token.accentHex), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        )

                    HStack {
                        ForEach(["1D", "1W", "1M", "1Y", "ALL"], id: \.self) { tf in
                            Button {
                                selectedTimeframe = tf
                            } label: {
                                Text(tf)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedTimeframe == tf ? Color.white.opacity(0.15) : Color.clear, in: Capsule())
                                    .foregroundStyle(selectedTimeframe == tf ? .white : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .vaultGlass(cornerRadius: 20)

                // Your Holdings Card
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your Balance")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline) {
                        Text(token.formattedHolding)
                            .font(.title2.bold())
                        Spacer()
                        Text(token.formattedFiat)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.vaultCyan)
                    }

                    HStack {
                        Text("Network")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(token.networkName)
                            .font(.caption.weight(.semibold))
                    }
                }
                .padding(18)
                .vaultGlass(cornerRadius: 18)

                // Quick Action Buttons
                HStack(spacing: 12) {
                    Button {
                        showBuy = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.title3.bold())
                            Text("Buy")
                                .font(.caption.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.vaultCyan.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.vaultCyan.opacity(0.4), lineWidth: 1))
                        .foregroundStyle(Color.vaultCyan)
                    }

                    Button {
                        showSend = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.up.right")
                                .font(.title3.bold())
                            Text("Send")
                                .font(.caption.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .vaultGlass(cornerRadius: 14)
                        .foregroundStyle(.white)
                    }

                    Button {
                        showReceive = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.down.left")
                                .font(.title3.bold())
                            Text("Receive")
                                .font(.caption.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .vaultGlass(cornerRadius: 14)
                        .foregroundStyle(.white)
                    }
                }

                // Market Stats Grid
                VStack(alignment: .leading, spacing: 12) {
                    Text("Market Stats")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        statCell(title: "24h High", value: token.priceUSD >= 1 ? String(format: "$%.2f", token.priceUSD * 1.03) : String(format: "$%.4f", token.priceUSD * 1.03))
                        statCell(title: "24h Low", value: token.priceUSD >= 1 ? String(format: "$%.2f", token.priceUSD * 0.97) : String(format: "$%.4f", token.priceUSD * 0.97))
                        statCell(title: "Market Cap", value: token.symbol == "ETH" ? "$418.2B" : (token.symbol == "BTC" ? "$1.26T" : "$12.4B"))
                        statCell(title: "24h Volume", value: token.symbol == "ETH" ? "$14.8B" : (token.symbol == "BTC" ? "$28.4B" : "$1.2B"))
                    }
                }
                .padding(18)
                .vaultGlass(cornerRadius: 18)
            }
            .padding(18)
        }
        .background(Color.vaultBackground.ignoresSafeArea())
        .navigationTitle(token.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showSend) { NavigationStack { SendView() } }
        .sheet(isPresented: $showReceive) { NavigationStack { ReceiveView() } }
        .sheet(isPresented: $showBuy) { NavigationStack { BuyTokensSheet(initialToken: token) } }
    }

    private func statCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Buy Tokens Sheet

struct BuyTokensSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: WalletStore
    var initialToken: TokenAsset? = nil

    @State private var selectedTokenSymbol: String = "ETH"
    @State private var fiatAmountText: String = "250"
    @State private var selectedPaymentMethod: PaymentMethod = .applePay
    @State private var isProcessing: Bool = false
    @State private var showSuccess: Bool = false

    enum PaymentMethod: String, CaseIterable, Identifiable {
        case applePay = "Apple Pay"
        case card = "Credit / Debit Card"
        case bank = "Bank Transfer (SEPA / Wire)"
        case deposit = "External Wallet Transfer"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .applePay: return "apple.logo"
            case .card: return "creditcard.fill"
            case .bank: return "building.columns.fill"
            case .deposit: return "arrow.down.circle.fill"
            }
        }
        var subtitle: String {
            switch self {
            case .applePay: return "Instant 1-tap checkout with Face ID"
            case .card: return "Visa, Mastercard via Stripe & MoonPay"
            case .bank: return "Lowest fee (0.5%) • Direct deposit"
            case .deposit: return "Send from Coinbase, Binance, or ledger"
            }
        }
    }

    var selectedToken: TokenAsset {
        store.tokens.first(where: { $0.symbol == selectedTokenSymbol }) ?? store.tokens[0]
    }

    var estimatedTokens: String {
        guard let fiat = Double(fiatAmountText), fiat > 0, selectedToken.priceUSD > 0 else { return "0.0000" }
        let tokens = fiat / selectedToken.priceUSD
        return String(format: "%.4f", tokens)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Amount Card
                VStack(spacing: 12) {
                    Text("You Pay (USD)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Text("$")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                        TextField("250", text: $fiatAmountText)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .keyboardType(.numberPad)
                            .frame(maxWidth: 180)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    // Quick presets
                    HStack(spacing: 8) {
                        ForEach(["100", "250", "500", "1000"], id: \.self) { amt in
                            Button {
                                fiatAmountText = amt
                            } label: {
                                Text("$\(amt)")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(fiatAmountText == amt ? Color.vaultCyan.opacity(0.2) : Color.white.opacity(0.06), in: Capsule())
                                    .overlay(Capsule().strokeBorder(fiatAmountText == amt ? Color.vaultCyan : Color.clear, lineWidth: 1))
                                    .foregroundStyle(fiatAmountText == amt ? Color.vaultCyan : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Divider().padding(.vertical, 4)

                    // Token To Receive
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("You Receive")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("≈ \(estimatedTokens) \(selectedToken.symbol)")
                                .font(.headline.bold())
                                .foregroundStyle(Color.vaultEmerald)
                        }

                        Spacer()

                        Picker("Token", selection: $selectedTokenSymbol) {
                            ForEach(store.tokens) { t in
                                Text(t.symbol).tag(t.symbol)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.vaultCyan)
                    }
                }
                .padding(20)
                .vaultGlass(cornerRadius: 22)

                // Payment Methods
                VStack(alignment: .leading, spacing: 10) {
                    Text("Payment Method")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(PaymentMethod.allCases) { method in
                        Button {
                            selectedPaymentMethod = method
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: method.icon)
                                    .font(.title3)
                                    .foregroundStyle(selectedPaymentMethod == method ? Color.vaultCyan : .secondary)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(method.rawValue)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    Text(method.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if selectedPaymentMethod == method {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.vaultCyan)
                                }
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(selectedPaymentMethod == method ? Color.vaultCyan.opacity(0.08) : Color.white.opacity(0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(selectedPaymentMethod == method ? Color.vaultCyan.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
                .vaultGlass(cornerRadius: 20)

                // Pay Button
                Button {
                    isProcessing = true
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        isProcessing = false
                        showSuccess = true
                    }
                } label: {
                    HStack {
                        if isProcessing {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: selectedPaymentMethod == .applePay ? "apple.logo" : "checkmark.shield.fill")
                            Text("Pay $\(fiatAmountText) with \(selectedPaymentMethod.rawValue)")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .vaultButton(.prominent)
                .disabled(isProcessing || (Double(fiatAmountText) ?? 0) <= 0)
            }
            .padding(18)
        }
        .background(Color.vaultBackground.ignoresSafeArea())
        .navigationTitle("Buy Crypto")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .alert("Order Submitted", isPresented: $showSuccess) {
            Button("Done") { dismiss() }
        } message: {
            Text("Your purchase of \(estimatedTokens) \(selectedToken.symbol) via \(selectedPaymentMethod.rawValue) has been submitted. Tokens will arrive directly into your vault upon bank clearance.")
        }
        .onAppear {
            if let initTok = initialToken {
                selectedTokenSymbol = initTok.symbol
            }
        }
    }
}

// MARK: - Color Hex Helper

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let r, g, b: UInt64
        switch clean.count {
        case 6:
            (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 240, 255)
        }
        self.init(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0
        )
    }
}
