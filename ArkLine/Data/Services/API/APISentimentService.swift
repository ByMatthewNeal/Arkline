import Foundation

// MARK: - API Sentiment Service
/// Real API implementation of SentimentServiceProtocol.
/// Uses various APIs for sentiment data.
final class APISentimentService: SentimentServiceProtocol {
    // MARK: - Dependencies
    private let networkManager = NetworkManager.shared
    private let cache = APICache.shared

    // MARK: - SentimentServiceProtocol

    func fetchFearGreedIndex() async throws -> FearGreedIndex {
        return try await cache.getOrFetch(CacheKey.fearGreedIndex, ttl: APICache.TTL.medium) {
            let endpoint = FearGreedEndpoint.current
            let response: FearGreedAPIResponse = try await networkManager.request(endpoint)

            guard let data = response.data.first else {
                throw AppError.invalidResponse
            }

            return FearGreedIndex(
                value: Int(data.value) ?? 50,
                classification: data.valueClassification,
                timestamp: Date(timeIntervalSince1970: TimeInterval(data.timestamp) ?? Date().timeIntervalSince1970)
            )
        }
    }

    func fetchFearGreedHistory(days: Int) async throws -> [FearGreedIndex] {
        let cacheKey = "fear_greed_history_\(days)"
        return try await cache.getOrFetch(cacheKey, ttl: APICache.TTL.long) {
            let endpoint = FearGreedEndpoint.historical(days: days)
            let response: FearGreedAPIResponse = try await networkManager.request(endpoint)

            return response.data.map { data in
                FearGreedIndex(
                    value: Int(data.value) ?? 50,
                    classification: data.valueClassification,
                    timestamp: Date(timeIntervalSince1970: TimeInterval(data.timestamp) ?? Date().timeIntervalSince1970)
                )
            }
        }
    }

    func fetchBTCDominance() async throws -> BTCDominance {
        return try await cache.getOrFetch(CacheKey.btcDominance, ttl: APICache.TTL.medium) {
            // Use CoinGecko global data for BTC dominance
            let endpoint = CoinGeckoEndpoint.globalData
            let response: CoinGeckoGlobalData = try await networkManager.request(endpoint)

            let dominance = response.data.marketCapPercentage["btc"] ?? 0

            return BTCDominance(
                value: dominance,
                change24h: 0, // Would need historical data to calculate
                timestamp: Date()
            )
        }
    }

    func fetchETFNetFlow() async throws -> ETFNetFlow {
        // Scrape ETF net flow data from Farside Investors
        let scraper = FarsideETFScraper()
        return try await scraper.fetchETFNetFlow()
    }

    func fetchFundingRate() async throws -> FundingRate {
        // Use Binance Futures API for funding rate (free, no API key needed)
        let binanceService = APIBinanceFundingService()

        // Fetch BTC and ETH funding rates
        async let btcRate = binanceService.fetchPremiumIndex(symbol: "BTC")
        async let ethRate = binanceService.fetchPremiumIndex(symbol: "ETH")

        let (btc, eth) = try await (btcRate, ethRate)

        // Average rate across BTC and ETH
        let avgRate = (btc.lastFundingRate + eth.lastFundingRate) / 2
        print("💰 Funding Rate: BTC=\(btc.lastFundingRate), ETH=\(eth.lastFundingRate), Avg=\(avgRate)")

        return FundingRate(
            averageRate: avgRate,
            exchanges: [
                ExchangeFundingRate(
                    exchange: "BTC",
                    rate: btc.lastFundingRate,
                    nextFundingTime: btc.nextFundingTime
                ),
                ExchangeFundingRate(
                    exchange: "ETH",
                    rate: eth.lastFundingRate,
                    nextFundingTime: eth.nextFundingTime
                )
            ],
            timestamp: Date()
        )
    }

    func fetchLiquidations() async throws -> LiquidationData {
        // Liquidation data requires paid Coinglass subscription
        // No free API available for aggregated liquidation data
        throw AppError.notImplemented
    }

