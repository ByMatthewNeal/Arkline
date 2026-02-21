import SwiftUI

// MARK: - Sentiment View Model
@MainActor
@Observable
class SentimentViewModel {
    // MARK: - Dependencies
    private let sentimentService: SentimentServiceProtocol
    private let marketService: MarketServiceProtocol
    private let itcRiskService: ITCRiskServiceProtocol
    private let vixService: VIXServiceProtocol
    private let dxyService: DXYServiceProtocol
    private let globalLiquidityService: GlobalLiquidityServiceProtocol
    private let macroStatisticsService: MacroStatisticsServiceProtocol
    private let coinglassService: CoinglassServiceProtocol

    /// When false, skips fire-and-forget archival/alerting (for unit tests)
    private let enableSideEffects: Bool

    // MARK: - Properties
    var isLoading = false
    var errorMessage: String?
    var lastRefreshed: Date?

    // Sentiment Indicators
    var fearGreedIndex: FearGreedIndex?
    var btcDominance: BTCDominance?
    var etfNetFlow: ETFNetFlow?
    var fundingRate: FundingRate?
    var liquidations: LiquidationData?
    var altcoinSeason: AltcoinSeasonIndex?
    var globalLiquidity: GlobalLiquidity?

    // Macro Indicators (VIX, DXY, Global M2)
    var vixData: VIXData?
    var dxyData: DXYData?
    var globalM2Data: GlobalLiquidityChanges?

    // Macro Z-Scores (statistical analysis)
    var macroZScores: [MacroIndicatorType: MacroZScoreData] = [:]

    /// Whether any macro indicator has an extreme z-score
    var hasExtremeMacroMove: Bool {
        macroZScores.values.contains { $0.isExtreme }
    }

    // Legacy single app ranking (backwards compatibility)
    var appStoreRanking: AppStoreRanking?

    // NEW: Multiple App Store Rankings (Coinbase, Binance, Kraken, etc.)
    var appStoreRankings: [AppStoreRanking] = []

    // NEW: ArkLine Proprietary Risk Score (0-100)
    var arkLineRiskScore: ArkLineRiskScore?

    // NEW: Google Trends Data
    var googleTrends: GoogleTrendsData?

    // Legacy risk level (backwards compatibility)
    var riskLevel: RiskLevel?

    // ITC Risk Levels
    var riskLevels: [String: ITCRiskLevel] = [:]
    var riskHistories: [String: [ITCRiskLevel]] = [:]
    var consecutiveDays: [String: Int] = [:]

    // Enhanced Risk History (per-coin) with TTL
    var riskHistoryCache: [String: [RiskHistoryPoint]] = [:]
    private var riskHistoryCacheTimestamps: [String: Date] = [:]

    // Multi-Factor Risk (enhanced model) with TTL
    var multiFactorRisk: MultiFactorRiskPoint?
    var multiFactorRiskCache: [String: MultiFactorRiskPoint] = [:]
    private var multiFactorRiskCacheTimestamps: [String: Date] = [:]
    var isLoadingMultiFactorRisk = false

    /// Cache TTL for risk data (5 minutes)
    private let riskCacheTTL: TimeInterval = 300

    // Market Overview Data
    var bitcoinSearchIndex: Int = 66
    var totalMarketCap: Double = 0
    var marketCapChange24h: Double = 0
    var marketCapHistory: [Double] = []

    // Historical Data
    var fearGreedHistory: [FearGreedIndex] = []
    var googleTrendsHistory: [GoogleTrendsDTO] = []

    // Capital Rotation
    var dominanceSnapshot: DominanceSnapshot?
    var capitalRotation: CapitalRotationSignal?

    // Derivatives (Coinglass)
    var btcOpenInterest: OpenInterestData?

    // Sentiment Regime Quadrant
    var sentimentRegimeData: SentimentRegimeData?
    var isLoadingRegimeData = false

    // MARK: - Computed Properties for UI

    /// Overall market sentiment tier based on ArkLine Risk Score
    var overallSentimentTier: SentimentTier {
        arkLineRiskScore?.tier ?? .neutral
    }

    /// Primary app for display (Coinbase as main indicator)
    var primaryAppRanking: AppStoreRanking? {
        appStoreRankings.first { $0.appName == "Coinbase" } ?? appStoreRankings.first
    }

    /// Average app store ranking change (sentiment indicator)
    var averageAppStoreChange: Int {
        guard !appStoreRankings.isEmpty else { return 0 }
        let total = appStoreRankings.reduce(0) { $0 + $1.change }
        return total / appStoreRankings.count
    }

