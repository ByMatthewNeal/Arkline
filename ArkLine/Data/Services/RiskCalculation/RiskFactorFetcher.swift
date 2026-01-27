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
            print("📦 Using cached factor data for \(coin)")
            return entry.data
        }

        print("🔄 Fetching fresh factor data for \(coin)...")

        // 1. Fetch macro data (VIX/DXY) - uses 2-hour cache
        let (vix, dxy) = await fetchMacroData(forceRefresh: false)

        // 2. Fetch Taapi.io data SEQUENTIALLY with delays (RSI, SMA, Price)
        let (rsi, sma, price) = await fetchTaapiDataSequentially(coin: coin)

        // 3. Fetch non-rate-limited data in parallel (Binance funding, Alternative.me F&G)
        async let fundingResult = fetchFundingRate()
        async let fearGreedResult = fetchFearGreed()

        let funding = await fundingResult
        let fearGreed = await fearGreedResult

        let factorData = RiskFactorData(
            rsi: rsi,
            sma200: sma,
            currentPrice: price,
            fundingRate: funding,
            fearGreedValue: fearGreed,
            vixValue: vix,
            dxyValue: dxy,
            fetchedAt: Date()
        )

        // Cache the results
        cache[cacheKey] = CacheEntry(data: factorData, timestamp: Date())

        print("✅ Factor data fetch complete for \(coin)")
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
            print("📦 Using cached macro data (VIX/DXY) - \(age) min old, refreshes in \(120 - age) min")
            return (macro.vix, macro.dxy)
        }

        print("🌐 Fetching fresh macro data (VIX/DXY) from Alpha Vantage...")

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
        print("📊 Fetching Taapi.io data sequentially (16s delay between calls)...")

        // First call: RSI
        await waitForTaapiRateLimit()
        let rsi = await fetchRSI(coin: coin)

        // Second call: SMA200
        await waitForTaapiRateLimit()
        let sma = await fetchSMA200(coin: coin)

        // Third call: Current Price
        await waitForTaapiRateLimit()
        let price = await fetchCurrentPrice(coin: coin)

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
            print("⏳ Rate limit: waiting \(String(format: "%.1f", waitTime))s before next Taapi.io call...")
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        lastTaapiCallTime = Date()
    }

    // MARK: - Individual Fetch Methods

    private func fetchRSI(coin: String) async -> Double? {
        do {
            let symbol = "\(coin.uppercased())/USDT"
            let rsi = try await technicalService.fetchRSI(
                symbol: symbol,
                exchange: "binance",
                interval: "1d",
                period: 14
            )
            print("📊 RSI for \(coin): \(rsi)")
            return rsi
        } catch {
            print("⚠️ RSI fetch failed for \(coin): \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchSMA200(coin: String) async -> Double? {
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
                print("📊 SMA200 for \(coin): \(sma)")
            }
            return sma200
        } catch {
            print("⚠️ SMA200 fetch failed for \(coin): \(error.localizedDescription)")
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
            print("📊 Price for \(coin): \(price)")
            return price
        } catch {
            print("⚠️ Price fetch failed for \(coin): \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchFundingRate() async -> Double? {
        do {
            let fundingData = try await sentimentService.fetchFundingRate()
            print("📊 Funding Rate: \(fundingData.averageRate)")
            return fundingData.averageRate
        } catch {
            print("⚠️ Funding rate fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchFearGreed() async -> Double? {
        do {
            let fearGreed = try await sentimentService.fetchFearGreedIndex()
            print("📊 Fear & Greed: \(fearGreed.value)")
            return Double(fearGreed.value)
        } catch {
            print("⚠️ Fear & Greed fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchVIX() async -> Double? {
        do {
            guard let vixData = try await vixService.fetchLatestVIX() else {
                print("⚠️ VIX data unavailable (nil response)")
                return nil
            }
            print("📊 VIX: \(vixData.value)")
            return vixData.value
        } catch {
            print("⚠️ VIX fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchDXY() async -> Double? {
        do {
            guard let dxyData = try await dxyService.fetchLatestDXY() else {
                print("⚠️ DXY data unavailable (nil response)")
                return nil
            }
            print("📊 DXY: \(dxyData.value)")
            return dxyData.value
        } catch {
            print("⚠️ DXY fetch failed: \(error.localizedDescription)")
            return nil
        }
    }
}
