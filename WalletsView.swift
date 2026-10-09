import SwiftUI

struct WalletsView: View {
    @EnvironmentObject private var store: WalletStore
    @State private var showAdd = false
    @State private var pendingDelete: WalletAccount?
    @State private var pendingRename: WalletAccount?
    @State private var draftName = ""
    @State private var viewingRecoveryPhraseFor: WalletAccount?
    @State private var managingENSFor: WalletAccount?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header overview
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(store.accounts.count) Active \(store.accounts.count == 1 ? "Vault" : "Vaults")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        showAdd = true
                    } label: {
                        Label("New Vault", systemImage: "plus.circle.fill")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(Color.vaultCyan)
                }
                .padding(.horizontal, 4)

                // Vault Cards
                ForEach(store.accounts) { account in
                    VaultCardRow(
                        account: account,
                        isSelected: account.id == store.selectedAccountID,
                        onSelect: { store.select(account) },
                        onShowPhrase: { viewingRecoveryPhraseFor = account },
                        onManageENS: { managingENSFor = account },
                        onRename: {
                            draftName = account.name
                            pendingRename = account
                        },
                        onDelete: { pendingDelete = account }
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .background(Color.vaultBackground.ignoresSafeArea())
        .navigationTitle("Vaults")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.vaultCyan)
                }
            }
        }
        .sheet(isPresented: $showAdd) { AddWalletView() }
        .sheet(item: $viewingRecoveryPhraseFor) { account in
            NavigationStack {
                RecoveryPhraseView(account: account)
            }
        }
        .sheet(item: $managingENSFor) { account in
            ENSManagerView(account: account)
        }
        .confirmationDialog(
            "Delete this vault from this device?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { account in
            Button("Delete \(account.name)", role: .destructive) { store.delete(account) }
        } message: { account in
            Text(account.backedUp
                 ? "You can restore it anytime using its 12-word recovery phrase."
                 : "CRITICAL: This vault is NOT backed up. Deleting it will permanently destroy all access to its funds.")
        }
        .alert("Rename Vault", isPresented: Binding(
            get: { pendingRename != nil },
            set: { if !$0 { pendingRename = nil } }
        )) {
            TextField("Vault name", text: $draftName)
                .textInputAutocapitalization(.words)
            Button("Save") {
                let trimmed = draftName.trimmingCharacters(in: .whitespaces)
                if let account = pendingRename, !trimmed.isEmpty {
                    store.rename(account, to: trimmed)
                }
                pendingRename = nil
            }
            Button("Cancel", role: .cancel) { pendingRename = nil }
        } message: {
            Text("Enter a new identifier for \"\(pendingRename?.name ?? "")\".")
        }
    }
}

// MARK: - Vault Card Row