    /// Composite app store sentiment (calculated from Coinbase, Binance, Kraken)
    var appStoreCompositeSentiment: AppStoreCompositeSentiment {
        // Filter to primary apps and iOS US rankings for the composite
        let primaryRankings = appStoreRankings.filter { ranking in
            ["Coinbase", "Binance", "Kraken"].contains(ranking.appName) &&
            ranking.platform == .ios &&
            (ranking.region == .us || (ranking.appName == "Binance" && ranking.region == .global))
        }
        return AppStoreRankingCalculator.calculateComposite(from: primaryRankings)
    }

    /// Get rankings filtered by platform and region
    func filteredRankings(platform: AppPlatform? = nil, region: AppRegion? = nil, apps: [String]? = nil) -> [AppStoreRanking] {
        appStoreRankings.filter { ranking in
            let platformMatch = platform == nil || ranking.platform == platform
            let regionMatch = region == nil || ranking.region == region
            let appMatch = apps?.contains(ranking.appName) ?? true
            return platformMatch && regionMatch && appMatch
        }
    }

    /// Get the best ranking for a specific app across all platforms/regions
    func bestRanking(for appName: String) -> AppStoreRanking? {
        appStoreRankings
            .filter { $0.appName == appName }
            .min(by: { $0.ranking < $1.ranking })
    }

    /// Is it Bitcoin season based on altcoin index?
    var isBitcoinSeason: Bool {
        altcoinSeason?.isBitcoinSeason ?? true
    }

    /// Season display text
    var seasonDisplayText: String {
        guard let alt = altcoinSeason else { return "Loading..." }
        return alt.isBitcoinSeason ? "Bitcoin Season" : "Altcoin Season"
    }

    // MARK: - Computed Properties
    var overallSentiment: SentimentLevel {
        guard let fg = fearGreedIndex else { return .neutral }

        switch fg.value {
        case 0..<25: return .extremeFear
        case 25..<45: return .fear
        case 45..<55: return .neutral
        case 55..<75: return .greed
        default: return .extremeGreed
        }
    }

    var sentimentCards: [SentimentCardData] {
        var cards: [SentimentCardData] = []

        if let fg = fearGreedIndex {
            cards.append(SentimentCardData(
                id: "fear_greed",
                title: "Fear & Greed",
                value: "\(fg.value)",
                subtitle: fg.classification,
                change: nil,
                icon: "gauge.with.needle.fill",
                color: Color(hex: fg.level.color.replacingOccurrences(of: "#", with: ""))
            ))
        }

        if let btc = btcDominance {
            cards.append(SentimentCardData(
                id: "btc_dominance",
                title: "BTC Dominance",
                value: btc.displayValue,
                subtitle: btc.change24h >= 0 ? "Increasing" : "Decreasing",
                change: btc.change24h,
                icon: "bitcoinsign.circle.fill",
                color: Color(hex: "F7931A")
            ))
        }

        if let etf = etfNetFlow {
            cards.append(SentimentCardData(
                id: "etf_flow",
                title: "ETF Net Flow",
                value: etf.dailyFormatted,
                subtitle: etf.isPositive ? "Inflow" : "Outflow",
                change: nil,
                icon: "arrow.left.arrow.right.circle.fill",
                color: etf.isPositive ? Color(hex: "22C55E") : Color(hex: "EF4444")
            ))
        }

        if let funding = fundingRate {
            cards.append(SentimentCardData(
                id: "funding_rate",
                title: "Funding Rate",
                value: funding.displayRate,
                subtitle: funding.sentiment,
                change: nil,
                icon: "percent",
                color: funding.averageRate >= 0 ? Color(hex: "22C55E") : Color(hex: "EF4444")
            ))
        }

        if let liq = liquidations {
            let longPercent = liq.total24h > 0 ? (liq.longLiquidations / liq.total24h) * 100 : 50
            cards.append(SentimentCardData(
                id: "liquidations",
                title: "24h Liquidations",
                value: liq.totalFormatted,
                subtitle: String(format: "%.0f%% Long", longPercent),
                change: nil,
                icon: "flame.fill",
                color: Color(hex: "F97316")
            ))
        }

        if let alt = altcoinSeason {
            cards.append(SentimentCardData(
                id: "altcoin_season",
                title: "Altcoin Season",
                value: "\(alt.value)",
                subtitle: alt.season,
                change: nil,
                icon: "sparkles",
                color: alt.isBitcoinSeason ? Color(hex: "F7931A") : Color(hex: "8B5CF6")
            ))
        }

        return cards
    }

