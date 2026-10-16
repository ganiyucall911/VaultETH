import SwiftUI
import UIKit

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
        .tint(.vaultMint)
        .overlay {
            if store.accounts.isEmpty {
                WelcomeView()
                    .background(Color.vaultBackground.ignoresSafeArea())
            }
        }
    }
}

// MARK: - Pulsing Alert Badge Component

struct PulsingAlertBadge: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.vaultDanger)
                .frame(width: 8, height: 8)
                .scaleEffect(isPulsing ? 1.6 : 1.0)
                .opacity(isPulsing ? 0.25 : 0.9)
                .animation(Animation.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: isPulsing)

            Circle()
                .fill(Color.vaultDanger)
                .frame(width: 7, height: 7)
        }
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - Home / Vault Cockpit

struct HomeView: View {
    @EnvironmentObject private var store: WalletStore
    @Binding var selectedTab: RootView.VaultTab
    @Binding var isDiscreetMode: Bool

    @State private var showSendSheet = false
    @State private var sendInitialRecipient = ""
    @State private var sendInitialAmount = ""
    @State private var showReceiveSheet = false
    @State private var showBuySheet = false
    @State private var showSwapSheet = false
    @State private var showScanner = false
    @State private var showNetworkPicker = false
    @State private var showENSManager = false
    @State private var showAlertsSheet = false
    @State private var selectedTokenForDetail: TokenAsset? = nil
    @State private var tokenFilter: String = "all"
    @State private var copiedToast = false

