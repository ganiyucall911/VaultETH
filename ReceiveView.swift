import SwiftUI
import UIKit

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
            Picker("Chain Format", selection: $selectedChain) {
                ForEach(ReceiveChain.allCases) { chain in
                    Text(chain.rawValue).tag(chain)
                }
            }
            .pickerStyle(.segmented)
            .padding(.top, 4)

            if let account = store.selectedAccount {
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

                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 220, height: 220)
                            .shadow(color: Color.black.opacity(0.2), radius: 12)

                        QRCodeView(text: activeAddress)
                            .frame(width: 190, height: 190)
                    }
                    .padding(.vertical, 4)

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
            return "Use only on EVM networks. VaultETH sends native assets only; ERC-20/token transfers are not supported."
        case .solana:
            return "Receive-only address. VaultETH cannot sign or broadcast Solana transactions."
        case .bitcoin:
            return "Receive-only address. VaultETH cannot sign or broadcast Bitcoin transactions."
        }
    }
}