    // MARK: - Initialization
    init(
        sentimentService: SentimentServiceProtocol = ServiceContainer.shared.sentimentService,
        marketService: MarketServiceProtocol = ServiceContainer.shared.marketService,
        itcRiskService: ITCRiskServiceProtocol = ServiceContainer.shared.itcRiskService,
        vixService: VIXServiceProtocol = ServiceContainer.shared.vixService,
        dxyService: DXYServiceProtocol = ServiceContainer.shared.dxyService,
        globalLiquidityService: GlobalLiquidityServiceProtocol = ServiceContainer.shared.globalLiquidityService,
        macroStatisticsService: MacroStatisticsServiceProtocol = ServiceContainer.shared.macroStatisticsService,
        coinglassService: CoinglassServiceProtocol = ServiceContainer.shared.coinglassService,
        enableSideEffects: Bool = true
    ) {
        self.sentimentService = sentimentService
        self.marketService = marketService
        self.itcRiskService = itcRiskService
        self.vixService = vixService
        self.dxyService = dxyService
        self.globalLiquidityService = globalLiquidityService
        self.macroStatisticsService = macroStatisticsService
        self.coinglassService = coinglassService
        self.enableSideEffects = enableSideEffects
    }

    // MARK: - Public Methods
    func refresh() async {
        isLoading = true
        errorMessage = nil

        // Trigger Wikipedia pageview collection (fire-and-forget, rate limited to 1x/hour)
        if enableSideEffects {
            Task { await sentimentService.refreshTrendsData() }
        }

        // Fetch all indicators independently using safe wrappers
        // This ensures one failure doesn't block others
        async let fgTask = fetchFearGreedSafe()
        async let btcTask = fetchBTCDominanceSafe()
        async let etfTask = fetchETFSafe()
        async let fundingTask = fetchFundingSafe()
        async let liqTask = fetchLiquidationsSafe()
        async let altTask = fetchAltcoinSeasonSafe()
        async let riskTask = fetchRiskLevelSafe()

        // NEW: Enhanced indicators
        async let appRankingsTask = fetchAppStoreRankingsSafe()
        async let arkLineScoreTask = fetchArkLineRiskScoreSafe()
        async let googleTrendsTask = fetchGoogleTrendsSafe()

        // ITC Risk Levels (fetch all supported coins)
        let allRiskCoins = AssetRiskConfig.allConfigs.map(\.assetId)
        async let allRiskResultsTask = fetchAllRiskLevels(coins: allRiskCoins)

        // Market Overview (market cap from CoinGecko global)
        async let marketOverviewTask = fetchMarketOverviewSafe()

        // Market cap sparkline (7-day BTC market cap as proxy)
        async let marketCapHistoryTask = fetchMarketCapHistorySafe()

        // Macro Indicators (VIX, DXY, Global M2)
        async let vixTask = fetchVIXSafe()
        async let dxyTask = fetchDXYSafe()
        async let globalM2Task = fetchGlobalM2Safe()

        // Macro Z-Scores (statistical analysis)
        async let zScoresTask = fetchMacroZScoresSafe()

        // Derivatives (Coinglass)
        async let btcOITask = fetchBTCOpenInterestSafe()

        // Await all results (none will throw since they use safe wrappers)
        let (fg, btc, etf, funding, liq, alt, risk) = await (fgTask, btcTask, etfTask, fundingTask, liqTask, altTask, riskTask)
        let (appRankings, arkLineScore, trends) = await (appRankingsTask, arkLineScoreTask, googleTrendsTask)
        let allRiskResults = await allRiskResultsTask
        let marketOverview = await marketOverviewTask
        let marketCapSparkline = await marketCapHistoryTask
        let (vix, dxy, globalM2) = await (vixTask, dxyTask, globalM2Task)
        let zScores = await zScoresTask
        let btcOI = await btcOITask

        // Core indicators (set unconditionally so stale data clears on failure)
        self.fearGreedIndex = fg
        self.btcDominance = btc

        // Market cap from global data
        if let overview = marketOverview {
            self.totalMarketCap = overview.totalMarketCap
            self.marketCapChange24h = overview.marketCapChange24h
        }
        if let sparkline = marketCapSparkline {
            self.marketCapHistory = sparkline
        }
        self.etfNetFlow = etf
        self.fundingRate = funding
        self.liquidations = liq
        self.altcoinSeason = alt
        self.riskLevel = risk

        // Enhanced indicators
        self.appStoreRankings = appRankings ?? []
        self.appStoreRanking = appRankings?.first // Legacy compatibility
        self.arkLineRiskScore = arkLineScore
        self.googleTrends = trends

        // ITC Risk Levels (all coins)
        for (coin, level, history) in allRiskResults {
            if let level = level { self.riskLevels[coin] = level }
            self.riskHistories[coin] = history
        }
        self.consecutiveDays = computeConsecutiveDays()

        // Macro Indicators
        self.vixData = vix
        self.dxyData = dxy
        self.globalM2Data = globalM2

        // Macro Z-Scores
        self.macroZScores = zScores

        // Derivatives
        self.btcOpenInterest = btcOI

        // Check for extreme moves and trigger alerts
        if enableSideEffects {
            ExtremeMoveAlertManager.shared.checkAllForExtremeMoves(zScores)
        }

        // Update search index from Google Trends
        if let trends = trends {
            self.bitcoinSearchIndex = trends.currentIndex
        }

        self.isLoading = false
        self.lastRefreshed = Date()

        // Surface failures via toast (only when multiple core indicators fail)
        if enableSideEffects {
            notifyFailures(
                fg: fg, btc: btc, marketOverview: marketOverview,
                vix: vix, dxy: dxy, globalM2: globalM2
            )
        }

        // Archive all sentiment/macro indicators (fire-and-forget)
        guard enableSideEffects else { return }
        Task {
            let collector = MarketDataCollector.shared
            if let fg = fg {
                await collector.recordIndicator(
                    name: "fear_greed", value: Double(fg.value),
                    metadata: ["classification": .string(fg.classification)]
                )
            }
            if let btc = btc {
                await collector.recordIndicator(
                    name: "btc_dominance", value: btc.value,
                    metadata: ["change_24h": .double(btc.change24h)]
                )
            }
            if let etf = etf {
                await collector.recordIndicator(
                    name: "etf_net_flow", value: etf.dailyNetFlow,
                    metadata: ["total_net_flow": .double(etf.totalNetFlow)]
                )
            }
            if let funding = funding {
                await collector.recordIndicator(name: "funding_rate", value: funding.averageRate)
            }
            if let liq = liq {
                await collector.recordIndicator(
                    name: "liquidations", value: liq.total24h,
                    metadata: ["long": .double(liq.longLiquidations), "short": .double(liq.shortLiquidations)]
                )
            }
            if let alt = alt {
                await collector.recordIndicator(
                    name: "altcoin_season", value: Double(alt.value),
                    metadata: ["is_bitcoin_season": .bool(alt.isBitcoinSeason),
                               "calculation_window": .int(alt.calculationWindow)]
                )
            }
            if let vix = vix {
                await collector.recordIndicator(name: "vix", value: vix.value)
            }
            if let dxy = dxy {
                await collector.recordIndicator(name: "dxy", value: dxy.value)
            }
            if let m2 = globalM2 {
                await collector.recordIndicator(
                    name: "global_m2", value: m2.current,
                    metadata: ["weekly_change": .double(m2.weeklyChange), "monthly_change": .double(m2.monthlyChange), "yearly_change": .double(m2.yearlyChange)]
                )
            }
            if let arkLineScore = arkLineScore {
                await collector.recordRiskScore(arkLineScore)
            }
            if let overview = marketOverview {
                await collector.recordIndicator(
                    name: "total_market_cap", value: overview.totalMarketCap,
                    metadata: ["change_24h_pct": .double(overview.marketCapChange24h),
                               "total_volume_24h": .double(overview.totalVolume24h)]
                )
            }
            if let trends = trends {
                await collector.recordIndicator(
                    name: "google_trends_bitcoin", value: Double(trends.currentIndex)
                )
            }
            if let rankings = appRankings, !rankings.isEmpty {
                var rankMeta: [String: AnyCodableValue] = [:]
                for r in rankings {
                    rankMeta[r.appName.lowercased()] = .int(r.ranking)
                }
                await collector.recordIndicator(
                    name: "app_store_rankings", value: Double(rankings.first?.ranking ?? 0),
                    metadata: rankMeta
                )
            }
            if let oi = btcOI {
                await collector.recordIndicator(
                    name: "btc_open_interest", value: oi.openInterest,
                    metadata: [
                        "change_24h": .double(oi.openInterestChange24h),
                        "change_pct_24h": .double(oi.openInterestChangePercent24h)
                    ]
                )
            }
        }
    }

