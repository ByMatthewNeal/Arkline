import SwiftUI
import Combine

// MARK: - Home View Model
@MainActor
@Observable
class HomeViewModel {
    // MARK: - Dependencies
    private let sentimentService: SentimentServiceProtocol
    private let marketService: MarketServiceProtocol
    private let dcaService: DCAServiceProtocol
    private let newsService: NewsServiceProtocol
    private let portfolioService: PortfolioServiceProtocol
    private let itcRiskService: ITCRiskServiceProtocol
    private let vixService: VIXServiceProtocol
    private let dxyService: DXYServiceProtocol
    private let rainbowChartService: RainbowChartServiceProtocol
    private let globalLiquidityService: GlobalLiquidityServiceProtocol
    private let macroStatisticsService: MacroStatisticsServiceProtocol
    private let santimentService: SantimentServiceProtocol

    /// When false, skips fire-and-forget archival tasks (for unit tests)
    private let enableSideEffects: Bool

    // MARK: - Auto-Refresh
    private var refreshTimer: Timer?
    private var portfolioPriceTimer: Timer?
    private let refreshInterval: TimeInterval = 300 // 5 minutes for events
    private let portfolioPriceInterval: TimeInterval = 60 // 60 seconds for portfolio prices
    var eventsLastUpdated: Date?

    /// Whether a refresh is currently in flight (prevents stacking)
    private var isRefreshing = false

    /// Tracks QPS signal IDs already notified this session to prevent repeated push notifications
    private var notifiedQPSIds: Set<String> = []

    // MARK: - Properties
    var isLoading = false
    var errorMessage: String?

    /// Timestamp of last successful data refresh
    var lastRefreshed: Date?
    /// Number of fetch failures in the last refresh cycle
    var failedFetchCount = 0

    // Fear & Greed
    var fearGreedIndex: FearGreedIndex?

    // DCA Reminders
    var activeReminders: [DCAReminder] = []
    var todayReminders: [DCAReminder] = []

    // Today's Events
    var todaysEvents: [EconomicEvent] = []

    // Upcoming Events (high/medium impact + holidays)
    var upcomingEvents: [EconomicEvent] = []

    // Market Widgets Data
    var fedWatchMeetings: [FedWatchData] = []
    var newsItems: [NewsItem] = []
    var sentimentViewModel: SentimentViewModel?

    // Market Indicators (VIX, DXY, Rainbow, Liquidity, Supply in Profit)
    var vixData: VIXData?
    var vixHistory: [VIXData] = []
    var dxyData: DXYData?
    var dxyHistory: [DXYData] = []
    var rainbowChartData: RainbowChartData?
    var globalLiquidityChanges: GlobalLiquidityChanges?
    var supplyInProfitData: SupplyProfitData?

    // Net Liquidity (Fed balance sheet - TGA - RRP)
    var netLiquidityData: NetLiquidityChanges?

    // Global Liquidity Index (BIS + FRED composite, server-synced)
    var globalLiquidityIndex: GlobalLiquidityIndex?

    // Macro Z-Scores (statistical analysis)
    var macroZScores: [MacroIndicatorType: MacroZScoreData] = [:]

    // Canonical macro regime (single source of truth for all widgets)
    var currentRegimeResult: MacroRegimeResult?

    /// The quadrant embedded in the current briefing's text.
    /// Parsed from the ## Posture section so we detect when live quadrant diverges.
    private var briefingQuadrant: MacroRegimeQuadrant?

    /// Extract the quadrant from a briefing's text (## Posture section).
    private static func quadrantFromBriefingText(_ text: String) -> MacroRegimeQuadrant? {
        // Parse the ## Posture section
        let lines = text.components(separatedBy: "\n")
        var inPosture = false
        var postureText = ""
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("## posture") {
                inPosture = true
                continue
            }
            if inPosture {
                if trimmed.hasPrefix("## ") { break }
                postureText += " " + trimmed
            }
        }

