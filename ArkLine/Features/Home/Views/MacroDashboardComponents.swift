import SwiftUI

// MARK: - Signal Key Row
struct SignalKeyRow: View {
    let signal: String
    let color: Color
    let meaning: String
    let description: String

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(signal)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(color)

                    Text(meaning)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(textPrimary.opacity(0.6))
                }

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(textPrimary.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
    }
}

// MARK: - Correlation Detail Row
struct CorrelationDetailRow: View {
    let indicator: String
    let strength: CorrelationStrength
    let relationship: String
    let explanation: String

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(indicator)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textPrimary)

                    Text(relationship)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(textPrimary.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(textPrimary.opacity(0.08))
                        )
                }

                Text(explanation)
                    .font(.system(size: 12))
                    .foregroundColor(textPrimary.opacity(0.6))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                CorrelationBars(strength: strength)

                Text(strength.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(textPrimary.opacity(0.5))
            }
        }
        .padding(14)
    }
}

// MARK: - Macro Detail Row
struct MacroDetailRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let value: String
    let change: Double?
    let interpretation: String
    let correlation: CorrelationStrength
    var zScoreData: MacroZScoreData?

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppColors.accent)

                // Pulsing indicator for extreme moves
                if let zScore = zScoreData, zScore.isExtreme {
                    Circle()
                        .fill(AppColors.error)
                        .frame(width: 10, height: 10)
                        .offset(x: 16, y: -16)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textPrimary)

                    CorrelationBars(strength: correlation)

                    // Z-Score badge
                    if let zScore = zScoreData {
                        ZScoreIndicator(zScore: zScore.zScore.zScore, size: .small)
                    }
                }

                Text(interpretation)
                    .font(.system(size: 12))
                    .foregroundColor(textPrimary.opacity(0.6))
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(textPrimary)
                    .monospacedDigit()

                if let change = change {
                    Text(String(format: "%+.2f%%", change))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textPrimary.opacity(0.3))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
        )
    }
}

// MARK: - Threshold Row
struct ThresholdRow: View {
    let indicator: String
    let bullish: String
    let bearish: String

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack {
            Text(indicator)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(textPrimary)
                .frame(width: 60, alignment: .leading)

            Spacer()

            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColors.success)
                        .frame(width: 6, height: 6)
                    Text(bullish)
                        .font(.system(size: 12))
                        .foregroundColor(textPrimary.opacity(0.7))
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColors.error)
                        .frame(width: 6, height: 6)
                    Text(bearish)
                        .font(.system(size: 12))
                        .foregroundColor(textPrimary.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Z-Score Analysis Row
/// Detailed z-score breakdown for statistical analysis section
struct ZScoreAnalysisRow: View {
    let zScoreData: MacroZScoreData

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with indicator and z-score badge
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(zScoreData.indicator.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(textPrimary)

                        ZScoreIndicator(zScore: zScoreData.zScore.zScore, size: .medium)

                        if zScoreData.isExtreme {
                            PulsingExtremeIndicator(isActive: true, color: AppColors.error)
                        }
                    }

                    // Market implication inline
                    HStack(spacing: 4) {
                        Image(systemName: zScoreData.marketImplication.iconName)
                            .font(.system(size: 10))
                        Text(zScoreData.marketImplication.description)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(zScoreData.marketImplication.color)
                }

                Spacer()

                // Current value
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formattedValue)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(textPrimary)

                    Text("Current")
                        .font(.system(size: 10))
                        .foregroundColor(textPrimary.opacity(0.4))
                }
            }

            // Simplified stats - 2 columns for cleaner look
            HStack(spacing: 12) {
                // Mean & Std Dev
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Mean:")
                            .font(.system(size: 11))
                            .foregroundColor(textPrimary.opacity(0.5))
                        Spacer()
                        Text(formatStatValue(zScoreData.zScore.mean))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(textPrimary.opacity(0.8))
                    }
                    HStack {
                        Text("Std Dev:")
                            .font(.system(size: 11))
                            .foregroundColor(textPrimary.opacity(0.5))
                        Spacer()
                        Text(formatStatValue(zScoreData.zScore.standardDeviation))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(textPrimary.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 40).background(textPrimary.opacity(0.1))

                // SD Bands
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("+2σ:")
                            .font(.system(size: 11))
                            .foregroundColor(textPrimary.opacity(0.5))
                        Spacer()
                        Text(formatStatValue(zScoreData.sdBands.plus2SD))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(textPrimary.opacity(0.8))
                    }
                    HStack {
                        Text("-2σ:")
                            .font(.system(size: 11))
                            .foregroundColor(textPrimary.opacity(0.5))
                        Spacer()
                        Text(formatStatValue(zScoreData.sdBands.minus2SD))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(textPrimary.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(textPrimary.opacity(0.04))
            )

            // Only show rarity for significant moves (|z| >= 2)
            if zScoreData.isSignificant, let rarity = zScoreData.zScore.rarity, rarity > 1 {
                HStack {
                    Spacer()
                    Text("Occurs ~1 in \(rarity) observations")
                        .font(.system(size: 10))
                        .foregroundColor(textPrimary.opacity(0.5))
                }
            }
        }
        .padding(14)
    }

    private var formattedValue: String {
        formatForIndicator(zScoreData.currentValue)
    }

    /// Format a value appropriately for this indicator type
    private func formatStatValue(_ value: Double) -> String {
        formatForIndicator(value)
    }

    /// Format value based on indicator type
    private func formatForIndicator(_ value: Double) -> String {
        switch zScoreData.indicator {
        case .vix:
            return String(format: "%.2f", value)
        case .dxy:
            return String(format: "%.2f", value)
        case .m2:
            return formatLargeNumber(value)
        }
    }

    /// Format large numbers (trillions/billions) for M2
    private func formatLargeNumber(_ value: Double) -> String {
        if value >= 1_000_000_000_000 {
            return String(format: "%.2fT", value / 1_000_000_000_000)
        } else if value >= 1_000_000_000 {
            return String(format: "%.1fB", value / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        }
        return String(format: "%.2f", value)
    }
}