    func fetchFearGreedHistory(days: Int = 30) async {
        do {
            let history = try await sentimentService.fetchFearGreedHistory(days: days)
            await MainActor.run {
                self.fearGreedHistory = history
            }
        } catch {
            // Silently fail for history - not critical
        }
    }

    func fetchGoogleTrendsHistory(limit: Int = 30) async {
        do {
            let history = try await SupabaseDatabase.shared.getGoogleTrendsHistory(limit: limit)
            await MainActor.run {
                self.googleTrendsHistory = history
            }
        } catch {
            // Silently fail for history - not critical
        }
    }

    /// Fetches BTC volume data and computes the sentiment regime quadrant
    /// using composite scores from all available live indicators.
    ///
    /// Updates are scheduled for **Sunday and Wednesday at 00:15 UTC** only.
    /// Between windows the cached result is reused from disk.
    func fetchSentimentRegime() async {
        // Check schedule: only recompute after a new Sunday/Wednesday 00:15 UTC window
        if let cached = Self.loadCachedRegimeData() {
            let lastWindow = Self.mostRecentScheduledUpdate(before: Date())
            if cached.computedAt >= lastWindow {
                self.sentimentRegimeData = cached.data
                return
            }
        }

        guard !fearGreedHistory.isEmpty else { return }

        isLoadingRegimeData = true
        defer { isLoadingRegimeData = false }

        do {
            let chart = try await marketService.fetchCoinMarketChart(
                id: "bitcoin", currency: "usd", days: 90
            )

            // Build live indicator snapshot for composite "Now" point
            let liveIndicators = RegimeIndicatorSnapshot(
                fundingRate: fundingRate?.averageRate,
                btcRiskLevel: riskLevels["BTC"]?.riskLevel,
                altcoinSeason: altcoinSeason?.value,
                btcDominance: btcDominance?.value,
                appStoreScore: appStoreRankings.isEmpty ? nil : appStoreCompositeSentiment.score,
                searchInterest: googleTrends?.currentIndex ?? (bitcoinSearchIndex != 66 ? bitcoinSearchIndex : nil),
                capitalRotation: capitalRotation?.score,
                openInterestChangePct: btcOpenInterest?.openInterestChangePercent24h
            )

            let data = SentimentRegimeService.computeRegimeData(
                fearGreedHistory: fearGreedHistory,
                volumeData: chart.totalVolumes,
                priceData: chart.prices,
                liveIndicators: liveIndicators
            )
            self.sentimentRegimeData = data

            // Persist to disk and archive
            if let data = data {
                Self.saveCachedRegimeData(data)
                if enableSideEffects {
                    Task { await MarketDataCollector.shared.recordRegimeSnapshot(data) }
                    SentimentRegimeAlertManager.shared.checkRegimeShift(newRegime: data.currentRegime)
                }
            }
        } catch {
            logWarning("Failed to compute sentiment regime: \(error.localizedDescription)", category: .data)
        }
    }

