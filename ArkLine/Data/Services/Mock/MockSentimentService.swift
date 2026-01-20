import Foundation

// MARK: - Mock Sentiment Service
/// Mock implementation of SentimentServiceProtocol for development and testing.
final class MockSentimentService: SentimentServiceProtocol {
    // MARK: - Configuration
    var simulatedDelay: UInt64 = 300_000_000

    // MARK: - SentimentServiceProtocol

    func fetchFearGreedIndex() async throws -> FearGreedIndex {
        try await simulateNetworkDelay()
        return FearGreedIndex(
            value: 49,
            classification: "Neutral",
            timestamp: Date(),
            previousClose: 52,
            weekAgo: 45,
            monthAgo: 38
        )
    }

    func fetchFearGreedHistory(days: Int) async throws -> [FearGreedIndex] {
        try await simulateNetworkDelay()
        var history: [FearGreedIndex] = []
        let calendar = Calendar.current

        for i in 0..<days {
            let date = calendar.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            let value = Int.random(in: 25...75)
            history.append(FearGreedIndex(
                value: value,
                classification: classificationFor(value: value),
                timestamp: date
            ))
        }

        return history.reversed()
    }

    func fetchBTCDominance() async throws -> BTCDominance {
        try await simulateNetworkDelay()
        return BTCDominance(
            value: 61.9,
            change24h: 0.35,
            timestamp: Date()
        )
    }

    func fetchETFNetFlow() async throws -> ETFNetFlow {
        try await simulateNetworkDelay()
        return ETFNetFlow(
            totalNetFlow: 58_000_000_000,
            dailyNetFlow: 667_000_000,
            etfData: [
                ETFData(ticker: "IBIT", name: "BlackRock iShares", netFlow: 125_000_000, aum: 21_000_000_000),
                ETFData(ticker: "FBTC", name: "Fidelity", netFlow: 85_000_000, aum: 12_500_000_000),
                ETFData(ticker: "GBTC", name: "Grayscale", netFlow: -45_000_000, aum: 15_000_000_000),
                ETFData(ticker: "ARKB", name: "ARK 21Shares", netFlow: 42_000_000, aum: 3_200_000_000)
            ],
            timestamp: Date()
        )
    }

    func fetchFundingRate() async throws -> FundingRate {
        try await simulateNetworkDelay()
        return FundingRate(
            averageRate: 0.008272,
            exchanges: [
                ExchangeFundingRate(exchange: "Binance", rate: 0.0085, nextFundingTime: Date().addingTimeInterval(3600)),
                ExchangeFundingRate(exchange: "Bybit", rate: 0.0081, nextFundingTime: Date().addingTimeInterval(3600)),
                ExchangeFundingRate(exchange: "OKX", rate: 0.0082, nextFundingTime: Date().addingTimeInterval(3600))
            ],
            timestamp: Date()
        )
    }

    func fetchLiquidations() async throws -> LiquidationData {
        try await simulateNetworkDelay()
        return LiquidationData(
            total24h: 125_000_000,
            longLiquidations: 85_000_000,
            shortLiquidations: 40_000_000,
            largestSingleLiquidation: 5_200_000,
            timestamp: Date()
        )
    }

    func fetchAltcoinSeason() async throws -> AltcoinSeasonIndex {
        try await simulateNetworkDelay()
        return AltcoinSeasonIndex(
            value: 24,
            isBitcoinSeason: true,
            timestamp: Date()
        )
    }

    func fetchRiskLevel() async throws -> RiskLevel {
        try await simulateNetworkDelay()
        return RiskLevel(
            level: 6,
            indicators: [
                RiskIndicator(name: "Volatility", value: 0.571, weight: 0.3, contribution: 0.17),
                RiskIndicator(name: "Market Momentum", value: 0.65, weight: 0.25, contribution: 0.16),
                RiskIndicator(name: "Leverage Ratio", value: 0.48, weight: 0.25, contribution: 0.12),
                RiskIndicator(name: "Sentiment", value: 0.55, weight: 0.2, contribution: 0.11)
            ],
            recommendation: "Moderate risk - consider balanced positions",
            timestamp: Date()
        )
    }

    func fetchGlobalLiquidity() async throws -> GlobalLiquidity {
        try await simulateNetworkDelay()
        return GlobalLiquidity(
            totalLiquidity: 95_000_000_000_000,
            weeklyChange: 0.8,
            monthlyChange: 2.3,
            yearlyChange: 5.2,
            components: [
                LiquidityComponent(name: "Fed", value: 7_500_000_000_000, change: 0.2),
                LiquidityComponent(name: "ECB", value: 5_200_000_000_000, change: -0.1),
                LiquidityComponent(name: "BoJ", value: 4_800_000_000_000, change: 0.5),
                LiquidityComponent(name: "PBoC", value: 6_100_000_000_000, change: 0.3)
            ],
            timestamp: Date()
        )
    }

    func fetchAppStoreRanking() async throws -> AppStoreRanking {
        try await simulateNetworkDelay()
        return AppStoreRanking(
            id: UUID(),
            appName: "Coinbase",
            ranking: 243,
            change: -12,
            recordedAt: Date()
        )
    }

    func fetchMarketOverview() async throws -> MarketOverview {
        async let fg = fetchFearGreedIndex()
        async let btc = fetchBTCDominance()
        async let alt = fetchAltcoinSeason()

        let (fearGreed, btcDominance, altcoinSeason) = try await (fg, btc, alt)

        return MarketOverview(
            fearGreed: fearGreed,
            btcDominance: btcDominance,
            altcoinSeason: altcoinSeason,
            totalMarketCap: 3_320_000_000_000,
            marketCapChange24h: 2.29,
            totalVolume24h: 98_500_000_000,
            btcPrice: 67234.50,
            ethPrice: 3456.78,
            timestamp: Date()
        )
    }

    // MARK: - Private Helpers

    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: simulatedDelay)
    }

    private func classificationFor(value: Int) -> String {
        switch value {
        case 0...24: return "Extreme Fear"
        case 25...44: return "Fear"
        case 45...55: return "Neutral"
        case 56...75: return "Greed"
        default: return "Extreme Greed"
        }
    }
}
