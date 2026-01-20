import SwiftUI

// MARK: - Official ArkLine Color Palette

/// App Colors namespace for all color tokens
/// Based on official ArkLine branding guidelines
struct AppColors {
    // MARK: - System Colors
    static let systemWhite = Color.white
    static let systemBlack = Color.black

    // MARK: - Primary Brand Colors
    static let fillPrimary = Color(hex: "3369FF")
    static let accent = Color(hex: "3B69FF")
    static let accentDark = Color(hex: "2B4FCC")
    static let accentLight = Color(hex: "5A8AFF")

    // MARK: - Semantic Colors (Same in both modes)
    static let success = Color(hex: "22C55E")
    static let warning = Color(hex: "F59E0B")
    static let error = Color(hex: "EF4444")
    static let info = Color(hex: "3B82F6")

    // MARK: - Adaptive Colors (Light/Dark mode)

    /// Background color - adapts to color scheme
    static func background(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "0F0F0F") : Color(hex: "F5F5F5")
    }

    /// Surface color for cards and elevated elements
    static func surface(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "0A0A0B") : Color.white
    }

    /// Card background color
    static func cardBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    /// Divider/separator color
    static func divider(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "E5E5E5")
    }

    /// Secondary fill color
    static func fillSecondary(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "2F2858") : Color(hex: "F5F5F5")
    }

    /// Primary text color
    static func textPrimary(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white : Color.black
    }

    /// Secondary text color
    static let textSecondary = Color(hex: "888888")

    /// Disabled text color
    static func textDisabled(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "4A4A5A") : Color(hex: "CCCCCC")
    }

    // MARK: - Chart Colors
    static let chartPositive = success
    static let chartNegative = error
    static let chartLine = accent

    // MARK: - Gradient Definitions
    static let primaryGradient = LinearGradient(
        colors: [accentLight, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let fearGreedGradient = LinearGradient(
        colors: [error, warning, success],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Hex Color Initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Environment-Aware Color Provider
@Observable
final class ColorProvider {
    var colorScheme: ColorScheme = .dark

    var background: Color { AppColors.background(colorScheme) }
    var surface: Color { AppColors.surface(colorScheme) }
    var cardBackground: Color { AppColors.cardBackground(colorScheme) }
    var divider: Color { AppColors.divider(colorScheme) }
    var fillSecondary: Color { AppColors.fillSecondary(colorScheme) }
    var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    var textDisabled: Color { AppColors.textDisabled(colorScheme) }

    // Non-adaptive colors
    var fillPrimary: Color { AppColors.fillPrimary }
    var accent: Color { AppColors.accent }
    var textSecondary: Color { AppColors.textSecondary }
    var success: Color { AppColors.success }
    var warning: Color { AppColors.warning }
    var error: Color { AppColors.error }
    var info: Color { AppColors.info }
}

// MARK: - Environment Key for Color Provider
struct ColorProviderKey: EnvironmentKey {
    static let defaultValue = ColorProvider()
}

extension EnvironmentValues {
    var colors: ColorProvider {
        get { self[ColorProviderKey.self] }
        set { self[ColorProviderKey.self] = newValue }
    }
}

// MARK: - Convenience Color Extensions
extension Color {
    // Quick access to app colors
    static let arkAccent = AppColors.accent
    static let arkFillPrimary = AppColors.fillPrimary
    static let arkSuccess = AppColors.success
    static let arkWarning = AppColors.warning
    static let arkError = AppColors.error
    static let arkInfo = AppColors.info
    static let arkTextSecondary = AppColors.textSecondary
}

// MARK: - View Modifier for Theme Colors
struct ThemedBackground: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(AppColors.background(colorScheme))
    }
}

struct ThemedCard: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 16) {
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .background(AppColors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func themedBackground() -> some View {
        modifier(ThemedBackground())
    }

    func themedCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(ThemedCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Glassmorphism & Modern Design System

extension AppColors {
    // MARK: - Glass Colors
    static func glassBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.white.opacity(0.7)
    }

    static func glassBorder(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.15)
            : Color.white.opacity(0.5)
    }

    // MARK: - Mesh Gradient Colors (Apple-style)
    static let meshPurple = Color(hex: "7C3AED")
    static let meshBlue = Color(hex: "3B82F6")
    static let meshCyan = Color(hex: "06B6D4")
    static let meshPink = Color(hex: "EC4899")
    static let meshIndigo = Color(hex: "6366F1")

    // MARK: - Glow Colors
    static let glowPrimary = Color(hex: "3B69FF")
    static let glowSuccess = Color(hex: "22C55E")
    static let glowWarning = Color(hex: "F59E0B")
    static let glowError = Color(hex: "EF4444")

    // MARK: - Modern Gradients
    static let meshGradient = LinearGradient(
        colors: [
            meshPurple.opacity(0.6),
            meshBlue.opacity(0.4),
            meshCyan.opacity(0.3)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGlow = RadialGradient(
        colors: [glowPrimary.opacity(0.5), glowPrimary.opacity(0)],
        center: .center,
        startRadius: 0,
        endRadius: 100
    )
}

// MARK: - Glassmorphism Card Modifier
struct GlassCard: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let cornerRadius: CGFloat
    let blur: CGFloat

    init(cornerRadius: CGFloat = 20, blur: CGFloat = 10) {
        self.cornerRadius = cornerRadius
        self.blur = blur
    }

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Frosted glass effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(AppColors.glassBackground(colorScheme))
                        .background(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(.ultraThinMaterial)
                        )

                    // Border glow
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(AppColors.glassBorder(colorScheme), lineWidth: 1)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Glow Button Modifier
struct GlowButton: ViewModifier {
    let color: Color
    let isPressed: Bool

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Outer glow
                    RoundedRectangle(cornerRadius: 16)
                        .fill(color)
                        .blur(radius: isPressed ? 15 : 10)
                        .opacity(isPressed ? 0.8 : 0.5)

                    // Button background
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
    }
}

// MARK: - Mesh Background View
struct MeshGradientBackground: View {
    @State private var animateGradient = false

    var body: some View {
        ZStack {
            // Base dark background
            Color(hex: "050507")

            // Animated mesh blobs
            GeometryReader { geometry in
                ZStack {
                    // Purple blob
                    Circle()
                        .fill(AppColors.meshPurple.opacity(0.4))
                        .frame(width: 300, height: 300)
                        .blur(radius: 80)
                        .offset(
                            x: animateGradient ? -50 : 50,
                            y: animateGradient ? -100 : -50
                        )

                    // Blue blob
                    Circle()
                        .fill(AppColors.meshBlue.opacity(0.35))
                        .frame(width: 250, height: 250)
                        .blur(radius: 70)
                        .offset(
                            x: animateGradient ? 80 : 20,
                            y: animateGradient ? 100 : 150
                        )

                    // Cyan blob
                    Circle()
                        .fill(AppColors.meshCyan.opacity(0.25))
                        .frame(width: 200, height: 200)
                        .blur(radius: 60)
                        .offset(
                            x: animateGradient ? -80 : -30,
                            y: animateGradient ? 200 : 250
                        )

                    // Pink accent
                    Circle()
                        .fill(AppColors.meshPink.opacity(0.2))
                        .frame(width: 150, height: 150)
                        .blur(radius: 50)
                        .offset(
                            x: animateGradient ? 100 : 60,
                            y: animateGradient ? -50 : 0
                        )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }

            // Noise overlay for texture
            Rectangle()
                .fill(Color.white.opacity(0.02))
                .background(
                    Image(systemName: "circle.grid.3x3.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .opacity(0.03)
                )
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .easeInOut(duration: 8)
                .repeatForever(autoreverses: true)
            ) {
                animateGradient = true
            }
        }
    }
}

// MARK: - View Extensions
extension View {
    func glassCard(cornerRadius: CGFloat = 20, blur: CGFloat = 10) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, blur: blur))
    }

    func glowButton(color: Color = AppColors.glowPrimary, isPressed: Bool = false) -> some View {
        modifier(GlowButton(color: color, isPressed: isPressed))
    }

    // Subtle inner shadow for depth
    func innerShadow(color: Color = .black.opacity(0.1), radius: CGFloat = 3) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(color, lineWidth: 1)
                .blur(radius: radius)
                .offset(y: 1)
                .mask(RoundedRectangle(cornerRadius: 20).fill(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)))
        )
    }
}
