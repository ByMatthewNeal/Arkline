import SwiftUI

// MARK: - Risk Factor Breakdown View
/// Displays the 6 risk factors with their raw values, normalized values, and weights.
struct RiskFactorBreakdownView: View {
    let multiFactorRisk: MultiFactorRiskPoint
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var textSecondary: Color {
        AppColors.textSecondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            // Header
            HStack {
                Text("Risk Factor Breakdown")
                    .font(.headline)
                    .foregroundColor(textPrimary)

                Spacer()

                // Factor availability badge
                Text("\(multiFactorRisk.availableFactorCount)/\(RiskFactorType.allCases.count) factors")
                    .font(.caption)
                    .foregroundColor(textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                    )
            }

            // Composite score
            HStack(spacing: ArkSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Composite Risk")
                        .font(.caption)
                        .foregroundColor(textSecondary)
                    Text(String(format: "%.3f", multiFactorRisk.riskLevel))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(RiskColors.color(for: multiFactorRisk.riskLevel))
                }

                Spacer()

                // Mini gauge
                ZStack {
                    Circle()
                        .stroke(
                            colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08),
                            lineWidth: 6
                        )
                        .frame(width: 50, height: 50)

                    Circle()
                        .trim(from: 0, to: multiFactorRisk.riskLevel)
                        .stroke(
                            RiskColors.color(for: multiFactorRisk.riskLevel),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                }
            }
            .padding(ArkSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: ArkSpacing.Radius.md)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.02))
            )

            // Factor rows
            VStack(spacing: ArkSpacing.sm) {
                ForEach(multiFactorRisk.factors, id: \.type) { factor in
                    RiskFactorRow(factor: factor)
                }
            }

            // Formula explanation
            VStack(alignment: .leading, spacing: 4) {
                Text("Calculation Method")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(textSecondary)

                Text("Weighted average of normalized factors. Unavailable factors have their weights redistributed proportionally.")
                    .font(.caption2)
                    .foregroundColor(textSecondary.opacity(0.8))
            }
            .padding(.top, ArkSpacing.xs)
        }
        .padding(ArkSpacing.md)
        .glassCard(cornerRadius: ArkSpacing.Radius.lg)
    }
}

// MARK: - Risk Factor Row
struct RiskFactorRow: View {
    let factor: RiskFactor
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var textSecondary: Color {
        AppColors.textSecondary
    }

    private var factorColor: Color {
        guard let normalized = factor.normalizedValue else {
            return textSecondary.opacity(0.3)
        }
        return RiskColors.color(for: normalized)
    }

    private var weightPercentage: String {
        String(format: "%.0f%%", factor.weight * 100)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                // Icon and name
                HStack(spacing: 8) {
                    Image(systemName: factor.type.icon)
                        .font(.system(size: 14))
                        .foregroundColor(factor.isAvailable ? factorColor : textSecondary.opacity(0.3))
                        .frame(width: 20)

                    Text(factor.type.rawValue)
                        .font(.subheadline)
                        .foregroundColor(factor.isAvailable ? textPrimary : textSecondary.opacity(0.5))
                }

                Spacer()

                // Weight
                Text(weightPercentage)
                    .font(.caption)
                    .foregroundColor(textSecondary)
                    .frame(width: 35, alignment: .trailing)

                // Value
                if factor.isAvailable {
                    Text(factor.normalizedValueDisplay)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(factorColor)
                        .frame(width: 45, alignment: .trailing)
                } else {
                    Text("N/A")
                        .font(.caption)
                        .foregroundColor(textSecondary.opacity(0.5))
                        .frame(width: 45, alignment: .trailing)
                }
            }

            // Progress bar showing contribution
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))

                    // Filled portion
                    if let normalized = factor.normalizedValue {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [factorColor.opacity(0.6), factorColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * normalized)
                    }
                }
            }
            .frame(height: 4)

            // Raw value subtitle
            if factor.isAvailable {
                HStack {
                    Text(factor.rawValueDisplay)
                        .font(.caption2)
                        .foregroundColor(textSecondary.opacity(0.7))

                    Spacer()
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(factor.isAvailable
                    ? (colorScheme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.02))
                    : Color.clear
                )
        )
    }
}

// MARK: - Compact Factor Summary
/// Compact view showing just the factor icons and availability
struct RiskFactorSummaryRow: View {
    let multiFactorRisk: MultiFactorRiskPoint
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            ForEach(multiFactorRisk.factors, id: \.type) { factor in
                VStack(spacing: 4) {
                    Image(systemName: factor.type.icon)
                        .font(.system(size: 12))
                        .foregroundColor(
                            factor.isAvailable
                                ? RiskColors.color(for: factor.normalizedValue ?? 0.5)
                                : AppColors.textSecondary.opacity(0.3)
                        )

                    if factor.isAvailable, let normalized = factor.normalizedValue {
                        // Tiny indicator dot
                        Circle()
                            .fill(RiskColors.color(for: normalized))
                            .frame(width: 4, height: 4)
                    } else {
                        Circle()
                            .stroke(AppColors.textSecondary.opacity(0.3), lineWidth: 1)
                            .frame(width: 4, height: 4)
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview("Risk Factor Breakdown") {
    let mockFactors: [RiskFactor] = [
        RiskFactor(type: .logRegression, rawValue: 0.15, normalizedValue: 0.48, weight: 0.40),
        RiskFactor(type: .rsi, rawValue: 58.0, normalizedValue: 0.70, weight: 0.15),
        RiskFactor(type: .smaPosition, rawValue: 0.3, normalizedValue: 0.30, weight: 0.15),
        RiskFactor(type: .fundingRate, rawValue: 0.0003, normalizedValue: 0.65, weight: 0.10),
        RiskFactor(type: .fearGreed, rawValue: 62.0, normalizedValue: 0.62, weight: 0.10),
        RiskFactor(type: .macroRisk, rawValue: 22.5, normalizedValue: 0.45, weight: 0.10)
    ]

    let mockRisk = MultiFactorRiskPoint(
        date: Date(),
        riskLevel: 0.52,
        price: 97500,
        fairValue: 85000,
        deviation: 0.06,
        factors: mockFactors
    )

    ScrollView {
        RiskFactorBreakdownView(multiFactorRisk: mockRisk)
            .padding()
    }
    .background(Color(hex: "0F0F0F"))
}

#Preview("Risk Factor Breakdown - Some Unavailable") {
    let mockFactors: [RiskFactor] = [
        RiskFactor(type: .logRegression, rawValue: 0.15, normalizedValue: 0.48, weight: 0.40),
        RiskFactor(type: .rsi, rawValue: 58.0, normalizedValue: 0.70, weight: 0.15),
        RiskFactor.unavailable(.smaPosition, weight: 0.15),
        RiskFactor.unavailable(.fundingRate, weight: 0.10),
        RiskFactor(type: .fearGreed, rawValue: 62.0, normalizedValue: 0.62, weight: 0.10),
        RiskFactor.unavailable(.macroRisk, weight: 0.10)
    ]

    let mockRisk = MultiFactorRiskPoint(
        date: Date(),
        riskLevel: 0.55,
        price: 97500,
        fairValue: 85000,
        deviation: 0.06,
        factors: mockFactors
    )

    ScrollView {
        RiskFactorBreakdownView(multiFactorRisk: mockRisk)
            .padding()
    }
    .background(Color(hex: "0F0F0F"))
}
