import SwiftUI

// MARK: - Color Tokens & Identity Palettes

extension Color {
    /// Deep obsidian background tone
    static let vaultBackground = Color(red: 0.04, green: 0.05, blue: 0.08)
    /// Surface tone for frosted glass cards
    static let vaultCardSurface = Color(red: 0.08, green: 0.10, blue: 0.15)
    /// Specular titanium border highlight
    static let vaultBorder = Color.white.opacity(0.12)
    /// Electric Ethereum Cyan
    static let vaultCyan = Color(red: 0.0, green: 0.95, blue: 1.0)
    /// Royal Ethereum Violet
    static let vaultViolet = Color(red: 0.50, green: 0.10, blue: 0.95)
    /// Security Warning Amber
    static let vaultAmber = Color(red: 1.0, green: 0.70, blue: 0.10)
    /// Confirmation Emerald
    static let vaultEmerald = Color(red: 0.10, green: 0.85, blue: 0.55)
}

// MARK: - Liquid Glass Modifier

/// Frosted titanium glass modifier built with native ultraThinMaterial and specular borders.
struct VaultGlass: ViewModifier {
    var cornerRadius: CGFloat = 24
    var specularBorder: Bool = true

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }

    func body(content: Content) -> some View {
        fallback(content)
    }

    private func fallback(_ content: Content) -> some View {
        content
            .background(
                shape
                    .fill(Color.vaultCardSurface.opacity(0.72))
                    .background(.ultraThinMaterial, in: shape)
            )
            .overlay(
                Group {
                    if specularBorder {
                        shape.strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.24),
                                    Color.white.opacity(0.04),
                                    Color.white.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    } else {
                        shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    }
                }
            )
    }
}

// MARK: - Premium Vault Card Modifier

struct VaultCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 24
    var highlightGradient: LinearGradient? = nil

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }

    func body(content: Content) -> some View {
        content
            .background(
                shape
                    .fill(Color.vaultCardSurface.opacity(0.85))
                    .background(.ultraThinMaterial, in: shape)
            )
            .overlay(
                shape.strokeBorder(
                    highlightGradient ?? LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 8)
    }
}

// MARK: - Tactile Spring Button Style

struct VaultButtonStyle: ButtonStyle {
    enum Variant {
        case prominent
        case glass
        case danger
    }

    var variant: Variant = .prominent
    var cornerRadius: CGFloat = 16

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(background(isPressed: configuration.isPressed))
            .foregroundStyle(foreground)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }

    @ViewBuilder
    private func background(isPressed: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        switch variant {
        case .prominent:
            shape.fill(
                LinearGradient(
                    colors: [Color.vaultCyan, Color.vaultViolet],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: Color.vaultCyan.opacity(isPressed ? 0.2 : 0.4), radius: 12, y: 4)
        case .glass:
            shape.fill(Color.vaultCardSurface.opacity(0.8))
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        case .danger:
            shape.fill(Color.red.opacity(0.15))
                .overlay(shape.strokeBorder(Color.red.opacity(0.4), lineWidth: 1))
        }
    }

    private var foreground: Color {
        switch variant {
        case .prominent: return .black
        case .glass: return .white
        case .danger: return .red
        }
    }
}

// MARK: - View Extensions

extension View {
    func vaultGlass(cornerRadius: CGFloat = 24, specularBorder: Bool = true) -> some View {
        modifier(VaultGlass(cornerRadius: cornerRadius, specularBorder: specularBorder))
    }

    func vaultCard(cornerRadius: CGFloat = 24, highlight: LinearGradient? = nil) -> some View {
        modifier(VaultCardModifier(cornerRadius: cornerRadius, highlightGradient: highlight))
    }

    func vaultButton(_ variant: VaultButtonStyle.Variant = .prominent, cornerRadius: CGFloat = 16) -> some View {
        buttonStyle(VaultButtonStyle(variant: variant, cornerRadius: cornerRadius))
    }
}
