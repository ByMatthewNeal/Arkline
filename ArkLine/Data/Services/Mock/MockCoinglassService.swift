import Foundation

// MARK: - Mock Coinglass Service
/// Mock implementation of CoinglassServiceProtocol for development and testing.
final class MockCoinglassService: CoinglassServiceProtocol {
    // MARK: - Configuration
    var simulatedDelay: UInt64 = 300_000_000 // 300ms

    // MARK: - Open Interest

    func fetchOpenInterest(symbol: String) async throws -> OpenInterestData {
        try await simulateNetworkDelay()
        return generateMockOpenInterest(symbol: symbol)
    }

    func fetchOpenInterestMultiple(symbols: [String]) async throws -> [OpenInterestData] {
        try await simulateNetworkDelay()
        return symbols.map { generateMockOpenInterest(symbol: $0) }
    }

    func fetchTotalMarketOI() async throws -> Double {
        try await simulateNetworkDelay()
        // Total crypto derivatives OI ~$80-120B typically
        return 98_500_000_000
    }

    // MARK: - Liquidations

    func fetchLiquidations(symbol: String) async throws -> CoinglassLiquidationData {
        try await simulateNetworkDelay()
        return generateMockLiquidations(symbol: symbol)
    }

    func fetchTotalLiquidations() async throws -> CoinglassLiquidationData {
        try await simulateNetworkDelay()
        return CoinglassLiquidationData(
            id: UUID(),
            symbol: "ALL",
            longLiquidations24h: 145_000_000,
            shortLiquidations24h: 98_000_000,
            totalLiquidations24h: 243_000_000,
            largestLiquidation: LiquidationEvent(
                id: UUID(),
                symbol: "BTC",
                exchange: "Binance",
                side: .long,
                amount: 8_500_000,
                price: 67_250,
                timestamp: Date().addingTimeInterval(-3600)
            ),
            timestamp: Date()
        )
    }

    func fetchRecentLiquidations(symbol: String?, limit: Int) async throws -> [LiquidationEvent] {
        try await simulateNetworkDelay()
        return generateMockLiquidationEvents(symbol: symbol, limit: limit)
    }

    // MARK: - Funding Rates

    func fetchFundingRate(symbol: String) async throws -> CoinglassFundingRateData {
        try await simulateNetworkDelay()
        return generateMockFundingRate(symbol: symbol)
    }

    func fetchFundingRatesMultiple(symbols: [String]) async throws -> [CoinglassFundingRateData] {
        try await simulateNetworkDelay()
        return symbols.map { generateMockFundingRate(symbol: $0) }
    }

    func fetchWeightedFundingRate(symbol: String) async throws -> Double {
        try await simulateNetworkDelay()
        return symbol == "BTC" ? 0.0082 : 0.0095
    }

    // MARK: - Long/Short Ratios

    func fetchLongShortRatio(symbol: String) async throws -> LongShortRatioData {
        try await simulateNetworkDelay()
        return generateMockLongShortRatio(symbol: symbol)
    }

    func fetchTopTraderRatio(symbol: String) async throws -> LongShortRatioData {
        try await simulateNetworkDelay()
        let ratio = generateMockLongShortRatio(symbol: symbol)
        // Top traders often have slightly different positioning
        return LongShortRatioData(
            id: UUID(),
            symbol: symbol,
            longRatio: 0.58,
            shortRatio: 0.42,
            longShortRatio: 1.38,
            topTraderLongRatio: 0.58,
            topTraderShortRatio: 0.42,
            timestamp: Date(),
            exchangeRatios: ratio.exchangeRatios
        )
    }

    // MARK: - Aggregated Overview

    func fetchDerivativesOverview() async throws -> DerivativesOverview {
        try await simulateNetworkDelay()

        return DerivativesOverview(
            btcOpenInterest: generateMockOpenInterest(symbol: "BTC"),
            ethOpenInterest: generateMockOpenInterest(symbol: "ETH"),
            totalMarketOI: 98_500_000_000,
            totalLiquidations24h: CoinglassLiquidationData(
                id: UUID(),
                symbol: "ALL",
                longLiquidations24h: 145_000_000,
                shortLiquidations24h: 98_000_000,
                totalLiquidations24h: 243_000_000,
                largestLiquidation: nil,
                timestamp: Date()
            ),
            btcFundingRate: generateMockFundingRate(symbol: "BTC"),
            ethFundingRate: generateMockFundingRate(symbol: "ETH"),
            btcLongShortRatio: generateMockLongShortRatio(symbol: "BTC"),
            ethLongShortRatio: generateMockLongShortRatio(symbol: "ETH"),
            lastUpdated: Date()
        )
    }