    private func refreshWalletData() async {
        await store.refreshBalance()
        if store.selectedNetwork.chainID == 1 {
            await store.refreshENS()
        }
        await store.refreshPendingTransactions()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Interactive Multi-Chain Network Selector
                networkSelectorButton

                // Autonomous Price Alert Notification Banner (when active)
                if let alert = store.activeBannerAlert {
                    priceAlertBanner(alert: alert)
                }

                // Hero Portfolio & Vault Card
                vaultHeroCard

                // Core Action Tiles (Send, Receive, Buy)
                coreActionButtons

                // Trending tokens row (Cash App-style cards)
                trendingTokensSection

                // Token Assets Section
                tokensSection

                // Autonomous Price Alerts Section
                priceAlertsSection

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
            await refreshWalletData()
        }
        .navigationTitle(store.selectedAccount?.name ?? "VaultETH")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 7) {
                    Image("VaultLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    Text("VaultETH")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.primary)
                    Button {
                        Task { await refreshWalletData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Color.vaultMint)
                    }
                    .accessibilityLabel("Refresh wallet")
                }
            }

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
                        showAlertsSheet = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(store.activeBannerAlert != nil ? Color.vaultMint : Color.secondary)

                            if store.priceAlerts.contains(where: { $0.isEnabled }) {
                                PulsingAlertBadge()
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }

                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                            .foregroundStyle(Color.vaultMint)
                    }

                    if store.accounts.count > 1 {
                        walletSwitchMenu
                    }
                }
            }
        }
        .sheet(isPresented: $showAlertsSheet) {
            NavigationStack { PriceAlertsSheet() }
        }
        .sheet(isPresented: $showSendSheet) {
            NavigationStack {
                SendView(initialRecipient: sendInitialRecipient, initialAmount: sendInitialAmount)
            }
        }
        .sheet(isPresented: $showReceiveSheet) {
            NavigationStack { ReceiveView() }
        }
        .sheet(isPresented: $showBuySheet) {
            NavigationStack { FeatureUnavailableSheet(feature: "Buying crypto") }
        }
        .sheet(isPresented: $showSwapSheet) {
            NavigationStack { FeatureUnavailableSheet(feature: "Swapping tokens") }
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
                sendInitialRecipient = parsed.recipient
                sendInitialAmount = parsed.amountETH ?? ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showSendSheet = true
                }
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
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.vaultMint)
                    Text("Address copied to clipboard").font(.footnote.weight(.medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.vaultMint.opacity(0.4), lineWidth: 1))
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
        VStack(alignment: .leading, spacing: 10) {
            // Cash App-style hero: giant tabular balance straight on the background
            VStack(alignment: .leading, spacing: 6) {
                Text("Vault Balance")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                if isDiscreetMode {
                    Text("••••••••")
                        .font(.system(size: 34, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.vaultMint)
                } else {
                    Text(store.formattedTotalPortfolioUSD)
                        .font(.system(size: 34, weight: .heavy, design: .monospaced))
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.right")
                        Text("Demo +4.82%")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(Color.vaultMint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.vaultMint.opacity(0.15), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.vaultMint.opacity(0.35), lineWidth: 0.5))
                }
            }

            // Compact account strip
            HStack(alignment: .center, spacing: 10) {
                if let account = store.selectedAccount {
                    VaultIdenticon(address: account.address, size: 28, showGlow: false)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(store.selectedAccount?.name ?? "No Wallet")
                            .font(.subheadline.weight(.semibold))

                        if store.selectedAccount?.backedUp == true {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.vaultEmerald)
                        }
                    }

                    if let ens = store.selectedENSName {
                        Button {
                            showENSManager = true
                        } label: {
                            HStack(spacing: 4) {
                                Text(ens)
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.vaultMint)
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Color.vaultMint)
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
                            .foregroundStyle(Color.vaultMint)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.vaultMint.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    if let addr = store.selectedAccount?.address {
                        Button {
                            copyAddress(addr)
                        } label: {
                            HStack(spacing: 4) {
                                Text(shortAddress(addr))
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 5) {
                        Text(store.selectedNetwork.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(isDiscreetMode ? "••••" : store.balanceETH)
                            .font(.caption2.monospaced().weight(.medium))
                            .foregroundStyle(.primary)
                    }
                }

                Spacer()

                Text(store.selectedNetwork.symbol)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: store.selectedNetwork.accentColorHex).opacity(0.18), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color(hex: store.selectedNetwork.accentColorHex).opacity(0.4), lineWidth: 1))
            }

            if let error = store.balanceError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(Color.red)
            }
        }
    }

    private var coreActionButtons: some View {
        HStack(spacing: 10) {
            bigActionButton(title: "Send", systemImage: "arrow.up.right", isProminent: false) {
                sendInitialRecipient = ""
                sendInitialAmount = ""
                showSendSheet = true
            }

            bigActionButton(title: "Receive", systemImage: "arrow.down.left", isProminent: false) {
                showReceiveSheet = true
            }

            bigActionButton(title: "Buy", systemImage: "plus", isProminent: true) {
                showBuySheet = true
            }
        }
    }

    private func bigActionButton(title: String, systemImage: String, isProminent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isProminent ? Color.vaultMint : .primary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(isProminent ? Color.vaultMint.opacity(0.18) : Color.white.opacity(0.07))
                    )
                    .overlay(
                        Circle().strokeBorder(isProminent ? Color.vaultMint.opacity(0.4) : Color.white.opacity(0.12), lineWidth: 1)
                    )

                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .vaultGlass(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Trending Tokens Row

    private var trendingTokensSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("TRENDING")
                    .font(.caption2.weight(.heavy))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showSwapSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Swap")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(Color.vaultMint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.vaultMint.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.tokens.sorted { $0.change24h > $1.change24h }) { token in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 7) {
                                TokenIconView(symbol: token.symbol, accentHex: token.accentHex, size: 24)

                                Text(token.symbol)
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(.primary)
                            }

                            Text(token.formattedPrice)
                                .font(.caption.monospaced().weight(.semibold))
                                .foregroundStyle(.primary)

                            HStack(spacing: 4) {
                                Image(systemName: token.change24h >= 0 ? "arrow.up.right" : "arrow.down.right")
                                Text(String(format: "%+.2f%%", token.change24h))
                            }
                            .font(.caption2.bold().monospaced())
                            .foregroundStyle(token.change24h >= 0 ? Color.vaultMint : Color.vaultDanger)
                        }
                        .padding(10)
                        .frame(width: 124, alignment: .leading)
                        .vaultGlass(cornerRadius: 14)
                    }
                }
            }
        }
    }

    // MARK: - Price Alert Notification Banner Component

    private func priceAlertBanner(alert: PriceAlertItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.vaultMint)

            TokenIconView(symbol: alert.symbol, accentHex: "#627EEA", size: 20)

            Text("\(alert.symbol) \(alert.condition == .above ? "rose above" : "dropped below") \(alert.formattedTarget)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    store.dismissBannerAlert()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.vaultSurfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.vaultMint.opacity(0.45), lineWidth: 1)
        )
    }

    // MARK: - Price Alerts Section

    private var priceAlertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Text("Price Alerts")
                        .font(.headline.weight(.bold))

                    Text("\(store.priceAlerts.filter { $0.isEnabled }.count) Active")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.vaultMint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.vaultMint.opacity(0.15), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.vaultMint.opacity(0.35), lineWidth: 0.5))
                }

                Spacer()

                Button {
                    showAlertsSheet = true
                } label: {
                    Text("Manage")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.vaultMint)
                }
            }

            VStack(spacing: 8) {
                ForEach(store.priceAlerts) { alert in
                    priceAlertRow(alert: alert)
                }
            }
        }
    }

    private func priceAlertRow(alert: PriceAlertItem) -> some View {
        HStack(spacing: 12) {
            TokenIconView(symbol: alert.symbol, accentHex: alert.accentHex, size: 30)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(alert.symbol)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    Text(alert.condition == .above ? "▲ Above" : "▼ Below")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(alert.condition == .above ? Color.vaultMint : Color.vaultDanger)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background((alert.condition == .above ? Color.vaultMint : Color.vaultDanger).opacity(0.12), in: Capsule())
                }

                Text(alert.note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(alert.formattedTarget)
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(.primary)

                Toggle("", isOn: Binding(
                    get: { alert.isEnabled },
                    set: { _ in store.toggleAlert(id: alert.id) }
                ))
                .labelsHidden()
                .tint(Color.vaultMint)
                .scaleEffect(0.8)
            }
        }
        .padding(12)
        .vaultGlass(cornerRadius: 16)
    }

    private var tokensSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Demo Assets")
                    .font(.headline.weight(.bold))

                Spacer()

                Text("Sample data only")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Demo only — sample prices and holdings are not live market data or your wallet balance.")
                .font(.caption)
                .foregroundStyle(.secondary)

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
                        HStack(spacing: 11) {
                            TokenIconView(symbol: token.symbol, accentHex: token.accentHex, size: 32)

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
                                        .foregroundStyle(token.change24h >= 0 ? Color.vaultMint : Color.vaultDanger)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background((token.change24h >= 0 ? Color.vaultMint : Color.vaultDanger).opacity(0.12), in: Capsule())
                                        .overlay(Capsule().strokeBorder((token.change24h >= 0 ? Color.vaultMint : Color.vaultDanger).opacity(0.3), lineWidth: 0.5))
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
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Color.vaultMint)
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
                .foregroundStyle(Color.vaultMint)
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
        #if canImport(UIKit)
        VaultHaptics.success()
        #endif
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
                                    .foregroundStyle(Color.vaultMint)
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
                        .foregroundStyle(Color.vaultMint)
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
                            .foregroundStyle(Color.vaultMint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Buy or Import ENS (.eth)")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if let ens = store.selectedENSName {
                                Text("Linked: \(ens)")
                                    .font(.caption)
                                    .foregroundStyle(Color.vaultMint)
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
                            colors: [Color.vaultMint.opacity(0.3), Color.vaultViolet.opacity(0.1), .clear],
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
                            colors: [Color.vaultMint, Color.vaultViolet],
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
                    .foregroundStyle(Color.vaultMint)

                Text("Send native assets on supported EVM networks. Solana and Bitcoin addresses are receive-only.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Pillar Highlights
            VStack(spacing: 12) {
                featureRow(icon: "network", color: Color.vaultMint, title: "Universal Multi-Chain", subtitle: "Seamlessly switch between Ethereum, L2s, and alternate chains")
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
}

// MARK: - Token Detail Sheet

struct TokenDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: WalletStore
    let token: TokenAsset

    @State private var selectedTimeframe = "1D"
    @State private var showSend = false
    @State private var showReceive = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Token Hero Header
                VStack(spacing: 6) {
                    TokenIconView(symbol: token.symbol, accentHex: token.accentHex, size: 48)

                    Text("\(token.name) • Demo data")
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
                    Text("Demo Balance")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline) {
                        Text(token.formattedHolding)
                            .font(.title2.bold())
                        Spacer()
                        Text(token.formattedFiat)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.vaultMint)
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
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.title3.bold())
                            Text("Buy Soon")
                                .font(.caption.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.vaultMint.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.vaultMint.opacity(0.4), lineWidth: 1))
                        .foregroundStyle(Color.vaultMint)
                    }
                    .disabled(true)

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
                    Text("Demo Market Stats")
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

