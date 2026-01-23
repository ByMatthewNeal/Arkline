import Foundation

// MARK: - Mock Rainbow Chart Service
final class MockRainbowChartService: RainbowChartServiceProtocol {
    // MARK: - Constants

    private let genesisDate: Date = {
        var components = DateComponents()
        components.year = 2009
        components.month = 1
        components.day = 3
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar.current.date(from: components) ?? Date()
    }()

    private let regressionCoefficients: (a: Double, b: Double) = (-17.2, 5.8)

    private let bandMultipliers: [RainbowBand: Double] = [
        .fireSale: 0.12,
        .buyBuy: 0.25,
        .accumulate: 0.40,
        .stillCheap: 0.60,
        .hodl: 0.85,
        .isBubble: 1.2,
        .fomo: 1.7,
        .sellSeriously: 2.5,
        .maxBubble: 4.0
    ]

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

        let logDays = log10(Double(max(1, daysSinceGenesis)))
        let logBasePrice = regressionCoefficients.a + (regressionCoefficients.b * logDays)
        let basePrice = pow(10, logBasePrice)

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
        // Generate mock historical data
        var history: [RainbowHistoryPoint] = []
        let calendar = Calendar.current
        let now = Date()

        // Mock BTC price range for simulation
        let basePrice = 104000.0
        let priceVariation = 20000.0

        for daysAgo in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) else { continue }

            // Simulate price movement with some noise
            let cyclicComponent = sin(Double(daysAgo) * 0.1) * priceVariation * 0.5
            let trendComponent = Double(days - daysAgo) / Double(days) * priceVariation * 0.3
            let price = basePrice + cyclicComponent + trendComponent + Double.random(in: -5000...5000)

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