private struct VaultCardRow: View {
    let account: WalletAccount
    let isSelected: Bool
    let onSelect: () -> Void
    let onShowPhrase: () -> Void
    let onManageENS: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VaultIdenticon(address: account.address, size: 44, showGlow: isSelected)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(account.name)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)

                            if isSelected {
                                Text("Active")
                                    .font(.caption2.bold())
                                    .foregroundStyle(Color.vaultCyan)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.vaultCyan.opacity(0.15), in: Capsule())
                            }
                        }

                        if let ens = account.importedENSName {
                            HStack(spacing: 4) {
                                Text(ens)
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.vaultCyan)
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Color.vaultCyan)
                            }
                        }

                        Text(account.address)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    Menu {
                        Button("ENS Identity (.eth)", systemImage: "at", action: onManageENS)
                        Button("View Recovery Phrase", systemImage: "key.fill", action: onShowPhrase)
                        Button("Rename Vault", systemImage: "pencil", action: onRename)
                        Menu("Copy Address") {
                            Button("Copy EVM Address (0x…)", systemImage: "doc.on.doc") {
                                UIPasteboard.general.string = account.address
                            }
                            if let sol = account.solanaAddress {
                                Button("Copy Solana Address", systemImage: "doc.on.doc") {
                                    UIPasteboard.general.string = sol
                                }
                            }
                            if let btc = account.bitcoinAddress {
                                Button("Copy Bitcoin Address", systemImage: "doc.on.doc") {
                                    UIPasteboard.general.string = btc
                                }
                            }
                        }
                        Divider()
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete Vault", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .padding(8)
                    }
                }

                HStack {
                    if account.backedUp {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(Color.vaultEmerald)
                            Text("Phrase Secured")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button(action: onShowPhrase) {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .foregroundStyle(Color.vaultAmber)
                                Text("Backup Needed")
                                    .font(.caption2.bold())
                                    .foregroundStyle(Color.vaultAmber)
                            }
                        }
                    }

                    Spacer()

                    Button(action: onManageENS) {
                        HStack(spacing: 3) {
                            Image(systemName: "at")
                                .font(.caption2)
                            Text(account.importedENSName != nil ? "Manage ENS" : "Buy / Link ENS")
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(Color.vaultCyan)
                    }
                }
            }
            .padding(18)
            .vaultCard(cornerRadius: 22, highlight: isSelected ? LinearGradient(
                colors: [Color.vaultCyan.opacity(0.6), Color.vaultViolet.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ) : nil)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add / Import Wallet View

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
            ScrollView {
                VStack(spacing: 24) {
                    Picker("Mode", selection: $importMode) {
                        Text("Create New").tag(false)
                        Text("Import Phrase").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Vault Name")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField(importMode ? "Imported Vault" : "Primary Vault", text: $name)
                            .font(.body)
                            .padding(14)
                            .vaultGlass(cornerRadius: 14)
                    }

                    if importMode {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("12 or 24-Word Recovery Phrase")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            TextEditor(text: $phrase)
                                .font(.body.monospaced())
                                .frame(height: 110)
                                .padding(10)
                                .vaultGlass(cornerRadius: 14)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                            Text("Enter words separated by spaces. Your phrase is processed locally and never leaves this device.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "key.viewfinder")
                                .font(.system(size: 42))
                                .foregroundStyle(Color.vaultCyan)
                                .padding(.top, 12)

                            Text("Cryptographically Secure Generation")
                                .font(.headline)

                            Text("A high-entropy BIP-39 mnemonic is generated directly within your device's Secure Enclave.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                        .padding(20)
                        .vaultGlass(cornerRadius: 20)
                    }

                    if let errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                            Text(errorMessage).font(.caption).foregroundStyle(.red)
                        }
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if isWorking {
                                ProgressView().tint(.black)
                            } else {
                                Text(importMode ? "Import Vault" : "Generate Vault")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .vaultButton(.prominent)
                    .disabled(isWorking || (importMode && phrase.trimmingCharacters(in: .whitespaces).isEmpty))
                }
                .padding(20)
            }
            .background(Color.vaultBackground.ignoresSafeArea())
            .navigationTitle(importMode ? "Import Vault" : "Create Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $created) { wallet in
                NavigationStack {
                    RecoveryPhraseView(
                        account: wallet.account,
                        initialMnemonic: wallet.mnemonic,
                        requiresConfirmation: true,
                        onFinish: { dismiss() }
                    )
                }
                .interactiveDismissDisabled()
            }
        }
    }

    private func submit() async {
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        do {
            if importMode {
                try await store.importWallet(name: name.isEmpty ? "Imported Vault" : name, mnemonic: phrase)
                phrase = ""
                dismiss()
            } else {
                created = try await store.createWallet(name: name.isEmpty ? "Primary Vault" : name)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Recovery Phrase Reveal View

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

    private var words: [String] {
        phrase?.split(separator: " ").map(String.init) ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    VaultIdenticon(address: account.address, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.name).font(.headline)
                        Text("Recovery Phrase").font(.subheadline).foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.vaultAmber)
                    Text("Anyone with these words has total control of your funds. Never photograph, screenshot, or store them in cloud services.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .vaultGlass(cornerRadius: 16)

                if !words.isEmpty {
                    // Beautiful 2-column numbered word capsules
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                            HStack(spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(Color.vaultCyan)
                                    .frame(width: 20, alignment: .trailing)
                                Text(word)
                                    .font(.subheadline.monospaced().weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .vaultGlass(cornerRadius: 12)
                        }
                    }

                    if requiresConfirmation {
                        Toggle("I have physically written down these words and stored them in a safe place.", isOn: $confirmed)
                            .font(.footnote)
                            .padding(.top, 8)
                    }

                    Button {
                        if !requiresConfirmation || confirmed { store.markBackedUp(account.id) }
                        dismiss()
                        onFinish?()
                    } label: {
                        Text("I've Backed Up My Phrase")
                            .frame(maxWidth: .infinity)
                    }
                    .vaultButton(.prominent)
                    .disabled(requiresConfirmation && !confirmed)
                    .padding(.top, 12)
                } else {
                    VStack(spacing: 16) {
                        Text("Authentication Required")
                            .font(.headline)
                        Text("Verify your identity with Face ID or device passcode to reveal your recovery phrase.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button {
                            Task { await reveal() }
                        } label: {
                            Label("Reveal with Face ID", systemImage: "faceid")
                                .frame(maxWidth: .infinity)
                        }
                        .vaultButton(.prominent)
                    }
                    .padding(24)
                    .vaultGlass(cornerRadius: 20)
                }

                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.red)
                }
            }
            .padding(20)
        }
        .background(Color.vaultBackground.ignoresSafeArea())
        .navigationTitle("Secret Recovery Phrase")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") { dismiss() }
            }
        }
        // Memory wiping on backgrounding
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active { phrase = nil }
        }
    }

    private func reveal() async {
        do {
            phrase = try await store.revealMnemonic(for: account.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
