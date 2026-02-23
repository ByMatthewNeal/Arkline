import SwiftUI

// MARK: - Sentiment Summary Section

/// Compact summary card showing ArkLine Risk Score + Fear & Greed.
/// Taps through to the full MarketSentimentSection via NavigationLink.
struct SentimentSummarySection: View {
    @Bindable var viewModel: SentimentViewModel
    var isPro: Bool = false

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "gauge.with.needle")
                    .foregroundColor(AppColors.accent)
                Text("Market Sentiment")
                    .font(.headline)
                    .foregroundColor(textPrimary)
                Spacer()
            }
            .padding(.horizontal)

            // Summary Card
            NavigationLink {
                SentimentDetailView(
                    viewModel: viewModel,
                    isPro: isPro
                )
            } label: {
                summaryCard
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                // Two key metrics side by side
                HStack(spacing: 20) {
                    // ArkLine Risk Score
                    metricDisplay(
                        label: "Risk Score",
                        value: viewModel.arkLineRiskScore.map { "\($0.score)" } ?? "--",
                        color: viewModel.arkLineRiskScore.map { Color(hex: $0.tier.color) } ?? AppColors.textSecondary,
                        badge: viewModel.arkLineRiskScore?.tier.rawValue
                    )

                    // Divider
                    Rectangle()
                        .fill(AppColors.divider(colorScheme))
                        .frame(width: 1, height: 36)

                    // Fear & Greed
                    metricDisplay(
                        label: "Fear & Greed",
                        value: viewModel.fearGreedIndex.map { "\($0.value)" } ?? "--",
                        color: fearGreedColor,
                        badge: viewModel.fearGreedIndex?.level.rawValue
                    )
                }

                // One-line summary
                Text(sentimentSummaryText)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .padding(.horizontal)
    }

    // MARK: - Metric Display

    private func metricDisplay(label: String, value: String, color: Color, badge: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textSecondary)

            Text(value)
                .font(AppFonts.number24)
                .foregroundColor(textPrimary)

            if let badge {
                Text(badge)
                    .font(AppFonts.footnote10)
                    .foregroundColor(color)
            }
        }
    }

    // MARK: - Helpers

    private var fearGreedColor: Color {
        guard let fg = viewModel.fearGreedIndex else { return AppColors.textSecondary }
        switch fg.value {
        case 0..<25: return AppColors.error
        case 25..<45: return Color(hex: "F97316")
        case 45..<55: return AppColors.warning
        case 55..<75: return Color(hex: "84CC16")
        default: return AppColors.success
        }
    }

    private var sentimentSummaryText: String {
        var parts: [String] = []

        if let score = viewModel.arkLineRiskScore {
            parts.append("\(score.tier.rawValue) risk environment")
        }

        if let fg = viewModel.fearGreedIndex {
            parts.append("market sentiment is \(fg.level.rawValue.lowercased())")
        }

        if parts.isEmpty {
            return "Loading sentiment data..."
        }

        return parts.joined(separator: ", ").prefix(1).uppercased() + parts.joined(separator: ", ").dropFirst()
    }
}
