import SwiftUI

/// Liquid Glass on iOS 26+ (when built with a Swift 6.2+ toolchain), material fallback everywhere else.
struct VaultGlass: ViewModifier {
    var cornerRadius: CGFloat = 24

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    private func fallback(_ content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.strokeBorder(.quaternary))
    }
}

extension View {
    func vaultGlass(cornerRadius: CGFloat = 24) -> some View {
        modifier(VaultGlass(cornerRadius: cornerRadius))
    }
}
