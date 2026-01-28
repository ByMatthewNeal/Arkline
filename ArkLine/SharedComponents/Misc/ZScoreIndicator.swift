import SwiftUI

// MARK: - Z-Score Indicator

/// A badge displaying z-score with color coding based on significance
struct ZScoreIndicator: View {
    let zScore: Double
    var style: ZScoreStyle = .badge
    var size: ZScoreSize = .medium
    var showDescription: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        switch style {
        case .badge:
            badgeView
        case .inline:
            inlineView
        case .expanded:
            expandedView
        }
    }

    // MARK: - Badge Style

    private var badgeView: some View {
        HStack(spacing: 2) {
            if isExtreme {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: size.iconSize))
            }

            Text(formattedZScore)
                .font(.system(size: size.fontSize, weight: .bold, design: .monospaced))
        }
        .foregroundColor(textColor)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(
            Capsule()
                .fill(backgroundColor)
        )
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: isExtreme ? 1.5 : 0)
        )
    }

    // MARK: - Inline Style

    private var inlineView: some View {
        HStack(spacing: 4) {
            Text(formattedZScore)
                .font(.system(size: size.fontSize, weight: .semibold, design: .monospaced))
                .foregroundColor(textColor)

            if showDescription {
                Text(description)
                    .font(.system(size: size.fontSize - 2))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    // MARK: - Expanded Style

    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                badgeView

                Text(description)
                    .font(.system(size: size.fontSize, weight: .medium))
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }

            if let rarity = rarity {
                Text("1 in \(rarity) occurrence")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    // MARK: - Computed Properties

    private var formattedZScore: String {
        String(format: "%+.1fσ", zScore)
    }

    private var isExtreme: Bool {
        abs(zScore) >= 3.0
    }

    private var isSignificant: Bool {
        abs(zScore) >= 2.0
    }

    private var description: String {
        if isExtreme {
            return zScore > 0 ? "Extremely High" : "Extremely Low"
        } else if isSignificant {
            return zScore > 0 ? "Significantly High" : "Significantly Low"
        } else if abs(zScore) >= 1.0 {
            return zScore > 0 ? "Above Average" : "Below Average"
        } else {
            return "Normal Range"
        }
    }

    private var rarity: Int? {
        guard isSignificant else { return nil }
        let p = (1 - normalCDF(abs(zScore))) * 2 // Two-tailed
        guard p > 0 else { return nil }
        return Int(1.0 / p)
    }

    // MARK: - Colors

    private var textColor: Color {
        if isExtreme {
            return .white
        } else if isSignificant {
            return colorScheme == .dark ? .white : signalColor
        } else {
            return AppColors.textSecondary
        }
    }

    private var backgroundColor: Color {
        if isExtreme {
            return signalColor
        } else if isSignificant {
            return signalColor.opacity(0.2)
        } else {
            return AppColors.cardBackground(colorScheme)
        }
    }

    private var borderColor: Color {
        isExtreme ? signalColor.opacity(0.8) : .clear
    }

    private var signalColor: Color {
        if abs(zScore) >= 3.0 {
            return AppColors.error
        } else if abs(zScore) >= 2.0 {
            return AppColors.warning
        } else {
            return AppColors.textSecondary
        }
    }

    // MARK: - Math Helpers

    private func normalCDF(_ x: Double) -> Double {
        0.5 * (1.0 + erf(x / sqrt(2.0)))
    }

    private func erf(_ x: Double) -> Double {
        let a1 =  0.254829592
        let a2 = -0.284496736
        let a3 =  1.421413741
        let a4 = -1.453152027
        let a5 =  1.061405429
        let p  =  0.3275911

        let sign = x < 0 ? -1.0 : 1.0
        let absX = abs(x)

        let t = 1.0 / (1.0 + p * absX)
        let y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-absX * absX)

        return sign * y
    }
}

// MARK: - Style & Size

enum ZScoreStyle {
    case badge      // Capsule badge with background
    case inline     // Just text, no background
    case expanded   // Badge + description + rarity
}

enum ZScoreSize {
    case small
    case medium
    case large

    var fontSize: CGFloat {
        switch self {
        case .small: return 9
        case .medium: return 11
        case .large: return 13
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small: return 7
        case .medium: return 9
        case .large: return 11
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 5
        case .medium: return 7
        case .large: return 9
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .small: return 2
        case .medium: return 3
        case .large: return 4
        }
    }
}

// MARK: - Contextual Z-Score Indicator

/// Z-Score indicator that shows different colors based on indicator type correlation
struct ContextualZScoreIndicator: View {
    let zScoreData: MacroZScoreData
    var style: ZScoreStyle = .badge
    var size: ZScoreSize = .medium

    var body: some View {
        HStack(spacing: 4) {
            ZScoreIndicator(zScore: zScoreData.zScore.zScore, style: style, size: size)

            if style == .expanded {
                Image(systemName: zScoreData.marketImplication.iconName)
                    .font(.system(size: size.fontSize))
                    .foregroundColor(zScoreData.marketImplication.color)
            }
        }
    }
}

// MARK: - Pulsing Extreme Indicator

/// A pulsing indicator for extreme moves
struct PulsingExtremeIndicator: View {
    let isActive: Bool
    var color: Color = AppColors.error

    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isActive ? (isPulsing ? 0.6 : 1.0) : 0)
            .animation(
                isActive ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                value: isPulsing
            )
            .onAppear {
                if isActive {
                    isPulsing = true
                }
            }
            .onChange(of: isActive) { _, newValue in
                isPulsing = newValue
            }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Group {
            Text("Badge Style").font(.headline)
            HStack(spacing: 12) {
                ZScoreIndicator(zScore: 0.5)
                ZScoreIndicator(zScore: 1.5)
                ZScoreIndicator(zScore: 2.3)
                ZScoreIndicator(zScore: 3.5)
            }
            HStack(spacing: 12) {
                ZScoreIndicator(zScore: -0.5)
                ZScoreIndicator(zScore: -1.5)
                ZScoreIndicator(zScore: -2.3)
                ZScoreIndicator(zScore: -3.5)
            }
        }

        Divider()

        Group {
            Text("Sizes").font(.headline)
            HStack(spacing: 12) {
                ZScoreIndicator(zScore: 2.5, size: .small)
                ZScoreIndicator(zScore: 2.5, size: .medium)
                ZScoreIndicator(zScore: 2.5, size: .large)
            }
        }

        Divider()

        Group {
            Text("Inline Style").font(.headline)
            ZScoreIndicator(zScore: -3.2, style: .inline, showDescription: true)
        }

        Divider()

        Group {
            Text("Expanded Style").font(.headline)
            ZScoreIndicator(zScore: -3.45, style: .expanded)
        }

        Divider()

        Group {
            Text("Pulsing Indicator").font(.headline)
            HStack {
                PulsingExtremeIndicator(isActive: true)
                Text("Extreme move detected")
            }
        }
    }
    .padding()
    .background(Color(hex: "0F0F0F"))
    .preferredColorScheme(.dark)
}
