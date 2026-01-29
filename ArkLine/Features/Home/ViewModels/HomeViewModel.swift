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

    // MARK: - Auto-Refresh
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 300 // 5 minutes for events
    var eventsLastUpdated: Date?

    // MARK: - Properties
    var isLoading = false
    var errorMessage: String?

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

    // Market Indicators (VIX, DXY, Rainbow, Liquidity)
    var vixData: VIXData?
    var dxyData: DXYData?
    var rainbowChartData: RainbowChartData?
    var globalLiquidityChanges: GlobalLiquidityChanges?

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
    var btcRiskLevel: ITCRiskLevel?
    var ethRiskLevel: ITCRiskLevel?
    var solRiskLevel: ITCRiskLevel?
    var selectedRiskCoin: String = "BTC"

    // User-selected risk coins from settings
    var userRiskCoins: [String] {
        UserDefaults.standard.stringArray(forKey: Constants.UserDefaults.riskCoins) ?? ["BTC", "ETH"]
    }

    // Computed property to get risk level for selected coin
    var selectedRiskLevel: ITCRiskLevel? {
        switch selectedRiskCoin {
        case "BTC": return btcRiskLevel
        case "ETH": return ethRiskLevel
        case "SOL": return solRiskLevel
        default: return btcRiskLevel // Fallback to BTC for other coins
        }
    }

    // Get all risk levels for user's selected coins
    var userSelectedRiskLevels: [(coin: String, riskLevel: ITCRiskLevel?)] {
        userRiskCoins.map { coin in
            switch coin {
            case "BTC": return (coin, btcRiskLevel)
            case "ETH": return (coin, ethRiskLevel)
            case "SOL": return (coin, solRiskLevel)
            default: return (coin, nil)
            }
        }
    }

    // Top Movers
    var topGainers: [CryptoAsset] = []
    var topLosers: [CryptoAsset] = []

    // User
    var userName: String = ""
    var userAvatar: URL?

    // User context
    private var currentUserId: UUID?

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
        macroStatisticsService: MacroStatisticsServiceProtocol = ServiceContainer.shared.macroStatisticsService
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
        Task { await loadInitialData() }
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
        print("🔵 HomeViewModel.refresh() called")
        isLoading = true
        errorMessage = nil

        let userId = currentUserId ?? Constants.Mock.userId

        // Fetch crypto prices first (critical for Core widget) - independent of other fetches
        let crypto = await fetchCryptoAssetsSafe()

        // Extract BTC, ETH, and SOL prices immediately
        let btc = crypto.first { $0.symbol.uppercased() == "BTC" }
        let eth = crypto.first { $0.symbol.uppercased() == "ETH" }
        let sol = crypto.first { $0.symbol.uppercased() == "SOL" }

        print("🟢 HomeViewModel: Fetched \(crypto.count) assets, BTC = \(btc?.currentPrice ?? -1), ETH = \(eth?.currentPrice ?? -1), SOL = \(sol?.currentPrice ?? -1)")

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
        async let fedWatchTask = fetchFedWatchMeetingsSafe()
        async let btcRiskTask = fetchITCRiskLevelSafe(coin: "BTC")
        async let ethRiskTask = fetchITCRiskLevelSafe(coin: "ETH")
        async let solRiskTask = fetchITCRiskLevelSafe(coin: "SOL")
        async let upcomingEventsTask = fetchUpcomingEventsSafe()
        async let todaysEventsTask = fetchTodaysEventsSafe()

        // Await macro indicators and events first (these use safe wrappers, won't throw)
        let vix = await vixTask
        let dxy = await dxyTask
        let liquidity = await liquidityTask
        let fedMeetings = await fedWatchTask
        let btcRisk = await btcRiskTask
        let ethRisk = await ethRiskTask
        let solRisk = await solRiskTask
        let upcoming = await upcomingEventsTask
        let todaysEvts = await todaysEventsTask

        // Update macro indicators and events immediately (before slow network calls)
        await MainActor.run {
            self.vixData = vix
            self.dxyData = dxy
            self.globalLiquidityChanges = liquidity
            self.fedWatchMeetings = fedMeetings ?? []
            self.btcRiskLevel = btcRisk
            self.ethRiskLevel = ethRisk
            self.solRiskLevel = solRisk
            self.upcomingEvents = upcoming
            self.todaysEvents = todaysEvts
            self.eventsLastUpdated = Date()
        }

        // Fetch z-scores in background (doesn't block main UI)
        Task {
            let zScores = await fetchMacroZScoresSafe()
            await MainActor.run {
                self.macroZScores = zScores
                // Check for extreme moves and trigger alerts
                ExtremeMoveAlertManager.shared.checkAllForExtremeMoves(zScores)
            }
        }

        // Now fetch other data that might fail (network-dependent)
        do {
            async let fgTask = sentimentService.fetchFearGreedIndex()
            async let riskScoreTask = sentimentService.fetchArkLineRiskScore()
            async let remindersTask = dcaService.fetchReminders(userId: userId)
            async let newsTask = newsService.fetchNews(category: nil, page: 1, perPage: 5)

            let (fg, riskScore, reminders) = try await (fgTask, riskScoreTask, remindersTask)
            let news = try await newsTask

            await MainActor.run {
                self.fearGreedIndex = fg
                self.activeReminders = reminders.filter { $0.isActive }
                self.todayReminders = reminders.filter { $0.isDueToday }
                self.compositeRiskScore = riskScore.score
                self.arkLineRiskScore = riskScore
                self.newsItems = news

                self.isLoading = false

                // Fetch Rainbow Chart data (needs BTC price) in background
                Task {
                    if self.btcPrice > 0 {
                        self.rainbowChartData = await self.fetchRainbowChartSafe(btcPrice: self.btcPrice)
                    }
                }
            }
        } catch {
            print("🔴 HomeViewModel other data fetch failed: \(error)")
            logError("HomeViewModel other data fetch failed: \(error)", category: .data)
            await MainActor.run {
                // Don't overwrite price data on error - prices are already set
                self.isLoading = false
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
            let userId = currentUserId ?? Constants.Mock.userId
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

    private func loadInitialData() async {
        // Set initial user data
        await MainActor.run {
            self.userName = "Matthew"
            // Initialize sentiment view model for Market Sentiment widget
            self.sentimentViewModel = SentimentViewModel()
        }

        // Load portfolios first
        await loadPortfolios()

        // Then refresh other data
        await refresh()
    }

    private func fetchFedWatchMeetingsSafe() async -> [FedWatchData]? {
        try? await newsService.fetchFedWatchMeetings()
    }

    private func fetchITCRiskLevelSafe(coin: String) async -> ITCRiskLevel? {
        try? await itcRiskService.fetchLatestRiskLevel(coin: coin)
    }

    private func fetchCryptoAssetsSafe() async -> [CryptoAsset] {
        do {
            let assets = try await marketService.fetchCryptoAssets(page: 1, perPage: 20)
            print("🟢 fetchCryptoAssetsSafe: Got \(assets.count) assets")
            return assets
        } catch {
            print("🔴 fetchCryptoAssetsSafe failed: \(error)")
            return []
        }
    }

    private func fetchVIXSafe() async -> VIXData? {
        try? await vixService.fetchLatestVIX()
    }

    private func fetchDXYSafe() async -> DXYData? {
        try? await dxyService.fetchLatestDXY()
    }

    private func fetchRainbowChartSafe(btcPrice: Double) async -> RainbowChartData? {
        try? await rainbowChartService.fetchCurrentRainbowData(btcPrice: btcPrice)
    }

    private func fetchGlobalLiquiditySafe() async -> GlobalLiquidityChanges? {
        try? await globalLiquidityService.fetchLiquidityChanges()
    }

    private func fetchUpcomingEventsSafe() async -> [EconomicEvent] {
        (try? await newsService.fetchUpcomingEvents(days: 7, impactFilter: [.high, .medium])) ?? []
    }

    private func fetchTodaysEventsSafe() async -> [EconomicEvent] {
        (try? await newsService.fetchTodaysEvents()) ?? []
    }

    private func fetchMacroZScoresSafe() async -> [MacroIndicatorType: MacroZScoreData] {
        (try? await macroStatisticsService.fetchAllZScores()) ?? [:]
    }
}
