import SwiftUI

// MARK: - Sentiment View Model
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

    // MARK: - Properties
    var isLoading = false
    var errorMessage: String?

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

    // Enhanced Risk History (per-coin)
    var riskHistoryCache: [String: [RiskHistoryPoint]] = [:]

    // Multi-Factor Risk (enhanced model)
    var multiFactorRisk: MultiFactorRiskPoint?
    var multiFactorRiskCache: [String: MultiFactorRiskPoint] = [:]
    var isLoadingMultiFactorRisk = false

    // Market Overview Data
    var bitcoinSearchIndex: Int = 66
    var totalMarketCap: Double = 0
    var marketCapChange24h: Double = 0
    var marketCapHistory: [Double] = []

    // Historical Data
    var fearGreedHistory: [FearGreedIndex] = []
    var googleTrendsHistory: [GoogleTrendsDTO] = []

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
            let longPercent = (liq.longLiquidations / liq.total24h) * 100
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
        macroStatisticsService: MacroStatisticsServiceProtocol = ServiceContainer.shared.macroStatisticsService
    ) {
        self.sentimentService = sentimentService
        self.marketService = marketService
        self.itcRiskService = itcRiskService
        self.vixService = vixService
        self.dxyService = dxyService
        self.globalLiquidityService = globalLiquidityService
        self.macroStatisticsService = macroStatisticsService
        Task { await loadInitialData() }
    }

    // MARK: - Public Methods
    func refresh() async {
        isLoading = true
        errorMessage = nil

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

        // Await all results (none will throw since they use safe wrappers)
        let (fg, btc, etf, funding, liq, alt, risk) = await (fgTask, btcTask, etfTask, fundingTask, liqTask, altTask, riskTask)
        let (appRankings, arkLineScore, trends) = await (appRankingsTask, arkLineScoreTask, googleTrendsTask)
        let allRiskResults = await allRiskResultsTask
        let marketOverview = await marketOverviewTask
        let marketCapSparkline = await marketCapHistoryTask
        let (vix, dxy, globalM2) = await (vixTask, dxyTask, globalM2Task)
        let zScores = await zScoresTask

        await MainActor.run {
            // Core indicators (only update if we got data)
            if let fg = fg { self.fearGreedIndex = fg }
            if let btc = btc { self.btcDominance = btc }

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

            // Macro Indicators
            self.vixData = vix
            self.dxyData = dxy
            self.globalM2Data = globalM2

            // Macro Z-Scores
            self.macroZScores = zScores

            // Check for extreme moves and trigger alerts
            ExtremeMoveAlertManager.shared.checkAllForExtremeMoves(zScores)

            // Update search index from Google Trends
            if let trends = trends {
                self.bitcoinSearchIndex = trends.currentIndex
            }

            self.isLoading = false
        }

        // Surface failures via toast (only when multiple core indicators fail)
        await notifyFailures(
            fg: fg, btc: btc, marketOverview: marketOverview,
            vix: vix, dxy: dxy, globalM2: globalM2
        )

        // Archive all sentiment/macro indicators (fire-and-forget)
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

    // MARK: - Private Methods
    private func loadInitialData() async {
        await refresh()
        await fetchFearGreedHistory()
        await fetchGoogleTrendsHistory()
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

    // MARK: - Enhanced Risk Methods

    /// Fetch enhanced risk history for a specific coin
    /// - Parameters:
    ///   - coin: Coin symbol (BTC, ETH, etc.)
    ///   - days: Number of days of history (nil for all available)
    /// - Returns: Array of enhanced risk history points
    func fetchEnhancedRiskHistory(coin: String, days: Int? = nil) async -> [RiskHistoryPoint] {
        // Check cache first
        let cacheKey = "\(coin)_\(days ?? 0)"
        if let cached = riskHistoryCache[cacheKey] {
            return cached
        }

        do {
            let history = try await itcRiskService.fetchRiskHistory(coin: coin, days: days)
            await MainActor.run {
                self.riskHistoryCache[cacheKey] = history
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
    }

    // MARK: - Multi-Factor Risk Methods

    /// Fetch multi-factor risk combining 6 data sources
    /// - Parameter coin: Coin symbol (BTC, ETH)
    /// - Returns: Multi-factor risk point with full breakdown
    func fetchMultiFactorRisk(coin: String) async -> MultiFactorRiskPoint? {
        // Check cache first
        if let cached = multiFactorRiskCache[coin] {
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
        multiFactorRisk = nil
    }

    /// Refresh multi-factor risk (force fetch)
    func refreshMultiFactorRisk(coin: String) async -> MultiFactorRiskPoint? {
        multiFactorRiskCache.removeValue(forKey: coin)
        return await fetchMultiFactorRisk(coin: coin)
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