    func fetchAltcoinSeason() async throws -> AltcoinSeasonIndex {
        return try await cache.getOrFetch(CacheKey.altcoinSeason, ttl: APICache.TTL.medium) {
            // Fetch top 150 coins with 30-day price change from CoinGecko
            let endpoint = CoinGeckoEndpoint.coinMarketsWithPriceChange(
                currency: "usd",
                perPage: 150,
                priceChangePeriods: ["30d"]
            )

            let coins: [CoinGeckoMarketCoin] = try await networkManager.request(endpoint)

            // Stablecoins and wrapped tokens to exclude
            let excludedCoins: Set<String> = [
                // Stablecoins
                "tether", "usd-coin", "dai", "binance-usd", "trueusd",
                "pax-dollar", "frax", "usdd", "gemini-dollar", "paypal-usd",
                "first-digital-usd", "ethena-usde", "usds", "ondo-us-dollar-yield",
                "usdc", "busd", "tusd", "gusd", "husd", "susd", "lusd", "musd",
                // Wrapped tokens
                "wrapped-bitcoin", "staked-ether", "lido-staked-ether",
                "rocket-pool-eth", "wrapped-steth", "coinbase-wrapped-staked-eth",
                "wrapped-eeth", "mantle-staked-ether", "wrapped-liquid-staked-ether",
                "weth", "wbtc", "steth", "reth", "cbeth"
            ]

            // Filter out stablecoins and wrapped tokens, take top 100
            let validCoins = coins.filter { !excludedCoins.contains($0.id) }.prefix(100)

            // Find Bitcoin's 30-day change
            guard let btcCoin = coins.first(where: { $0.id == "bitcoin" }) else {
                // Fallback to dominance-based calculation
                return try await calculateAltcoinSeasonFromDominance()
            }

            let btcChange30d = btcCoin.priceChangePercentage30dInCurrency ?? 0

            // Count altcoins outperforming BTC
            var outperformers = 0
            var totalAltcoins = 0

            for coin in validCoins {
                if coin.id == "bitcoin" { continue }
                totalAltcoins += 1

                let coinChange = coin.priceChangePercentage30dInCurrency ?? 0
                if coinChange > btcChange30d {
                    outperformers += 1
                }
            }

            guard totalAltcoins > 0 else {
                return try await calculateAltcoinSeasonFromDominance()
            }

            // Calculate index (0-100)
            let index = Int((Double(outperformers) / Double(totalAltcoins)) * 100)
            let isBitcoinSeason = index < 50

            print("📊 Altcoin Season Index: \(index) (\(outperformers)/\(totalAltcoins) outperforming BTC's \(String(format: "%.1f", btcChange30d))%)")

            return AltcoinSeasonIndex(
                value: index,
                isBitcoinSeason: isBitcoinSeason,
                timestamp: Date()
            )
        }
    }

    /// Fallback calculation using BTC dominance
    private func calculateAltcoinSeasonFromDominance() async throws -> AltcoinSeasonIndex {
        let btcDominance = try await fetchBTCDominance()

        // Map dominance to index:
        // BTC dom 65% -> index ~20 (Bitcoin Season)
        // BTC dom 55% -> index ~50 (Neutral)
        // BTC dom 45% -> index ~80 (Altcoin Season)
        let index = Int(max(0, min(100, (65 - btcDominance.value) * 3)))
        let isBitcoinSeason = index < 50

        print("📊 Altcoin Season Index (from dominance): \(index) (BTC dom: \(String(format: "%.1f", btcDominance.value))%)")

        return AltcoinSeasonIndex(
            value: index,
            isBitcoinSeason: isBitcoinSeason,
            timestamp: Date()
        )
    }

    func fetchRiskLevel() async throws -> RiskLevel {
        // Calculate risk level from multiple indicators
        async let fearGreed = fetchFearGreedIndex()
        async let btcDom = fetchBTCDominance()

        let (fg, btc) = try await (fearGreed, btcDom)

        // Simple risk calculation based on available data
        let fgRisk = Double(fg.value) / 100.0
        let domRisk = btc.value / 100.0

        let overallRisk = Int((fgRisk * 0.5 + domRisk * 0.5) * 10)

        return RiskLevel(
            level: min(10, max(1, overallRisk)),
            indicators: [
                RiskIndicator(name: "Fear & Greed", value: fgRisk, weight: 0.5, contribution: fgRisk * 0.5),
                RiskIndicator(name: "BTC Dominance", value: domRisk, weight: 0.5, contribution: domRisk * 0.5)
            ],
            recommendation: generateRiskRecommendation(level: overallRisk),
            timestamp: Date()
        )
    }

    func fetchGlobalLiquidity() async throws -> GlobalLiquidity {
        // TODO: Implement with appropriate API
        // This requires macroeconomic data APIs
        throw AppError.notImplemented
    }

    func fetchAppStoreRanking() async throws -> AppStoreRanking {
        let rankings = try await fetchAppStoreRankings()
        guard let first = rankings.first else {
            throw AppError.dataNotFound
        }
        return first
    }

    func fetchAppStoreRankings() async throws -> [AppStoreRanking] {
        // Use Apple's iTunes RSS feed to get Coinbase ranking (US All Free Apps)
        let appStoreService = APIAppStoreRankingService()
        let result = try await appStoreService.fetchCoinbaseRanking()

        // Return ranking (0 means >200 / not ranked)
        let rank = result.ranking ?? 0

        if rank > 0 {
            print("🏆 Coinbase US App Store ranking: #\(rank)")
        } else {
            print("⚠️ Coinbase not in top 200 - showing >200")
        }

        // Save to Supabase for historical tracking (with BTC price)
        Task {
            await saveRankingToSupabase(ranking: rank > 0 ? rank : nil)
        }

        return [
            AppStoreRanking(
                id: UUID(),
                appName: "Coinbase",
                ranking: rank,
                change: 0,
                platform: .ios,
                region: .us,
                category: "All Free Apps",
                recordedAt: Date()
            )
        ]
    }