    /// Fetches multi-dominance data and computes the capital rotation signal.
    func fetchCapitalRotation() async {
        do {
            let snapshot = try await sentimentService.fetchDominanceSnapshot()
            let previous = CapitalRotationService.loadPreviousSnapshot()
            let rotation = CapitalRotationService.computeRotationSignal(current: snapshot, previous: previous)
            CapitalRotationService.savePreviousSnapshot(snapshot)
            await MainActor.run {
                self.dominanceSnapshot = snapshot
                self.capitalRotation = rotation
            }
        } catch {
            logWarning("Failed to fetch capital rotation: \(error.localizedDescription)", category: .data)
        }
    }

    func retrySentimentRegime() async {
        if fearGreedHistory.isEmpty {
            await fetchFearGreedHistory(days: 90)
        }
        await fetchSentimentRegime()
    }

    // MARK: - Private Methods
    func loadInitialData() async {
        await refresh()
        await fetchFearGreedHistory(days: 90)
        await fetchGoogleTrendsHistory()
        await fetchCapitalRotation()
        await fetchSentimentRegime()
    }

    // MARK: - Individual Retry Methods

    func retryFearGreed() async {
        if let result = try? await sentimentService.fetchFearGreedIndex() {
            await MainActor.run { self.fearGreedIndex = result }
        }
    }

    func retryBTCDominance() async {
        if let result = try? await sentimentService.fetchBTCDominance() {
            await MainActor.run { self.btcDominance = result }
        }
    }

