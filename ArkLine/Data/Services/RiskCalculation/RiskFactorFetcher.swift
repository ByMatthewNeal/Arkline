import Foundation

// MARK: - Risk Factor Fetcher
/// Actor-based service for fetching all risk factor data.
/// - Alpha Vantage (VIX/DXY): 2-hour cache to stay within 25 requests/day limit
/// - RSI/SMA200: Calculated from Coinbase daily candles (no rate limits)
/// - Other APIs (Fear & Greed, Funding, Oil): Fetched in parallel
/// All factors are fetched concurrently for maximum speed (~5s vs ~35s with Taapi.io).
actor RiskFactorFetcher {

    // MARK: - Singleton
    static let shared = RiskFactorFetcher()

    // MARK: - Dependencies
    private let sentimentService: SentimentServiceProtocol
    private let vixService: VIXServiceProtocol
    private let dxyService: DXYServiceProtocol
    private let crudeOilService: CrudeOilServiceProtocol

    // MARK: - Cache Configuration

    /// Standard cache TTL for combined factor data (5 minutes)
    private let standardCacheTTL: TimeInterval = 300

    /// Alpha Vantage cache TTL (2 hours) - keeps us well under 25 requests/day
    private let macroCacheTTL: TimeInterval = 7200

    // MARK: - Standard Cache (5 min TTL)
    private struct CacheEntry {
        let data: RiskFactorData
        let timestamp: Date

        func isExpired(ttl: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }
    }

    private var cache: [String: CacheEntry] = [:]

    // MARK: - Macro Cache (2 hour TTL) - VIX and DXY from Alpha Vantage
    private struct MacroCacheEntry {
        let vix: Double?
        let dxy: Double?
        let timestamp: Date

        func isExpired(ttl: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }
    }

    private var macroCache: MacroCacheEntry?

    // MARK: - Initialization

    init(
        sentimentService: SentimentServiceProtocol = ServiceContainer.shared.sentimentService,
        vixService: VIXServiceProtocol = ServiceContainer.shared.vixService,
        dxyService: DXYServiceProtocol = ServiceContainer.shared.dxyService,
        crudeOilService: CrudeOilServiceProtocol = ServiceContainer.shared.crudeOilService
    ) {
        self.sentimentService = sentimentService
        self.vixService = vixService
        self.dxyService = dxyService
        self.crudeOilService = crudeOilService
    }

    // MARK: - Public Methods

    /// Fetch all risk factor data for a coin
    /// - Parameters:
    ///   - coin: Coin symbol (BTC, ETH)
    ///   - forceRefresh: Bypass cache (note: macro data still uses 2hr cache unless forceMacroRefresh)
    /// - Returns: RiskFactorData with available factors
    func fetchFactors(for coin: String, forceRefresh: Bool = false) async -> RiskFactorData {
        let cacheKey = coin.uppercased()

        // Check standard cache first
        if !forceRefresh, let entry = cache[cacheKey], !entry.isExpired(ttl: standardCacheTTL) {
            logDebug("Using cached factor data for \(coin)", category: .network)
            return entry.data
        }

        logDebug("Fetching fresh factor data for \(coin)...", category: .network)

        // Fetch ALL data in parallel — Coinbase-first for RSI/SMA avoids Taapi.io 16s rate limit waits.
        // Taapi.io is tried first inline but falls back to Coinbase calculation on failure,
        // so we skip the sequential Taapi path entirely and use Coinbase directly for speed.
        async let priceResult = fetchPriceFromCoinbase(coin: coin)
        async let rsiResult = fetchRSIFromCoinbase(coin: coin)
        async let smaResult = fetchSMA200FromCoinbase(coin: coin)
        async let macroResult = fetchMacroData(forceRefresh: false)
        async let fundingResult = fetchFundingRate()
        async let fearGreedResult = fetchFearGreed()
        async let oilResult = fetchCrudeOil()

        // Await all in parallel
        let price = await priceResult
        let rsi = await rsiResult
        let sma = await smaResult
        let (vix, dxy) = await macroResult
        let funding = await fundingResult
        let fearGreed = await fearGreedResult
        let oil = await oilResult

        // Bull Market Bands needs price, but the Coinbase fetch is fast
        let bullMarketBands = await fetchBullMarketBands(coin: coin, currentPrice: price)

        let factorData = RiskFactorData(
            rsi: rsi,
            sma200: sma,
            currentPrice: price,
            bullMarketBands: bullMarketBands,
            fundingRate: funding,
            fearGreedValue: fearGreed,
            vixValue: vix,
            dxyValue: dxy,
            oilValue: oil,
            fetchedAt: Date()
        )

        // Cache the results
        cache[cacheKey] = CacheEntry(data: factorData, timestamp: Date())

        logDebug("Factor data fetch complete for \(coin)", category: .network)
        return factorData
    }

    /// Clear all caches
    func clearCache() {
        cache.removeAll()
        macroCache = nil
    }

    /// Clear cache for a specific coin (keeps macro cache)
    func clearCache(for coin: String) {
        cache.removeValue(forKey: coin.uppercased())
    }

    /// Force refresh macro data (VIX/DXY) - use sparingly due to API limits
    func refreshMacroData() async -> (vix: Double?, dxy: Double?) {
        return await fetchMacroData(forceRefresh: true)
    }

    // MARK: - Stock Factor Fetching

    /// Fetch risk factor data for a stock symbol.
    /// Uses cached FMP price history from StockPriceStore for RSI, SMA200, and Bull Market Bands.
    /// Funding rate is unavailable for stocks (weight redistributed automatically).
    /// Fear & Greed uses VIX as stock market fear proxy.
    func fetchStockFactors(for symbol: String, forceRefresh: Bool = false) async -> RiskFactorData {
        let cacheKey = "STOCK_\(symbol.uppercased())"

        if !forceRefresh, let entry = cache[cacheKey], !entry.isExpired(ttl: standardCacheTTL) {
            return entry.data
        }

        logDebug("Fetching stock factor data for \(symbol)...", category: .network)

        // Get cached price history from StockPriceStore
        let priceHistory = await StockPriceStore.shared.fullPriceHistory(for: symbol)

        // Calculate technicals from price history (no API calls needed)
        let rsi = calculateRSI(from: priceHistory)
        let sma200 = calculateSMA200(from: priceHistory)
        let price = priceHistory.last?.price
        let bullMarketBands = calculateBullMarketBands(from: priceHistory, currentPrice: price)

        // Fetch market-wide factors in parallel (shared with crypto)
        async let macroResult = fetchMacroData(forceRefresh: false)
        async let oilResult = fetchCrudeOil()

        let (vix, dxy) = await macroResult
        let oil = await oilResult

        // Use VIX as stock fear gauge (inverted: high VIX = extreme fear = 0-25 on F&G scale)
        let fearGreed: Double? = vix.map { v in
            // Map VIX to 0-100 Fear & Greed equivalent:
            // VIX 10 → F&G 90 (extreme greed), VIX 40+ → F&G 10 (extreme fear)
            max(0, min(100, 100 - ((v - 10) / 30) * 90))
        }

        let factorData = RiskFactorData(
            rsi: rsi,
            sma200: sma200,
            currentPrice: price,
            bullMarketBands: bullMarketBands,
            fundingRate: nil, // Not applicable for stocks
            fearGreedValue: fearGreed,
            vixValue: vix,
            dxyValue: dxy,
            oilValue: oil,
            fetchedAt: Date()
        )

        cache[cacheKey] = CacheEntry(data: factorData, timestamp: Date())
        logDebug("Stock factor data complete for \(symbol) (\(factorData.availableCount) factors)", category: .network)
        return factorData
    }

    // MARK: - Price History Technical Calculations

    /// Calculate 14-period RSI from price history tuples
    private func calculateRSI(from prices: [(date: Date, price: Double)]) -> Double? {
        guard prices.count >= 15 else { return nil }
        let recent = Array(prices.suffix(15))

        var gains: [Double] = []
        var losses: [Double] = []

        for i in 1..<recent.count {
            let change = recent[i].price - recent[i-1].price
            gains.append(max(change, 0))
            losses.append(max(-change, 0))
        }

        let avgGain = gains.reduce(0, +) / 14.0
        let avgLoss = losses.reduce(0, +) / 14.0
        guard avgLoss > 0 else { return 100.0 }

        let rs = avgGain / avgLoss
        return 100.0 - (100.0 / (1.0 + rs))
    }

    /// Calculate 200-day SMA from price history tuples
    private func calculateSMA200(from prices: [(date: Date, price: Double)]) -> Double? {
        guard prices.count >= 200 else { return nil }
        let last200 = prices.suffix(200).map(\.price)
        return last200.reduce(0, +) / Double(last200.count)
    }

    /// Calculate Bull Market Support Bands (20W SMA + 21W EMA) from daily price history
    private func calculateBullMarketBands(from prices: [(date: Date, price: Double)], currentPrice: Double?) -> BullMarketSupportBands? {
        guard let price = currentPrice, prices.count >= 147 else { return nil }

        let calendar = Calendar(identifier: .iso8601)
        var weeklyCloses: [(yearWeek: Int, close: Double)] = []
        var currentYearWeek = 0

        for point in prices {
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: point.date)
            let yw = (components.yearForWeekOfYear ?? 0) * 100 + (components.weekOfYear ?? 0)

            if yw != currentYearWeek {
                weeklyCloses.append((yearWeek: yw, close: point.price))
                currentYearWeek = yw
            } else {
                weeklyCloses[weeklyCloses.count - 1] = (yearWeek: yw, close: point.price)
            }
        }

        if weeklyCloses.count > 1 { weeklyCloses.removeLast() }
        guard weeklyCloses.count >= 21 else { return nil }

        let closingPrices = weeklyCloses.map(\.close)

        let last20 = Array(closingPrices.suffix(20))
        let sma20Week = last20.reduce(0, +) / Double(last20.count)

        let last21 = Array(closingPrices.suffix(21))
        let multiplier = 2.0 / 22.0
        var ema21Week = last21[0]
        for i in 1..<last21.count {
            ema21Week = (last21[i] - ema21Week) * multiplier + ema21Week
        }

        return BullMarketSupportBands(sma20Week: sma20Week, ema21Week: ema21Week, currentPrice: price)
    }

    // MARK: - Macro Data Fetching (Alpha Vantage - 2hr cache)

    private func fetchMacroData(forceRefresh: Bool) async -> (vix: Double?, dxy: Double?) {
        // Check 2-hour cache unless force refresh
        if !forceRefresh, let macro = macroCache, !macro.isExpired(ttl: macroCacheTTL) {
            let age = Int(Date().timeIntervalSince(macro.timestamp) / 60)
            logDebug("Using cached macro data (VIX/DXY) - \(age) min old, refreshes in \(120 - age) min", category: .network)
            return (macro.vix, macro.dxy)
        }

        logDebug("Fetching fresh macro data (VIX/DXY) from Alpha Vantage...", category: .network)

        // Fetch VIX and DXY in parallel (same provider, counted as 2 requests)
        async let vixResult = fetchVIX()
        async let dxyResult = fetchDXY()

        let vix = await vixResult
        let dxy = await dxyResult

        // Update 2-hour cache
        macroCache = MacroCacheEntry(vix: vix, dxy: dxy, timestamp: Date())

        return (vix, dxy)
    }

    // MARK: - Coinbase Technical Indicators

    /// Calculate RSI from Coinbase kline data (14-period)
    private func fetchRSIFromCoinbase(coin: String) async -> Double? {
        do {
            let pair = "\(coin.uppercased())-USD"
            let candles = try await CoinbaseCandle.fetch(pair: pair, granularity: "ONE_DAY", limit: 15)
            guard candles.count >= 15 else {
                logWarning("Not enough candles for RSI calculation for \(coin) (got \(candles.count))", category: .network)
                return nil
            }

            // Calculate price changes
            var gains: [Double] = []
            var losses: [Double] = []

            for i in 1..<candles.count {
                let change = candles[i].close - candles[i-1].close
                if change > 0 {
                    gains.append(change)
                    losses.append(0)
                } else {
                    gains.append(0)
                    losses.append(abs(change))
                }
            }

            // Calculate average gain and loss (simple moving average for first RSI)
            let avgGain = gains.reduce(0, +) / 14.0
            let avgLoss = losses.reduce(0, +) / 14.0

            guard avgLoss > 0 else {
                logDebug("RSI for \(coin) (Coinbase): 100.0", category: .network)
                return 100.0
            }

            let rs = avgGain / avgLoss
            let rsi = 100.0 - (100.0 / (1.0 + rs))

            logDebug("RSI for \(coin) (Coinbase fallback): \(rsi)", category: .network)
            return rsi
        } catch {
            logWarning("RSI Coinbase fallback failed for \(coin): \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    /// Calculate 200-day SMA from Coinbase kline data
    private func fetchSMA200FromCoinbase(coin: String) async -> Double? {
        do {
            let pair = "\(coin.uppercased())-USD"
            let candles = try await CoinbaseCandle.fetch(pair: pair, granularity: "ONE_DAY", limit: 300)
            guard candles.count >= 200 else {
                logWarning("Not enough candles for SMA200 calculation for \(coin) (got \(candles.count))", category: .network)
                return nil
            }

            // Use last 200 candles
            let last200 = Array(candles.suffix(200))
            let closingPrices = last200.map { $0.close }
            let sma200 = closingPrices.reduce(0, +) / Double(closingPrices.count)

            logDebug("SMA200 for \(coin) (Coinbase fallback): \(sma200)", category: .network)
            return sma200
        } catch {
            logWarning("SMA200 Coinbase fallback failed for \(coin): \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    /// Fetch current price from Coinbase
    private func fetchPriceFromCoinbase(coin: String) async -> Double? {
        do {
            let pair = "\(coin.uppercased())-USD"
            let candles = try await CoinbaseCandle.fetch(pair: pair, granularity: "ONE_HOUR", limit: 1)
            guard let latest = candles.last else { return nil }
            logDebug("Price for \(coin) (Coinbase): \(latest.close)", category: .network)
            return latest.close
        } catch {
            logWarning("Coinbase price fetch failed for \(coin): \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    private func fetchBullMarketBands(coin: String, currentPrice: Double?) async -> BullMarketSupportBands? {
        guard let price = currentPrice else { return nil }

        do {
            // Coinbase has no weekly granularity, so fetch ~160 daily candles and aggregate to weekly
            let pair = "\(coin.uppercased())-USD"
            let candles = try await CoinbaseCandle.fetch(pair: pair, granularity: "ONE_DAY", limit: 160)
            guard candles.count >= 147 else { return nil } // Need 21 weeks of daily data

            // Group daily candles into ISO weeks, take last close of each week
            let calendar = Calendar(identifier: .iso8601)
            var weeklyCloses: [(yearWeek: Int, close: Double)] = []
            var currentYearWeek = 0

            for candle in candles {
                let date = Date(timeIntervalSince1970: Double(candle.start))
                let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
                let yw = (components.yearForWeekOfYear ?? 0) * 100 + (components.weekOfYear ?? 0)

                if yw != currentYearWeek {
                    weeklyCloses.append((yearWeek: yw, close: candle.close))
                    currentYearWeek = yw
                } else {
                    // Update the close for this week (last daily close wins)
                    weeklyCloses[weeklyCloses.count - 1] = (yearWeek: yw, close: candle.close)
                }
            }

            // Drop the current (incomplete) week
            if weeklyCloses.count > 1 { weeklyCloses.removeLast() }
            guard weeklyCloses.count >= 21 else { return nil }

            let closingPrices = weeklyCloses.map { $0.close }

            // Calculate 20-week SMA
            let last20 = Array(closingPrices.suffix(20))
            let sma20Week = last20.reduce(0, +) / Double(last20.count)

            // Calculate 21-week EMA
            let last21 = Array(closingPrices.suffix(21))
            let multiplier = 2.0 / 22.0
            var ema21Week = last21[0]
            for i in 1..<last21.count {
                ema21Week = (last21[i] - ema21Week) * multiplier + ema21Week
            }

            logDebug("Bull Market Bands for \(coin): 20W SMA=\(sma20Week), 21W EMA=\(ema21Week)", category: .network)

            return BullMarketSupportBands(
                sma20Week: sma20Week,
                ema21Week: ema21Week,
                currentPrice: price
            )
        } catch {
            logWarning("Bull Market Bands fetch failed for \(coin): \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    private func fetchFundingRate() async -> Double? {
        do {
            let fundingData = try await sentimentService.fetchFundingRate()
            logDebug("Funding Rate: \(fundingData.averageRate)", category: .network)
            return fundingData.averageRate
        } catch {
            logWarning("Funding rate fetch failed: \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    private func fetchFearGreed() async -> Double? {
        do {
            let fearGreed = try await sentimentService.fetchFearGreedIndex()
            logDebug("Fear & Greed: \(fearGreed.value)", category: .network)
            return Double(fearGreed.value)
        } catch {
            logWarning("Fear & Greed fetch failed: \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    private func fetchCrudeOil() async -> Double? {
        do {
            guard let oilData = try await crudeOilService.fetchLatestCrudeOil() else {
                logWarning("Crude oil data unavailable (nil response)", category: .network)
                return nil
            }
            logDebug("WTI Crude Oil: $\(oilData.value)", category: .network)
            return oilData.value
        } catch {
            logWarning("Crude oil fetch failed: \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    private func fetchVIX() async -> Double? {
        do {
            guard let vixData = try await vixService.fetchLatestVIX() else {
                logWarning("VIX data unavailable (nil response)", category: .network)
                return nil
            }
            logDebug("VIX: \(vixData.value)", category: .network)
            return vixData.value
        } catch {
            logWarning("VIX fetch failed: \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    private func fetchDXY() async -> Double? {
        do {
            guard let dxyData = try await dxyService.fetchLatestDXY() else {
                logWarning("DXY data unavailable (nil response)", category: .network)
                return nil
            }
            logDebug("DXY: \(dxyData.value)", category: .network)
            return dxyData.value
        } catch {
            logWarning("DXY fetch failed: \(error.localizedDescription)", category: .network)
            return nil
        }
    }
}
