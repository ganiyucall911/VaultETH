import SwiftUI

struct WalletsView: View {
    @EnvironmentObject private var store: WalletStore
    @State private var showAdd = false
    @State private var pendingDelete: WalletAccount?
    @State private var pendingRename: WalletAccount?
    @State private var draftName = ""

    var body: some View {
        List {
            ForEach(store.accounts) { account in
                Button { store.select(account) } label: {
                    HStack {
                        Image(systemName: account.id == store.selectedAccountID ? "checkmark.circle.fill" : "circle")
                        VStack(alignment: .leading) {
                            Text(account.name)
                            Text(account.address).font(.caption.monospaced())
                                .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                        Spacer()
                        if !account.backedUp {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        }
                    }
                    .foregroundStyle(.primary)
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) { pendingDelete = account }
                }
                .swipeActions(edge: .leading) {
                    Button("Rename", systemImage: "pencil") {
                        draftName = account.name
                        pendingRename = account
                    }
                    .tint(.blue)
                }
            }
        }
        .navigationTitle("Wallets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button("Add", systemImage: "plus") { showAdd = true } }
        }
        .sheet(isPresented: $showAdd) { AddWalletView() }
        .confirmationDialog(
            "Delete this wallet from this device?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { account in
            Button("Delete \(account.name)", role: .destructive) { store.delete(account) }
        } message: { account in
            Text(account.backedUp
                 ? "You can restore it later with your recovery phrase."
                 : "This wallet is NOT backed up. Deleting it permanently loses access to its funds.")
        }
        .alert("Rename Wallet", isPresented: Binding(
            get: { pendingRename != nil },
            set: { if !$0 { pendingRename = nil } }
        )) {
            TextField("Wallet name", text: $draftName)
                .textInputAutocapitalization(.words)
            Button("Rename") {
                let trimmed = draftName.trimmingCharacters(in: .whitespaces)
                if let account = pendingRename, !trimmed.isEmpty {
                    store.rename(account, to: trimmed)
                }
                pendingRename = nil
            }
            Button("Cancel", role: .cancel) { pendingRename = nil }
        } message: {
            Text("Enter a new name for "\(pendingRename?.name ?? "")".")
        }
    }
}

struct AddWalletView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: WalletStore

    @State private var importMode = false
    @State private var name = ""
    @State private var phrase = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var created: CreatedWallet?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Mode", selection: $importMode) {
                    Text("Create").tag(false)
                    Text("Import").tag(true)
                }
                .pickerStyle(.segmented)

                TextField("Wallet name", text: $name)

                if importMode {
                    SecureField("Recovery phrase (12–24 words)", text: $phrase)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                } else {
                    Text("A recovery phrase is generated on this device and stored in the Keychain.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle(importMode ? "Import wallet" : "Create wallet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(importMode ? "Import" : "Create") { Task { await submit() } }
                        .disabled(isWorking || (importMode && phrase.trimmingCharacters(in: .whitespaces).isEmpty))
                }
            }
            .sheet(item: $created) { wallet in
                RecoveryPhraseView(account: wallet.account, initialMnemonic: wallet.mnemonic,
                                   requiresConfirmation: true, onFinish: { dismiss() })
                    .interactiveDismissDisabled()
            }
        }
    }

    private func submit() async {
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        do {
            if importMode {
                try await store.importWallet(name: name.isEmpty ? "Imported Wallet" : name, mnemonic: phrase)
                phrase = ""
                dismiss()
            } else {
                created = try await store.createWallet(name: name.isEmpty ? "Main Wallet" : name)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct RecoveryPhraseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var store: WalletStore

    let account: WalletAccount
    var initialMnemonic: String?
    var requiresConfirmation = false
    var onFinish: (() -> Void)?

    @State private var phrase: String?
    @State private var confirmed = false
    @State private var errorMessage: String?

    init(account: WalletAccount, initialMnemonic: String? = nil, requiresConfirmation: Bool = false,
         onFinish: (() -> Void)? = nil) {
        self.account = account
        self.initialMnemonic = initialMnemonic
        self.requiresConfirmation = requiresConfirmation
        self.onFinish = onFinish
        _phrase = State(initialValue: initialMnemonic)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Recovery phrase").font(.largeTitle.bold())
            Text("Anyone with these words can take everything in this wallet. Write them down on paper and never share or photograph them.")
                .foregroundStyle(.secondary)

            if let phrase {
                Text(phrase).font(.body.monospaced()).padding().vaultGlass()
                if requiresConfirmation { Toggle("I wrote it down and stored it safely.", isOn: $confirmed) }
                Button("Done") {
                    if !requiresConfirmation || confirmed { store.markBackedUp(account.id) }
                    dismiss(); onFinish?()
                }
                .buttonStyle(.borderedProminent)
                .disabled(requiresConfirmation && !confirmed)
            } else {
                Button("Reveal with Face ID") { Task { await reveal() } }.buttonStyle(.borderedProminent)
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            Spacer()
        }
        .padding()
        // Hide the recovery phrase as soon as the app leaves the foreground so it does not
        // appear in the iOS app-switcher snapshot — regardless of whether it was passed in
        // directly (after wallet creation) or revealed on demand via Face ID.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active { phrase = nil }
        }
    }

    private func reveal() async {
        do { phrase = try await store.revealMnemonic(for: account.id); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }
}
