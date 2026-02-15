import SwiftUI

// MARK: - Risk Level Info Sheet
struct RiskLevelInfoSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // What is it
                    infoSection(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "What is the Risk Level?",
                        body: "The Risk Level is a score from 0.00 to 1.00 that measures where an asset sits in its market cycle. It uses logarithmic regression on historical price data to determine whether the current price is relatively cheap or expensive compared to its long-term trend."
                    )

                    // How to use it
                    infoSection(
                        icon: "lightbulb",
                        title: "How to Use It",
                        body: """
                        Use the risk level to guide your investment decisions:

                        \u{2022} Low risk (below 0.40) suggests the asset is undervalued relative to its historical trend — a potentially good time to accumulate.

                        \u{2022} Neutral (0.40 - 0.55) means the asset is fairly priced. Neither a strong buy nor sell signal.

                        \u{2022} High risk (above 0.70) indicates the asset may be overheated. Consider taking profits or reducing exposure.
                        """
                    )

                    // Why it matters
                    infoSection(
                        icon: "exclamationmark.shield",
                        title: "Why It Matters",
                        body: "Markets move in cycles. Buying when risk is low and being cautious when risk is high has historically led to better outcomes. This tool helps you avoid buying tops and missing bottoms by providing an objective, data-driven perspective on market conditions."
                    )

                    // Multi-factor
                    infoSection(
                        icon: "slider.horizontal.3",
                        title: "Multi-Factor Analysis",
                        body: "The Multi-Factor Risk score combines multiple on-chain and technical indicators — including logarithmic regression, MVRV ratio, NUPL, and Puell Multiple — to produce a more robust signal than any single metric alone. Each factor is weighted based on its historical reliability."
                    )

                    // Chart interaction
                    infoSection(
                        icon: "hand.tap",
                        title: "Interacting with the Chart",
                        body: "Tap and drag on the chart to explore historical risk levels at specific dates. Use the time range buttons (7D, 30D, 90D, 1Y, All) to zoom in or out. You can also switch between coins using the coin selector at the top."
                    )
                }
                .padding(20)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("About Risk Level")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    private func infoSection(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 28)

                Text(title)
                    .font(.headline)
                    .foregroundColor(textPrimary)
            }

            Text(body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }
}

// MARK: - Confidence Info Popover
/// Explains the data confidence indicator
struct ConfidenceInfoPopover: View {
    let config: AssetRiskConfig
    let colorScheme: ColorScheme

    @State private var adaptiveResult: AdaptiveConfidenceResult?

    private var displayConfidence: Int {
        adaptiveResult?.adaptiveConfidence ?? config.confidenceLevel
    }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var textSecondary: Color {
        AppColors.textSecondary
    }

    private var confidenceDescription: String {
        switch displayConfidence {
        case 9:
            return "Highest confidence. Over 15 years of price data provides excellent regression accuracy."
        case 8:
            return "Very high confidence. Nearly a decade of data ensures reliable fair value estimates."
        case 7:
            return "High confidence. Multiple market cycles covered for solid regression modeling."
        case 6:
            return "Good confidence. Several years of data, though fewer complete cycles than BTC/ETH."
        case 5:
            return "Moderate confidence. Limited historical data may affect accuracy during unusual conditions."
        default:
            return "Lower confidence. Newer asset with limited price history for regression analysis."
        }
    }

    private var yearsOfData: String {
        let days = Calendar.current.dateComponents([.day], from: config.originDate, to: Date()).day ?? 0
        let years = Double(days) / 365.25
        return String(format: "%.1f", years)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.accent)

                Text("Data Confidence")
                    .font(.headline)
                    .foregroundColor(textPrimary)
            }

            Divider()

            // Confidence level visual
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(config.displayName) Confidence:")
                        .font(.subheadline)
                        .foregroundColor(textSecondary)

                    Spacer()

                    Text("\(displayConfidence)/9")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.accent)
                }

                // Confidence bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08))

                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppColors.accent)
                            .frame(width: geometry.size.width * (Double(displayConfidence) / 9.0))
                    }
                }
                .frame(height: 6)
            }

            // Adaptive badge
            if let result = adaptiveResult,
               result.adaptiveConfidence != result.staticConfidence {
                HStack(spacing: 4) {
                    Image(systemName: result.adaptiveConfidence > result.staticConfidence
                          ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 10))
                    Text("Adapted from base \(result.staticConfidence)/9")
                        .font(.caption2)
                }
                .foregroundColor(AppColors.accent.opacity(0.8))
            }

            // Description
            Text(confidenceDescription)
                .font(.caption)
                .foregroundColor(textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // Stats
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Data since:")
                        .font(.caption)
                        .foregroundColor(textSecondary)
                    Spacer()
                    Text(config.originDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(textPrimary)
                }

                HStack {
                    Text("Years of data:")
                        .font(.caption)
                        .foregroundColor(textSecondary)
                    Spacer()
                    Text("\(yearsOfData) years")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(textPrimary)
                }

                if let r2 = adaptiveResult?.rSquared {
                    HStack {
                        Text("R-squared:")
                            .font(.caption)
                            .foregroundColor(textSecondary)
                        Spacer()
                        Text(String(format: "%.4f", r2))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(textPrimary)
                    }
                }

                if let accuracy = adaptiveResult?.predictionAccuracy,
                   let count = adaptiveResult?.validatedPredictionCount {
                    HStack {
                        Text("Prediction accuracy:")
                            .font(.caption)
                            .foregroundColor(textSecondary)
                        Spacer()
                        Text(String(format: "%.0f%% (%d validated)", accuracy * 100, count))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(textPrimary)
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: 280)
        .background(colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white)
        .task {
            adaptiveResult = await ConfidenceTracker.shared
                .computeAdaptiveConfidence(for: config.assetId)
        }
    }
}

// MARK: - Risk Level Legend Row
struct RiskLevelLegendRow: View {
    let range: String
    let category: String
    let description: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack(alignment: .top, spacing: ArkSpacing.sm) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: ArkSpacing.xs) {
                    Text(category)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(color)

                    Text("(\(range))")
                        .font(.caption)
                        .foregroundColor(textPrimary.opacity(0.5))
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(textPrimary.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.vertical, ArkSpacing.xs)
    }
}

// MARK: - Legacy ITCRiskDetailView (for backward compatibility)
struct ITCRiskDetailView: View {
    let riskLevel: ITCRiskLevel
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    var body: some View {
        ITCRiskChartView()
    }
}