// MARK: - Dedicated Price Alerts Sheet

struct PriceAlertsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: WalletStore

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header badge
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.vaultMint.opacity(0.18))
                            .frame(width: 58, height: 58)
                            .overlay(Circle().strokeBorder(Color.vaultMint.opacity(0.4), lineWidth: 1))
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Color.vaultMint)
                    }

                    Text("Obsidian Price Alerts")
                        .font(.title2.bold())

                    Text("Smart autonomous volatility alerts trigger directly on-device with zero tracking or external notification servers.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(.top, 12)

                // Active alerts list
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Configured Alerts")
                            .font(.headline)
                        Spacer()
                        Text("\(store.priceAlerts.filter { $0.isEnabled }.count) Active")
                            .font(.caption.bold())
                            .foregroundStyle(Color.vaultMint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.vaultMint.opacity(0.15), in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.vaultMint.opacity(0.35), lineWidth: 0.5))
                    }

                    VStack(spacing: 12) {
                        ForEach(store.priceAlerts) { alert in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 12) {
                                    TokenIconView(symbol: alert.symbol, accentHex: alert.accentHex, size: 30)

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(alert.name)
                                                .font(.subheadline.bold())
                                            Text(alert.symbol)
                                                .font(.caption.monospaced())
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(alert.note)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Toggle("", isOn: Binding(
                                        get: { alert.isEnabled },
                                        set: { _ in store.toggleAlert(id: alert.id) }
                                    ))
                                    .labelsHidden()
                                    .tint(Color.vaultMint)
                                }

                                Divider()
                                    .background(Color.white.opacity(0.06))

                                HStack {
                                    HStack(spacing: 4) {
                                        Text("Target:")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(alert.formattedTarget)
                                            .font(.caption.bold().monospacedDigit())
                                            .foregroundStyle(.primary)
                                    }

                                    Spacer()

                                    Text(alert.condition == .above ? "▲ ABOVE TARGET" : "▼ BELOW TARGET")
                                        .font(.system(size: 10, weight: .heavy))
                                        .foregroundStyle(alert.condition == .above ? Color.vaultMint : Color.vaultDanger)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background((alert.condition == .above ? Color.vaultMint : Color.vaultDanger).opacity(0.15), in: Capsule())
                                }
                            }
                            .padding(14)
                            .vaultGlass(cornerRadius: 18)
                        }
                    }
                }

                // Info Box
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.vaultMint)
                    Text("Alerts evaluate on every RPC sync and portfolio refresh against decentralized oracle data.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(14)
                .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(18)
        }
        .background(Color.vaultBackground.ignoresSafeArea())
        .navigationTitle("Price Alerts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .font(.body.bold())
                    .foregroundStyle(Color.vaultMint)
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
            (r, g, b) = (0, 214, 50)
        }
        self.init(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0
        )
    }
}

// MARK: - Real Token Icons

/// Renders a bundled real token logo when one exists for the symbol, falling
/// back to the accent monogram for anything else.
struct TokenIconView: View {
    let symbol: String
    let accentHex: String
    var size: CGFloat = 28

    private var assetName: String? {
        let candidates = ["token-\(symbol.lowercased())", "token-usd\(symbol.lowercased())"]
        for name in candidates where UIImage(named: name) != nil {
            return name
        }
        return nil
    }

    var body: some View {
        if let name = assetName {
            Image(name)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color(hex: accentHex))
                .frame(width: size, height: size)
                .overlay(
                    Text(symbol.prefix(2))
                        .font(.system(size: size * 0.36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                )
        }
    }
}
