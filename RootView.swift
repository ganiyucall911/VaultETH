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
    @State private var showScanner = false
    @State private var copiedToast = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Live Network Beacon
                networkStatusBar

                // Hero Vault Card
                vaultHeroCard

                // Action Cockpit (Send / Receive / Scan / Copy)
                cockpitActions

                // Backup Status Banner
                if let account = store.selectedAccount, !account.backedUp {
                    backupWarningBanner(account: account)
                } else if store.selectedAccount != nil {
                    securityHealthPill
                }

                // Recent Activity Snapshot
                recentActivitySection
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .background(Color.vaultBackground.ignoresSafeArea())
        .refreshable {
            await store.refreshBalance()
            await store.refreshENS()
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
        .sheet(isPresented: $showScanner) {
            QRScannerView { scanned in
                let parsed = WalletEngine.parsePaymentURI(scanned)
                UIPasteboard.general.string = parsed.recipient
                showSendSheet = true
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

    private var networkStatusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.vaultEmerald)
                .frame(width: 8, height: 8)
                .shadow(color: Color.vaultEmerald.opacity(0.8), radius: 4)

            Text("Ethereum Mainnet")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            if store.isLoadingBalance {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Text("Block Synced")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .vaultGlass(cornerRadius: 14)
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
                        HStack(spacing: 4) {
                            Text(ens)
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.vaultCyan)
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.vaultCyan)
                        }
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
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Total Balance")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                if isDiscreetMode {
                    Text("•••••••• ETH")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.vaultCyan)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(store.balanceETH)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)

                        Text("ETH")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
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

    private var cockpitActions: some View {
        HStack(spacing: 12) {
            cockpitButton(title: "Send", systemImage: "arrow.up.right", color: Color.vaultCyan) {
                showSendSheet = true
            }

            cockpitButton(title: "Receive", systemImage: "arrow.down.left", color: Color.vaultViolet) {
                showReceiveSheet = true
            }

            cockpitButton(title: "Scan", systemImage: "qrcode.viewfinder", color: Color.white) {
                showScanner = true
            }

            cockpitButton(title: "Copy", systemImage: "doc.on.doc", color: Color.secondary) {
                if let addr = store.selectedAccount?.address {
                    copyAddress(addr)
                }
            }
        }
    }

    private func cockpitButton(title: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 48, height: 48)

                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .vaultGlass(cornerRadius: 18)
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
            Text("Hardware-Backed Secure Enclave Active")
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
                                    if let ens = tx.toENSName {
                                        Text("to \(ens)").font(.caption).foregroundStyle(Color.vaultCyan)
                                    }
                                }
                                Text(shortAddress(tx.toAddress))
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(tx.amountETH) ETH")
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

// MARK: - Receive View (The Digital Vault Pass)

struct ReceiveView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: WalletStore
    @State private var copied = false

    var body: some View {
        VStack(spacing: 22) {
            if let account = store.selectedAccount {
                // Digital Identity Card
                VStack(spacing: 16) {
                    VaultIdenticon(address: account.address, size: 76, showGlow: true)
                        .padding(.top, 8)

                    VStack(spacing: 4) {
                        Text(account.name)
                            .font(.title3.bold())

                        if let ens = store.selectedENSName {
                            Text(ens)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.vaultCyan)
                        }
                    }

                    // Frosted QR Card
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 230, height: 230)
                            .shadow(color: Color.black.opacity(0.2), radius: 12)

                        QRCodeView(text: account.address)
                            .frame(width: 200, height: 200)
                    }
                    .padding(.vertical, 8)

                    // Address Pill
                    Button {
                        UIPasteboard.general.string = account.address
                        withAnimation { copied = true }
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            withAnimation { copied = false }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(account.address)
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

                    if let shareURL = URL(string: "ethereum:\(account.address)") {
                        ShareLink("Share Vault Address", item: shareURL)
                            .vaultButton(.glass, cornerRadius: 14)
                    }
                }
                .padding(24)
                .vaultCard(cornerRadius: 28)

                // Network Security Notice
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.vaultCyan)
                    Text("Only send Ethereum Mainnet assets (ETH, ERC-20) to this address. Cross-chain assets sent here may be permanently lost.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
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
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject private var store: WalletStore

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        List {
            Section("Vault Security") {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title2)
                        .foregroundStyle(Color.vaultEmerald)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hardware-Backed Enclave")
                            .font(.headline)
                        Text("Recovery phrases are stored exclusively in the iOS Secure Keychain with biometric gating.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Network Infrastructure") {
                LabeledContent("Blockchain", value: "Ethereum Mainnet (ID 1)")
                LabeledContent("Primary RPC", value: "publicnode.com")
                LabeledContent("Fallback RPC", value: "cloudflare-eth.com")

                Button {
                    Task { await store.refreshBalance() }
                } label: {
                    Label("Test RPC Latency & Sync", systemImage: "bolt.horizontal.circle")
                }
            }

            Section("Legal & App Store Compliance") {
                if let privacyURL = URL(string: "https://github.com/ganiyucall911/VaultETH/blob/main/PRIVACY_POLICY.md") {
                    Link("Privacy Policy", destination: privacyURL)
                }
                if let supportURL = URL(string: "https://github.com/ganiyucall911/VaultETH/blob/main/SUPPORT.md") {
                    Link("Support & FAQ", destination: supportURL)
                }
                if let checklistURL = URL(string: "https://github.com/ganiyucall911/VaultETH/blob/main/APP_STORE_CHECKLIST.md") {
                    Link("App Store Review Checklist", destination: checklistURL)
                }
            }

            Section("About VaultETH") {
                LabeledContent("Version", value: version)
                LabeledContent("Architecture", value: "100% Non-Custodial")
                if let url = URL(string: "https://github.com/ganiyucall911/VaultETH") {
                    Link("Open Source Repository", destination: url)
                }
            }
        }
        .navigationTitle("Settings")
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

                Text("The Sovereign Ethereum Vault")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.vaultCyan)

                Text("Self-custody reimagined with cryptographic elegance, hardware-backed security, and zero compromise.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Pillar Highlights
            VStack(spacing: 12) {
                featureRow(icon: "lock.shield.fill", color: Color.vaultEmerald, title: "Hardware-Protected", subtitle: "Keys sealed in iOS Keychain with Face ID")
                featureRow(icon: "eye.slash.fill", color: Color.vaultCyan, title: "Zero Tracking", subtitle: "No analytics, no data collection, no telemetry")
                featureRow(icon: "bolt.shield.fill", color: Color.vaultViolet, title: "Direct On-Chain", subtitle: "Instant EIP-1559 execution via decentralized RPCs")
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
