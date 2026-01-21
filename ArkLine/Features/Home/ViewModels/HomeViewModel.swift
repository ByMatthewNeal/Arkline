import SwiftUI

// MARK: - Home View Model
@Observable
class HomeViewModel {
    // MARK: - Dependencies
    private let sentimentService: SentimentServiceProtocol
    private let marketService: MarketServiceProtocol
    private let dcaService: DCAServiceProtocol
    private let newsService: NewsServiceProtocol

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

    // Market Summary
    var btcPrice: Double = 0
    var ethPrice: Double = 0
    var btcChange24h: Double = 0
    var ethChange24h: Double = 0

    // Portfolio Summary
    var portfolioValue: Double = 0
    var portfolioChange24h: Double = 0
    var portfolioChangePercent: Double = 0

    // Composite Risk Score (0-100)
    var compositeRiskScore: Int? = nil

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
        newsService: NewsServiceProtocol = ServiceContainer.shared.newsService
    ) {
        self.sentimentService = sentimentService
        self.marketService = marketService
        self.dcaService = dcaService
        self.newsService = newsService
        Task { await loadInitialData() }
    }

    // MARK: - Public Methods
    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            let userId = currentUserId ?? UUID()

            // Fetch all data concurrently
            async let fgTask = sentimentService.fetchFearGreedIndex()
            async let cryptoTask = marketService.fetchCryptoAssets(page: 1, perPage: 20)
            async let remindersTask = dcaService.fetchReminders(userId: userId)
            async let eventsTask = newsService.fetchTodaysEvents()

            let (fg, crypto, reminders, events) = try await (fgTask, cryptoTask, remindersTask, eventsTask)

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
                self.btcPrice = btc?.currentPrice ?? 0
                self.ethPrice = eth?.currentPrice ?? 0
                self.btcChange24h = btc?.priceChangePercentage24h ?? 0
                self.ethChange24h = eth?.priceChangePercentage24h ?? 0
                self.topGainers = gainers
                self.topLosers = losers
                self.compositeRiskScore = fg.value
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

    // MARK: - Private Methods
    private func loadInitialData() async {
        // Set initial user data
        await MainActor.run {
            self.userName = "Matthew"
            self.portfolioValue = 125432.67
            self.portfolioChange24h = 2341.23
            self.portfolioChangePercent = 1.89
        }

        await refresh()
    }
}