    func retryAltcoinSeason() async {
        if let result = try? await sentimentService.fetchAltcoinSeason() {
            await MainActor.run { self.altcoinSeason = result }
        }
    }

    func retryArkLineScore() async {
        if let result = try? await sentimentService.fetchArkLineRiskScore() {
            await MainActor.run { self.arkLineRiskScore = result }
        }
    }

    func retryAppStoreRankings() async {
        if let result = try? await sentimentService.fetchAppStoreRankings() {
            await MainActor.run {
                self.appStoreRankings = result
                self.appStoreRanking = result.first
            }
        }
    }

    func retryFundingRate() async {
        if let result = try? await sentimentService.fetchFundingRate() {
            await MainActor.run { self.fundingRate = result }
        }
    }

    // MARK: - Failure Notifications

    @MainActor
    private func notifyFailures(
        fg: FearGreedIndex?, btc: BTCDominance?, marketOverview: MarketOverview?,
        vix: VIXData?, dxy: DXYData?, globalM2: GlobalLiquidityChanges?
    ) {
        var failedCore: [String] = []
        if fg == nil { failedCore.append("Fear & Greed") }
        if btc == nil { failedCore.append("BTC Dominance") }
        if marketOverview == nil { failedCore.append("Market Cap") }

        var failedMacro: [String] = []
        if vix == nil { failedMacro.append("VIX") }
        if dxy == nil { failedMacro.append("DXY") }
        if globalM2 == nil { failedMacro.append("Global M2") }

        let totalFailed = failedCore.count + failedMacro.count
        if totalFailed >= 3 {
            ToastManager.shared.warning(
                "Some data unavailable",
                message: "\(totalFailed) indicators couldn't be updated"
            )
        } else if !failedCore.isEmpty {
            ToastManager.shared.warning(
                "\(failedCore.joined(separator: ", ")) unavailable"
            )
        }
    }

    // Safe fetch methods that return nil on error (for non-critical data)
    private func fetchFearGreedSafe() async -> FearGreedIndex? {
        try? await sentimentService.fetchFearGreedIndex()
    }

    private func fetchBTCDominanceSafe() async -> BTCDominance? {
        try? await sentimentService.fetchBTCDominance()
    }

    private func fetchETFSafe() async -> ETFNetFlow? {
        try? await sentimentService.fetchETFNetFlow()
    }

    private func fetchFundingSafe() async -> FundingRate? {
        try? await sentimentService.fetchFundingRate()
    }

    private func fetchLiquidationsSafe() async -> LiquidationData? {
        try? await sentimentService.fetchLiquidations()
    }

    private func fetchAltcoinSeasonSafe() async -> AltcoinSeasonIndex? {
        try? await sentimentService.fetchAltcoinSeason()
    }

    private func fetchRiskLevelSafe() async -> RiskLevel? {
        try? await sentimentService.fetchRiskLevel()
    }

    private func fetchAppStoreRankingsSafe() async -> [AppStoreRanking]? {
        try? await sentimentService.fetchAppStoreRankings()
    }

    private func fetchArkLineRiskScoreSafe() async -> ArkLineRiskScore? {
        try? await sentimentService.fetchArkLineRiskScore()
    }

    private func fetchGoogleTrendsSafe() async -> GoogleTrendsData? {
        try? await sentimentService.fetchGoogleTrends()
    }

    private func fetchITCRiskLevelSafe(coin: String) async -> ITCRiskLevel? {
        try? await itcRiskService.fetchLatestRiskLevel(coin: coin)
    }

    private func fetchITCRiskHistorySafe(coin: String) async -> [ITCRiskLevel]? {
        try? await itcRiskService.fetchRiskLevel(coin: coin)
    }

