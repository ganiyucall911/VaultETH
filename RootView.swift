import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: WalletStore

    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }
            NavigationStack { WalletsView() }
                .tabItem { Label("Wallets", systemImage: "wallet.pass") }
            NavigationStack { SendView() }
                .tabItem { Label("Send", systemImage: "arrow.up.right") }
            NavigationStack { ReceiveView() }
                .tabItem { Label("Receive", systemImage: "arrow.down.left") }
            NavigationStack { TransactionHistoryView() }
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .overlay {
            if store.accounts.isEmpty { WelcomeView().background(.background) }
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: WalletStore

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ethereum balance").foregroundStyle(.secondary)
                    Text(store.balanceETH)
                        .font(.system(size: 38, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.5).lineLimit(1)
                    if let ens = store.selectedENSName {
                        Text(ens)
                            .font(.subheadline.bold())
                            .foregroundStyle(.tint)
                    }
                    Text(store.selectedAccount?.address ?? "No wallet")
                        .font(.caption.monospaced()).lineLimit(1).truncationMode(.middle)
                    if let error = store.balanceError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                .vaultGlass()

                if let account = store.selectedAccount, !account.backedUp {
                    NavigationLink {
                        RecoveryPhraseView(account: account)
                    } label: {
                        Label("Back up your wallet", systemImage: "exclamationmark.shield.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .vaultGlass()
                    }
                    .foregroundStyle(.primary)
                }
            }
            .padding()
        }
        .refreshable {
            await store.refreshBalance()
            await store.refreshENS()
        }
        .navigationTitle(store.selectedAccount?.name ?? "VaultETH")
        .toolbar {
            if store.accounts.count > 1 {
                ToolbarItem(placement: .primaryAction) {
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
                        Label("Switch wallet", systemImage: "wallet.pass")
                    }
                }
            }
        }
    }
}

struct ReceiveView: View {
    @EnvironmentObject private var store: WalletStore

    var body: some View {
        VStack(spacing: 18) {
            if let account = store.selectedAccount {
                QRCodeView(text: account.address).frame(width: 240, height: 240)
                Text(account.address).font(.footnote.monospaced()).textSelection(.enabled).multilineTextAlignment(.center)
                Button("Copy address", systemImage: "doc.on.doc") { UIPasteboard.general.string = account.address }
                    .buttonStyle(.bordered)
                Text("Only send Ethereum Mainnet assets to this address.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                Text("Create a wallet first")
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Receive")
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: WalletStore

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }

    var body: some View {
        List {
            Section("Security") {
                Label("Non-custodial Keychain vault", systemImage: "lock.fill")
                Text("Recovery phrases stay on this device, protected by Face ID or your passcode. They are never uploaded or backed up to iCloud.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Network") {
                LabeledContent("Chain", value: "Ethereum Mainnet")
                LabeledContent("Primary RPC", value: "publicnode.com")
                LabeledContent("Fallback RPC", value: "cloudflare-eth.com")
                Text("These providers see your IP address and public wallet address when the app fetches balances or broadcasts transactions.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Refresh balance", systemImage: "arrow.clockwise") {
                    Task { await store.refreshBalance() }
                }
            }
            Section("About") {
                LabeledContent("Version", value: version)
                if let url = URL(string: "https://github.com/ganiyucall911/VaultETH") {
                    Link("Source code on GitHub", destination: url)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

struct WelcomeView: View {
    @State private var showAdd = false

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "wallet.pass.fill").font(.system(size: 58)).padding(25).vaultGlass()
            Text("VaultETH").font(.largeTitle.bold())
            Text("Your keys. Your wallet.").font(.title2)
            Text("A non-custodial Ethereum wallet designed for iPhone.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Create or import a wallet") { showAdd = true }.buttonStyle(.borderedProminent)
        }
        .padding(30)
        .sheet(isPresented: $showAdd) { AddWalletView() }
    }
}
