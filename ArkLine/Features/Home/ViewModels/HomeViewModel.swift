import SwiftUI
import Combine

// MARK: - Home View Model
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

    // Favorites
    var favoriteAssets: [CryptoAsset] = []

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

    // Portfolio Summary (base value for selected portfolio)
    var portfolioValue: Double = 0
    private var basePortfolioChange: Double = 0
    private var basePortfolioChangePercent: Double = 0

    // Time-period adjusted values (computed)
    var portfolioChange: Double {
        getChangeForTimePeriod(selectedTimePeriod).amount
    }

    var portfolioChangePercent: Double {
        getChangeForTimePeriod(selectedTimePeriod).percent
    }

    // Portfolio Chart Data - computed based on selected time period
    var portfolioChartData: [CGFloat] {
        generateChartData(for: selectedTimePeriod, isPositive: portfolioChange >= 0)
    }

    /// Returns mock change data for each time period
    /// In production, this would fetch historical data from an API
    private func getChangeForTimePeriod(_ period: TimePeriod) -> (amount: Double, percent: Double) {
        // Use portfolio name as seed for consistent data
        // Use overflow addition (&+) to prevent arithmetic overflow crash
        let seed = (selectedPortfolio?.name ?? "Main").hashValue &+ period.hashValue
        srand48(seed)

        // Base the mock data on realistic scenarios
        switch period {
        case .hour:
            // Small fluctuations for 1 hour
            let percent = (drand48() - 0.4) * 0.8  // -0.32% to +0.48%
            let amount = portfolioValue * percent / 100
            return (amount, percent)

        case .day:
            // Typical daily movement
            let percent = (drand48() - 0.35) * 4.0  // -1.4% to +2.6%
            let amount = portfolioValue * percent / 100
            return (amount, percent)

        case .week:
            // Weekly movement - slightly larger
            let percent = (drand48() - 0.3) * 8.0  // -2.4% to +5.6%
            let amount = portfolioValue * percent / 100
            return (amount, percent)

        case .month:
            // Monthly movement
            let percent = (drand48() - 0.25) * 15.0  // -3.75% to +11.25%
            let amount = portfolioValue * percent / 100
            return (amount, percent)

        case .ytd:
            // Year-to-date - use current month to vary
            let monthProgress = Double(Calendar.current.component(.month, from: Date())) / 12.0
            let basePercent = (drand48() - 0.2) * 30.0 * monthProgress  // Scales with year progress
            let amount = portfolioValue * basePercent / 100
            return (amount, basePercent)

        case .year:
            // Full year - larger swings possible
            let percent = (drand48() - 0.15) * 50.0  // -7.5% to +42.5%
            let amount = portfolioValue * percent / 100
            return (amount, percent)

        case .all:
            // All time - typically positive for long-term holdings
            let percent = (drand48() * 0.8 + 0.2) * 150.0  // +30% to +150%
            let amount = portfolioValue * percent / 100
            return (amount, percent)
        }
    }

    /// Generates mock chart data based on time period
    /// In production, this would fetch from an API
    private func generateChartData(for period: TimePeriod, isPositive: Bool) -> [CGFloat] {
        // Different data point counts for different time periods
        let dataPointCount: Int
        let volatility: CGFloat
        let trendStrength: CGFloat

        switch period {
        case .hour:
            dataPointCount = 12  // Every 5 minutes
            volatility = 0.02
            trendStrength = 0.3
        case .day:
            dataPointCount = 24  // Hourly
            volatility = 0.03
            trendStrength = 0.5
        case .week:
            dataPointCount = 28  // 4x daily
            volatility = 0.05
            trendStrength = 0.6
        case .month:
            dataPointCount = 30  // Daily
            volatility = 0.08
            trendStrength = 0.7
        case .ytd:
            dataPointCount = 52  // Weekly-ish
            volatility = 0.12
            trendStrength = 0.8
        case .year:
            dataPointCount = 52  // Weekly
            volatility = 0.15
            trendStrength = 0.85
        case .all:
            dataPointCount = 60  // Monthly
            volatility = 0.20
            trendStrength = 0.9
        }

        // Generate data with a trend and some noise
        var data: [CGFloat] = []
        var currentValue: CGFloat = 0.3  // Start point

        // Use portfolio name as seed for consistent data per portfolio
        // Use overflow addition (&+) to prevent arithmetic overflow crash
        let seed = (selectedPortfolio?.name.hashValue ?? 0) &+ period.hashValue
        srand48(seed)

        for i in 0..<dataPointCount {
            // Add trend direction
            let progress = CGFloat(i) / CGFloat(dataPointCount - 1)
            let trend = isPositive ? trendStrength * progress : -trendStrength * progress * 0.5

            // Add some controlled randomness
            let noise = CGFloat(drand48() - 0.5) * volatility

            // Small dips and recoveries for realism
            let cycleNoise = sin(CGFloat(i) * 0.5) * volatility * 0.5

            currentValue = max(0.1, min(0.95, currentValue + trend * 0.05 + noise + cycleNoise))
            data.append(currentValue)
        }

        // Ensure end point reflects the trend direction
        if isPositive {
            data[data.count - 1] = max(data[data.count - 1], 0.85)
        } else {
            data[data.count - 1] = min(data[data.count - 1], 0.35)
        }

        return data
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
        var count = 0

        // Count backwards from end of history
        for level in history.reversed() {
            if level.riskCategory == currentCategory {
                count += 1
            } else {
                break
            }
        }

        // Only return if we have at least 2 days (meaningful streak)
        return count >= 2 ? count : nil
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

    deinit {
        stopAutoRefresh()
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
        var failures = 0

        let userId = await MainActor.run { SupabaseAuthManager.shared.currentUserId }

        // Fetch crypto prices first (critical for Core widget) - independent of other fetches
        let crypto = await fetchCryptoAssetsSafe()
        if crypto.isEmpty { failures += 1 }

        // Extract BTC, ETH, and SOL prices immediately
        let btc = crypto.first { $0.symbol.uppercased() == "BTC" }
        let eth = crypto.first { $0.symbol.uppercased() == "ETH" }
        let sol = crypto.first { $0.symbol.uppercased() == "SOL" }

        // Set prices on main actor immediately
        await MainActor.run {
            self.btcPrice = btc?.currentPrice ?? 0
            self.ethPrice = eth?.currentPrice ?? 0
            self.solPrice = sol?.currentPrice ?? 0
            self.btcChange24h = btc?.priceChangePercentage24h ?? 0
            self.ethChange24h = eth?.priceChangePercentage24h ?? 0
            self.solChange24h = sol?.priceChangePercentage24h ?? 0
            self.favoriteAssets = Array(crypto.prefix(3))

            // Calculate top gainers and losers
            let sortedByGain = crypto.sorted { $0.priceChangePercentage24h > $1.priceChangePercentage24h }
            self.topGainers = Array(sortedByGain.prefix(3))
            self.topLosers = Array(sortedByGain.suffix(3).reversed())
        }

        // Fetch macro indicators and hardcoded events independently (these should always succeed quickly)
        async let vixTask = fetchVIXSafe()
        async let dxyTask = fetchDXYSafe()
        async let liquidityTask = fetchGlobalLiquiditySafe()
        async let supplyProfitTask = fetchSupplyInProfitSafe()
        async let fedWatchTask = fetchFedWatchMeetingsSafe()
        async let upcomingEventsTask = fetchUpcomingEventsSafe()
        async let todaysEventsTask = fetchTodaysEventsSafe()

        // Fetch risk levels for all supported coins in parallel
        let riskCoins = AssetRiskConfig.allConfigs.map(\.assetId)
        async let riskResultsTask = fetchAllRiskLevels(coins: riskCoins)

        // Await macro indicators and events first (these use safe wrappers, won't throw)
        let vix = await vixTask
        let dxy = await dxyTask
        let liquidity = await liquidityTask
        let supplyProfit = await supplyProfitTask
        let fedMeetings = await fedWatchTask
        let riskResults = await riskResultsTask
        let upcoming = await upcomingEventsTask
        let todaysEvts = await todaysEventsTask

        // Update macro indicators and events immediately (before slow network calls)
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
            self.upcomingEvents = upcoming
            self.todaysEvents = todaysEvts
            self.eventsLastUpdated = Date()
        }

        // Fetch z-scores alongside other secondary data
        async let zScoresTask = fetchMacroZScoresSafe()

        // Fetch other data independently so each can succeed/fail on its own
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

        let (fg, riskScore, reminders, news) = await (fgResult, riskScoreResult, remindersResult, newsResult)
        let zScores = await zScoresTask

        // Count secondary failures
        if fg == nil { failures += 1 }
        if riskScore == nil { failures += 1 }

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
            self.failedFetchCount = failures
            self.lastRefreshed = Date()
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
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func loadPortfolios() async {
        do {
            let resolvedUserId: UUID? = await MainActor.run { SupabaseAuthManager.shared.currentUserId }
            guard let userId = resolvedUserId else {
                logWarning("No authenticated user for portfolio fetch", category: .data)
                return
            }
            let fetchedPortfolios = try await portfolioService.fetchPortfolios(userId: userId)

            await MainActor.run {
                self.portfolios = fetchedPortfolios
                // Select first portfolio if none selected
                if self.selectedPortfolio == nil, let first = fetchedPortfolios.first {
                    self.selectedPortfolio = first
                    self.updatePortfolioValues(for: first)
                }
            }
        } catch {
            logError("Failed to load portfolios: \(error)", category: .data)
        }
    }

    func selectPortfolio(_ portfolio: Portfolio) {
        selectedPortfolio = portfolio
        updatePortfolioValues(for: portfolio)
    }

    func selectRiskCoin(_ coin: String) {
        selectedRiskCoin = coin
    }

    // MARK: - Private Methods
    private func updatePortfolioValues(for portfolio: Portfolio) {
        // Calculate portfolio value from holdings
        if let holdings = portfolio.holdings {
            let totalValue = holdings.reduce(0.0) { $0 + $1.currentValue }
            let totalCost = holdings.reduce(0.0) { $0 + $1.totalCost }
            let change = totalValue - totalCost
            let changePercent = totalCost > 0 ? (change / totalCost) * 100 : 0

            portfolioValue = totalValue
            basePortfolioChange = change
            basePortfolioChangePercent = changePercent
        } else {
            // Use mock values based on portfolio name for demo
            // Change values are computed dynamically based on time period
            switch portfolio.name {
            case "Main Portfolio":
                portfolioValue = 3_017_500.00
            case "Crypto Only":
                portfolioValue = 3_450_000.00
            case "Long Term":
                portfolioValue = 2_847_500.00
            default:
                portfolioValue = 2_500_000.00
            }
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
            return try await marketService.fetchCryptoAssets(page: 1, perPage: 20)
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
