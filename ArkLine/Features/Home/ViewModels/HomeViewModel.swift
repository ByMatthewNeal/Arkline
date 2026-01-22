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

    // Market Summary
    var btcPrice: Double = 0
    var ethPrice: Double = 0
    var btcChange24h: Double = 0
    var ethChange24h: Double = 0

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
        let seed = (selectedPortfolio?.name ?? "Main").hashValue
        srand48(seed + period.hashValue)

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
        let seed = selectedPortfolio?.name.hashValue ?? 0
        srand48(seed + period.hashValue)

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

    // ITC Risk Level (Into The Cryptoverse - powers ArkLine Risk Score card)
    var btcRiskLevel: ITCRiskLevel?

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
        itcRiskService: ITCRiskServiceProtocol = ServiceContainer.shared.itcRiskService
    ) {
        self.sentimentService = sentimentService
        self.marketService = marketService
        self.dcaService = dcaService
        self.newsService = newsService
        self.portfolioService = portfolioService
        self.itcRiskService = itcRiskService
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
        isLoading = true
        errorMessage = nil

        do {
            let userId = currentUserId ?? UUID()

            // Fetch all data concurrently
            async let fgTask = sentimentService.fetchFearGreedIndex()
            async let riskScoreTask = sentimentService.fetchArkLineRiskScore()
            async let cryptoTask = marketService.fetchCryptoAssets(page: 1, perPage: 20)
            async let remindersTask = dcaService.fetchReminders(userId: userId)
            async let eventsTask = newsService.fetchTodaysEvents()
            async let upcomingEventsTask = newsService.fetchUpcomingEvents(days: 7, impactFilter: [.high, .medium])
            async let newsTask = newsService.fetchNews(category: nil, page: 1, perPage: 5)
            async let fedWatchTask = fetchFedWatchMeetingsSafe()
            async let btcRiskTask = fetchITCRiskLevelSafe(coin: "BTC")

            let (fg, riskScore, crypto, reminders, events, upcoming) = try await (fgTask, riskScoreTask, cryptoTask, remindersTask, eventsTask, upcomingEventsTask)
            let news = try await newsTask
            let fedMeetings = await fedWatchTask
            let btcRisk = await btcRiskTask

            logInfo("HomeViewModel: Fetched \(crypto.count) crypto assets", category: .data)

            // Extract BTC and ETH prices from crypto data
            let btc = crypto.first { $0.symbol.uppercased() == "BTC" }
            let eth = crypto.first { $0.symbol.uppercased() == "ETH" }

            logInfo("HomeViewModel: BTC = \(btc?.currentPrice ?? -1), ETH = \(eth?.currentPrice ?? -1)", category: .data)

            // Calculate top gainers and losers
            let sortedByGain = crypto.sorted { $0.priceChangePercentage24h > $1.priceChangePercentage24h }
            let gainers = Array(sortedByGain.prefix(3))
            let losers = Array(sortedByGain.suffix(3).reversed())

            await MainActor.run {
                self.fearGreedIndex = fg
                self.favoriteAssets = Array(crypto.prefix(3))
                self.activeReminders = reminders.filter { $0.isActive }
                self.todayReminders = reminders.filter { $0.isDueToday }
                self.todaysEvents = events
                self.upcomingEvents = upcoming
                self.eventsLastUpdated = Date()
                self.btcPrice = btc?.currentPrice ?? 0
                self.ethPrice = eth?.currentPrice ?? 0
                self.btcChange24h = btc?.priceChangePercentage24h ?? 0
                self.ethChange24h = eth?.priceChangePercentage24h ?? 0
                self.topGainers = gainers
                self.topLosers = losers
                self.compositeRiskScore = riskScore.score
                self.arkLineRiskScore = riskScore
                // ITC Risk Level (powers ArkLine Risk Score card)
                self.btcRiskLevel = btcRisk
                // Market widget data
                self.newsItems = news
                self.fedWatchMeetings = fedMeetings ?? []
                self.isLoading = false
                logInfo("HomeViewModel: Set btcPrice=\(self.btcPrice), ethPrice=\(self.ethPrice)", category: .data)
            }
        } catch {
            logError("HomeViewModel refresh failed: \(error)", category: .data)
            await MainActor.run {
                self.errorMessage = error.localizedDescription
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
            let userId = currentUserId ?? UUID()
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
                portfolioValue = 125432.67
            case "Crypto Only":
                portfolioValue = 142580.00
            case "Long Term":
                portfolioValue = 89750.25
            default:
                portfolioValue = 50000.00
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
}