        let lower = postureText.isEmpty ? text.lowercased() : postureText.lowercased()
        for q in MacroRegimeQuadrant.allCases {
            if lower.contains(q.rawValue.lowercased()) { return q }
        }
        // Fallback: broad match
        let isRiskOn = lower.contains("risk-on") || lower.contains("risk on")
        let isInflation = lower.contains("inflation") && !lower.contains("disinflation")
        if isRiskOn {
            return isInflation ? .riskOnInflation : .riskOnDisinflation
        } else {
            return isInflation ? .riskOffInflation : .riskOffDisinflation
        }
    }

    /// Simple 3-state regime derived from MacroRegimeCalculator
    var computedRegime: MarketRegime {
        currentRegimeResult?.baseRegime ?? .noData
    }

    /// Whether any macro indicator has an extreme z-score
    var hasExtremeMacroMove: Bool {
        macroZScores.values.contains { $0.isExtreme }
    }

    /// Get z-score for a specific indicator
    func zScore(for indicator: MacroIndicatorType) -> MacroZScoreData? {
        macroZScores[indicator]
    }

    // Flash Intel (strong swing signals)
    var flashIntelSignals: [TradeSignal] = []
    var signalStats: SignalStats?
    var marketConditions: SignalMarketConditions?
    private let swingSetupService = SwingSetupService()

    // QPS (Daily Positioning Signals)
    var qpsSignals: [DailyPositioningSignal] = []
    private let qpsService = PositioningSignalService()

    // Weekly Market Deck
    var latestDeck: MarketUpdateDeck?
    private let marketDeckService: MarketUpdateDeckServiceProtocol = ServiceContainer.shared.marketDeckService

    // Model Portfolio Updates
    var latestPortfolioTrade: ModelPortfolioTrade?
    var followedPortfolioName: String?
    private let modelPortfolioService: ModelPortfolioServiceProtocol = ServiceContainer.shared.modelPortfolioService

    // Market Summary
    var btcPrice: Double = 0
    var ethPrice: Double = 0
    var solPrice: Double = 0
    var btcChange24h: Double = 0
    var ethChange24h: Double = 0
    var solChange24h: Double = 0

    // Multiple Portfolios
    var portfolios: [Portfolio] = []
    var selectedPortfolio: Portfolio?
    var selectedTimePeriod: TimePeriod = .day
    var hasLoadedPortfolios = false

    // Portfolio Summary (real data from Supabase)
    var portfolioValue: Double = 0
    private var portfolioHoldings: [PortfolioHolding] = []
    private var portfolioHistory: [PortfolioHistoryPoint] = []

    // Time-period adjusted values (computed)
    var portfolioChange: Double {
        getChangeForTimePeriod(selectedTimePeriod).amount
    }

    var portfolioChangePercent: Double {
        getChangeForTimePeriod(selectedTimePeriod).percent
    }

    // Portfolio Chart Data - computed from real portfolio history
    var portfolioChartData: [CGFloat] {
        generateChartData(for: selectedTimePeriod)
    }

    /// Returns real change data for each time period using holdings and portfolio history
    private func getChangeForTimePeriod(_ period: TimePeriod) -> (amount: Double, percent: Double) {
        guard portfolioValue > 0 else { return (0, 0) }

        switch period {
        case .hour:
            // Approximate: 1/24th of the daily change
            let dayChange = calculateDayChange()
            let hourChange = dayChange / 24.0
            let previousValue = portfolioValue - hourChange
            let hourPercent = previousValue > 0 ? (hourChange / previousValue) * 100 : 0
            return (hourChange, hourPercent)

        case .day:
            // Use 24h price change from holdings
            let dayChange = calculateDayChange()
            let previousValue = portfolioValue - dayChange
            let dayPercent = previousValue > 0 ? (dayChange / previousValue) * 100 : 0
            return (dayChange, dayPercent)

        case .all:
            // All-time: compare current value to total cost basis
            let totalCost = portfolioHoldings.reduce(0) { $0 + $1.totalCost }
            guard totalCost > 0 else { return (0, 0) }
            let change = portfolioValue - totalCost
            let percent = (change / totalCost) * 100
            return (change, percent)

        default:
            // Use portfolio history for week/month/ytd/year
            let days = period.days
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let relevantHistory = portfolioHistory.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }

            guard let earliest = relevantHistory.first else {
                // No history for this period — fall back to cost basis
                let totalCost = portfolioHoldings.reduce(0) { $0 + $1.totalCost }
                guard totalCost > 0 else { return (0, 0) }
                let change = portfolioValue - totalCost
                let percent = (change / totalCost) * 100
                return (change, percent)
            }

            let change = portfolioValue - earliest.value
            let percent = earliest.value > 0 ? (change / earliest.value) * 100 : 0
            return (change, percent)
        }
    }

    /// Sum of 24h dollar changes across all holdings
    private func calculateDayChange() -> Double {
        portfolioHoldings.reduce(0.0) { total, holding in
            guard let change = holding.priceChangePercentage24h else { return total }
            return total + holding.currentValue * (change / 100)
        }
    }

    /// Generates chart data from real portfolio history points.
    /// For short periods (1H, 1D) where history snapshots are sparse,
    /// synthesizes a line from the computed 24h change so the chart
    /// matches the displayed percentage.
    private func generateChartData(for period: TimePeriod) -> [CGFloat] {
        guard portfolioValue > 0 else { return [] }

        let days = period.days
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        var relevantHistory = portfolioHistory
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }

        // Add current value as the latest point
        relevantHistory.append(PortfolioHistoryPoint(date: Date(), value: portfolioValue))

        // When history is sparse (< 5 points), synthesize a natural curve
        // so the sparkline doesn't render as a straight line.
        if relevantHistory.count < 5 {
            let change = getChangeForTimePeriod(period)
            let previousValue = portfolioValue - change.amount
            let startValue = previousValue > 0 ? previousValue : (portfolioHoldings.reduce(0) { $0 + $1.totalCost })
            if startValue > 0 {
                return synthesizeCurve(from: startValue, to: portfolioValue)
            }
            return [0.5, 0.5]
        }

        let values = relevantHistory.map { $0.value }
        return normalizeValues(values)
    }

    /// Normalizes an array of values to 0–1 range for sparkline rendering.
    private func normalizeValues(_ values: [Double]) -> [CGFloat] {
        guard let minVal = values.min(), let maxVal = values.max() else { return [] }
        let range = maxVal - minVal
        if range < 0.01 {
            // All values nearly equal — show a subtle slope based on direction
            // so the chart isn't misleadingly flat.
            guard values.count >= 2 else { return [0.5] }
            let first = values.first ?? 0, last = values.last ?? 0
            if last >= first {
                return [CGFloat(0.4), CGFloat(0.6)]
            } else {
                return [CGFloat(0.6), CGFloat(0.4)]
            }
        }
        return values.map { CGFloat(($0 - minVal) / range) }
    }

    /// Synthesizes a natural-looking curve between two values by generating
    /// intermediate points with deterministic variation based on the date.
    /// Produces 8 segments so the Catmull-Rom spline renders a smooth curve.
    private func synthesizeCurve(from startValue: Double, to endValue: Double, segments: Int = 8) -> [CGFloat] {
        let totalChange = endValue - startValue
        var values: [Double] = [startValue]

        // Use day-of-year as seed for deterministic but daily-varying wobble
        let daySeed = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1

        for i in 1..<segments {
            let progress = Double(i) / Double(segments)
            // Ease-in-out curve for the base trend
            let eased = progress * progress * (3.0 - 2.0 * progress)
            let baseValue = startValue + totalChange * eased

            // Add deterministic wobble (±3% of total change) using a simple hash
            let hash = (daySeed * 31 + i * 17) % 100
            let wobbleFactor = (Double(hash) / 100.0 - 0.5) * 0.06
            let wobble = abs(totalChange) * wobbleFactor

            values.append(baseValue + wobble)
        }

        values.append(endValue)
        return normalizeValues(values)
    }

    // Composite Risk Score (0-100)
    var compositeRiskScore: Int? = nil
    var arkLineRiskScore: ArkLineRiskScore? = nil

    // Risk Level (powers ArkLine Risk Score card)
    var riskLevels: [String: ITCRiskLevel] = [:]
    var riskHistories: [String: [ITCRiskLevel]] = [:]
    var selectedRiskCoin: String = "BTC"

    // User-selected risk coins from settings
    var userRiskCoins: [String] {
        UserDefaults.standard.stringArray(forKey: Constants.UserDefaults.riskCoins) ?? ["BTC", "ETH"]
    }

    // Computed property to get risk level for selected coin
    var selectedRiskLevel: ITCRiskLevel? {
        riskLevels[selectedRiskCoin]
    }

    // Get all risk levels for user's selected coins (with consecutive days + weekly avg)
    var userSelectedRiskLevels: [(coin: String, riskLevel: ITCRiskLevel?, daysAtLevel: Int?, weeklyAvgRisk: Double?)] {
        userRiskCoins.map { coin in
            let level = riskLevels[coin]
            let history = riskHistories[coin] ?? []
            return (coin, level, consecutiveDaysAtCurrentLevel(history: history, current: level), weeklyAverageRiskLevel(for: coin))
        }
    }

    // MARK: - Stock Risk Levels

    var stockRiskLevels: [String: ITCRiskLevel] = [:]
    var stockRiskHistories: [String: [ITCRiskLevel]] = [:]

    /// Default stocks to show risk for
    var stockRiskSymbols: [String] {
        AssetRiskConfig.stockConfigs.map(\.assetId)
    }

    /// Stock risk data formatted for MultiCoinRiskSection
    var stockSelectedRiskLevels: [(coin: String, riskLevel: ITCRiskLevel?, daysAtLevel: Int?, weeklyAvgRisk: Double?)] {
        stockRiskSymbols.compactMap { symbol in
            let level = stockRiskLevels[symbol]
            let history = stockRiskHistories[symbol] ?? []
            guard level != nil || !history.isEmpty else { return nil }
            return (symbol, level, consecutiveDaysAtCurrentLevel(history: history, current: level), stockWeeklyAvg(symbol))
        }
    }

    private func stockWeeklyAvg(_ symbol: String) -> Double? {
        guard let history = stockRiskHistories[symbol], history.count >= 3 else { return nil }
        let last7 = history.suffix(7)
        return last7.map(\.riskLevel).reduce(0, +) / Double(last7.count)
    }

    // Calculate consecutive days at current risk category
    private func consecutiveDaysAtCurrentLevel(history: [ITCRiskLevel], current: ITCRiskLevel?) -> Int? {
        guard let current = current, !history.isEmpty else { return nil }

        let currentCategory = current.riskCategory
        let currentRisk = current.riskLevel
        var count = 0

        // Count backwards from end of history.
        // Uses tolerance-based matching: the live price (current) and daily close
        // (history) can land in different categories when risk is near a boundary
        // (e.g. 0.40). A 0.05 tolerance bridges this live-vs-close gap without
        // masking genuine risk level changes.
        for level in history.reversed() {
            if level.riskCategory == currentCategory ||
                abs(level.riskLevel - currentRisk) < 0.05 {
                count += 1
            } else {
                break
            }
        }

        return count >= 1 ? count : nil
    }

    // Thread-safe date formatter for risk history parsing
    private static let riskDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // Calculate rolling 7-day average risk level from history
    private func weeklyAverageRiskLevel(for coin: String) -> Double? {
        let history = riskHistories[coin] ?? []
        guard !history.isEmpty else { return nil }
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentPoints = history.filter { level in
            guard let date = Self.riskDateFormatter.date(from: level.date) else { return false }
            return date >= sevenDaysAgo
        }
        guard recentPoints.count >= 3 else { return nil }
        return recentPoints.reduce(0.0) { $0 + $1.riskLevel } / Double(recentPoints.count)
    }

    // MARK: - Stock Risk Loading

    private func loadStockRiskLevels() async {
        guard let riskService = ServiceContainer.shared.itcRiskService as? APIITCRiskService else { return }

        // Process in batches of 4 to avoid overwhelming the network
        let batchSize = 4
        for batchStart in stride(from: 0, to: stockRiskSymbols.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, stockRiskSymbols.count)
            let batch = Array(stockRiskSymbols[batchStart..<batchEnd])

            await withTaskGroup(of: (String, ITCRiskLevel?).self) { group in
                for symbol in batch {
                    group.addTask {
                        do {
                            let risk = try await riskService.calculateStockCurrentRisk(symbol: symbol)
                            return (symbol, ITCRiskLevel(from: risk))
                        } catch {
                            return (symbol, nil)
                        }
                    }
                }

                for await (symbol, level) in group {
                    if let level {
                        stockRiskLevels[symbol] = level
                    }
                }
            }
        }

        // Archive stock risk levels to Supabase (fire-and-forget)
        if enableSideEffects {
            Task {
                let collector = MarketDataCollector.shared
                for (symbol, level) in stockRiskLevels {
                    await collector.recordIndicator(
                        name: "stock_risk_\(symbol.lowercased())",
                        value: level.riskLevel,
                        metadata: [
                            "symbol": .string(symbol),
                            "price": .double(level.price ?? 0),
                            "fair_value": .double(level.fairValue ?? 0),
                            "category": .string(RiskColors.category(for: level.riskLevel))
                        ]
                    )
                }
                // Also archive crypto risk levels
                for (coin, level) in riskLevels {
                    await collector.recordIndicator(
                        name: "crypto_risk_\(coin.lowercased())",
                        value: level.riskLevel,
                        metadata: [
                            "symbol": .string(coin),
                            "price": .double(level.price ?? 0),
                            "fair_value": .double(level.fairValue ?? 0),
                            "category": .string(RiskColors.category(for: level.riskLevel))
                        ]
                    )
                }
            }
        }

        // Load 7-day history in parallel batches after cards are populated
        for batchStart in stride(from: 0, to: stockRiskSymbols.count, by: 4) {
            let batchEnd = min(batchStart + 4, stockRiskSymbols.count)
            let batch = Array(stockRiskSymbols[batchStart..<batchEnd])

            await withTaskGroup(of: (String, [ITCRiskLevel]).self) { group in
                for symbol in batch {
                    group.addTask {
                        guard let history = try? await riskService.fetchStockRiskHistory(symbol: symbol, days: 30) else {
                            return (symbol, [])
                        }
                        return (symbol, history.map { ITCRiskLevel(from: $0) })
                    }
                }
                for await (symbol, history) in group {
                    if !history.isEmpty {
                        stockRiskHistories[symbol] = history
                    }
                }
            }
        }

        // Fetch live quotes for favorited stocks
        let favoriteStockSymbols = AssetRiskConfig.stockConfigs
            .map(\.assetId)
            .filter { FavoritesStore.shared.isFavorite($0) }
        if !favoriteStockSymbols.isEmpty {
            do {
                let quotes = try await FMPService.shared.fetchStockQuotes(symbols: favoriteStockSymbols)
                for quote in quotes {
                    cachedStockQuotes[quote.symbol.uppercased()] = quote
                }
            } catch {
                logDebug("Failed to fetch stock quotes for favorites: \(error.localizedDescription)", category: .network)
            }
        }
    }

    // Cached crypto assets for favorites filtering
    private(set) var cachedCryptoAssets: [CryptoAsset] = []

    /// Cached stock quotes for favorite stocks
    var cachedStockQuotes: [String: FMPQuote] = [:]

    /// Favorite assets computed from FavoritesStore + cached crypto data + stock configs
    var favoriteAssets: [CryptoAsset] {
        let favoriteIds = FavoritesStore.shared.allFavoriteIds()
        guard !favoriteIds.isEmpty else { return [] }

        // Crypto favorites (matched by CoinGecko ID)
        var results = cachedCryptoAssets.filter { favoriteIds.contains($0.id) }

        // Stock favorites (matched by symbol, with live price if available)
        for config in AssetRiskConfig.stockConfigs where favoriteIds.contains(config.assetId) {
            let quote = cachedStockQuotes[config.assetId]
            let stub = CryptoAsset(
                id: config.assetId,
                symbol: config.assetId,
                name: config.displayName,
                currentPrice: quote?.price ?? 0,
                priceChange24h: quote?.change ?? 0,
                priceChangePercentage24h: quote?.changePercentage ?? 0,
                iconUrl: config.logoURL?.absoluteString
            )
            results.append(stub)
        }

        return results
    }

    // AI Market Summary — show persisted briefing instantly on cold start
    private static let _persistedBriefing = MarketSummaryService.shared.loadPersistedBriefing()
    var marketSummary: MarketSummary? = _persistedBriefing
    var isLoadingSummary: Bool = _persistedBriefing == nil

    // Notification Inbox
    var recentSignalsForInbox: [TradeSignal] = []
    var readNotificationIds: Set<String> = [] {
        didSet {
            guard !isLoadingReadIds else { return }
            persistReadIds()
        }
    }
    private static let readIdsKey = "arkline_read_notification_ids"
    private var isLoadingReadIds = false

    var inboxNotifications: [AppNotification] {
        NotificationInboxBuilder.build(
            todayReminders: todayReminders,
            recentSignals: recentSignalsForInbox,
            marketSummary: marketSummary,
            extremeMoveHistory: ExtremeMoveAlertManager.shared.getAlertHistory(),
            qpsSignals: qpsSignals,
            readIds: readNotificationIds
        )
    }

    var unreadNotificationCount: Int {
        inboxNotifications.filter { !$0.isRead }.count
    }

    func markNotificationRead(_ id: String) {
        readNotificationIds.insert(id)
    }

    func markAllNotificationsRead() {
        for notification in inboxNotifications {
            readNotificationIds.insert(notification.id)
        }
    }

    private func persistReadIds() {
        // Only prune if notifications have loaded, otherwise save all IDs
        let currentIds = Set(inboxNotifications.map(\.id))
        let idsToSave: Set<String>
        if currentIds.isEmpty {
            idsToSave = readNotificationIds
        } else {
            idsToSave = readNotificationIds.intersection(currentIds)
        }
        UserDefaults.standard.set(Array(idsToSave), forKey: Self.readIdsKey)
    }

    private func loadReadIds() {
        if let array = UserDefaults.standard.stringArray(forKey: Self.readIdsKey) {
            isLoadingReadIds = true
            readNotificationIds = Set(array)
            isLoadingReadIds = false
        }
    }

    // Top Movers
    var topGainers: [CryptoAsset] = []
    var topLosers: [CryptoAsset] = []

    // User
    var userName: String = ""
    var userAvatar: URL?

    // MARK: - Computed Properties
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<21:
            return "Good evening"
        default:
            return "Good night"
        }
    }

    var hasTodayReminders: Bool {
        !todayReminders.isEmpty
    }

    var hasUpcomingEvents: Bool {
        !todaysEvents.isEmpty
    }

    // MARK: - Initialization
    init(
        sentimentService: SentimentServiceProtocol = ServiceContainer.shared.sentimentService,
        marketService: MarketServiceProtocol = ServiceContainer.shared.marketService,
        dcaService: DCAServiceProtocol = ServiceContainer.shared.dcaService,
        newsService: NewsServiceProtocol = ServiceContainer.shared.newsService,
        portfolioService: PortfolioServiceProtocol = ServiceContainer.shared.portfolioService,
        itcRiskService: ITCRiskServiceProtocol = ServiceContainer.shared.itcRiskService,
        vixService: VIXServiceProtocol = ServiceContainer.shared.vixService,
        dxyService: DXYServiceProtocol = ServiceContainer.shared.dxyService,
        rainbowChartService: RainbowChartServiceProtocol = ServiceContainer.shared.rainbowChartService,
        globalLiquidityService: GlobalLiquidityServiceProtocol = ServiceContainer.shared.globalLiquidityService,
        macroStatisticsService: MacroStatisticsServiceProtocol = ServiceContainer.shared.macroStatisticsService,
        santimentService: SantimentServiceProtocol = ServiceContainer.shared.santimentService,
        enableSideEffects: Bool = true
    ) {
        self.sentimentService = sentimentService
        self.marketService = marketService
        self.dcaService = dcaService
        self.newsService = newsService
        self.portfolioService = portfolioService
        self.itcRiskService = itcRiskService
        self.vixService = vixService
        self.dxyService = dxyService
        self.rainbowChartService = rainbowChartService
        self.globalLiquidityService = globalLiquidityService
        self.macroStatisticsService = macroStatisticsService
        self.santimentService = santimentService
        self.enableSideEffects = enableSideEffects
        // Initialize user data synchronously; data loading is triggered by HomeView.task
        self.sentimentViewModel = SentimentViewModel()
        loadReadIds()
        restoreCachedPortfolio()
    }

    nonisolated deinit {
        // Timer cleanup — access stored property directly since deinit is nonisolated
        MainActor.assumeIsolated {
            refreshTimer?.invalidate()
            refreshTimer = nil
            portfolioPriceTimer?.invalidate()
            portfolioPriceTimer = nil
        }
    }

    // MARK: - Auto-Refresh Methods
    func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.refreshEvents()
            }
        }
        portfolioPriceTimer = Timer.scheduledTimer(withTimeInterval: portfolioPriceInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.refreshPortfolioPrices()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        portfolioPriceTimer?.invalidate()
        portfolioPriceTimer = nil
    }

    /// Refresh events and news data (lighter weight than full refresh)
    func refreshEvents() async {
        guard !isRefreshing else { return }
        do {
            async let upcomingTask = newsService.fetchUpcomingEvents(days: 7, impactFilter: [.high, .medium])
            async let newsTask: [NewsItem] = {
                do {
                    return try await self.fetchNewsCombined()
                } catch {
                    logError("HomeViewModel: Failed to refresh news: \(error)", category: .network)
                    return []
                }
            }()

            let upcoming = try await upcomingTask
            let news = await newsTask

            await MainActor.run {
                self.upcomingEvents = upcoming
                self.eventsLastUpdated = Date()
                if !news.isEmpty {
                    self.newsItems = news
                }
            }
            logInfo("HomeViewModel: Auto-refreshed events and news at \(Date())", category: .data)
        } catch {
            logError("HomeViewModel: Failed to refresh events: \(error)", category: .data)
        }
    }

    // MARK: - Refresh Cooldown
    private let refreshCooldown: TimeInterval = 30

    // MARK: - Public Methods
    func refresh(forceRefresh: Bool = false) async {
        // If a previous refresh is somehow stuck, force-reset after 30s
        if isRefreshing {
            if let last = lastRefreshed, Date().timeIntervalSince(last) > 30 {
                logWarning("HomeViewModel: isRefreshing was stuck — force-resetting", category: .data)
                isRefreshing = false
            } else {
                return
            }
        }
        // Skip re-fetch if data loaded within the last 30 seconds (unless forced)
        if !forceRefresh, let last = lastRefreshed, Date().timeIntervalSince(last) < refreshCooldown { return }
        isRefreshing = true
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            isRefreshing = false
        }

        let userId = await MainActor.run { SupabaseAuthManager.shared.currentUserId }
        let riskCoins = AssetRiskConfig.allConfigs.map(\.assetId)

        // Launch ALL fetches concurrently, then progressively update UI as each group resolves.
        // Each group is an independent Task so widgets render as data arrives.

        let eventsTask = Task { @MainActor in
            let upcoming = await self.fetchUpcomingEventsSafe()
            let todaysEvts = await self.fetchTodaysEventsSafe()
            self.upcomingEvents = upcoming
            self.todaysEvents = todaysEvts
            self.eventsLastUpdated = Date()
        }

        let cryptoTask = Task { @MainActor [enableSideEffects] in
            let crypto = await self.fetchCryptoAssetsSafe()

            if !crypto.isEmpty {
                if enableSideEffects { Task { await MarketDataCollector.shared.recordCryptoAssets(crypto) } }
                self.cachedCryptoAssets = crypto
            }

            let btc = crypto.first { $0.symbol.uppercased() == "BTC" }
            let eth = crypto.first { $0.symbol.uppercased() == "ETH" }
            let sol = crypto.first { $0.symbol.uppercased() == "SOL" }

            withAnimation(.easeInOut(duration: 0.4)) {
                self.btcPrice = btc?.currentPrice ?? 0
                self.ethPrice = eth?.currentPrice ?? 0
                self.solPrice = sol?.currentPrice ?? 0
                self.btcChange24h = btc?.priceChangePercentage24h ?? 0
                self.ethChange24h = eth?.priceChangePercentage24h ?? 0
                self.solChange24h = sol?.priceChangePercentage24h ?? 0
            }
            let sortedByGain = crypto.sorted { $0.priceChangePercentage24h > $1.priceChangePercentage24h }
            self.topGainers = Array(sortedByGain.prefix(3))
            self.topLosers = Array(sortedByGain.suffix(3).reversed())
            return crypto
        }

        let macroTask = Task { @MainActor [enableSideEffects] in
            async let vixFetch = self.fetchVIXSafe()
            async let dxyFetch = self.fetchDXYSafe()
            async let vixHistFetch = self.fetchVIXHistorySafe()
            async let dxyHistFetch = self.fetchDXYHistorySafe()
            async let liquidityFetch = self.fetchGlobalLiquiditySafe()
            async let netLiqFetch = self.fetchNetLiquiditySafe()
            async let globalLiqFetch = self.fetchGlobalLiquidityIndexSafe()
            async let supplyProfitFetch = self.fetchSupplyInProfitSafe()
            async let fedWatchFetch = self.fetchFedWatchMeetingsSafe()

            let (vix, dxy, vixHist, dxyHist, liquidity, netLiq, globalLiq, supplyProfit, fedMeetings) = await (vixFetch, dxyFetch, vixHistFetch, dxyHistFetch, liquidityFetch, netLiqFetch, globalLiqFetch, supplyProfitFetch, fedWatchFetch)

            self.vixData = vix
            self.dxyData = dxy
            self.vixHistory = vixHist
            self.dxyHistory = dxyHist
            self.globalLiquidityChanges = liquidity
            self.netLiquidityData = netLiq
            self.globalLiquidityIndex = globalLiq
            self.supplyInProfitData = supplyProfit
            self.fedWatchMeetings = fedMeetings ?? []

            // Archive macro indicators (fire-and-forget)
            if enableSideEffects {
                Task {
                    let collector = MarketDataCollector.shared
                    if let vix = vix {
                        await collector.recordIndicator(
                            name: "vix", value: vix.value,
                            metadata: vix.open.map { ["open": .double($0), "high": .double(vix.high ?? 0), "low": .double(vix.low ?? 0), "close": .double(vix.close ?? 0)] }
                        )
                    }
                    if let dxy = dxy {
                        await collector.recordIndicator(
                            name: "dxy", value: dxy.value,
                            metadata: dxy.open.map { ["open": .double($0), "high": .double(dxy.high ?? 0), "low": .double(dxy.low ?? 0), "close": .double(dxy.close ?? 0)] }
                        )
                    }
                    if let m2 = liquidity {
                        await collector.recordIndicator(
                            name: "global_m2", value: m2.current,
                            metadata: ["weekly_change": .double(m2.weeklyChange), "monthly_change": .double(m2.monthlyChange), "yearly_change": .double(m2.yearlyChange)]
                        )
                    }
                    if let nl = netLiq {
                        await collector.recordIndicator(
                            name: "net_liquidity", value: nl.current,
                            metadata: ["weekly_change": .double(nl.weeklyChange), "monthly_change": .double(nl.monthlyChange), "yearly_change": .double(nl.yearlyChange)]
                        )
                    }
                    if let sp = supplyProfit {
                        await collector.recordIndicator(name: "supply_in_profit", value: sp.value)
                    }
                }
            }

            return (vix, dxy, liquidity)
        }

        let riskTask = Task { @MainActor in
            let riskResults = await self.fetchAllRiskLevels(coins: riskCoins)
            for (coin, level, history) in riskResults {
                self.riskLevels[coin] = level
                self.riskHistories[coin] = history
            }
        }

        let sentimentTask = Task { @MainActor [enableSideEffects, sentimentService, dcaService] in
            async let fgFetch: FearGreedIndex? = {
                do { return try await sentimentService.fetchFearGreedIndex() }
                catch {
                    logError("Fear & Greed fetch failed: \(error.localizedDescription)", category: .network)
                    return nil
                }
            }()
            async let riskScoreFetch: ArkLineRiskScore? = {
                do { return try await sentimentService.fetchArkLineRiskScore() }
                catch {
                    logError("ArkLine Risk Score fetch failed: \(error.localizedDescription)", category: .network)
                    return nil
                }
            }()
            async let remindersFetch: [DCAReminder] = {
                guard let uid = userId else { return [] }
                do { return try await dcaService.fetchReminders(userId: uid) }
                catch {
                    logError("Reminders fetch failed: \(error.localizedDescription)", category: .network)
                    return []
                }
            }()
            async let newsFetch: [NewsItem] = {
                do { return try await self.fetchNewsCombined() }
                catch {
                    logError("News fetch failed: \(error.localizedDescription)", category: .network)
                    return []
                }
            }()

            let (fg, riskScore, reminders, news) = await (fgFetch, riskScoreFetch, remindersFetch, newsFetch)

            if let fg = fg {
                self.fearGreedIndex = fg
            }
            self.activeReminders = reminders.filter { $0.isActive }
            self.todayReminders = reminders.filter { $0.isDueToday }
            if enableSideEffects {
                Task { await DCANotificationScheduler.syncAll(reminders) }
            }
            if let riskScore = riskScore {
                self.compositeRiskScore = riskScore.score
                self.arkLineRiskScore = riskScore
            }
            self.newsItems = news

            // Archive fear/greed and risk score (fire-and-forget)
            if enableSideEffects {
                Task {
                    let collector = MarketDataCollector.shared
                    if let fg = fg {
                        await collector.recordIndicator(
                            name: "fear_greed", value: Double(fg.value),
                            metadata: [
                                "classification": .string(fg.classification),
                                "previous_close": .int(fg.previousClose ?? 0),
                                "week_ago": .int(fg.weekAgo ?? 0),
                                "month_ago": .int(fg.monthAgo ?? 0)
                            ]
                        )
                    }
                    if let riskScore = riskScore {
                        await collector.recordRiskScore(riskScore)
                    }
                }
            }

            return (fg, riskScore)
        }

        let zScoreTask = Task { @MainActor [enableSideEffects] in
            let zScores = await self.fetchMacroZScoresSafe()
            self.macroZScores = zScores
            if enableSideEffects {
                ExtremeMoveAlertManager.shared.checkAllForExtremeMoves(zScores)
            }
            return zScores
        }

        // Briefing: fetch in parallel with other data (not after).
        // Persisted briefing is already showing, this refreshes it.
        let briefingTask = Task { @MainActor [enableSideEffects] in
            guard enableSideEffects else { return }
            if forceRefresh {
                MarketSummaryService.shared.clearLocalCache()
            }
            self.isLoadingSummary = true
            await self.fetchMarketSummary()
        }

        // Await all progressive tasks, then compute regime + failure count.
        // Race against a 20-second deadline so the Home tab never stays stuck
        // in loading state (e.g. on flaky wifi / airplane mode).
        let timedOut = await withTaskGroup(of: Bool.self) { group in
            group.addTask { @MainActor in
                _ = await eventsTask.value
                _ = await cryptoTask.value
                _ = await macroTask.value
                _ = await riskTask.value
                _ = await sentimentTask.value
                _ = await zScoreTask.value
                _ = await briefingTask.value
                return false // completed
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                return true // timed out
            }
            let first = await group.next() ?? true
            group.cancelAll()
            return first
        }

        if timedOut {
            logWarning("HomeViewModel: refresh timed out after 20s, showing partial data", category: .network)
        }

        // Compute regime from whatever data arrived (tasks update published properties directly)
        self.currentRegimeResult = MacroRegimeCalculator.computeRegime(
            vixData: self.vixData,
            dxyData: self.dxyData,
            globalM2Data: self.globalLiquidityChanges,
            macroZScores: self.macroZScores
        )
        self.failedFetchCount = (self.cachedCryptoAssets.isEmpty ? 1 : 0) + (self.fearGreedIndex == nil ? 1 : 0) + (self.arkLineRiskScore == nil ? 1 : 0)

        // All data has arrived (or timed out) — finalize
        self.lastRefreshed = Date()
        self.isLoading = false
        self.isRefreshing = false

        // Load stock risk levels AFTER main content is rendered (deferred to avoid lag)
        Task { @MainActor in
            await self.loadStockRiskLevels()
        }

        guard enableSideEffects else { return }

        // Fetch Flash Intel signals (all active signals)
        Task {
            do {
                let active = try await self.swingSetupService.fetchActiveSignals()
                await MainActor.run {
                    // Notify for truly new signals (not seen before)
                    let existingIds = Set(self.flashIntelSignals.map(\.id))
                    let newSignals = active.filter { !existingIds.contains($0.id) }
                    for signal in newSignals where !existingIds.isEmpty {
                        Task { await BroadcastNotificationService.shared.sendSwingSignalNotification(for: signal) }
                    }
                    self.flashIntelSignals = active
                        .filter(\.isFlashIntelWorthy)
                        .sorted { $0.confidence < $1.confidence }
                }
            } catch {
                logWarning("Flash Intel fetch failed: \(error.localizedDescription)", category: .network)
            }
        }

        // Fetch signal stats for home widget
        Task {
            do {
                let stats = try await self.swingSetupService.fetchSignalStats()
                await MainActor.run { self.signalStats = stats }
            } catch {
                logWarning("Signal stats fetch failed: \(error.localizedDescription)", category: .network)
            }
        }

        // Fetch market conditions (explains why signals are quiet)
        Task {
            do {
                let conditions = try await self.swingSetupService.fetchMarketConditions()
                await MainActor.run { self.marketConditions = conditions }
            } catch {
                logWarning("Market conditions fetch failed: \(error.localizedDescription)", category: .network)
            }
        }

        // Fetch recent signals for notification inbox (includes closed signals)
        Task {
            do {
                let recent = try await self.swingSetupService.fetchRecentSignals(limit: 30)
                await MainActor.run { self.recentSignalsForInbox = recent }
            } catch {
                logWarning("Inbox signal fetch failed: \(error.localizedDescription)", category: .network)
            }
        }

        // Fetch QPS (daily positioning signals)
        Task {
            do {
                let signals = try await self.qpsService.fetchLatestSignals(forceRefresh: forceRefresh)
                await MainActor.run {
                    // Notify for signal changes (only today's, only once per signal)
                    let today = Calendar.current.startOfDay(for: Date())
                    let changed = signals.filter { $0.hasChanged && $0.signalDate >= today }
                    if !changed.isEmpty && !self.qpsSignals.isEmpty {
                        for signal in changed {
                            let notifId = "qps_\(signal.asset)_\(signal.signal)"
                            guard !self.notifiedQPSIds.contains(notifId) else { continue }
                            self.notifiedQPSIds.insert(notifId)
                            Task { await BroadcastNotificationService.shared.sendQPSChangeNotification(for: signal) }
                        }
                    }
                    self.qpsSignals = signals
                }
            } catch {
                logWarning("QPS signals fetch failed: \(error.localizedDescription)", category: .network)
            }
        }

        // Fetch latest weekly market deck
        Task {
            do {
                let deck = try await self.marketDeckService.fetchLatestPublished()
                await MainActor.run { self.latestDeck = deck }
            } catch {
                logWarning("Market deck fetch failed: \(error.localizedDescription)", category: .network)
            }
        }

        // Fetch latest model portfolio trade (followed strategy, or most recent from any)
        Task {
            do {
                let portfolios = try await self.modelPortfolioService.fetchPortfolios()
                guard !portfolios.isEmpty else { return }

                let followed = UserDefaults.standard.string(forKey: Constants.UserDefaults.followedModelPortfolio)

                // If following a specific strategy, show that one; otherwise show most recent from any
                let targetPortfolios = followed != nil
                    ? portfolios.filter { $0.strategy == followed }
                    : portfolios

                // Find the most recent trade across target portfolios
                var latestTrade: ModelPortfolioTrade?
                var latestName: String?
                for portfolio in targetPortfolios {
                    let trades = try await self.modelPortfolioService.fetchTrades(portfolioId: portfolio.id, limit: 1)
                    if let trade = trades.first {
                        if latestTrade == nil || trade.tradeDate > (latestTrade?.tradeDate ?? "") {
                            latestTrade = trade
                            latestName = portfolio.name
                        }
                    }
                }

                await MainActor.run {
                    self.latestPortfolioTrade = latestTrade
                    self.followedPortfolioName = latestName
                }
            } catch {
                logWarning("Model portfolio trade fetch failed: \(error.localizedDescription)", category: .network)
            }
        }

        // Fetch Rainbow Chart data (needs BTC price) in background
        if btcPrice > 0 {
            Task {
                let rainbow = await self.fetchRainbowChartSafe(btcPrice: self.btcPrice)
                await MainActor.run { self.rainbowChartData = rainbow }
            }
        }

    }

    func markReminderComplete(_ reminder: DCAReminder) async {
        do {
            let updated = try await dcaService.markAsInvested(id: reminder.id)

            await MainActor.run {
                if let index = self.activeReminders.firstIndex(where: { $0.id == reminder.id }) {
                    self.activeReminders[index] = updated
                }
                self.todayReminders.removeAll { $0.id == reminder.id }
            }

            // Re-schedule notification for the next DCA date
            await DCANotificationScheduler.schedule(updated)
        } catch {
            await MainActor.run {
                self.errorMessage = AppError.from(error).userMessage
            }
        }
    }

    func loadPortfolios(forceRefresh: Bool = false) async {
        guard !hasLoadedPortfolios || forceRefresh else { return }
        do {
            // Wait for auth session to finish restoring (avoids race on cold launch)
            for _ in 0..<30 {
                let ready = await MainActor.run { !SupabaseAuthManager.shared.isLoading }
                if ready { break }
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms, up to 3s total
            }

            // Prefer cached user from UserDefaults (available immediately), fall back to Supabase auth
            let cachedUserId: UUID? = {
                guard let data = UserDefaults.standard.data(forKey: Constants.UserDefaults.currentUser),
                      let user = try? JSONDecoder().decode(User.self, from: data) else { return nil }
                return user.id
            }()
            let supabaseUserId: UUID? = await MainActor.run { SupabaseAuthManager.shared.currentUserId }
            let resolvedUserId: UUID? = cachedUserId ?? supabaseUserId
            guard let userId = resolvedUserId else {
                logWarning("No authenticated user for portfolio fetch", category: .data)
                await MainActor.run { self.hasLoadedPortfolios = true }
                return
            }
            let fetchedPortfolios = try await withTimeout(seconds: 15) { [portfolioService] in
                try await portfolioService.fetchPortfolios(userId: userId)
            }

            await MainActor.run {
                self.portfolios = fetchedPortfolios
                if self.selectedPortfolio == nil, let first = fetchedPortfolios.first {
                    self.selectedPortfolio = first
                }
                // Mark loaded immediately so UI shows portfolio card (not spinner)
                self.hasLoadedPortfolios = true
            }

            // Load detailed holdings/prices in a detached task (doesn't block loadPortfolios)
            if let portfolio = selectedPortfolio {
                Task { [weak self] in
                    await self?.loadPortfolioData(for: portfolio)
                }
            }
        } catch {
            logError("Failed to load portfolios: \(error)", category: .data)
            await MainActor.run { self.hasLoadedPortfolios = true }
        }
    }

    /// Lightweight price-only refresh — reuses existing holdings, skips history fetch
    private func refreshPortfolioPrices() async {
        guard !portfolioHoldings.isEmpty else { return }
        do {
            let updated = try await portfolioService.refreshHoldingPrices(holdings: portfolioHoldings)
            let totalValue = updated.reduce(0) { $0 + $1.currentValue }
            await MainActor.run {
                self.portfolioHoldings = updated
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.portfolioValue = totalValue
                }
                self.cachePortfolioSnapshot()
            }
        } catch {
            // Silent failure — stale prices are fine, next tick will retry
        }
    }

    func selectPortfolio(_ portfolio: Portfolio) {
        selectedPortfolio = portfolio
        Task { await loadPortfolioData(for: portfolio) }
    }

    func selectRiskCoin(_ coin: String) {
        selectedRiskCoin = coin
    }

    // MARK: - Private Methods

    /// Fetches real holdings, live prices, and history for a portfolio
    private func loadPortfolioData(for portfolio: Portfolio) async {
        do {
            // Fetch holdings and history concurrently
            async let holdingsTask = portfolioService.fetchHoldings(portfolioId: portfolio.id)
            async let historyTask = portfolioService.fetchPortfolioHistory(portfolioId: portfolio.id, days: 365 * 5)

            let fetchedHoldings = try await holdingsTask
            let history = (try? await historyTask) ?? []

            // Refresh live prices
            let holdingsWithPrices: [PortfolioHolding]
            do {
                holdingsWithPrices = try await portfolioService.refreshHoldingPrices(holdings: fetchedHoldings)
            } catch {
                logError("Home portfolio price refresh failed: \(error)", category: .data)
                holdingsWithPrices = fetchedHoldings
            }

            let totalValue = holdingsWithPrices.reduce(0) { $0 + $1.currentValue }

            await MainActor.run {
                self.portfolioHoldings = holdingsWithPrices
                self.portfolioHistory = history
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.portfolioValue = totalValue
                }
                self.cachePortfolioSnapshot()
            }
        } catch {
            logError("Failed to load portfolio data: \(error)", category: .data)
        }
    }

    // MARK: - Portfolio Cache (instant launch)

    private static let portfolioCacheKey = "cachedPortfolioSnapshot"

    private func cachePortfolioSnapshot() {
        guard portfolioValue > 0, let portfolio = selectedPortfolio else { return }
        let snapshot: [String: Any] = [
            "value": portfolioValue,
            "name": portfolio.name,
            "portfolioId": portfolio.id.uuidString
        ]
        UserDefaults.standard.set(snapshot, forKey: Self.portfolioCacheKey)
    }

    private func restoreCachedPortfolio() {
        guard let snapshot = UserDefaults.standard.dictionary(forKey: Self.portfolioCacheKey) else { return }
        if let value = snapshot["value"] as? Double, value > 0 {
            portfolioValue = value
            // Don't set hasLoadedPortfolios here — let the real fetch set portfolios array
            // This just pre-fills the value so the card shows a number instead of $0
        }
    }

    private func fetchFedWatchMeetingsSafe() async -> [FedWatchData]? {
        do {
            return try await newsService.fetchFedWatchMeetings()
        } catch {
            logError("Fed Watch fetch failed: \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    private func fetchITCRiskLevelSafe(coin: String) async -> ITCRiskLevel? {
        do {
            return try await itcRiskService.fetchLatestRiskLevel(coin: coin)
        } catch {
            logDebug("Risk level fetch failed for \(coin): \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    private func fetchITCRiskHistorySafe(coin: String) async -> [ITCRiskLevel] {
        do {
            return try await itcRiskService.fetchRiskLevel(coin: coin)
        } catch {
            logError("Risk history fetch failed for \(coin): \(error.localizedDescription)", category: .network)
            return []
        }
    }

    private func fetchAllRiskLevels(coins: [String]) async -> [(String, ITCRiskLevel?, [ITCRiskLevel])] {
        await withTaskGroup(of: (String, ITCRiskLevel?, [ITCRiskLevel]).self) { group in
            for coin in coins {
                group.addTask { [weak self] in
                    guard let self else { return (coin, nil, []) }
                    let level = await self.fetchITCRiskLevelSafe(coin: coin)
                    let history = await self.fetchITCRiskHistorySafe(coin: coin)
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

    private func fetchCryptoAssetsSafe() async -> [CryptoAsset] {
        do {
            return try await marketService.fetchCryptoAssets(page: 1, perPage: 100)
        } catch {
            logError("Crypto assets fetch failed: \(error.localizedDescription)", category: .network)
            return []
        }
    }

    private func fetchVIXSafe() async -> VIXData? {
        do {
            return try await vixService.fetchLatestVIX()
        } catch {
            logError("VIX fetch failed: \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    private func fetchDXYSafe() async -> DXYData? {
        do {
            return try await dxyService.fetchLatestDXY()
        } catch {
            logError("DXY fetch failed: \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    private func fetchVIXHistorySafe() async -> [VIXData] {
        do {
            return try await vixService.fetchVIXHistory(days: 7)
        } catch {
            logError("VIX history fetch failed: \(error.localizedDescription)", category: .network)
            return []
        }
    }

    private func fetchDXYHistorySafe() async -> [DXYData] {
        do {
            return try await dxyService.fetchDXYHistory(days: 7)
        } catch {
            logError("DXY history fetch failed: \(error.localizedDescription)", category: .network)
            return []
        }
    }

    private func fetchRainbowChartSafe(btcPrice: Double) async -> RainbowChartData? {
        do {
            return try await rainbowChartService.fetchCurrentRainbowData(btcPrice: btcPrice)
        } catch {
            logError("Rainbow chart fetch failed: \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    private func fetchGlobalLiquiditySafe() async -> GlobalLiquidityChanges? {
        do {
            return try await globalLiquidityService.fetchLiquidityChanges()
        } catch {
            logError("Global liquidity fetch failed: \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    private func fetchNetLiquiditySafe() async -> NetLiquidityChanges? {
        do {
            return try await globalLiquidityService.fetchNetLiquidityChanges()
        } catch {
            logError("Net liquidity fetch failed: \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    private func fetchGlobalLiquidityIndexSafe() async -> GlobalLiquidityIndex? {
        do {
            return try await globalLiquidityService.fetchGlobalLiquidityIndex()
        } catch {
            logDebug("Global liquidity index not available: \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    private func fetchSupplyInProfitSafe() async -> SupplyProfitData? {
        do {
            return try await santimentService.fetchLatestSupplyInProfit()
        } catch {
            logError("Supply in profit fetch failed: \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    private func fetchUpcomingEventsSafe() async -> [EconomicEvent] {
        do {
            return try await newsService.fetchUpcomingEvents(days: 7, impactFilter: [.high, .medium])
        } catch {
            logError("Upcoming events fetch failed: \(error.localizedDescription)", category: .network)
            return []
        }
    }

    private func fetchTodaysEventsSafe() async -> [EconomicEvent] {
        do {
            return try await newsService.fetchTodaysEvents()
        } catch {
            logError("Today's events fetch failed: \(error.localizedDescription)", category: .network)
            return []
        }
    }

    /// Fetches combined news feed using the same logic as Market Overview,
    /// respecting user topic preferences and pulling from multiple sources.
    private func fetchNewsCombined() async throws -> [NewsItem] {
        var selectedTopics: Set<Constants.NewsTopic>? = nil
        var customKeywords: [String]? = nil

        if let data = UserDefaults.standard.data(forKey: Constants.UserDefaults.selectedNewsTopics),
           let topics = try? JSONDecoder().decode(Set<Constants.NewsTopic>.self, from: data),
           !topics.isEmpty {
            selectedTopics = topics
        }

        if let custom = UserDefaults.standard.stringArray(forKey: Constants.UserDefaults.customNewsTopics),
           !custom.isEmpty {
            customKeywords = custom
        }

        let hasCustomization = selectedTopics != nil || customKeywords != nil
        let fetchLimit = hasCustomization ? 30 : 15

        return try await newsService.fetchCombinedNewsFeed(
            limit: fetchLimit,
            includeTwitter: true,
            includeGoogleNews: true,
            topics: selectedTopics,
            customKeywords: customKeywords
        )
    }

    private func fetchMacroZScoresSafe() async -> [MacroIndicatorType: MacroZScoreData] {
        do {
            return try await macroStatisticsService.fetchAllZScores()
        } catch {
            logError("Macro Z-scores fetch failed: \(error.localizedDescription)", category: .network)
            return [:]
        }
    }

    // MARK: - Briefing Feedback

    func submitBriefingFeedback(rating: Bool, note: String?, userId: UUID) async {
        guard let summary = marketSummary else { return }
        let service = MarketSummaryService.shared
        let hasNote = !(note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        // Optimistic update
        self.marketSummary = MarketSummary(
            summary: summary.summary,
            generatedAt: summary.generatedAt,
            summaryDate: summary.summaryDate,
            slot: summary.slot,
            feedbackRating: rating,
            feedbackNote: note
        )

        do {
            try await service.submitFeedback(
                userId: userId,
                summaryDate: summary.summaryDate,
                slot: summary.slot,
                rating: rating,
                note: note
            )
        } catch {
            logError("Failed to submit briefing feedback: \(error.localizedDescription)", category: .network)
        }

        // Only regenerate on negative feedback with a note (thumbs up = keep the briefing)
        guard !rating, hasNote else { return }

        // Nil out summary so the widget shows shimmer during regeneration
        marketSummary = nil
        isLoadingSummary = true
        do {
            try await service.clearServerCache()
        } catch {
            logError("Failed to clear server cache: \(error.localizedDescription)", category: .network)
        }
        await fetchMarketSummary()
    }

    // MARK: - AI Market Summary

    /// Fetch the latest pre-generated daily briefing.
    /// Briefings are generated server-side by cron at 10am and 5pm ET.
    func fetchMarketSummary(retryCount: Int = 0) async {
        guard enableSideEffects else { return }
        isLoadingSummary = true
        defer { isLoadingSummary = false }

        let service = MarketSummaryService.shared

        do {
            let summary = try await withTimeout(seconds: 15) {
                try await service.fetchLatestBriefing()
            }
            let textQuadrant = Self.quadrantFromBriefingText(summary.summary)

            await MainActor.run {
                self.marketSummary = summary
                self.briefingQuadrant = textQuadrant
            }
        } catch {
            logError("Briefing fetch failed (attempt \(retryCount + 1)): \(error)", category: .network)
            // Retry once after a short delay if first attempt failed
            if retryCount == 0 && marketSummary == nil {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await fetchMarketSummary(retryCount: 1)
            }
        }
    }
}
