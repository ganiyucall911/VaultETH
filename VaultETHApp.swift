import SwiftUI

@main
struct VaultETHApp: App {
    @StateObject private var store = WalletStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .task { await store.refreshBalance() }
        }
    }
}
