import SwiftUI

// MARK: - Official ArkLine Color Palette

/// App Colors namespace for all color tokens
/// Based on official ArkLine branding guidelines
struct AppColors {
    // MARK: - System Colors
    static let systemWhite = Color.white
    static let systemBlack = Color.black

    // MARK: - Primary Brand Colors
    static let fillPrimary = Color(hex: "3B82F6")    // blue-500
    static let accent = Color(hex: "3B82F6")          // blue-500
    static let accentDark = Color(hex: "2563EB")      // blue-600
    static let accentLight = Color(hex: "60A5FA")     // blue-400

    // MARK: - Semantic Colors (Same in both modes)
    static let success = Color(hex: "22C55E")
    static let warning = Color(hex: "F59E0B")
    static let error = Color(hex: "DC2626")  // red-600
    static let info = Color(hex: "3B82F6")

    /// Focus ring color for inputs (sky-500)
    static let focusRing = Color(hex: "0EA5E9")  // sky-500

    // MARK: - Adaptive Colors (Light/Dark mode)

    /// Background color - adapts to color scheme
    static func background(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "0F0F0F") : Color(hex: "F8F8F8")
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
        colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "E2E8F0")  // slate-200
    }

    /// Card border color (visible in light mode)
    static func cardBorder(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.clear : Color(hex: "E2E8F0")  // slate-200
    }

    /// Secondary fill color
    static func fillSecondary(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "2F2858") : Color(hex: "F5F5F5")
    }

    /// Primary text color
    static func textPrimary(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white : Color(hex: "1E293B")  // slate-800
    }

    /// Secondary text color
    static let textSecondary = Color(hex: "475569")  // slate-600

    /// Tertiary text color (lighter than secondary)
    static let textTertiary = Color(hex: "64748B")  // slate-500

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
    var textTertiary: Color { AppColors.textTertiary }
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

    // MARK: - Mesh Gradient Colors (Based on ArkLine palette)
    static let meshPurple = Color(hex: "2F2858")  // fill-secondary dark
    static let meshBlue = Color(hex: "3B82F6")     // blue-500
    static let meshCyan = Color(hex: "3B82F6")    // info blue
    static let meshPink = Color(hex: "6366F1")    // subtle purple
    static let meshIndigo = Color(hex: "1E3A8A")  // deep blue

    // MARK: - Glow Colors
    static let glowPrimary = Color(hex: "3B82F6")  // blue-500
    static let glowSuccess = Color(hex: "22C55E")
    static let glowWarning = Color(hex: "F59E0B")
    static let glowError = Color(hex: "DC2626")  // red-600

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
struct GlassmorphismCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let cornerRadius: CGFloat
    let blur: CGFloat

    init(cornerRadius: CGFloat = 16, blur: CGFloat = 10) {
        self.cornerRadius = cornerRadius
        self.blur = blur
    }

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Ultra-thin material for blur effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)

                    // Subtle tinted glass overlay
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            colorScheme == .dark
                                ? Color(hex: "1F1F1F").opacity(0.45)
                                : Color.white.opacity(0.55)
                        )

                    // Very subtle blue tint from accent color
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppColors.accent.opacity(colorScheme == .dark ? 0.05 : 0.03),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Inner highlight at top (very subtle)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.3),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )

                    // Border - subtle gradient
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.15 : 0.4),
                                    Color.white.opacity(colorScheme == .dark ? 0.03 : 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 10, x: 0, y: 4)
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
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Base dark background (matches ArkLine #0F0F0F)
            Color(hex: colorScheme == .dark ? "0A0A0B" : "F5F5F5")

            // Static mesh blobs - subtle, dark blue/purple tones
            GeometryReader { geometry in
                ZStack {
                    // Large deep blue blob (top-left)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    AppColors.meshIndigo.opacity(colorScheme == .dark ? 0.7 : 0.3),
                                    AppColors.meshIndigo.opacity(0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 250
                            )
                        )
                        .frame(width: 500, height: 500)
                        .offset(x: -100, y: -175)

                    // Accent blue blob (center-right)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    AppColors.meshBlue.opacity(colorScheme == .dark ? 0.4 : 0.25),
                                    AppColors.meshBlue.opacity(0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 400, height: 400)
                        .offset(x: 80, y: 100)

                    // Purple blob (bottom-left)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    AppColors.meshPurple.opacity(colorScheme == .dark ? 0.6 : 0.25),
                                    AppColors.meshPurple.opacity(0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 180
                            )
                        )
                        .frame(width: 360, height: 360)
                        .offset(x: -60, y: 375)

                    // Subtle accent glow (top-right)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    AppColors.accent.opacity(colorScheme == .dark ? 0.25 : 0.15),
                                    AppColors.accent.opacity(0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .offset(x: 100, y: -80)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Detail Header Gradient
struct DetailHeaderGradient: View {
    let primaryColor: Color
    let secondaryColor: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [primaryColor.opacity(blobOpacity(0.25)), primaryColor.opacity(0)],
                    center: .center, startRadius: 0, endRadius: 200
                ))
                .frame(width: 400, height: 400)
                .offset(x: -100, y: -120)

            Circle()
                .fill(RadialGradient(
                    colors: [secondaryColor.opacity(blobOpacity(0.2)), secondaryColor.opacity(0)],
                    center: .center, startRadius: 0, endRadius: 160
                ))
                .frame(width: 320, height: 320)
                .offset(x: 120, y: -60)
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func blobOpacity(_ base: CGFloat) -> CGFloat {
        colorScheme == .dark ? base : base * 0.5
    }
}

// MARK: - View Extensions
// MARK: - Glass List Row Background
struct GlassListRowBackground: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Ultra-thin material for blur effect
            Rectangle()
                .fill(.ultraThinMaterial)

            // Subtle tinted glass overlay
            Rectangle()
                .fill(
                    colorScheme == .dark
                        ? Color(hex: "1F1F1F").opacity(0.45)
                        : Color.white.opacity(0.55)
                )

            // Very subtle accent tint
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.accent.opacity(colorScheme == .dark ? 0.03 : 0.02),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, blur: CGFloat = 10) -> some View {
        modifier(GlassmorphismCardModifier(cornerRadius: cornerRadius, blur: blur))
    }

    func glassListRowBackground() -> some View {
        listRowBackground(GlassListRowBackground())
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


// MARK: - Focus Ring Modifier
struct FocusRingModifier: ViewModifier {
    let isFocused: Bool
    let cornerRadius: CGFloat

    init(isFocused: Bool, cornerRadius: CGFloat = ArkSpacing.Radius.input) {
        self.isFocused = isFocused
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppColors.focusRing.opacity(0.5), lineWidth: 2)
                    .opacity(isFocused ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isFocused)
            )
    }
}

extension View {
    /// Adds a sky-500 focus ring when focused (matches Julia's focus:ring-2 focus:ring-sky-500/50)
    func arkFocusRing(_ isFocused: Bool, cornerRadius: CGFloat = ArkSpacing.Radius.input) -> some View {
        modifier(FocusRingModifier(isFocused: isFocused, cornerRadius: cornerRadius))
    }
}

// MARK: - Avatar Color Theme Extension
extension Constants.AvatarColorTheme {
    /// SwiftUI Color values for the avatar gradient
    var gradientColors: (light: Color, dark: Color) {
        let hexColors = gradientHexColors
        return (Color(hex: hexColors.light), Color(hex: hexColors.dark))
    }
}
