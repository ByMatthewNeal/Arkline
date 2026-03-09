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
    private let refreshInterval: TimeInterval = 300 // 5 minutes for events
    var eventsLastUpdated: Date?

    /// Whether a refresh is currently in flight (prevents stacking)
    private var isRefreshing = false

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
    private let swingSetupService = SwingSetupService()

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
            let first = values.first!, last = values.last!
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

    // Calculate rolling 7-day average risk level from history
    private func weeklyAverageRiskLevel(for coin: String) -> Double? {
        guard let history = riskHistories[coin], !history.isEmpty else { return nil }
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let recentPoints = history.filter { level in
            guard let date = formatter.date(from: level.date) else { return false }
            return date >= sevenDaysAgo
        }
        guard recentPoints.count >= 3 else { return nil }
        return recentPoints.reduce(0.0) { $0 + $1.riskLevel } / Double(recentPoints.count)
    }

    // Cached crypto assets for favorites filtering
    private(set) var cachedCryptoAssets: [CryptoAsset] = []

    /// Favorite assets computed from FavoritesStore + cached crypto data
    var favoriteAssets: [CryptoAsset] {
        let favoriteIds = FavoritesStore.shared.allFavoriteIds()
        guard !favoriteIds.isEmpty else { return [] }
        return cachedCryptoAssets.filter { favoriteIds.contains($0.id) }
    }

    // AI Market Summary
    var marketSummary: MarketSummary? = nil
    var isLoadingSummary = true

    // Notification Inbox
    var recentSignalsForInbox: [TradeSignal] = []
    var readNotificationIds: Set<String> = [] {
        didSet { persistReadIds() }
    }
    private static let readIdsKey = "arkline_read_notification_ids"

    var inboxNotifications: [AppNotification] {
        NotificationInboxBuilder.build(
            todayReminders: todayReminders,
            recentSignals: recentSignalsForInbox,
            marketSummary: marketSummary,
            extremeMoveHistory: ExtremeMoveAlertManager.shared.getAlertHistory(),
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
        let currentIds = Set(inboxNotifications.map(\.id))
        let pruned = readNotificationIds.intersection(currentIds)
        UserDefaults.standard.set(Array(pruned), forKey: Self.readIdsKey)
    }

    private func loadReadIds() {
        if let array = UserDefaults.standard.stringArray(forKey: Self.readIdsKey) {
            readNotificationIds = Set(array)
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
    }

    nonisolated deinit {
        // Timer cleanup — access stored property directly since deinit is nonisolated
        MainActor.assumeIsolated {
            refreshTimer?.invalidate()
            refreshTimer = nil
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
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
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
        guard !isRefreshing else { return }
        // Skip re-fetch if data loaded within the last 30 seconds (unless forced)
        if !forceRefresh, let last = lastRefreshed, Date().timeIntervalSince(last) < refreshCooldown { return }
        isRefreshing = true
        isLoading = true
        errorMessage = nil

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
            async let supplyProfitFetch = self.fetchSupplyInProfitSafe()
            async let fedWatchFetch = self.fetchFedWatchMeetingsSafe()

            let (vix, dxy, vixHist, dxyHist, liquidity, netLiq, supplyProfit, fedMeetings) = await (vixFetch, dxyFetch, vixHistFetch, dxyHistFetch, liquidityFetch, netLiqFetch, supplyProfitFetch, fedWatchFetch)

            self.vixData = vix
            self.dxyData = dxy
            self.vixHistory = vixHist
            self.dxyHistory = dxyHist
            self.globalLiquidityChanges = liquidity
            self.netLiquidityData = netLiq
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

        // Await all progressive tasks, then compute regime + failure count
        _ = await eventsTask.value
        let crypto = await cryptoTask.value
        let (vix, dxy, liquidity) = await macroTask.value
        _ = await riskTask.value
        let (fg, riskScore) = await sentimentTask.value
        let zScores = await zScoreTask.value

        // Regime computation depends on macro + z-scores
        self.currentRegimeResult = MacroRegimeCalculator.computeRegime(
            vixData: vix,
            dxyData: dxy,
            globalM2Data: liquidity,
            macroZScores: zScores
        )
        self.failedFetchCount = (crypto.isEmpty ? 1 : 0) + (fg == nil ? 1 : 0) + (riskScore == nil ? 1 : 0)

        // All data has arrived — finalize
        self.lastRefreshed = Date()
        self.isLoading = false
        self.isRefreshing = false

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

        // Fetch recent signals for notification inbox (includes closed signals)
        Task {
            do {
                let recent = try await self.swingSetupService.fetchRecentSignals(limit: 30)
                await MainActor.run { self.recentSignalsForInbox = recent }
            } catch {
                logWarning("Inbox signal fetch failed: \(error.localizedDescription)", category: .network)
            }
        }

        // Fetch Rainbow Chart data (needs BTC price) in background
        if btcPrice > 0 {
            Task {
                let rainbow = await self.fetchRainbowChartSafe(btcPrice: self.btcPrice)
                await MainActor.run { self.rainbowChartData = rainbow }
            }
        }

        // Fetch AI market summary (uses already-loaded state).
        // Regime-shift detection happens inside fetchMarketSummary itself.
        // On force refresh (pull-to-refresh), clear stale briefing cache first.
        if forceRefresh {
            APICache.shared.remove("market_summary_session")
        }
        // Set loading flag BEFORE launching task to avoid race where isLoading=false
        // and isLoadingSummary=false simultaneously → "unavailable" flash
        self.isLoadingSummary = true
        Task { await self.fetchMarketSummary() }
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
            let fetchedPortfolios = try await portfolioService.fetchPortfolios(userId: userId)

            await MainActor.run {
                self.portfolios = fetchedPortfolios
                if self.selectedPortfolio == nil, let first = fetchedPortfolios.first {
                    self.selectedPortfolio = first
                }
            }

            // Load real holdings data for the selected portfolio
            if let portfolio = selectedPortfolio {
                await loadPortfolioData(for: portfolio)
            }

            // Mark loaded AFTER portfolio data (value) has been fetched
            await MainActor.run { self.hasLoadedPortfolios = true }
        } catch {
            logError("Failed to load portfolios: \(error)", category: .data)
            await MainActor.run { self.hasLoadedPortfolios = true }
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
            }
        } catch {
            logError("Failed to load portfolio data: \(error)", category: .data)
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
            logError("Risk level fetch failed for \(coin): \(error.localizedDescription)", category: .network)
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
                group.addTask { [self] in
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

    func fetchMarketSummary(checkRegimeShift: Bool = true, retryCount: Int = 0) async {
        guard enableSideEffects else { return }
        isLoadingSummary = true
        defer { isLoadingSummary = false }

        let service = MarketSummaryService.shared

        // Fetch index quotes, sentiment data, financial news, and BTC TA in parallel
        async let indexQuotes = service.fetchIndexQuotes()
        async let sentimentRefresh: () = { [weak self] in
            await self?.sentimentViewModel?.refresh()
        }()
        async let btcTA: TechnicalAnalysis? = {
            do {
                let taService: TechnicalAnalysisServiceProtocol = ServiceContainer.shared.technicalAnalysisService
                return try await taService.fetchTechnicalAnalysis(symbol: "BTC/USDT", exchange: "binance", interval: .daily)
            } catch { return nil }
        }()
        async let financialNews: [NewsItem] = {
            do {
                return try await GoogleNewsRSSService().fetchNews(
                    query: "stock market OR federal reserve OR economy OR inflation OR interest rates OR earnings",
                    limit: 5
                )
            } catch { return [] }
        }()

        let (sp500, nasdaq) = await indexQuotes
        _ = await sentimentRefresh
        let finNews = await financialNews
        let btcTechnical = await btcTA
        logDebug("Briefing data ready — SP500: \(sp500 != nil), BTC: \(btcPrice), TA: \(btcTechnical != nil), news: \(finNews.count)", category: .network)

        // Build net liquidity signal
        var netLiqSignal: String? = nil
        if let nl = netLiquidityData {
            netLiqSignal = "\(nl.overallSignal.rawValue) (\(nl.formattedCurrent), weekly \(String(format: "%+.1f", nl.weeklyChange))%)"
        }

        // Build gold signal
        var goldSignal: String? = nil
        if let gold = sentimentViewModel?.goldData {
            let changeStr = gold.changePercent.map { String(format: "%+.1f%%", $0) } ?? ""
            goldSignal = "\(gold.signalDescription) ($\(String(format: "%.0f", gold.value))\(changeStr.isEmpty ? "" : " \(changeStr)"))"
        }

        // Build top gainer string
        var topGainerStr: String? = nil
        if let top = topGainers.first, top.priceChangePercentage24h > 0 {
            topGainerStr = "\(top.symbol.uppercased()) \(String(format: "%+.1f", top.priceChangePercentage24h))%"
        }

        // Build BTC search interest signal
        var btcSearchStr: String? = nil
        if let trends = sentimentViewModel?.googleTrends {
            btcSearchStr = "\(trends.currentIndex)/100 (\(trends.trend.rawValue))"
        }

        // Build derivatives strings
        var fundingRateStr: String? = nil
        if let funding = sentimentViewModel?.fundingRate {
            fundingRateStr = "\(funding.displayRate) (\(funding.sentiment)), annualized \(funding.annualizedDisplay)"
        }

        var liquidationsStr: String? = nil
        if let liq = sentimentViewModel?.liquidations {
            liquidationsStr = "\(liq.longsFormatted) longs / \(liq.shortsFormatted) shorts liquidated, \(liq.dominantSide.lowercased()) dominant"
        }

        // No long/short ratio data available on SentimentViewModel
        let longShortStr: String? = nil

        var openInterestStr: String? = nil
        if let oi = sentimentViewModel?.btcOpenInterest {
            openInterestStr = "\(oi.formattedOI) (\(String(format: "%+.1f%%", oi.openInterestChangePercent24h)))"
        }

        // Build capital flow strings
        var btcDomStr: String? = nil
        if let dom = sentimentViewModel?.btcDominance {
            btcDomStr = "\(dom.displayValue) (\(dom.changeFormatted))"
        }

        var capitalRotationStr: String? = nil
        if let rotation = sentimentViewModel?.capitalRotation {
            capitalRotationStr = "\(rotation.phase.rawValue) (score \(Int(rotation.score))/100)"
        }

        var etfFlowStr: String? = nil
        if let etf = sentimentViewModel?.etfNetFlow {
            let direction = etf.isPositive ? "inflow" : "outflow"
            etfFlowStr = "\(etf.dailyFormatted) daily net \(direction)"
        }

        // Build risk factors string
        var riskFactorsStr: String? = nil
        if let mfr = sentimentViewModel?.multiFactorRisk {
            let available = mfr.factors.filter { $0.isAvailable }
            let top = available.sorted { ($0.normalizedValue ?? 0) > ($1.normalizedValue ?? 0) }.prefix(3)
            let parts = top.map { "\($0.type.rawValue): \(String(format: "%.2f", $0.normalizedValue ?? 0))" }
            if !parts.isEmpty {
                riskFactorsStr = parts.joined(separator: ", ")
            }
        }

        // Build macro enrichment strings
        var geiStr: String? = nil
        if let gei = sentimentViewModel?.geiData {
            let trendComponents = gei.components.filter { ["HG=F", "^TNX"].contains($0.seriesId) }
            let trendNotes = trendComponents.map { "\($0.name) \($0.contribution > 0 ? "rising" : "declining")" }
            let trendSuffix = trendNotes.isEmpty ? "" : ", \(trendNotes.joined(separator: "/"))"
            geiStr = "GEI \(gei.formattedScore) (\(gei.signal.rawValue))\(trendSuffix)"
        }

        var supplyProfitStr: String? = nil
        if let sp = supplyInProfitData {
            supplyProfitStr = "\(sp.formattedValue) supply in profit (\(sp.signalDescription) zone)"
        }

        var rainbowStr: String? = nil
        if let rainbow = rainbowChartData {
            rainbowStr = "\(rainbow.currentBand.rawValue) band (normalized \(String(format: "%.2f", rainbow.normalizedPosition)))"
        }

        // Build BTC key levels from active signals
        var btcKeyLevelsStr: String? = nil
        let btcSignals = recentSignalsForInbox.filter {
            $0.asset == "BTC" && ($0.status == .active || $0.status == .triggered)
        }
        if let sig = btcSignals.first {
            var parts: [String] = []
            parts.append("Entry zone: $\(sig.entryZoneLow.asSignalPrice)-$\(sig.entryZoneHigh.asSignalPrice)")
            if let t1 = sig.target1 {
                parts.append("T1: $\(t1.asSignalPrice)")
            }
            parts.append("Stop: $\(sig.stopLoss.asSignalPrice)")
            btcKeyLevelsStr = parts.joined(separator: ", ")
        }

        let payload = MarketSummaryService.MarketSummaryPayload(
            btcPrice: btcPrice > 0 ? btcPrice : nil,
            btcChange24h: btcPrice > 0 ? btcChange24h : nil,
            ethPrice: ethPrice > 0 ? ethPrice : nil,
            ethChange24h: ethPrice > 0 ? ethChange24h : nil,
            solPrice: solPrice > 0 ? solPrice : nil,
            solChange24h: solPrice > 0 ? solChange24h : nil,
            sp500Price: sp500?.price,
            sp500Change: sp500?.change,
            nasdaqPrice: nasdaq?.price,
            nasdaqChange: nasdaq?.change,
            fearGreedValue: fearGreedIndex.map { $0.value },
            fearGreedClassification: fearGreedIndex?.classification,
            riskScore: arkLineRiskScore?.score,
            riskTier: arkLineRiskScore?.tier.rawValue,
            vixValue: vixData?.value,
            vixSignal: vixData?.signalDescription,
            dxyValue: dxyData?.value,
            dxySignal: dxyData?.signalDescription,
            netLiquiditySignal: netLiqSignal,
            goldSignal: goldSignal,
            macroRegime: currentRegimeResult.map {
                "\($0.baseRegime.rawValue) (\($0.quadrant.rawValue), Growth: \(Int($0.growthScore))/100, Inflation: \(Int($0.inflationScore))/100)"
            },
            cryptoPositioning: currentRegimeResult?.quadrant.cryptoPositioning,
            btcRiskZone: riskLevels["BTC"]?.riskCategory,
            ethRiskZone: riskLevels["ETH"]?.riskCategory,
            altcoinSeason: sentimentViewModel?.altcoinSeason?.season,
            sentimentRegime: sentimentViewModel?.sentimentRegimeData?.currentRegime.rawValue,
            coinbaseRank: sentimentViewModel?.primaryAppRanking?.ranking,
            btcSearchInterest: btcSearchStr,
            topGainer: topGainerStr,
            btcTrend: btcTechnical.map { "\($0.trend.direction.rawValue) (\($0.trend.strength.rawValue), \($0.trend.daysInTrend)d)" },
            btcRsi: btcTechnical.map { "RSI(\($0.rsi.period)) = \(String(format: "%.1f", $0.rsi.value)) (\($0.rsi.zone.rawValue))" },
            btcSmaPosition: btcTechnical.map {
                let sma = $0.smaAnalysis
                var parts: [String] = []
                parts.append("21 SMA: \(sma.above21SMA ? "above" : "below") (\(sma.sma21.distanceLabel))")
                parts.append("50 SMA: \(sma.above50SMA ? "above" : "below") (\(sma.sma50.distanceLabel))")
                parts.append("200 SMA: \(sma.above200SMA ? "above" : "below") (\(sma.sma200.distanceLabel))")
                if sma.goldenCross { parts.append("Golden Cross active") }
                if sma.deathCross { parts.append("Death Cross active") }
                return parts.joined(separator: ", ")
            },
            btcBmsbPosition: btcTechnical.map {
                let bmsb = $0.bullMarketBands
                return "\(bmsb.position.rawValue) — 20W SMA: $\(String(format: "%.0f", bmsb.sma20Week)) (\(String(format: "%+.1f%%", bmsb.percentFromSMA))), 21W EMA: $\(String(format: "%.0f", bmsb.ema21Week)) (\(String(format: "%+.1f%%", bmsb.percentFromEMA)))"
            },
            btcBollingerPosition: btcTechnical.map {
                let bb = $0.bollingerBands.daily
                return "\(bb.position.rawValue) — %B: \(String(format: "%.2f", bb.percentB)), bandwidth: \(String(format: "%.3f", bb.bandwidth))"
            },
            btcFundingRate: fundingRateStr,
            btcLiquidations: liquidationsStr,
            btcLongShortRatio: longShortStr,
            btcOpenInterest: openInterestStr,
            btcDominance: btcDomStr,
            capitalRotation: capitalRotationStr,
            etfNetFlow: etfFlowStr,
            riskFactors: riskFactorsStr,
            geiScore: geiStr,
            supplyInProfit: supplyProfitStr,
            rainbowBand: rainbowStr,
            btcKeyLevels: btcKeyLevelsStr,
            economicEvents: todaysEvents.filter { $0.impact == .high }.prefix(3).map { event in
                .init(title: event.title, time: event.timeFormatted)
            },
            newsHeadlines: {
                // Merge crypto + financial headlines, deduped
                var seen = Set<String>()
                var headlines: [String] = []
                for item in (Array(newsItems.prefix(3)) + Array(finNews.prefix(3))) {
                    let key = item.title.lowercased()
                    if !seen.contains(key) {
                        seen.insert(key)
                        headlines.append(item.title)
                    }
                }
                return Array(headlines.prefix(6))
            }()
        )

        do {
            let summary = try await service.fetchSummary(payload: payload)
            let textQuadrant = Self.quadrantFromBriefingText(summary.summary)
            let liveQuadrant = self.currentRegimeResult?.quadrant

            // If the briefing text quadrant doesn't match live, clear caches and regenerate (once)
            if checkRegimeShift,
               let live = liveQuadrant,
               let text = textQuadrant,
               text != live {
                logInfo("Briefing text says \(text.rawValue) but live is \(live.rawValue), regenerating", category: .data)
                try? await service.clearServerCache()
                await fetchMarketSummary(checkRegimeShift: false)
                return
            }

            // If this is a regenerated briefing (not first fetch), clear stale DB feedback
            var result = summary
            if !checkRegimeShift {
                result.feedbackRating = nil
                result.feedbackNote = nil
            }

            await MainActor.run {
                self.marketSummary = result
                self.briefingQuadrant = textQuadrant
            }
        } catch {
            logError("Market summary fetch failed (attempt \(retryCount + 1)): \(error)", category: .network)
            #if DEBUG
            print("🔴 BRIEFING ERROR (attempt \(retryCount + 1)): \(error)")
            #endif
            // Retry once after a short delay if first attempt failed
            if retryCount == 0 && marketSummary == nil {
                logInfo("Retrying market summary fetch in 3s...", category: .network)
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await fetchMarketSummary(checkRegimeShift: false, retryCount: 1)
            }
        }
    }
}
