import Foundation

// MARK: - API Rainbow Chart Service
/// Calculates Bitcoin Rainbow Chart bands using logarithmic regression
/// Based on the methodology from blockchaincenter.net
final class APIRainbowChartService: RainbowChartServiceProtocol {
    // MARK: - Constants

    /// Bitcoin genesis block date: January 3, 2009
    private let genesisDate: Date = {
        var components = DateComponents()
        components.year = 2009
        components.month = 1
        components.day = 3
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar.current.date(from: components) ?? Date()
    }()

    /// Logarithmic regression coefficients (calibrated to historical BTC data)
    /// These coefficients approximate the blockchaincenter.net rainbow chart
    private let regressionCoefficients: (a: Double, b: Double) = (-17.2, 5.8)

    /// Band multipliers from the baseline regression
    /// Each band is offset by a percentage from the center regression line
    private let bandMultipliers: [RainbowBand: Double] = [
        .fireSale: 0.12,       // -88% from center
        .buyBuy: 0.25,         // -75% from center
        .accumulate: 0.40,     // -60% from center
        .stillCheap: 0.60,     // -40% from center
        .hodl: 0.85,           // -15% from center (baseline)
        .isBubble: 1.2,        // +20% from center
        .fomo: 1.7,            // +70% from center
        .sellSeriously: 2.5,   // +150% from center
        .maxBubble: 4.0        // +300% from center
    ]

    // MARK: - Market Service for Price Data
    private let marketService: MarketServiceProtocol

    init(marketService: MarketServiceProtocol = ServiceContainer.shared.marketService) {
        self.marketService = marketService
    }

    // MARK: - Public Methods

    func fetchCurrentRainbowData(btcPrice: Double) async throws -> RainbowChartData {
        let now = Date()
        let bands = calculateBands(for: now)

        return RainbowChartData(
            date: now,
            currentPrice: btcPrice,
            bands: bands
        )
    }

    func calculateBands(for date: Date) -> RainbowBands {
        let daysSinceGenesis = daysSince(genesisDate, to: date)

        // Calculate baseline regression price
        // log10(price) = a + b * log10(days)
        let logDays = log10(Double(max(1, daysSinceGenesis)))
        let logBasePrice = regressionCoefficients.a + (regressionCoefficients.b * logDays)
        let basePrice = pow(10, logBasePrice)

        // Calculate each band by applying multipliers
        return RainbowBands(
            fireSale: basePrice * (bandMultipliers[.fireSale] ?? 0.12),
            buyBuy: basePrice * (bandMultipliers[.buyBuy] ?? 0.25),
            accumulate: basePrice * (bandMultipliers[.accumulate] ?? 0.40),
            stillCheap: basePrice * (bandMultipliers[.stillCheap] ?? 0.60),
            hodl: basePrice * (bandMultipliers[.hodl] ?? 0.85),
            isBubble: basePrice * (bandMultipliers[.isBubble] ?? 1.2),
            fomo: basePrice * (bandMultipliers[.fomo] ?? 1.7),
            sellSeriously: basePrice * (bandMultipliers[.sellSeriously] ?? 2.5),
            maxBubble: basePrice * (bandMultipliers[.maxBubble] ?? 4.0)
        )
    }

    func fetchRainbowHistory(days: Int) async throws -> [RainbowHistoryPoint] {
        // Fetch historical BTC prices using market chart data
        let chartData = try await marketService.fetchCoinMarketChart(id: "bitcoin", currency: "usd", days: days)

        var history: [RainbowHistoryPoint] = []

        // Process price data from chart
        for pricePoint in chartData.prices {
            let timestamp = pricePoint[0] / 1000 // Convert milliseconds to seconds
            let price = pricePoint[1]
            let date = Date(timeIntervalSince1970: timestamp)

            // Get band for this price and date
            let band = getCurrentBand(btcPrice: price, date: date)

            history.append(RainbowHistoryPoint(
                date: date,
                price: price,
                band: band
            ))
        }

        return history
    }

    func getCurrentBand(btcPrice: Double, date: Date) -> RainbowBand {
        let bands = calculateBands(for: date)

        if btcPrice >= bands.maxBubble {
            return .maxBubble
        } else if btcPrice >= bands.sellSeriously {
            return .sellSeriously
        } else if btcPrice >= bands.fomo {
            return .fomo
        } else if btcPrice >= bands.isBubble {
            return .isBubble
        } else if btcPrice >= bands.hodl {
            return .hodl
        } else if btcPrice >= bands.stillCheap {
            return .stillCheap
        } else if btcPrice >= bands.accumulate {
            return .accumulate
        } else if btcPrice >= bands.buyBuy {
            return .buyBuy
        } else {
            return .fireSale
        }
    }

    // MARK: - Private Helpers

    private func daysSince(_ startDate: Date, to endDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return components.day ?? 0
    }
}
