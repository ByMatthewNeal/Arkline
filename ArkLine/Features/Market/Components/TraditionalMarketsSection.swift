import SwiftUI

// MARK: - Traditional Markets Section

/// Combined section for Indexes (S&P 500, Nasdaq) and Precious Metals (Gold, Silver).
/// Replaces two separate sections with one consolidated view.
struct TraditionalMarketsSection: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var metals: [MetalAsset] = []
    @State private var sma20: [String: Double] = [:]  // symbol → 20-day SMA
    @State private var isLoadingMetals = true

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

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
                IndexWidgetCard(index: .sp500)
                IndexWidgetCard(index: .nasdaq)

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
                        PreciousMetalCard(metal: metal, sma20: sma20[metal.symbol])
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
        var smaMap: [String: Double] = [:]

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

                // Fetch 20-day SMA for trend signal
                if let history = try? await FMPService.shared.fetchHistoricalPrices(symbol: mapping.futures, limit: 20),
                   history.count >= 10 {
                    let avg = history.reduce(0.0) { $0 + $1.close } / Double(history.count)
                    smaMap[mapping.symbol] = avg
                }
            } catch {
                logWarning("TraditionalMarkets: Failed to fetch \(mapping.futures): \(error.localizedDescription)", category: .network)
            }
        }

        metals = loaded
        sma20 = smaMap
        isLoadingMetals = false
    }
}
