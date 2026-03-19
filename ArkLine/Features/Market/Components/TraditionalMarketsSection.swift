import SwiftUI

// MARK: - Traditional Markets Section

/// Combined section for Indexes (S&P 500, Nasdaq) and Precious Metals (Gold, Silver).
/// Signal badges come from the unified QPS pipeline.
struct TraditionalMarketsSection: View {
    let qpsSignals: [DailyPositioningSignal]
    @Environment(\.colorScheme) var colorScheme
    @State private var metals: [MetalAsset] = []
    @State private var isLoadingMetals = true

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

                // Precious Metals
                if isLoadingMetals {
                    ForEach(0..<2, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 16)
                            .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
                            .frame(height: 72)
                            .redacted(reason: .placeholder)
                    }
                } else {
                    ForEach(metals) { metal in
                        let ticker = metal.symbol == "XAU" ? "GOLD" : "SILVER"
                        PreciousMetalCard(metal: metal, qpsSignal: qpsSignal(for: ticker))
                    }
                }
            }
            .padding(.horizontal)
        }
        .task {
            await loadMetals()
        }
    }

    private func loadMetals() async {
        let futuresMap: [(futures: String, symbol: String, name: String)] = [
            ("GCUSD", "XAU", "Gold"),
            ("SIUSD", "XAG", "Silver"),
        ]

        var loaded: [MetalAsset] = []

        for mapping in futuresMap {
            do {
                let quote = try await FMPService.shared.fetchStockQuote(symbol: mapping.futures)
                loaded.append(MetalAsset(
                    id: mapping.symbol.lowercased(),
                    symbol: mapping.symbol,
                    name: mapping.name,
                    currentPrice: quote.price,
                    priceChange24h: quote.change,
                    priceChangePercentage24h: quote.changePercentage,
                    iconUrl: nil,
                    unit: "oz",
                    currency: "USD",
                    timestamp: Date()
                ))
            } catch {
                logWarning("TraditionalMarkets: Failed to fetch \(mapping.futures): \(error.localizedDescription)", category: .network)
            }
        }

        metals = loaded
        isLoadingMetals = false
    }
}
