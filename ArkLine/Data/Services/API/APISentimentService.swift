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

    func fetchDominanceSnapshot() async throws -> DominanceSnapshot {
        let endpoint = CoinGeckoEndpoint.globalData
        let response: CoinGeckoGlobalData = try await networkManager.request(endpoint)

        let btcDom = response.data.marketCapPercentage["btc"] ?? 0
        let ethDom = response.data.marketCapPercentage["eth"] ?? 0
        let usdtDom = response.data.marketCapPercentage["usdt"] ?? 0
        let totalMcap = response.data.totalMarketCap["usd"] ?? 0
        let altMcap = totalMcap * (1.0 - btcDom / 100.0)

        return DominanceSnapshot(
            btcDominance: btcDom,
            ethDominance: ethDom,
            usdtDominance: usdtDom,
            totalMarketCap: totalMcap,
            altMarketCap: altMcap,
            timestamp: Date()
        )
    }

    func fetchETFNetFlow() async throws -> ETFNetFlow {
        // Scrape ETF net flow data from Farside Investors
        let scraper = FarsideETFScraper()
        return try await scraper.fetchETFNetFlow()
    }

    func fetchFundingRate() async throws -> FundingRate {
        // Cascading fallback: try multiple exchanges until one succeeds
        // Each exchange may be geo-blocked in different regions
        let providers: [FundingRateProvider] = [.bybit, .binance, .okx]
        var lastError: Error = AppError.dataNotFound

        for provider in providers {
            do {
                // Fetch sequentially per provider to avoid async let scoping issues
                let btc = try await fetchFundingRateFrom(provider: provider, base: "BTC")
                let eth = try await fetchFundingRateFrom(provider: provider, base: "ETH")
                let avgRate = (btc.rate + eth.rate) / 2

                logDebug("Funding rate loaded via \(provider.name)", category: .network)

                return FundingRate(
                    averageRate: avgRate,
                    exchanges: [
                        ExchangeFundingRate(exchange: "BTC", rate: btc.rate, nextFundingTime: btc.nextFundingTime),
                        ExchangeFundingRate(exchange: "ETH", rate: eth.rate, nextFundingTime: eth.nextFundingTime)
                    ],
                    timestamp: Date()
                )
            } catch {
                logWarning("Funding rate via \(provider.name) failed: \(error), trying next provider", category: .network)
                lastError = error
            }
        }

        logError("All funding rate providers failed", category: .network)
        throw lastError
    }

    // MARK: - Funding Rate Providers

    private enum FundingRateProvider {
        case bybit, binance, okx

        var name: String {
            switch self {
            case .bybit: return "Bybit"
            case .binance: return "Binance"
            case .okx: return "OKX"
            }
        }
    }

    private struct FundingRateResult {
        let rate: Double
        let nextFundingTime: Date?
    }

    private func fetchFundingRateFrom(provider: FundingRateProvider, base: String) async throws -> FundingRateResult {
        switch provider {
        case .bybit:
            return try await fetchBybitFundingRate(symbol: "\(base)USDT")
        case .binance:
            return try await fetchBinanceFundingRate(symbol: "\(base)USDT")
        case .okx:
            return try await fetchOKXFundingRate(symbol: "\(base)-USDT-SWAP")
        }
    }

    // MARK: - Bybit (works in US + most regions)

    private func fetchBybitFundingRate(symbol: String) async throws -> FundingRateResult {
        let url = URL(string: "https://api.bybit.com/v5/market/tickers?category=linear&symbol=\(symbol)")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AppError.custom(message: "Bybit HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let list = (json?["result"] as? [String: Any])?["list"] as? [[String: Any]]

        guard let ticker = list?.first,
              let rateStr = ticker["fundingRate"] as? String,
              let rate = Double(rateStr) else {
            throw AppError.dataNotFound
        }

        var nextTime: Date?
        if let ts = ticker["nextFundingTime"] as? String, let ms = Double(ts) {
            nextTime = Date(timeIntervalSince1970: ms / 1000)
        }

        return FundingRateResult(rate: rate, nextFundingTime: nextTime)
    }

    // MARK: - Binance Futures (works outside US)

    private func fetchBinanceFundingRate(symbol: String) async throws -> FundingRateResult {
        let url = URL(string: "https://fapi.binance.com/fapi/v1/premiumIndex?symbol=\(symbol)")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AppError.custom(message: "Binance HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let rateStr = json?["lastFundingRate"] as? String,
              let rate = Double(rateStr) else {
            throw AppError.dataNotFound
        }

        var nextTime: Date?
        if let ts = json?["nextFundingTime"] as? Int64 {
            nextTime = Date(timeIntervalSince1970: TimeInterval(ts) / 1000)
        } else if let ts = json?["nextFundingTime"] as? Double {
            nextTime = Date(timeIntervalSince1970: ts / 1000)
        }

        return FundingRateResult(rate: rate, nextFundingTime: nextTime)
    }

    // MARK: - OKX (works in most regions)

    private func fetchOKXFundingRate(symbol: String) async throws -> FundingRateResult {
        let url = URL(string: "https://www.okx.com/api/v5/public/funding-rate?instId=\(symbol)")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AppError.custom(message: "OKX HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let list = json?["data"] as? [[String: Any]]

        guard let item = list?.first,
              let rateStr = item["fundingRate"] as? String,
              let rate = Double(rateStr) else {
            throw AppError.dataNotFound
        }

        var nextTime: Date?
        if let ts = item["nextFundingTime"] as? String, let ms = Double(ts) {
            nextTime = Date(timeIntervalSince1970: ms / 1000)
        }

        return FundingRateResult(rate: rate, nextFundingTime: nextTime)
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

            // Filter out stablecoins and wrapped tokens, take top 50 by market cap
            let validCoins = Array(coins
                .filter { !excludedCoins.contains($0.id) && $0.id != "bitcoin" }
                .prefix(50))

            // Find Bitcoin's 30-day change
            guard let btcCoin = coins.first(where: { $0.id == "bitcoin" }) else {
                // Fallback: dominance-based calculation
                return try await self.calculateAltcoinSeasonFromDominance()
            }

            let btcChange30d = btcCoin.priceChangePercentage30dInCurrency ?? 0

            guard !validCoins.isEmpty else {
                return try await self.calculateAltcoinSeasonFromDominance()
            }

            // ── Component 1: Market-Cap-Weighted Outperformance (40%) ──
            // Altcoin must beat BTC by >5pp to count. Weighted by market cap.
            let totalAltMcap = validCoins.compactMap(\.marketCap).reduce(0, +)
            var weightedOutperformers: Double = 0

            for coin in validCoins {
                let coinChange = coin.priceChangePercentage30dInCurrency ?? 0
                let mcap = coin.marketCap ?? 0
                let weight = totalAltMcap > 0 ? mcap / totalAltMcap : 1.0 / Double(validCoins.count)

                if coinChange > btcChange30d + 5.0 {
                    weightedOutperformers += weight
                }
            }
            let outperformanceScore = min(100.0, weightedOutperformers * 100.0)

            // ── Component 2: Absolute Performance (30%) ──
            // What % of top-50 alts are actually UP in USD over 30d?
            var altsUp = 0
            for coin in validCoins {
                let coinChange = coin.priceChangePercentage30dInCurrency ?? 0
                if coinChange > 0 {
                    altsUp += 1
                }
            }
            let absoluteScore = (Double(altsUp) / Double(validCoins.count)) * 100.0

            // ── Component 3: BTC Dominance (30%) ──
            // Lower dominance = higher score. Map 40-65% range to 100-0.
            let globalEndpoint = CoinGeckoEndpoint.globalData
            let globalData: CoinGeckoGlobalData = try await networkManager.request(globalEndpoint)
            let btcDominance = globalData.data.marketCapPercentage["btc"] ?? 55
            let dominanceScore = max(0.0, min(100.0, (65.0 - btcDominance) * (100.0 / 25.0)))

            // ── Composite ──
            let composite = outperformanceScore * 0.4 + absoluteScore * 0.3 + dominanceScore * 0.3
            let score30d = Int(max(0, min(100, composite)))

            // Persist daily snapshot for progressive 90-day calculation
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

            // Fall back to 30-day composite
            return AltcoinSeasonIndex(
                value: score30d,
                isBitcoinSeason: score30d < 25,
                timestamp: Date(),
                calculationWindow: 30
            )
        }
    }

    /// Fallback calculation using BTC dominance only
    private func calculateAltcoinSeasonFromDominance() async throws -> AltcoinSeasonIndex {
        let btcDominance = try await fetchBTCDominance()

        // Map dominance 40-65% → score 100-0
        let index = Int(max(0, min(100, (65 - btcDominance.value) * (100.0 / 25.0))))

        return AltcoinSeasonIndex(
            value: index,
            isBitcoinSeason: index < 25,
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

    /// Fetch current BTC price from CoinGecko, falling back to cached market data
    private func fetchCurrentBTCPrice() async -> Double? {
        // Try CoinGecko simple price first
        do {
            let endpoint = CoinGeckoEndpoint.simplePrice(ids: ["bitcoin"], currencies: ["usd"])
            let response: [String: [String: Double]] = try await networkManager.request(endpoint)
            if let price = response["bitcoin"]?["usd"] {
                return price
            }
        } catch {
            logWarning("CoinGecko BTC price failed, trying cache fallback: \(error.localizedDescription)", category: .network)
        }

        // Fallback: use cached crypto assets (pre-fetched during splash)
        if let assets = try? await ServiceContainer.shared.marketService.fetchCryptoAssets(page: 1, perPage: 10),
           let btc = assets.first(where: { $0.symbol.lowercased() == "btc" }) {
            return btc.currentPrice
        }

        return nil
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
        async let domSnapshotTask = try? fetchDominanceSnapshot()
        async let fundingTask = try? fetchFundingRate()
        async let altcoinTask = try? fetchAltcoinSeason()
        async let appStoreTask = try? fetchAppStoreRankings()

        // Coinglass derivatives data
        let coinglassService = ServiceContainer.shared.coinglassService
        async let btcOITask = try? coinglassService.fetchOpenInterest(symbol: "BTC")

        // Fetch macro indicators from other services
        let vixService = ServiceContainer.shared.vixService
        let dxyService = ServiceContainer.shared.dxyService
        let liquidityService = ServiceContainer.shared.globalLiquidityService
        let itcRiskService = ServiceContainer.shared.itcRiskService
        let crudeOilService = ServiceContainer.shared.crudeOilService

        async let vixTask = try? vixService.fetchLatestVIX()
        async let dxyTask = try? dxyService.fetchLatestDXY()
        async let liquidityTask = try? liquidityService.fetchNetLiquidityChanges()
        async let itcRiskTask = try? itcRiskService.fetchLatestRiskLevel(coin: "BTC")
        async let oilTask = try? crudeOilService.fetchLatestCrudeOil()

        // Await all results
        let fg = try await fearGreedTask
        let btc = try await btcDomTask
        let domSnapshot = await domSnapshotTask
        let funding = await fundingTask
        let altcoin = await altcoinTask
        let appStore = await appStoreTask
        let btcOI = await btcOITask
        let vix = await vixTask
        let dxy = await dxyTask
        let liquidity = await liquidityTask
        let itcRisk = await itcRiskTask
        let oil = await oilTask

        // Build components from all available data
        var components: [RiskScoreComponent] = []
        var totalWeight: Double = 0

        // 1. Fear & Greed (13% weight) - Direct sentiment
        let fgValue = Double(fg.value) / 100.0
        components.append(RiskScoreComponent(
            name: "Fear & Greed",
            value: fgValue,
            weight: 0.13,
            signal: SentimentTier.from(score: fg.value)
        ))
        totalWeight += 0.13

        // 2. ITC Risk Level (13% weight) - Bitcoin cycle risk
        if let risk = itcRisk {
            let riskValue = risk.riskLevel  // Already 0-1
            components.append(RiskScoreComponent(
                name: "BTC Cycle Risk",
                value: riskValue,
                weight: 0.13,
                signal: riskSignalTier(riskValue)
            ))
            totalWeight += 0.13
        }

        // 3. Open Interest (9% weight) - Leverage buildup = risk
        if let oi = btcOI {
            // Normalize: -10% to +10% OI 24h change -> 0-1 (rising OI = more leverage = more risk)
            let oiNormalized = min(1.0, max(0.0, (oi.openInterestChangePercent24h + 10.0) / 20.0))
            components.append(RiskScoreComponent(
                name: "Open Interest",
                value: oiNormalized,
                weight: 0.09,
                signal: oiSignalTier(oi.openInterestChangePercent24h)
            ))
            totalWeight += 0.09
        }

        // 4. Funding Rates (9% weight) - Leverage sentiment
        if let fund = funding {
            // Normalize: -0.1% to +0.1% range -> 0-1 (higher funding = more greed)
            let fundingValue = min(1.0, max(0.0, (fund.averageRate + 0.001) / 0.002))
            components.append(RiskScoreComponent(
                name: "Funding Rates",
                value: fundingValue,
                weight: 0.09,
                signal: fundingSignalTier(fund.averageRate)
            ))
            totalWeight += 0.09
        }

        // 5. VIX (9% weight) - Market fear gauge (INVERSE - low VIX = complacency/greed)
        if let vixData = vix {
            // Normalize: VIX 10-40 range -> 0-1 (INVERTED: low VIX = high risk/greed)
            let vixNormalized = min(1.0, max(0.0, (40.0 - vixData.value) / 30.0))
            components.append(RiskScoreComponent(
                name: "VIX (Volatility)",
                value: vixNormalized,
                weight: 0.09,
                signal: vixSignalTier(vixData.value)
            ))
            totalWeight += 0.09
        }

        // 6. DXY (9% weight) - Dollar strength (INVERSE - weak dollar = risk-on/greed)
        if let dxyData = dxy {
            // Normalize: DXY 85-110 range -> 0-1 (INVERTED: low DXY = risk-on)
            let dxyNormalized = min(1.0, max(0.0, (110.0 - dxyData.value) / 25.0))
            components.append(RiskScoreComponent(
                name: "DXY (Dollar)",
                value: dxyNormalized,
                weight: 0.09,
                signal: dxySignalTier(dxyData.value)
            ))
            totalWeight += 0.09
        }

        // 7. US Net Liquidity (8% weight) - Expanding liquidity = risk-on
        if let liq = liquidity {
            // Normalize: -5% to +5% monthly change -> 0-1
            let liqNormalized = min(1.0, max(0.0, (liq.monthlyChange + 5.0) / 10.0))
            components.append(RiskScoreComponent(
                name: "US Net Liquidity",
                value: liqNormalized,
                weight: 0.08,
                signal: liquiditySignalTier(liq.monthlyChange)
            ))
            totalWeight += 0.08
        }

        // 8. WTI Crude Oil (7% weight) - Inflation pressure (INVERSE - low oil = risk-on)
        if let oilData = oil {
            // Normalize: $40-120 range -> 0-1 (INVERTED: low oil = disinflationary = bullish)
            let oilNormalized = min(1.0, max(0.0, (120.0 - oilData.value) / 80.0))
            components.append(RiskScoreComponent(
                name: "WTI Crude Oil",
                value: oilNormalized,
                weight: 0.07,
                signal: oilSignalTier(oilData.value)
            ))
            totalWeight += 0.07
        }

        // 9. App Store Ranking (7% weight) - Retail FOMO indicator
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
                weight: 0.07,
                signal: appStoreSignalTier(coinbase.ranking)
            ))
            totalWeight += 0.07
        }

        // 10. Capital Flow (7% weight) - Multi-dominance rotation signal
        if let snapshot = domSnapshot {
            let previous = CapitalRotationService.loadPreviousSnapshot()
            let rotation = CapitalRotationService.computeRotationSignal(current: snapshot, previous: previous)
            CapitalRotationService.savePreviousSnapshot(snapshot)
            components.append(RiskScoreComponent(
                name: "Capital Flow",
                value: rotation.score / 100.0,
                weight: 0.07,
                signal: rotationSignalTier(rotation.score)
            ))
            totalWeight += 0.07
        } else {
            // Fallback to raw BTC dominance if snapshot unavailable
            let btcDomValue = 1.0 - (btc.value / 100.0)
            components.append(RiskScoreComponent(
                name: "Capital Flow",
                value: btcDomValue,
                weight: 0.07,
                signal: btcDomSignalTier(btc.value)
            ))
            totalWeight += 0.07
        }

        // 11. Altcoin Season (7% weight) - Higher = altcoin greed
        if let alt = altcoin {
            let altValue = Double(alt.value) / 100.0
            components.append(RiskScoreComponent(
                name: "Altcoin Season",
                value: altValue,
                weight: 0.07,
                signal: altcoinSignalTier(alt.value)
            ))
            totalWeight += 0.07
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

    private func oilSignalTier(_ price: Double) -> SentimentTier {
        // Low oil = disinflationary (bullish for crypto), High oil = inflationary (bearish)
        if price < 60 { return .extremelyBullish }
        if price < 70 { return .bullish }
        if price < 80 { return .neutral }
        if price < 90 { return .bearish }
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

    private func rotationSignalTier(_ score: Double) -> SentimentTier {
        switch score {
        case ..<20: return .extremelyBearish   // Risk off
        case 20..<40: return .bearish          // BTC accumulation
        case 40..<60: return .neutral
        case 60..<80: return .bullish          // Alt rotation
        default: return .extremelyBullish      // Peak speculation
        }
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

    private func oiSignalTier(_ changePct: Double) -> SentimentTier {
        // Rising OI = leverage buildup = more risk/greed
        if changePct > 5.0 { return .extremelyBullish }
        if changePct > 2.0 { return .bullish }
        if changePct > -2.0 { return .neutral }
        if changePct > -5.0 { return .bearish }
        return .extremelyBearish  // Rapid deleveraging
    }

    func fetchGoogleTrends() async throws -> GoogleTrendsData {
        // Read real data from Supabase (populated by collect-trends edge function)
        let history = try? await SupabaseDatabase.shared.getGoogleTrendsHistory(limit: 30)
        let latest = history?.first // Most recent (ordered by date DESC)

        let currentIndex = latest?.searchIndex ?? 50
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

        return GoogleTrendsData(
            keyword: "Bitcoin",
            currentIndex: currentIndex,
            weekAgoIndex: weekAgoIndex,
            monthAgoIndex: monthAgoIndex,
            trend: trend,
            timestamp: latest?.date ?? Date()
        )
    }

    /// Calculate days since a date
    private func daysSince(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }

    // MARK: - Trends Data Collection

    /// Timestamp of last trends refresh to avoid excessive calls
    private static var lastTrendsRefresh: Date?

    /// Trigger the collect-trends edge function to fetch fresh Wikipedia pageview data.
    /// Rate limited to once per hour.
    func refreshTrendsData() async {
        // Rate limit: skip if refreshed within the last hour
        if let last = Self.lastTrendsRefresh, Date().timeIntervalSince(last) < 3600 {
            return
        }

        do {
            let secret = Constants.API.collectTrendsSecret
            let _: Data = try await SupabaseManager.shared.functions.invoke(
                "collect-trends",
                options: .init(
                    headers: ["X-Trends-Secret": secret],
                    body: ["trigger": "ios_refresh"]
                ),
                decode: { data, _ in data }
            )
            Self.lastTrendsRefresh = Date()
        } catch {
            logWarning("Failed to trigger trends collection: \(error.localizedDescription)", category: .network)
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
            btcPrice: 0, // Not available from global endpoint; unused
            ethPrice: 0, // Not available from global endpoint; unused
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
