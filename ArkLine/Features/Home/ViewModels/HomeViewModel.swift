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
    var dxyData: DXYData?
    var rainbowChartData: RainbowChartData?
    var globalLiquidityChanges: GlobalLiquidityChanges?
    var supplyInProfitData: SupplyProfitData?

    // Macro Z-Scores (statistical analysis)
    var macroZScores: [MacroIndicatorType: MacroZScoreData] = [:]

    /// Whether any macro indicator has an extreme z-score
    var hasExtremeMacroMove: Bool {
        macroZScores.values.contains { $0.isExtreme }
    }

    /// Get z-score for a specific indicator
    func zScore(for indicator: MacroIndicatorType) -> MacroZScoreData? {
        macroZScores[indicator]
    }

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

    /// Generates chart data from real portfolio history points
    private func generateChartData(for period: TimePeriod) -> [CGFloat] {
        let days = period.days
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        var relevantHistory = portfolioHistory
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }

        // Add current value as the latest point
        if portfolioValue > 0 {
            relevantHistory.append(PortfolioHistoryPoint(date: Date(), value: portfolioValue))
        }

        // If not enough history for the selected period, fall back to cost basis → current value
        if relevantHistory.count < 2 && portfolioValue > 0 {
            let totalCost = portfolioHoldings.reduce(0) { $0 + $1.totalCost }
            if totalCost > 0 {
                return [CGFloat(0), CGFloat(totalCost > portfolioValue ? 0 : 1)]
            }
            // No cost basis either — show a flat line so the chart area isn't empty
            return [0.5, 0.5]
        }

        guard relevantHistory.count >= 2 else { return [] }

        let values = relevantHistory.map { $0.value }
        guard let minVal = values.min(), let maxVal = values.max() else { return [] }
        let range = maxVal - minVal

        if range < 0.01 {
            return values.map { _ in CGFloat(0.5) }
        }

        return values.map { CGFloat(($0 - minVal) / range) }
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

    // Get all risk levels for user's selected coins (with consecutive days)
    var userSelectedRiskLevels: [(coin: String, riskLevel: ITCRiskLevel?, daysAtLevel: Int?)] {
        userRiskCoins.map { coin in
            let level = riskLevels[coin]
            let history = riskHistories[coin] ?? []
            return (coin, level, consecutiveDaysAtCurrentLevel(history: history, current: level))
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

    // Cached crypto assets for favorites filtering
    private(set) var cachedCryptoAssets: [CryptoAsset] = []

    /// Favorite assets computed from FavoritesStore + cached crypto data
    var favoriteAssets: [CryptoAsset] {
        let favoriteIds = FavoritesStore.shared.allFavoriteIds()
        guard !favoriteIds.isEmpty else { return [] }
        return cachedCryptoAssets.filter { favoriteIds.contains($0.id) }
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
        santimentService: SantimentServiceProtocol = ServiceContainer.shared.santimentService
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
        // Initialize user data synchronously; data loading is triggered by HomeView.task
        self.sentimentViewModel = SentimentViewModel()
        startAutoRefresh()
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

    /// Refresh only events data (lighter weight than full refresh)
    func refreshEvents() async {
        guard !isRefreshing else { return }
        do {
            let upcoming = try await newsService.fetchUpcomingEvents(days: 7, impactFilter: [.high, .medium])

            await MainActor.run {
                self.upcomingEvents = upcoming
                self.eventsLastUpdated = Date()
            }
            logInfo("HomeViewModel: Auto-refreshed events at \(Date())", category: .data)
        } catch {
            logError("HomeViewModel: Failed to refresh events: \(error)", category: .data)
        }
    }

    // MARK: - Public Methods
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        isLoading = true
        defer {
            isLoading = false
            isRefreshing = false
        }
        errorMessage = nil

        let userId = await MainActor.run { SupabaseAuthManager.shared.currentUserId }
        let riskCoins = AssetRiskConfig.allConfigs.map(\.assetId)

        // Launch ALL fetches in parallel — crypto no longer blocks macro/sentiment
        async let cryptoTask = fetchCryptoAssetsSafe()
        async let vixTask = fetchVIXSafe()
        async let dxyTask = fetchDXYSafe()
        async let liquidityTask = fetchGlobalLiquiditySafe()
        async let supplyProfitTask = fetchSupplyInProfitSafe()
        async let fedWatchTask = fetchFedWatchMeetingsSafe()
        async let upcomingEventsTask = fetchUpcomingEventsSafe()
        async let todaysEventsTask = fetchTodaysEventsSafe()
        async let riskResultsTask = fetchAllRiskLevels(coins: riskCoins)
        async let zScoresTask = fetchMacroZScoresSafe()

        async let fgResult: FearGreedIndex? = {
            do {
                return try await sentimentService.fetchFearGreedIndex()
            } catch {
                logError("Fear & Greed fetch failed: \(error.localizedDescription)", category: .network)
                return nil
            }
        }()

        async let riskScoreResult: ArkLineRiskScore? = {
            do {
                return try await sentimentService.fetchArkLineRiskScore()
            } catch {
                logError("ArkLine Risk Score fetch failed: \(error.localizedDescription)", category: .network)
                return nil
            }
        }()

        async let remindersResult: [DCAReminder] = {
            guard let uid = userId else { return [] }
            do {
                return try await dcaService.fetchReminders(userId: uid)
            } catch {
                logError("Reminders fetch failed: \(error.localizedDescription)", category: .network)
                return []
            }
        }()

        async let newsResult: [NewsItem] = {
            do {
                return try await newsService.fetchNews(category: nil, page: 1, perPage: 5)
            } catch {
                logError("News fetch failed: \(error.localizedDescription)", category: .network)
                return []
            }
        }()

        // Process events first (hardcoded data, instant)
        let upcoming = await upcomingEventsTask
        let todaysEvts = await todaysEventsTask
        await MainActor.run {
            self.upcomingEvents = upcoming
            self.todaysEvents = todaysEvts
            self.eventsLastUpdated = Date()
        }

        // Process crypto prices as soon as they arrive
        let crypto = await cryptoTask

        if !crypto.isEmpty {
            Task { await MarketDataCollector.shared.recordCryptoAssets(crypto) }
            cachedCryptoAssets = crypto
        }

        let btc = crypto.first { $0.symbol.uppercased() == "BTC" }
        let eth = crypto.first { $0.symbol.uppercased() == "ETH" }
        let sol = crypto.first { $0.symbol.uppercased() == "SOL" }

        await MainActor.run {
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
        }

        // Process macro indicators
        let vix = await vixTask
        let dxy = await dxyTask
        let liquidity = await liquidityTask
        let supplyProfit = await supplyProfitTask
        let fedMeetings = await fedWatchTask
        let riskResults = await riskResultsTask

        await MainActor.run {
            self.vixData = vix
            self.dxyData = dxy
            self.globalLiquidityChanges = liquidity
            self.supplyInProfitData = supplyProfit
            self.fedWatchMeetings = fedMeetings ?? []
            for (coin, level, history) in riskResults {
                self.riskLevels[coin] = level
                self.riskHistories[coin] = history
            }
        }

        // Archive macro indicators (fire-and-forget)
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
            if let sp = supplyProfit {
                await collector.recordIndicator(name: "supply_in_profit", value: sp.value)
            }
        }

        // Process secondary data (sentiment, news, reminders, z-scores)
        let (fg, riskScore, reminders, news) = await (fgResult, riskScoreResult, remindersResult, newsResult)
        let zScores = await zScoresTask

        let failureCount = (crypto.isEmpty ? 1 : 0) + (fg == nil ? 1 : 0) + (riskScore == nil ? 1 : 0)

        await MainActor.run {
            if let fg = fg {
                self.fearGreedIndex = fg
            }
            self.activeReminders = reminders.filter { $0.isActive }
            self.todayReminders = reminders.filter { $0.isDueToday }
            if let riskScore = riskScore {
                self.compositeRiskScore = riskScore.score
                self.arkLineRiskScore = riskScore
            }
            self.newsItems = news
            self.macroZScores = zScores
            ExtremeMoveAlertManager.shared.checkAllForExtremeMoves(zScores)
            self.failedFetchCount = failureCount
            self.lastRefreshed = Date()
        }

        // Archive fear/greed and risk score (fire-and-forget)
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
            _ = try await dcaService.markAsInvested(id: reminder.id)

            await MainActor.run {
                if let index = self.activeReminders.firstIndex(where: { $0.id == reminder.id }) {
                    self.activeReminders[index].completedPurchases += 1
                }
                if let index = self.todayReminders.firstIndex(where: { $0.id == reminder.id }) {
                    self.todayReminders.remove(at: index)
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = AppError.from(error).userMessage
            }
        }
    }

    func loadPortfolios() async {
        do {
            let resolvedUserId: UUID? = await MainActor.run { SupabaseAuthManager.shared.currentUserId }
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
                self.hasLoadedPortfolios = true
            }

            // Load real holdings data for the selected portfolio
            if let portfolio = selectedPortfolio {
                await loadPortfolioData(for: portfolio)
            }
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

    private func fetchMacroZScoresSafe() async -> [MacroIndicatorType: MacroZScoreData] {
        do {
            return try await macroStatisticsService.fetchAllZScores()
        } catch {
            logError("Macro Z-scores fetch failed: \(error.localizedDescription)", category: .network)
            return [:]
        }
    }
}
