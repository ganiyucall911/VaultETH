import SwiftUI

// MARK: - Color Tokens & Identity Palettes

extension Color {
    /// Deep obsidian matte background tone (#080A0E)
    static let vaultBackground = Color(red: 11/255.0, green: 13/255.0, blue: 16/255.0)
    /// Obsidian secondary surface tone (#0E1219)
    static let vaultSurface = Color(red: 18/255.0, green: 21/255.0, blue: 26/255.0)
    /// Obsidian elevated surface tone (#141A24)
    static let vaultSurfaceElevated = Color(red: 24/255.0, green: 28/255.0, blue: 35/255.0)
    /// Surface tone for frosted glass cards (#121822)
    static let vaultCardSurface = Color(red: 20/255.0, green: 24/255.0, blue: 29/255.0)
    /// Obsidian secondary card / surface tone (#121822)
    static let vaultSurfaceVariant = Color(red: 20/255.0, green: 24/255.0, blue: 29/255.0)
    /// Obsidian card hover surface tone (#18202D)
    static let vaultCardHover = Color(red: 28/255.0, green: 33/255.0, blue: 40/255.0)
    /// Specular hairline border highlight (8% opacity)
    static let vaultBorder = Color.white.opacity(0.10)
    /// Hairline border specular highlight (16% opacity)
    static let vaultBorderHighlight = Color.white.opacity(0.20)
    /// Cash App Mint Green Signature Accent (#00D632)
    static let vaultMint = Color(red: 0.0, green: 214/255.0, blue: 50/255.0)
    /// Primary Brand Accent
    static let vaultPrimary = vaultMint
    /// Electric Cyan aliased to Cash App Mint Green for full backwards-compatibility
    static let vaultCyan = vaultMint
    /// Royal Ethereum Violet (#8A2BE2)
    static let vaultViolet = Color(red: 0.42, green: 0.45, blue: 0.49) // neutral slate (monochrome system)
    /// Semantic Danger Red (#FF4757)
    static let vaultDanger = Color(red: 229/255.0, green: 72/255.0, blue: 77/255.0)
    /// Security Warning Amber (#FFA502)
    static let vaultAmber = Color(red: 217/255.0, green: 158/255.0, blue: 66/255.0)
    /// Confirmation Emerald / Trend Positive (#00D632)
    static let vaultEmerald = vaultMint
    /// Accent Blue (#3867D6)
    static let vaultBlue = Color(red: 0.42, green: 0.45, blue: 0.49) // neutral slate (monochrome system)
    /// Text Primary (#F8FAFC)
    static let vaultText = Color(red: 232/255.0, green: 234/255.0, blue: 237/255.0)
    /// Text Muted (#94A3B8)
    static let vaultTextMuted = Color(red: 138/255.0, green: 145/255.0, blue: 156/255.0)
    /// Text Dim (#64748B)
    static let vaultTextDim = Color(red: 107/255.0, green: 114/255.0, blue: 128/255.0)
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
                    .fill(Color.vaultCardSurface.opacity(0.55))
                    .background(.ultraThinMaterial, in: shape)
            )
            .overlay(
                Group {
                    if specularBorder {
                        // Specular edge: light catches the top-left of the glass
                        shape.strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.white.opacity(0.04),
                                    Color.white.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    } else {
                        shape.strokeBorder(Color.vaultBorder, lineWidth: 1)
                    }
                }
            )
            .shadow(color: Color.black.opacity(0.30), radius: 10, x: 0, y: 4)
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
                    .fill(Color.vaultCardSurface.opacity(0.65))
                    .background(.ultraThinMaterial, in: shape)
            )
            .overlay(
                shape.strokeBorder(
                    highlightGradient ?? LinearGradient(
                        colors: [Color.vaultBorderHighlight, Color.vaultBorder],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
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
            shape.fill(Color.vaultMint.opacity(isPressed ? 0.85 : 1.0))
        case .glass:
            shape.fill(Color.vaultCardSurface.opacity(0.55))
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.vaultBorderHighlight, lineWidth: 1))
        case .danger:
            shape.fill(Color.vaultDanger.opacity(0.15))
                .overlay(shape.strokeBorder(Color.vaultDanger.opacity(0.4), lineWidth: 1))
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

    func vaultGlow(_ color: Color = .vaultMint, radius: CGFloat = 16, opacity: Double = 0.35) -> some View {
        modifier(VaultGlow(color: color, radius: radius, opacity: opacity))
    }

    func vaultShimmer() -> some View {
        modifier(VaultShimmer())
    }
}

// MARK: - Shimmer Skeleton & Glow Modifiers

struct VaultShimmer: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.18),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: -geo.size.width + (phase * geo.size.width * 2))
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

struct VaultGlow: ViewModifier {
    var color: Color = .vaultMint
    var radius: CGFloat = 16
    var opacity: Double = 0.35

    func body(content: Content) -> some View {
        // Flat monochrome design system: glow effects are intentionally disabled.
        content
    }
}

// MARK: - Tactile Haptic System

#if canImport(UIKit)
import UIKit

enum VaultHaptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
#endif

