import AppIntents

/// Siri/Shortcuts only open the app. They never read balances, addresses or keys, and cannot sign or send.
struct OpenVaultETHIntent: AppIntent {
    static let title: LocalizedStringResource = "Open VaultETH"
    static let openAppWhenRun = true
    func perform() async throws -> some IntentResult { .result() }
}

struct VaultETHBalanceIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Ethereum balance"
    static let openAppWhenRun = true
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Opening VaultETH. Your balance is shown in the app.")
    }
}

struct VaultETHShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenVaultETHIntent(),
                    phrases: ["Open \(.applicationName)", "Open my wallet in \(.applicationName)"],
                    shortTitle: "Open wallet", systemImageName: "wallet.pass")
        AppShortcut(intent: VaultETHBalanceIntent(),
                    phrases: ["Show my Ethereum balance in \(.applicationName)"],
                    shortTitle: "Ethereum balance", systemImageName: "chart.bar.fill")
    }
}
