import SwiftUI

/// Generates a deterministic, luxury cryptographic crest (identicon) for any Ethereum address.
/// Unlike standard 8-bit blockies or cartoon avatars, VaultIdenticon produces a geometric
/// crystalline Ethereum crest featuring:
/// - A deterministic chromatic aura gradient computed from the address bytes
/// - Precision-aligned geometric facets reflecting cryptographic key symmetry
/// - Concentric orbital rings and glowing beacon nodes
struct VaultIdenticon: View {
    let address: String
    var size: CGFloat = 40
    var showGlow: Bool = false

    /// Deterministic seed extracted from the hex address (first 16 bytes)
    private var seed: [UInt8] {
        let clean = address.lowercased().replacingOccurrences(of: "0x", with: "")
        guard !clean.isEmpty else { return Array(repeating: 0, count: 16) }
        var bytes: [UInt8] = []
        var index = clean.startIndex
        while index < clean.endIndex && bytes.count < 16 {
            let nextIndex = clean.index(index, offsetBy: 2, limitedBy: clean.endIndex) ?? clean.endIndex
            let byteStr = String(clean[index..<nextIndex])
            if let b = UInt8(byteStr, radix: 16) {
                bytes.append(b)
            } else {
                bytes.append(0)
            }
            index = nextIndex
        }
        while bytes.count < 16 { bytes.append(0) }
        return bytes
    }

    /// Primary signature color calculated from bytes 0..2
    private var primaryColor: Color {
        let hue = Double(seed[0]) / 255.0
        let saturation = 0.75 + (Double(seed[1] % 50) / 200.0)
        let brightness = 0.85 + (Double(seed[2] % 30) / 200.0)
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    /// Secondary signature color calculated from bytes 3..5 (complementary / shifted)
    private var secondaryColor: Color {
        let shift = 0.15 + (Double(seed[3] % 100) / 300.0)
        let hue = (Double(seed[0]) / 255.0 + shift).truncatingRemainder(dividingBy: 1.0)
        let saturation = 0.70 + (Double(seed[4] % 40) / 200.0)
        let brightness = 0.90
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    /// Accent highlight color from byte 6
    private var accentColor: Color {
        let hue = (Double(seed[0]) / 255.0 + 0.5).truncatingRemainder(dividingBy: 1.0)
        return Color(hue: hue, saturation: 0.8, brightness: 1.0)
    }

    /// Rotation angle derived from byte 7
    private var facetAngle: Angle {
        Angle(degrees: Double(seed[7] % 45))
    }

    var body: some View {
        ZStack {
            // Ambient Aura Glow
            if showGlow {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [primaryColor.opacity(0.45), secondaryColor.opacity(0.15), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.9
                        )
                    )
                    .frame(width: size * 1.6, height: size * 1.6)
                    .blur(radius: size * 0.15)
            }

            // Outer Obsidian Chassis
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.12), Color(white: 0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: [primaryColor.opacity(0.6), secondaryColor.opacity(0.3), primaryColor.opacity(0.6)],
                                center: .center
                            ),
                            lineWidth: max(1.0, size * 0.035)
                        )
                )

            // Concentric Orbit Ring with Micro-Ticks
            Circle()
                .strokeBorder(Color.white.opacity(0.15), lineWidth: max(0.5, size * 0.02))
                .frame(width: size * 0.76, height: size * 0.76)

            // Inner Cryptographic Rhomboid / Diamond (Ethereum facet motif)
            Group {
                // Background facet
                EthereumFacetShape()
                    .fill(
                        LinearGradient(
                            colors: [primaryColor.opacity(0.85), secondaryColor.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.44, height: size * 0.60)
                    .shadow(color: primaryColor.opacity(0.4), radius: size * 0.08)

                // Top specular facet highlight
                EthereumTopFacetShape()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.5), Color.white.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.44, height: size * 0.30)
                    .offset(y: -size * 0.15)
            }

            // Central Beacon Node
            Circle()
                .fill(Color.white)
                .frame(width: max(2, size * 0.08), height: max(2, size * 0.08))
                .shadow(color: accentColor, radius: max(2, size * 0.08))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Geometric Shapes

/// Stylized Ethereum octahedron silhouette
private struct EthereumFacetShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = CGPoint(x: rect.midX, y: rect.minY)
        let bottom = CGPoint(x: rect.midX, y: rect.maxY)
        let left = CGPoint(x: rect.minX, y: rect.midY)
        let right = CGPoint(x: rect.maxX, y: rect.midY)

        path.move(to: top)
        path.addLine(to: right)
        path.addLine(to: bottom)
        path.addLine(to: left)
        path.closeSubpath()
        return path
    }
}

/// Specular upper reflection
private struct EthereumTopFacetShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = CGPoint(x: rect.midX, y: rect.minY)
        let bottom = CGPoint(x: rect.midX, y: rect.maxY)
        let left = CGPoint(x: rect.minX, y: rect.maxY)
        let right = CGPoint(x: rect.maxX, y: rect.maxY)

        path.move(to: top)
        path.addLine(to: right)
        path.addLine(to: bottom)
        path.addLine(to: left)
        path.closeSubpath()
        return path
    }
}
