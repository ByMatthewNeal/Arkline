import SwiftUI

// MARK: - Risk Gauge
/// Circular gauge showing the risk level with gradient coloring
struct RiskGauge: View {
    let riskLevel: Double
    let size: CGFloat
    let strokeWidth: CGFloat
    let colorScheme: ColorScheme

    private var normalizedValue: Double {
        min(max(riskLevel, 0), 1)
    }

    private var riskColor: Color {
        RiskColors.color(for: riskLevel)
    }

    private var riskColorLight: Color {
        riskColor.opacity(0.6)
    }

    private var displayValue: String {
        String(format: "%.2f", riskLevel)
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.08),
                    lineWidth: strokeWidth
                )
                .frame(width: size, height: size)

            // Progress ring with gradient
            Circle()
                .trim(from: 0, to: normalizedValue)
                .stroke(
                    LinearGradient(
                        colors: [riskColorLight, riskColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            // Subtle glow effect
            Circle()
                .fill(riskColor.opacity(0.2))
                .blur(radius: size * 0.15)
                .frame(width: size * 0.6, height: size * 0.6)

            // Risk level value (0.00 - 1.00 format)
            Text(displayValue)
                .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Risk gauge, \(displayValue)")
        .accessibilityAddTraits(.isImage)
    }
}

// Legacy alias
typealias ITCRiskGauge = RiskGauge

// MARK: - Compact Risk Gauge
struct CompactRiskGauge: View {
    let riskLevel: Double
    let colorScheme: ColorScheme

    private var normalizedValue: Double {
        min(max(riskLevel, 0), 1)
    }

    private var riskColor: Color {
        RiskColors.color(for: riskLevel)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.08),
                    lineWidth: 6
                )
                .frame(width: 50, height: 50)

            Circle()
                .trim(from: 0, to: normalizedValue)
                .stroke(riskColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(-90))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Risk gauge, \(String(format: "%.2f", riskLevel))")
        .accessibilityAddTraits(.isImage)
    }
}

// Legacy alias
typealias CompactITCGauge = CompactRiskGauge

// MARK: - Compact Risk Card (for Market Sentiment Grid)
struct RiskCard: View {
    let riskLevel: ITCRiskLevel
    let coinSymbol: String
    var daysAtLevel: Int? = nil
    @Environment(\.colorScheme) var colorScheme
    @State private var showingDetail = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(coinSymbol) Risk Level")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.accent)
                }

                Spacer()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        // Value (3 decimal places)
                        Text(String(format: "%.3f", riskLevel.riskLevel))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(RiskColors.color(for: riskLevel.riskLevel))

                        // Category with dot
                        HStack(spacing: 4) {
                            Circle()
                                .fill(RiskColors.color(for: riskLevel.riskLevel))
                                .frame(width: 6, height: 6)

                            Text(RiskColors.category(for: riskLevel.riskLevel))
                                .font(.caption2)
                                .foregroundColor(RiskColors.color(for: riskLevel.riskLevel))
                        }

                        if let days = daysAtLevel {
                            Text("\(days) day\(days == 1 ? "" : "s") at this level")
                                .font(.system(size: 9))
                                .foregroundColor(textPrimary.opacity(0.5))
                        }
                    }

                    Spacer()

                    // Mini gauge
                    CompactRiskGauge(riskLevel: riskLevel.riskLevel, colorScheme: colorScheme)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 120)
            .glassCard(cornerRadius: 16)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            RiskLevelChartView(initialCoin: RiskCoin(rawValue: coinSymbol) ?? .btc)
        }
    }
}

// Legacy alias
typealias ITCRiskCard = RiskCard
