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

    func fetchAppStoreRankings() async throws -> [AppStoreRanking] {
        try await simulateNetworkDelay()
        return [
            AppStoreRanking(
                id: UUID(),
                appName: "Coinbase",
                ranking: 243,
                change: -12,
                recordedAt: Date()
            ),
            AppStoreRanking(
                id: UUID(),
                appName: "Binance",
                ranking: 89,
                change: 5,
                recordedAt: Date()
            ),
            AppStoreRanking(
                id: UUID(),
                appName: "Kraken",
                ranking: 412,
                change: -28,
                recordedAt: Date()
            ),
            AppStoreRanking(
                id: UUID(),
                appName: "Crypto.com",
                ranking: 156,
                change: 3,
                recordedAt: Date()
            ),
            AppStoreRanking(
                id: UUID(),
                appName: "Robinhood",
                ranking: 42,
                change: -8,
                recordedAt: Date()
            )
        ]
    }

    func fetchArkLineRiskScore() async throws -> ArkLineRiskScore {
        try await simulateNetworkDelay()

        // Calculate composite score from multiple indicators
        let components = [
            RiskScoreComponent(
                name: "Fear & Greed",
                value: 0.49,
                weight: 0.20,
                signal: .neutral
            ),
            RiskScoreComponent(
                name: "App Store Sentiment",
                value: 0.35,
                weight: 0.15,
                signal: .bearish
            ),
            RiskScoreComponent(
                name: "Funding Rates",
                value: 0.62,
                weight: 0.15,
                signal: .bullish
            ),
            RiskScoreComponent(
                name: "ETF Flows",
                value: 0.71,
                weight: 0.15,
                signal: .bullish
            ),
            RiskScoreComponent(
                name: "Liquidation Ratio",
                value: 0.55,
                weight: 0.10,
                signal: .neutral
            ),
            RiskScoreComponent(
                name: "BTC Dominance",
                value: 0.62,
                weight: 0.10,
                signal: .bullish
            ),
            RiskScoreComponent(
                name: "Google Trends",
                value: 0.66,
                weight: 0.15,
                signal: .bullish
            )
        ]

        // Weighted average calculation
        let weightedSum = components.reduce(0.0) { $0 + ($1.value * $1.weight) }
        let score = Int(weightedSum * 100)

        return ArkLineRiskScore(
            score: score,
            tier: SentimentTier.from(score: score),
            components: components,
            recommendation: recommendationFor(score: score),
            timestamp: Date()
        )
    }

    func fetchGoogleTrends() async throws -> GoogleTrendsData {
        try await simulateNetworkDelay()
        return GoogleTrendsData(
            keyword: "Bitcoin",
            currentIndex: 66,
            weekAgoIndex: 58,
            monthAgoIndex: 45,
            trend: .rising,
            timestamp: Date()
        )
    }

    private func recommendationFor(score: Int) -> String {
        switch score {
        case 0...20:
            return "Extreme fear in the market. Historically a good accumulation zone. Consider DCA buying."
        case 21...40:
            return "Market showing fear. Potential buying opportunity with caution."
        case 41...60:
            return "Neutral sentiment. Market in consolidation. Hold positions and monitor."
        case 61...80:
            return "Greed in the market. Consider taking partial profits. Reduce leverage."
        default:
            return "Extreme greed. High risk zone. Consider de-risking portfolio significantly."
        }
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