    // MARK: - Private Helpers

    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: simulatedDelay)
    }

    private func generateMockOpenInterest(symbol: String) -> OpenInterestData {
        let baseOI: Double
        let change: Double
        let changePercent: Double

        switch symbol.uppercased() {
        case "BTC":
            baseOI = 38_500_000_000      // ~$38.5B BTC OI
            change = 1_250_000_000        // +$1.25B
            changePercent = 3.35
        case "ETH":
            baseOI = 14_200_000_000       // ~$14.2B ETH OI
            change = -420_000_000         // -$420M
            changePercent = -2.87
        case "SOL":
            baseOI = 3_800_000_000        // ~$3.8B SOL OI
            change = 180_000_000
            changePercent = 4.97
        case "XRP":
            baseOI = 1_200_000_000
            change = 45_000_000
            changePercent = 3.89
        default:
            baseOI = 500_000_000
            change = Double.random(in: -50_000_000...50_000_000)
            changePercent = (change / baseOI) * 100
        }

        return OpenInterestData(
            id: UUID(),
            symbol: symbol.uppercased(),
            openInterest: baseOI,
            openInterestChange24h: change,
            openInterestChangePercent24h: changePercent,
            timestamp: Date(),
            exchangeBreakdown: [
                ExchangeOI(exchange: "Binance", openInterest: baseOI * 0.35, percentage: 35),
                ExchangeOI(exchange: "Bybit", openInterest: baseOI * 0.22, percentage: 22),
                ExchangeOI(exchange: "OKX", openInterest: baseOI * 0.18, percentage: 18),
                ExchangeOI(exchange: "Bitget", openInterest: baseOI * 0.12, percentage: 12),
                ExchangeOI(exchange: "dYdX", openInterest: baseOI * 0.08, percentage: 8),
                ExchangeOI(exchange: "Others", openInterest: baseOI * 0.05, percentage: 5)
            ]
        )
    }

    private func generateMockLiquidations(symbol: String) -> CoinglassLiquidationData {
        let totalLiqs: Double
        let longPct: Double

        switch symbol.uppercased() {
        case "BTC":
            totalLiqs = 85_000_000    // $85M BTC liquidations
            longPct = 0.62            // 62% longs liquidated (market moved down)
        case "ETH":
            totalLiqs = 42_000_000
            longPct = 0.58
        case "SOL":
            totalLiqs = 18_000_000
            longPct = 0.45            // More shorts liquidated (market moved up)
        default:
            totalLiqs = 5_000_000
            longPct = 0.52
        }

        let longLiqs = totalLiqs * longPct
        let shortLiqs = totalLiqs * (1 - longPct)

        return CoinglassLiquidationData(
            id: UUID(),
            symbol: symbol.uppercased(),
            longLiquidations24h: longLiqs,
            shortLiquidations24h: shortLiqs,
            totalLiquidations24h: totalLiqs,
            largestLiquidation: LiquidationEvent(
                id: UUID(),
                symbol: symbol.uppercased(),
                exchange: "Binance",
                side: longPct > 0.5 ? .long : .short,
                amount: totalLiqs * 0.05, // Largest is ~5% of total
                price: symbol == "BTC" ? 67_250 : (symbol == "ETH" ? 3_450 : 185),
                timestamp: Date().addingTimeInterval(-1800)
            ),
            timestamp: Date()
        )
    }

    private func generateMockLiquidationEvents(symbol: String?, limit: Int) -> [LiquidationEvent] {
        let symbols = symbol != nil ? [symbol!] : ["BTC", "ETH", "SOL", "XRP", "DOGE"]
        let exchanges = ["Binance", "Bybit", "OKX", "Bitget", "dYdX"]

        return (0..<limit).map { i in
            let sym = symbols[i % symbols.count]
            let price: Double
            switch sym {
            case "BTC": price = Double.random(in: 65_000...70_000)
            case "ETH": price = Double.random(in: 3_300...3_600)
            case "SOL": price = Double.random(in: 170...200)
            case "XRP": price = Double.random(in: 0.50...0.70)
            default: price = Double.random(in: 0.05...0.15)
            }

            return LiquidationEvent(
                id: UUID(),
                symbol: sym,
                exchange: exchanges[i % exchanges.count],
                side: Bool.random() ? .long : .short,
                amount: Double.random(in: 50_000...2_000_000),
                price: price,
                timestamp: Date().addingTimeInterval(Double(-i * 300)) // Every 5 min
            )
        }
    }

    private func generateMockFundingRate(symbol: String) -> CoinglassFundingRateData {
        let rate: Double
        let annualized: Double

        switch symbol.uppercased() {
        case "BTC":
            rate = 0.0082              // 0.0082% per 8 hours
            annualized = rate * 3 * 365 // ~8.97% annualized
        case "ETH":
            rate = 0.0095
            annualized = rate * 3 * 365
        case "SOL":
            rate = 0.0156              // Higher funding = more bullish
            annualized = rate * 3 * 365
        case "XRP":
            rate = -0.0045             // Negative = shorts paying longs
            annualized = rate * 3 * 365
        default:
            rate = Double.random(in: -0.01...0.02)
            annualized = rate * 3 * 365
        }

        let nextFunding = Calendar.current.date(byAdding: .hour, value: Int.random(in: 1...8), to: Date())

        return CoinglassFundingRateData(
            id: UUID(),
            symbol: symbol.uppercased(),
            fundingRate: rate,
            predictedRate: rate + Double.random(in: -0.002...0.002),
            nextFundingTime: nextFunding,
            annualizedRate: annualized,
            timestamp: Date(),
            exchangeRates: [
                CoinglassExchangeFundingRate(exchange: "Binance", fundingRate: rate * 0.98, nextFundingTime: nextFunding),
                CoinglassExchangeFundingRate(exchange: "Bybit", fundingRate: rate * 1.02, nextFundingTime: nextFunding),
                CoinglassExchangeFundingRate(exchange: "OKX", fundingRate: rate * 0.95, nextFundingTime: nextFunding),
                CoinglassExchangeFundingRate(exchange: "Bitget", fundingRate: rate * 1.05, nextFundingTime: nextFunding),
                CoinglassExchangeFundingRate(exchange: "dYdX", fundingRate: rate * 0.92, nextFundingTime: nextFunding)
            ]
        )
    }

    private func generateMockLongShortRatio(symbol: String) -> LongShortRatioData {
        let longRatio: Double
        let shortRatio: Double

        switch symbol.uppercased() {
        case "BTC":
            longRatio = 0.52           // 52% long
            shortRatio = 0.48
        case "ETH":
            longRatio = 0.54
            shortRatio = 0.46
        case "SOL":
            longRatio = 0.58           // More bullish sentiment
            shortRatio = 0.42
        case "XRP":
            longRatio = 0.48           // Slightly bearish
            shortRatio = 0.52
        default:
            longRatio = Double.random(in: 0.45...0.55)
            shortRatio = 1 - longRatio
        }

        return LongShortRatioData(
            id: UUID(),
            symbol: symbol.uppercased(),
            longRatio: longRatio,
            shortRatio: shortRatio,
            longShortRatio: longRatio / shortRatio,
            topTraderLongRatio: longRatio + 0.05,
            topTraderShortRatio: shortRatio - 0.05,
            timestamp: Date(),
            exchangeRatios: [
                ExchangeLongShortRatio(exchange: "Binance", longRatio: longRatio * 0.98, shortRatio: shortRatio * 1.02, longShortRatio: (longRatio * 0.98) / (shortRatio * 1.02)),
                ExchangeLongShortRatio(exchange: "Bybit", longRatio: longRatio * 1.02, shortRatio: shortRatio * 0.98, longShortRatio: (longRatio * 1.02) / (shortRatio * 0.98)),
                ExchangeLongShortRatio(exchange: "OKX", longRatio: longRatio * 0.95, shortRatio: shortRatio * 1.05, longShortRatio: (longRatio * 0.95) / (shortRatio * 1.05)),
                ExchangeLongShortRatio(exchange: "Bitget", longRatio: longRatio * 1.03, shortRatio: shortRatio * 0.97, longShortRatio: (longRatio * 1.03) / (shortRatio * 0.97))
            ]
        )
    }
}