// MARK: - Stat Box
/// Small stat display box for z-score analysis
struct StatBox: View {
    let label: String
    let value: String

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(textPrimary)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(textPrimary.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Asset Impact Row
/// Shows how a macro indicator affects different asset classes
struct AssetImpactRow: View {
    let indicator: String
    let currentValue: Double?
    let impacts: [(asset: String, impact: (signal: String, description: String, color: Color), icon: String)]

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Indicator header
            HStack {
                Text(indicator)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textPrimary)

                if let value = currentValue {
                    Text(indicator == "DXY" ? String(format: "%.1f", value) : String(format: "%.1f", value))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textPrimary.opacity(0.5))
                }

                Spacer()
            }

            // Asset impacts
            HStack(spacing: 16) {
                ForEach(impacts, id: \.asset) { item in
                    HStack(spacing: 8) {
                        // Asset icon
                        ZStack {
                            Circle()
                                .fill(item.impact.color.opacity(0.15))
                                .frame(width: 28, height: 28)

                            if item.asset == "BTC" {
                                Image(systemName: "bitcoinsign")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(item.impact.color)
                            } else {
                                // Gold circle
                                Circle()
                                    .fill(Color(hex: "FFD700"))
                                    .frame(width: 12, height: 12)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(item.asset)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(textPrimary)

                                Text(item.impact.signal)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(item.impact.color)
                            }

                            Text(item.impact.description)
                                .font(.system(size: 9))
                                .foregroundColor(textPrimary.opacity(0.5))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
    }
}

// MARK: - Learn More Row
struct LearnMoreRow: View {
    let color: Color
    let label: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)

            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

// MARK: - Simple Indicator Row
struct SimpleIndicatorRow: View {
    let icon: String
    let title: String
    let value: String
    var change: Double? = nil
    let status: String
    let statusColor: Color
    var isExpanded: Bool = false

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(AppColors.accent)
                .frame(width: 32)

            // Title
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(textPrimary)

            Spacer()

            // Value and change
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 6) {
                    Text(value)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundColor(textPrimary)

                    if let change = change {
                        Text(String(format: "%+.1f%%", change))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
                    }
                }

                Text(status)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(statusColor)
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textPrimary.opacity(0.3))
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
        .padding(14)
    }
}
