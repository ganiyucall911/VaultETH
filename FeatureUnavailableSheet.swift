import SwiftUI

struct FeatureUnavailableSheet: View {
    @Environment(\.dismiss) private var dismiss

    let feature: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.largeTitle)
                .foregroundStyle(Color.vaultCyan)

            Text("\(feature) is coming soon")
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            Text("This feature is not integrated. No purchase, swap, or transaction will be submitted.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Done") { dismiss() }
                .vaultButton(.prominent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.vaultBackground.ignoresSafeArea())
        .navigationTitle("Coming Soon")
        .navigationBarTitleDisplayMode(.inline)
    }
}