    private func fetchAllRiskLevels(coins: [String]) async -> [(String, ITCRiskLevel?, [ITCRiskLevel])] {
        await withTaskGroup(of: (String, ITCRiskLevel?, [ITCRiskLevel]).self) { group in
            for coin in coins {
                group.addTask { [self] in
                    let level = await self.fetchITCRiskLevelSafe(coin: coin)
                    let history = await self.fetchITCRiskHistorySafe(coin: coin) ?? []
                    return (coin, level, history)
                }
            }
            var results: [(String, ITCRiskLevel?, [ITCRiskLevel])] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }

    private func fetchMarketOverviewSafe() async -> MarketOverview? {
        try? await sentimentService.fetchMarketOverview()
    }

    private func fetchMarketCapHistorySafe() async -> [Double]? {
        guard let chart = try? await marketService.fetchCoinMarketChart(id: "bitcoin", currency: "usd", days: 7) else {
            return nil
        }
        let values = chart.marketCaps.compactMap { pair -> Double? in
            guard pair.count >= 2 else { return nil }
            return pair[1]
        }
        return values.isEmpty ? nil : values
    }

    private func fetchVIXSafe() async -> VIXData? {
        try? await vixService.fetchLatestVIX()
    }

    private func fetchDXYSafe() async -> DXYData? {
        try? await dxyService.fetchLatestDXY()
    }

    private func fetchGlobalM2Safe() async -> GlobalLiquidityChanges? {
        try? await globalLiquidityService.fetchLiquidityChanges()
    }

    private func fetchMacroZScoresSafe() async -> [MacroIndicatorType: MacroZScoreData] {
        (try? await macroStatisticsService.fetchAllZScores()) ?? [:]
    }

    private func fetchBTCOpenInterestSafe() async -> OpenInterestData? {
        try? await coinglassService.fetchOpenInterest(symbol: "BTC")
    }

    // MARK: - Enhanced Risk Methods

    /// Fetch enhanced risk history for a specific coin
    /// - Parameters:
    ///   - coin: Coin symbol (BTC, ETH, etc.)
    ///   - days: Number of days of history (nil for all available)
    /// - Returns: Array of enhanced risk history points
    func fetchEnhancedRiskHistory(coin: String, days: Int? = nil) async -> [RiskHistoryPoint] {
        // Check cache with TTL
        let cacheKey = "\(coin)_\(days ?? 0)"
        if let cached = riskHistoryCache[cacheKey],
           let timestamp = riskHistoryCacheTimestamps[cacheKey],
           Date().timeIntervalSince(timestamp) < riskCacheTTL {
            return cached
        }

        do {
            let history = try await itcRiskService.fetchRiskHistory(coin: coin, days: days)
            await MainActor.run {
                self.riskHistoryCache[cacheKey] = history
                self.riskHistoryCacheTimestamps[cacheKey] = Date()
            }
            return history
        } catch {
            return []
        }
    }

    /// Get cached risk history for a coin (without fetching)
    func getCachedRiskHistory(coin: String, days: Int? = nil) -> [RiskHistoryPoint]? {
        let cacheKey = "\(coin)_\(days ?? 0)"
        return riskHistoryCache[cacheKey]
    }

    /// Clear risk history cache
    func clearRiskHistoryCache() {
        riskHistoryCache.removeAll()
        riskHistoryCacheTimestamps.removeAll()
    }

    // MARK: - Multi-Factor Risk Methods

    /// Fetch multi-factor risk combining 6 data sources
    /// - Parameter coin: Coin symbol (BTC, ETH)
    /// - Returns: Multi-factor risk point with full breakdown
    func fetchMultiFactorRisk(coin: String) async -> MultiFactorRiskPoint? {
        // Check cache with TTL
        if let cached = multiFactorRiskCache[coin],
           let timestamp = multiFactorRiskCacheTimestamps[coin],
           Date().timeIntervalSince(timestamp) < riskCacheTTL {
            return cached
        }

        await MainActor.run {
            self.isLoadingMultiFactorRisk = true
        }

        do {
            let riskPoint = try await itcRiskService.calculateMultiFactorRisk(coin: coin, weights: .default)
            await MainActor.run {
                self.multiFactorRisk = riskPoint
                self.multiFactorRiskCache[coin] = riskPoint
                self.multiFactorRiskCacheTimestamps[coin] = Date()
                self.isLoadingMultiFactorRisk = false
            }
            return riskPoint
        } catch {
            await MainActor.run {
                self.isLoadingMultiFactorRisk = false
            }
            return nil
        }
    }

    /// Get cached multi-factor risk
    func getCachedMultiFactorRisk(coin: String) -> MultiFactorRiskPoint? {
        multiFactorRiskCache[coin]
    }

    /// Clear multi-factor risk cache
    func clearMultiFactorRiskCache() {
        multiFactorRiskCache.removeAll()
        multiFactorRiskCacheTimestamps.removeAll()
        multiFactorRisk = nil
    }

    /// Refresh multi-factor risk (force fetch)
    func refreshMultiFactorRisk(coin: String) async -> MultiFactorRiskPoint? {
        multiFactorRiskCache.removeValue(forKey: coin)
        return await fetchMultiFactorRisk(coin: coin)
    }

    // MARK: - Regime Schedule Info

    /// When the current regime snapshot was computed (nil if never)
    var regimeLastUpdated: Date? {
        Self.loadCachedRegimeData()?.computedAt
    }

    /// Next scheduled regime update (the upcoming Sunday or Wednesday 00:15 UTC)
    var regimeNextUpdate: Date {
        Self.nextScheduledUpdate(after: Date())
    }

    // MARK: - Consecutive Days Computation

    private func computeConsecutiveDays() -> [String: Int] {
        var cache: [String: Int] = [:]
        for (coin, current) in riskLevels {
            let history = riskHistories[coin] ?? []
            guard !history.isEmpty else { continue }
            let currentCategory = current.riskCategory
            let currentRisk = current.riskLevel
            var count = 0
            for level in history.reversed() {
                if level.riskCategory == currentCategory ||
                    abs(level.riskLevel - currentRisk) < 0.05 {
                    count += 1
                } else {
                    break
                }
            }
            if count >= 1 { cache[coin] = count }
        }
        return cache
    }

    // MARK: - Regime Schedule Cache

    /// Wrapper for persisted regime data with computation timestamp
    private struct CachedRegimeData: Codable {
        let data: SentimentRegimeData
        let computedAt: Date
    }

    private static var regimeCacheURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return caches.appendingPathComponent("sentiment_regime_cache.json")
    }

