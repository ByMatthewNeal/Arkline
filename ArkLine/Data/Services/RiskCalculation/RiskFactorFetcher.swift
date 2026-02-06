import Foundation

// MARK: - Risk Factor Fetcher
/// Actor-based service for fetching all risk factor data with rate limiting.
/// - Alpha Vantage (VIX/DXY): 2-hour cache to stay within 25 requests/day limit
/// - Taapi.io (RSI/SMA/Price): Sequential calls with 16s delay to respect 1 req/15s limit
/// - Other APIs (Fear & Greed, Funding): No strict limits, fetched in parallel
actor RiskFactorFetcher {

    // MARK: - Singleton
    static let shared = RiskFactorFetcher()

    // MARK: - Dependencies
    private let technicalService: TechnicalAnalysisServiceProtocol
    private let sentimentService: SentimentServiceProtocol
    private let vixService: VIXServiceProtocol
    private let dxyService: DXYServiceProtocol

    // MARK: - Cache Configuration

    /// Standard cache TTL for combined factor data (5 minutes)
    private let standardCacheTTL: TimeInterval = 300

    /// Alpha Vantage cache TTL (2 hours) - keeps us well under 25 requests/day
    private let macroCacheTTL: TimeInterval = 7200

    /// Delay between Taapi.io API calls (16 seconds for safety margin over 15s limit)
    private let taapiDelaySeconds: TimeInterval = 16

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

    // MARK: - Taapi.io Rate Limiting
    private var lastTaapiCallTime: Date?

    // MARK: - Initialization

    init(
        technicalService: TechnicalAnalysisServiceProtocol = ServiceContainer.shared.technicalAnalysisService,
        sentimentService: SentimentServiceProtocol = ServiceContainer.shared.sentimentService,
        vixService: VIXServiceProtocol = ServiceContainer.shared.vixService,
        dxyService: DXYServiceProtocol = ServiceContainer.shared.dxyService
    ) {
        self.technicalService = technicalService
        self.sentimentService = sentimentService
        self.vixService = vixService
        self.dxyService = dxyService
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

        // 1. Fetch macro data (VIX/DXY) - uses 2-hour cache
        let (vix, dxy) = await fetchMacroData(forceRefresh: false)

        // 2. Fetch Taapi.io data SEQUENTIALLY with delays (RSI, SMA, Price)
        let (rsi, sma, price) = await fetchTaapiDataSequentially(coin: coin)

        // 3. Fetch non-rate-limited data in parallel (Binance funding, Alternative.me F&G)
        async let fundingResult = fetchFundingRate()
        async let fearGreedResult = fetchFearGreed()

        let funding = await fundingResult
        let fearGreed = await fearGreedResult

        // 4. Fetch Bull Market Support Bands (from Binance weekly data)
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
        lastTaapiCallTime = nil
    }

    /// Clear cache for a specific coin (keeps macro cache)
    func clearCache(for coin: String) {
        cache.removeValue(forKey: coin.uppercased())
    }

    /// Force refresh macro data (VIX/DXY) - use sparingly due to API limits
    func refreshMacroData() async -> (vix: Double?, dxy: Double?) {
        return await fetchMacroData(forceRefresh: true)
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

    // MARK: - Taapi.io Sequential Fetching with Rate Limiting

    private func fetchTaapiDataSequentially(coin: String) async -> (rsi: Double?, sma: Double?, price: Double?) {
        logDebug("Fetching Taapi.io data sequentially (16s delay between calls)...", category: .network)

        // Fetch price from Binance in parallel (no rate limit) while we wait for Taapi
        async let priceTask = fetchPriceFromBinance(coin: coin)

        // First Taapi call: RSI
        await waitForTaapiRateLimit()
        let rsi = await fetchRSI(coin: coin)

        // Second Taapi call: SMA200
        await waitForTaapiRateLimit()
        let sma = await fetchSMA200(coin: coin)

        // Get the price (already fetched in parallel)
        let price = await priceTask

        return (rsi, sma, price)
    }

    private func waitForTaapiRateLimit() async {
        guard let lastCall = lastTaapiCallTime else {
            // First call, no wait needed
            lastTaapiCallTime = Date()
            return
        }

        let elapsed = Date().timeIntervalSince(lastCall)
        if elapsed < taapiDelaySeconds {
            let waitTime = taapiDelaySeconds - elapsed
            logDebug("Rate limit: waiting \(String(format: "%.1f", waitTime))s before next Taapi.io call...", category: .network)
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        lastTaapiCallTime = Date()
    }

    // MARK: - Individual Fetch Methods

    private func fetchRSI(coin: String) async -> Double? {
        // Try Taapi.io first
        do {
            let symbol = "\(coin.uppercased())/USDT"
            let rsi = try await technicalService.fetchRSI(
                symbol: symbol,
                exchange: "binance",
                interval: "1d",
                period: 14
            )
            logDebug("RSI for \(coin) (Taapi): \(rsi)", category: .network)
            return rsi
        } catch {
            logWarning("RSI fetch failed for \(coin) via Taapi: \(error.localizedDescription), trying Binance fallback...", category: .network)
            // Fall back to calculating from Binance klines
            return await fetchRSIFromBinance(coin: coin)
        }
    }

    private func fetchSMA200(coin: String) async -> Double? {
        // Try Taapi.io first
        do {
            let symbol = "\(coin.uppercased())/USDT"
            let smaValues = try await technicalService.fetchSMAValues(
                symbol: symbol,
                exchange: "binance",
                periods: [200],
                interval: "1d"
            )
            let sma200 = smaValues[200]
            if let sma = sma200 {
                logDebug("SMA200 for \(coin) (Taapi): \(sma)", category: .network)
            }
            return sma200
        } catch {
            logWarning("SMA200 fetch failed for \(coin) via Taapi: \(error.localizedDescription), trying Binance fallback...", category: .network)
            // Fall back to calculating from Binance klines
            return await fetchSMA200FromBinance(coin: coin)
        }
    }

    // MARK: - Binance Fallback Methods

    /// Calculate RSI from Binance kline data (14-period)
    private func fetchRSIFromBinance(coin: String) async -> Double? {
        do {
            let binanceSymbol = "\(coin.uppercased())USDT"
            // Need 15 candles to calculate 14-period RSI (first candle is just for price change reference)
            let endpoint = BinanceEndpoint.klines(symbol: binanceSymbol, interval: "1d", limit: 15)

            let data = try await NetworkManager.shared.requestData(endpoint: endpoint)
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[Any]] else {
                return nil
            }

            let klines = jsonArray.compactMap { BinanceKline(from: $0) }
            guard klines.count >= 15 else {
                logWarning("Not enough klines for RSI calculation for \(coin)", category: .network)
                return nil
            }

            // Calculate price changes
            var gains: [Double] = []
            var losses: [Double] = []

            for i in 1..<klines.count {
                let change = klines[i].close - klines[i-1].close
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
                // No losses means RSI is 100
                logDebug("RSI for \(coin) (Binance): 100.0", category: .network)
                return 100.0
            }

            let rs = avgGain / avgLoss
            let rsi = 100.0 - (100.0 / (1.0 + rs))

            logDebug("RSI for \(coin) (Binance fallback): \(rsi)", category: .network)
            return rsi
        } catch {
            logWarning("RSI Binance fallback failed for \(coin): \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    /// Calculate 200-day SMA from Binance kline data
    private func fetchSMA200FromBinance(coin: String) async -> Double? {
        do {
            let binanceSymbol = "\(coin.uppercased())USDT"
            let endpoint = BinanceEndpoint.klines(symbol: binanceSymbol, interval: "1d", limit: 200)

            let data = try await NetworkManager.shared.requestData(endpoint: endpoint)
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[Any]] else {
                return nil
            }

            let klines = jsonArray.compactMap { BinanceKline(from: $0) }
            guard klines.count >= 200 else {
                logWarning("Not enough klines for SMA200 calculation for \(coin) (got \(klines.count))", category: .network)
                return nil
            }

            // Calculate 200-day SMA from closing prices
            let closingPrices = klines.map { $0.close }
            let sma200 = closingPrices.reduce(0, +) / Double(closingPrices.count)

            logDebug("SMA200 for \(coin) (Binance fallback): \(sma200)", category: .network)
            return sma200
        } catch {
            logWarning("SMA200 Binance fallback failed for \(coin): \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    private func fetchCurrentPrice(coin: String) async -> Double? {
        do {
            let symbol = "\(coin.uppercased())/USDT"
            let price = try await technicalService.fetchCurrentPrice(
                symbol: symbol,
                exchange: "binance"
            )
            logDebug("Price for \(coin): \(price)", category: .network)
            return price
        } catch {
            logWarning("Price fetch failed for \(coin): \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    /// Fetch current price directly from Binance (no rate limit)
    private func fetchPriceFromBinance(coin: String) async -> Double? {
        do {
            let binanceSymbol = "\(coin.uppercased())USDT"
            let endpoint = BinanceEndpoint.tickerPrice(symbol: binanceSymbol)
            let data = try await NetworkManager.shared.requestData(endpoint: endpoint)

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let priceString = json["price"] as? String,
               let price = Double(priceString) {
                logDebug("Price for \(coin) (Binance): \(price)", category: .network)
                return price
            }
            return nil
        } catch {
            logWarning("Binance price fetch failed for \(coin): \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    private func fetchBullMarketBands(coin: String, currentPrice: Double?) async -> BullMarketSupportBands? {
        guard let price = currentPrice else { return nil }

        do {
            // Fetch weekly candles from Binance to calculate 20W SMA and 21W EMA
            let binanceSymbol = "\(coin.uppercased())USDT"
            let endpoint = BinanceEndpoint.klines(symbol: binanceSymbol, interval: "1w", limit: 25)

            let data = try await NetworkManager.shared.requestData(endpoint: endpoint)
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[Any]] else {
                return nil
            }

            let klines = jsonArray.compactMap { BinanceKline(from: $0) }
            guard klines.count >= 21 else { return nil }

            // Get closing prices (excluding current incomplete candle)
            let closingPrices = klines.dropLast().map { $0.close }

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
