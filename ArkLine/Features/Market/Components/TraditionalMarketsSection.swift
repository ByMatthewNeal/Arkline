import SwiftUI

// MARK: - Traditional Markets Section

/// Combined section for Indexes (S&P 500, Nasdaq) and Precious Metals (Gold, Silver).
/// Signal badges come from the unified QPS pipeline.
struct TraditionalMarketsSection: View {
    let qpsSignals: [DailyPositioningSignal]
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    /// Look up QPS signal for a given ticker
    private func qpsSignal(for ticker: String) -> PositioningSignal? {
        qpsSignals.first(where: { $0.asset == ticker })?.positioningSignal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(AppColors.accent)
                Text("Traditional Markets")
                    .font(.headline)
                    .foregroundColor(textPrimary)
                Spacer()
            }
            .padding(.horizontal)

            VStack(spacing: 10) {
                // Indexes
                IndexWidgetCard(index: .sp500, qpsSignal: qpsSignal(for: "SPY"))
                IndexWidgetCard(index: .nasdaq, qpsSignal: qpsSignal(for: "QQQ"))

                // Precious Metals (with trend channel analysis)
                IndexWidgetCard(index: .gold, qpsSignal: qpsSignal(for: "GOLD"))
                IndexWidgetCard(index: .silver, qpsSignal: qpsSignal(for: "SILVER"))
            }
            .padding(.horizontal)
        }
    }

}