    private static func loadCachedRegimeData() -> CachedRegimeData? {
        guard let raw = try? Data(contentsOf: regimeCacheURL) else { return nil }
        return try? JSONDecoder().decode(CachedRegimeData.self, from: raw)
    }

    private static func saveCachedRegimeData(_ regimeData: SentimentRegimeData) {
        let cached = CachedRegimeData(data: regimeData, computedAt: Date())
        if let raw = try? JSONEncoder().encode(cached) {
            try? raw.write(to: regimeCacheURL)
        }
    }

    /// Returns the most recent scheduled update time (Sunday or Wednesday at 00:15 UTC)
    /// before the given date.
    static func mostRecentScheduledUpdate(before date: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current

        var comps = cal.dateComponents([.year, .month, .day], from: date)
        comps.hour = 0
        comps.minute = 15
        comps.second = 0
        var candidate = cal.date(from: comps) ?? date

        // If we haven't passed today's 00:15 UTC yet, start from yesterday
        if date < candidate {
            candidate = cal.date(byAdding: .day, value: -1, to: candidate) ?? candidate
        }

        // Walk backwards (up to 7 days) to find Sunday(1) or Wednesday(4)
        for _ in 0..<7 {
            let weekday = cal.component(.weekday, from: candidate)
            if weekday == 1 || weekday == 4 { return candidate }
            candidate = cal.date(byAdding: .day, value: -1, to: candidate) ?? candidate
        }
        return candidate
    }

    /// Returns the next scheduled update time (Sunday or Wednesday 00:15 UTC)
    /// on or after the given date.
    static func nextScheduledUpdate(after date: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current

        var comps = cal.dateComponents([.year, .month, .day], from: date)
        comps.hour = 0
        comps.minute = 15
        comps.second = 0
        var candidate = cal.date(from: comps) ?? date

        // If today's 00:15 UTC has already passed, start from tomorrow
        if date >= candidate {
            candidate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }

        // Walk forward (up to 7 days) to find Sunday(1) or Wednesday(4)
        for _ in 0..<7 {
            let weekday = cal.component(.weekday, from: candidate)
            if weekday == 1 || weekday == 4 { return candidate }
            candidate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }
}

// MARK: - Sentiment Level
enum SentimentLevel {
    case extremeFear
    case fear
    case neutral
    case greed
    case extremeGreed

    var displayName: String {
        switch self {
        case .extremeFear: return "Extreme Fear"
        case .fear: return "Fear"
        case .neutral: return "Neutral"
        case .greed: return "Greed"
        case .extremeGreed: return "Extreme Greed"
        }
    }

    var color: Color {
        switch self {
        case .extremeFear: return Color(hex: "EF4444")
        case .fear: return Color(hex: "F97316")
        case .neutral: return Color(hex: "EAB308")
        case .greed: return Color(hex: "84CC16")
        case .extremeGreed: return Color(hex: "22C55E")
        }
    }
}

// MARK: - Sentiment Card Data
struct SentimentCardData: Identifiable {
    let id: String
    let title: String
    let value: String
    let subtitle: String
    let change: Double?
    let icon: String
    let color: Color
}
