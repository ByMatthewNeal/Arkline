import Foundation

// MARK: - API Sentiment Service
/// Real API implementation of SentimentServiceProtocol.
/// Uses various APIs for sentiment data.
final class APISentimentService: SentimentServiceProtocol {
    // MARK: - Dependencies
    private let networkManager = NetworkManager.shared
    private let cache = APICache.shared
    private let sharedCache = SharedCacheService.shared

    private static let snapshotDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    // MARK: - SentimentServiceProtocol

    func fetchFearGreedIndex() async throws -> FearGreedIndex {
        return try await sharedCache.getOrFetch(CacheKey.fearGreedIndex, ttl: APICache.TTL.medium) { [networkManager] in
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
        return try await sharedCache.getOrFetch(cacheKey, ttl: APICache.TTL.long) { [networkManager] in
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

    private static let dominanceDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    func fetchBTCDominance() async throws -> BTCDominance {
        return try await sharedCache.getOrFetch(CacheKey.btcDominance, ttl: APICache.TTL.medium) { [networkManager] in
            let endpoint = CoinGeckoEndpoint.globalData
            let response: CoinGeckoGlobalData = try await networkManager.request(endpoint)

            let dominance = response.data.marketCapPercentage["btc"] ?? 0
            let todayStr = Self.dominanceDateFormatter.string(from: Date())

            // Compute 24h change from previously stored value
            let previousValue = UserDefaults.standard.double(forKey: "btcDominance_previousValue")
            let previousDate = UserDefaults.standard.string(forKey: "btcDominance_previousDate") ?? ""

            var change24h: Double = 0
            if previousValue > 0, previousDate != todayStr {
                change24h = dominance - previousValue
            }

            // Store today's value for next comparison
            if previousDate != todayStr {
                UserDefaults.standard.set(dominance, forKey: "btcDominance_previousValue")
                UserDefaults.standard.set(todayStr, forKey: "btcDominance_previousDate")
            }

            return BTCDominance(
                value: dominance,
                change24h: change24h,
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
        // Return placeholder data indicating unavailable
        return LiquidationData(
            total24h: 0,
            longLiquidations: 0,
            shortLiquidations: 0,
            largestSingleLiquidation: nil,
            timestamp: Date()
        )
    }

    func fetchAltcoinSeason() async throws -> AltcoinSeasonIndex {
        return try await sharedCache.getOrFetch(CacheKey.altcoinSeason, ttl: APICache.TTL.medium) { [networkManager] in
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
                // Fallback: dominance-based calculation
                let globalEndpoint = CoinGeckoEndpoint.globalData
                let globalData: CoinGeckoGlobalData = try await networkManager.request(globalEndpoint)
                let dominance = globalData.data.marketCapPercentage["btc"] ?? 50
                let fallbackIndex = Int(max(0, min(100, (65 - dominance) * 3)))
                return AltcoinSeasonIndex(value: fallbackIndex, isBitcoinSeason: fallbackIndex < 50, timestamp: Date())
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
                // Fallback: dominance-based calculation
                let globalEndpoint = CoinGeckoEndpoint.globalData
                let globalData: CoinGeckoGlobalData = try await networkManager.request(globalEndpoint)
                let dominance = globalData.data.marketCapPercentage["btc"] ?? 50
                let fallbackIndex = Int(max(0, min(100, (65 - dominance) * 3)))
                return AltcoinSeasonIndex(value: fallbackIndex, isBitcoinSeason: fallbackIndex < 50, timestamp: Date())
            }

            // Calculate index (0-100)
            let score30d = Int((Double(outperformers) / Double(totalAltcoins)) * 100)

            // Persist daily snapshot for 90-day calculation
            let todayStr = Self.snapshotDateFormatter.string(from: Date())
            let snapshotCoins = validCoins.compactMap { coin -> AltcoinSnapshotCoin? in
                guard let price = coin.currentPrice, price > 0,
                      let rank = coin.marketCapRank else { return nil }
                return AltcoinSnapshotCoin(coinId: coin.id, price: price, marketCapRank: rank)
            }
            if let btcPrice = btcCoin.currentPrice, btcPrice > 0, !snapshotCoins.isEmpty {
                let snapshot = AltcoinSeasonSnapshot(
                    date: todayStr,
                    btcPrice: btcPrice,
                    coins: snapshotCoins,
                    score30d: score30d
                )
                Task {
                    await AltcoinSeasonStore.shared.recordSnapshot(snapshot)
                }
            }

            // Use local data if we have >30 days (progressively improves toward 90d)
            if let localIndex = await AltcoinSeasonStore.shared.computeBestIndex() {
                return localIndex
            }

            // Fall back to 30-day CoinGecko data
            return AltcoinSeasonIndex(
                value: score30d,
                isBitcoinSeason: score30d < 50,
                timestamp: Date(),
                calculationWindow: 30
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
        // Use the dedicated GlobalLiquidityService for this data
        // Return placeholder if called directly
        return GlobalLiquidity(
            totalLiquidity: 0,
            weeklyChange: 0,
            monthlyChange: 0,
            yearlyChange: 0,
            components: [],
            timestamp: Date()
        )
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
            logWarning("Failed to save App Store ranking to Supabase: \(error.localizedDescription)", category: .network)
        }
    }

    /// Fetch current BTC price from CoinGecko
    private func fetchCurrentBTCPrice() async -> Double? {
        do {
            let endpoint = CoinGeckoEndpoint.simplePrice(ids: ["bitcoin"], currencies: ["usd"])
            let response: [String: [String: Double]] = try await networkManager.request(endpoint)
            return response["bitcoin"]?["usd"]
        } catch {
            logWarning("Failed to fetch BTC price: \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    /// Fetch historical App Store rankings from Supabase
    func fetchAppStoreRankingHistory(limit: Int = 30) async throws -> [AppStoreRankingDTO] {
        return try await SupabaseDatabase.shared.getAppStoreRankings(appName: "Coinbase", limit: limit)
    }

    func fetchArkLineRiskScore() async throws -> ArkLineRiskScore {
        // Enhanced ArkLine Risk Score from ALL available indicators
        // Fetch all data in parallel for performance
        async let fearGreedTask = fetchFearGreedIndex()
        async let btcDomTask = fetchBTCDominance()
        async let fundingTask = try? fetchFundingRate()
        async let altcoinTask = try? fetchAltcoinSeason()
        async let appStoreTask = try? fetchAppStoreRankings()

        // Fetch macro indicators from other services
        let vixService = ServiceContainer.shared.vixService
        let dxyService = ServiceContainer.shared.dxyService
        let liquidityService = ServiceContainer.shared.globalLiquidityService
        let itcRiskService = ServiceContainer.shared.itcRiskService

        async let vixTask = try? vixService.fetchLatestVIX()
        async let dxyTask = try? dxyService.fetchLatestDXY()
        async let liquidityTask = try? liquidityService.fetchLiquidityChanges()
        async let itcRiskTask = try? itcRiskService.fetchLatestRiskLevel(coin: "BTC")

        // Await all results
        let fg = try await fearGreedTask
        let btc = try await btcDomTask
        let funding = await fundingTask
        let altcoin = await altcoinTask
        let appStore = await appStoreTask
        let vix = await vixTask
        let dxy = await dxyTask
        let liquidity = await liquidityTask
        let itcRisk = await itcRiskTask

        // Build components from all available data
        var components: [RiskScoreComponent] = []
        var totalWeight: Double = 0

        // 1. Fear & Greed (15% weight) - Direct sentiment
        let fgValue = Double(fg.value) / 100.0
        components.append(RiskScoreComponent(
            name: "Fear & Greed",
            value: fgValue,
            weight: 0.15,
            signal: SentimentTier.from(score: fg.value)
        ))
        totalWeight += 0.15

        // 2. ITC Risk Level (15% weight) - Bitcoin cycle risk
        if let risk = itcRisk {
            let riskValue = risk.riskLevel  // Already 0-1
            components.append(RiskScoreComponent(
                name: "BTC Cycle Risk",
                value: riskValue,
                weight: 0.15,
                signal: riskSignalTier(riskValue)
            ))
            totalWeight += 0.15
        }

        // 3. Funding Rates (12% weight) - Leverage sentiment
        if let fund = funding {
            // Normalize: -0.1% to +0.1% range -> 0-1 (higher funding = more greed)
            let fundingValue = min(1.0, max(0.0, (fund.averageRate + 0.001) / 0.002))
            components.append(RiskScoreComponent(
                name: "Funding Rates",
                value: fundingValue,
                weight: 0.12,
                signal: fundingSignalTier(fund.averageRate)
            ))
            totalWeight += 0.12
        }

        // 4. VIX (12% weight) - Market fear gauge (INVERSE - low VIX = complacency/greed)
        if let vixData = vix {
            // Normalize: VIX 10-40 range -> 0-1 (INVERTED: low VIX = high risk/greed)
            let vixNormalized = min(1.0, max(0.0, (40.0 - vixData.value) / 30.0))
            components.append(RiskScoreComponent(
                name: "VIX (Volatility)",
                value: vixNormalized,
                weight: 0.12,
                signal: vixSignalTier(vixData.value)
            ))
            totalWeight += 0.12
        }

        // 5. DXY (10% weight) - Dollar strength (INVERSE - weak dollar = risk-on/greed)
        if let dxyData = dxy {
            // Normalize: DXY 85-110 range -> 0-1 (INVERTED: low DXY = risk-on)
            let dxyNormalized = min(1.0, max(0.0, (110.0 - dxyData.value) / 25.0))
            components.append(RiskScoreComponent(
                name: "DXY (Dollar)",
                value: dxyNormalized,
                weight: 0.10,
                signal: dxySignalTier(dxyData.value)
            ))
            totalWeight += 0.10
        }

        // 6. Global M2 Liquidity (10% weight) - Expanding liquidity = risk-on
        if let liq = liquidity {
            // Normalize: -5% to +5% monthly change -> 0-1
            let m2Normalized = min(1.0, max(0.0, (liq.monthlyChange + 5.0) / 10.0))
            components.append(RiskScoreComponent(
                name: "Global M2",
                value: m2Normalized,
                weight: 0.10,
                signal: liquiditySignalTier(liq.monthlyChange)
            ))
            totalWeight += 0.10
        }

        // 7. App Store Ranking (10% weight) - Retail FOMO indicator
        if let rankings = appStore, let coinbase = rankings.first(where: { $0.appName == "Coinbase" }) {
            // Normalize: Rank 1-200 -> 0-1 (INVERTED: lower rank = more FOMO/greed)
            let rankValue: Double
            if coinbase.ranking > 0 && coinbase.ranking <= 200 {
                rankValue = 1.0 - (Double(coinbase.ranking - 1) / 199.0)
            } else {
                rankValue = 0.1  // Not ranked = low retail interest
            }
            components.append(RiskScoreComponent(
                name: "App Store FOMO",
                value: rankValue,
                weight: 0.10,
                signal: appStoreSignalTier(coinbase.ranking)
            ))
            totalWeight += 0.10
        }

        // 8. BTC Dominance (8% weight) - Lower dominance = altcoin speculation/greed
        let btcDomValue = 1.0 - (btc.value / 100.0)  // Invert: low dominance = greed
        components.append(RiskScoreComponent(
            name: "BTC Dominance",
            value: btcDomValue,
            weight: 0.08,
            signal: btcDomSignalTier(btc.value)
        ))
        totalWeight += 0.08

        // 9. Altcoin Season (8% weight) - Higher = altcoin greed
        if let alt = altcoin {
            let altValue = Double(alt.value) / 100.0
            components.append(RiskScoreComponent(
                name: "Altcoin Season",
                value: altValue,
                weight: 0.08,
                signal: altcoinSignalTier(alt.value)
            ))
            totalWeight += 0.08
        }

        // Normalize weights if some indicators are missing
        let weightMultiplier = totalWeight > 0 ? 1.0 / totalWeight : 1.0
        let normalizedComponents = components.map { comp in
            RiskScoreComponent(
                name: comp.name,
                value: comp.value,
                weight: comp.weight * weightMultiplier,
                signal: comp.signal
            )
        }

        // Calculate weighted score
        let weightedSum = normalizedComponents.reduce(0.0) { $0 + ($1.value * $1.weight) }
        let score = Int(weightedSum * 100)

        return ArkLineRiskScore(
            score: score,
            tier: SentimentTier.from(score: score),
            components: normalizedComponents,
            recommendation: generateArkLineRecommendation(score: score),
            timestamp: Date()
        )
    }

    // MARK: - Signal Tier Helpers

    private func riskSignalTier(_ value: Double) -> SentimentTier {
        switch value {
        case 0..<0.2: return .extremelyBearish
        case 0.2..<0.4: return .bearish
        case 0.4..<0.6: return .neutral
        case 0.6..<0.8: return .bullish
        default: return .extremelyBullish
        }
    }

    private func fundingSignalTier(_ rate: Double) -> SentimentTier {
        if rate > 0.0005 { return .extremelyBullish }  // High positive = greed
        if rate > 0.0001 { return .bullish }
        if rate > -0.0001 { return .neutral }
        if rate > -0.0005 { return .bearish }
        return .extremelyBearish  // Negative = fear
    }

    private func vixSignalTier(_ vix: Double) -> SentimentTier {
        // Low VIX = complacency (greed), High VIX = fear
        if vix < 15 { return .extremelyBullish }  // Complacent
        if vix < 20 { return .bullish }
        if vix < 25 { return .neutral }
        if vix < 30 { return .bearish }
        return .extremelyBearish  // High fear
    }

    private func dxySignalTier(_ dxy: Double) -> SentimentTier {
        // Low DXY = risk-on (bullish for crypto), High DXY = risk-off
        if dxy < 90 { return .extremelyBullish }
        if dxy < 100 { return .bullish }
        if dxy < 105 { return .neutral }
        if dxy < 110 { return .bearish }
        return .extremelyBearish
    }

    private func liquiditySignalTier(_ change: Double) -> SentimentTier {
        if change > 2.0 { return .extremelyBullish }
        if change > 0.5 { return .bullish }
        if change > -0.5 { return .neutral }
        if change > -2.0 { return .bearish }
        return .extremelyBearish
    }

    private func appStoreSignalTier(_ rank: Int) -> SentimentTier {
        if rank <= 0 { return .bearish }  // Not ranked
        if rank <= 20 { return .extremelyBullish }  // High FOMO
        if rank <= 50 { return .bullish }
        if rank <= 100 { return .neutral }
        if rank <= 150 { return .bearish }
        return .extremelyBearish
    }

    private func btcDomSignalTier(_ dominance: Double) -> SentimentTier {
        // Low dominance = altcoin speculation (greedy market)
        if dominance < 40 { return .extremelyBullish }
        if dominance < 50 { return .bullish }
        if dominance < 55 { return .neutral }
        if dominance < 60 { return .bearish }
        return .extremelyBearish
    }

    private func altcoinSignalTier(_ value: Int) -> SentimentTier {
        switch value {
        case 0..<25: return .extremelyBearish  // Bitcoin season
        case 25..<40: return .bearish
        case 40..<60: return .neutral
        case 60..<75: return .bullish
        default: return .extremelyBullish  // Altcoin season
        }
    }

    func fetchGoogleTrends() async throws -> GoogleTrendsData {
        // Google Trends API requires SerpAPI or similar service
        // Using placeholder data for now (50 = baseline)
        let currentIndex = 50

        // Try to get historical data from Supabase to calculate change
        let history = try? await SupabaseDatabase.shared.getGoogleTrendsHistory(limit: 30)
        let weekAgoIndex = history?.first(where: { daysSince($0.date) >= 7 })?.searchIndex ?? currentIndex
        let monthAgoIndex = history?.first(where: { daysSince($0.date) >= 30 })?.searchIndex ?? currentIndex

        // Determine trend direction
        let trend: TrendDirection
        if currentIndex > weekAgoIndex + 5 {
            trend = .rising
        } else if currentIndex < weekAgoIndex - 5 {
            trend = .falling
        } else {
            trend = .stable
        }

        // Save current data to Supabase for historical tracking
        Task {
            await saveGoogleTrendsToSupabase(searchIndex: currentIndex)
        }

        return GoogleTrendsData(
            keyword: "Bitcoin",
            currentIndex: currentIndex,
            weekAgoIndex: weekAgoIndex,
            monthAgoIndex: monthAgoIndex,
            trend: trend,
            timestamp: Date()
        )
    }

    /// Calculate days since a date
    private func daysSince(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }

    /// Save current Google Trends data to Supabase with BTC price
    private func saveGoogleTrendsToSupabase(searchIndex: Int) async {
        do {
            // Fetch current BTC price
            let btcPrice = await fetchCurrentBTCPrice()

            // Create DTO
            let trendsDTO = GoogleTrendsDTO(
                searchIndex: searchIndex,
                btcPrice: btcPrice
            )

            // Save to Supabase
            try await SupabaseDatabase.shared.saveGoogleTrends(trendsDTO)
        } catch {
            logWarning("Failed to save Google Trends to Supabase: \(error.localizedDescription)", category: .network)
        }
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