    /// Save current ranking to Supabase with BTC price
    private func saveRankingToSupabase(ranking: Int?) async {
        do {
            // Fetch current BTC price
            let btcPrice = await fetchCurrentBTCPrice()

            // Create ranking DTO
            let rankingDTO = AppStoreRankingDTO(
                appName: "Coinbase",
                ranking: ranking,
                btcPrice: btcPrice
            )

            // Save to Supabase
            try await SupabaseDatabase.shared.saveAppStoreRanking(rankingDTO)
        } catch {
            print("⚠️ Failed to save App Store ranking to Supabase: \(error.localizedDescription)")
        }
    }

    /// Fetch current BTC price from CoinGecko
    private func fetchCurrentBTCPrice() async -> Double? {
        do {
            let endpoint = CoinGeckoEndpoint.simplePrice(ids: ["bitcoin"], currencies: ["usd"])
            let response: [String: [String: Double]] = try await networkManager.request(endpoint)
            return response["bitcoin"]?["usd"]
        } catch {
            print("⚠️ Failed to fetch BTC price: \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetch historical App Store rankings from Supabase
    func fetchAppStoreRankingHistory(limit: Int = 30) async throws -> [AppStoreRankingDTO] {
        return try await SupabaseDatabase.shared.getAppStoreRankings(appName: "Coinbase", limit: limit)
    }

    func fetchArkLineRiskScore() async throws -> ArkLineRiskScore {
        // Calculate ArkLine Risk Score from available indicators
        async let fearGreed = fetchFearGreedIndex()
        async let btcDom = fetchBTCDominance()

        let (fg, btc) = try await (fearGreed, btcDom)

        // Build components from available data
        var components: [RiskScoreComponent] = []

        // Fear & Greed component (20% weight)
        let fgValue = Double(fg.value) / 100.0
        components.append(RiskScoreComponent(
            name: "Fear & Greed",
            value: fgValue,
            weight: 0.35,
            signal: SentimentTier.from(score: fg.value)
        ))

        // BTC Dominance component (15% weight)
        let btcValue = btc.value / 100.0
        components.append(RiskScoreComponent(
            name: "BTC Dominance",
            value: btcValue,
            weight: 0.25,
            signal: btcValue > 0.55 ? .bullish : (btcValue < 0.45 ? .bearish : .neutral)
        ))

        // Add placeholder components for unavailable data
        components.append(RiskScoreComponent(
            name: "Market Momentum",
            value: 0.5,
            weight: 0.20,
            signal: .neutral
        ))

        components.append(RiskScoreComponent(
            name: "Volatility",
            value: 0.5,
            weight: 0.20,
            signal: .neutral
        ))

        // Calculate weighted score
        let weightedSum = components.reduce(0.0) { $0 + ($1.value * $1.weight) }
        let score = Int(weightedSum * 100)

        return ArkLineRiskScore(
            score: score,
            tier: SentimentTier.from(score: score),
            components: components,
            recommendation: generateArkLineRecommendation(score: score),
            timestamp: Date()
        )
    }

    func fetchGoogleTrends() async throws -> GoogleTrendsData {
        // TODO: Implement with Google Trends API or SerpAPI
        // For now, throw not implemented
        throw AppError.notImplemented
    }

    func fetchMarketOverview() async throws -> MarketOverview {
        async let fg = fetchFearGreedIndex()
        async let btc = fetchBTCDominance()
        async let global = fetchGlobalData()

        let (fearGreed, btcDominance, globalData) = try await (fg, btc, global)

        return MarketOverview(
            fearGreed: fearGreed,
            btcDominance: btcDominance,
            altcoinSeason: nil,
            totalMarketCap: globalData.data.totalMarketCap["usd"] ?? 0,
            marketCapChange24h: globalData.data.marketCapChangePercentage24hUsd,
            totalVolume24h: globalData.data.totalVolume["usd"] ?? 0,
            btcPrice: 0, // Would need separate call
            ethPrice: 0, // Would need separate call
            timestamp: Date()
        )
    }

    // MARK: - Private Helpers

    private func fetchGlobalData() async throws -> CoinGeckoGlobalData {
        let endpoint = CoinGeckoEndpoint.globalData
        return try await networkManager.request(endpoint)
    }

    private func generateRiskRecommendation(level: Int) -> String {
        switch level {
        case 1...3: return "Low risk environment - consider increasing exposure"
        case 4...6: return "Moderate risk - maintain balanced positions"
        case 7...8: return "High risk - consider reducing exposure"
        default: return "Extreme risk - exercise caution"
        }
    }

    private func generateArkLineRecommendation(score: Int) -> String {
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
}

// MARK: - Fear & Greed API Response
struct FearGreedAPIResponse: Codable {
    let name: String
    let data: [FearGreedAPIData]
    let metadata: FearGreedMetadata?
}

struct FearGreedAPIData: Codable {
    let value: String
    let valueClassification: String
    let timestamp: String
    let timeUntilUpdate: String?

    enum CodingKeys: String, CodingKey {
        case value
        case valueClassification = "value_classification"
        case timestamp
        case timeUntilUpdate = "time_until_update"
    }
}

struct FearGreedMetadata: Codable {
    let error: String?
}
