import SwiftUI

// MARK: - Home View Model
@Observable
class HomeViewModel {
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
    init() {
        loadMockData()
    }

    // MARK: - Public Methods
    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            async let fearGreed = fetchFearGreedIndex()
            async let favorites = fetchFavorites()
            async let reminders = fetchDCAReminders()
            async let events = fetchTodaysEvents()
            async let prices = fetchMarketPrices()

            let (fg, fav, rem, ev, pr) = try await (fearGreed, favorites, reminders, events, prices)

            await MainActor.run {
                self.fearGreedIndex = fg
                self.favoriteAssets = fav
                self.activeReminders = rem
                self.todayReminders = rem.filter { $0.isDueToday }
                self.todaysEvents = ev
                self.btcPrice = pr.btc
                self.ethPrice = pr.eth
                self.btcChange24h = pr.btcChange
                self.ethChange24h = pr.ethChange
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func markReminderComplete(_ reminder: DCAReminder) {
        if let index = activeReminders.firstIndex(where: { $0.id == reminder.id }) {
            activeReminders[index].completedPurchases += 1
        }
        if let index = todayReminders.firstIndex(where: { $0.id == reminder.id }) {
            todayReminders.remove(at: index)
        }
    }

    // MARK: - Private Methods
    private func fetchFearGreedIndex() async throws -> FearGreedIndex {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)
        return FearGreedIndex(
            value: 65,
            classification: "Greed",
            timestamp: Date()
        )
    }

    private func fetchFavorites() async throws -> [CryptoAsset] {
        try await Task.sleep(nanoseconds: 300_000_000)
        return [
            CryptoAsset(
                id: "bitcoin",
                symbol: "BTC",
                name: "Bitcoin",
                currentPrice: 67234.50,
                priceChange24h: 1523.40,
                priceChangePercentage24h: 2.32,
                iconUrl: "https://assets.coingecko.com/coins/images/1/large/bitcoin.png",
                marketCap: 1324500000000,
                marketCapRank: 1
            ),
            CryptoAsset(
                id: "ethereum",
                symbol: "ETH",
                name: "Ethereum",
                currentPrice: 3456.78,
                priceChange24h: -45.23,
                priceChangePercentage24h: -1.29,
                iconUrl: "https://assets.coingecko.com/coins/images/279/large/ethereum.png",
                marketCap: 415600000000,
                marketCapRank: 2
            ),
            CryptoAsset(
                id: "solana",
                symbol: "SOL",
                name: "Solana",
                currentPrice: 145.67,
                priceChange24h: 8.92,
                priceChangePercentage24h: 6.52,
                iconUrl: "https://assets.coingecko.com/coins/images/4128/large/solana.png",
                marketCap: 67800000000,
                marketCapRank: 5
            )
        ]
    }

    private func fetchDCAReminders() async throws -> [DCAReminder] {
        try await Task.sleep(nanoseconds: 200_000_000)
        return [
            DCAReminder(
                id: UUID(),
                userId: UUID(),
                symbol: "BTC",
                name: "Bitcoin",
                amount: 100,
                frequency: .weekly,
                totalPurchases: 52,
                completedPurchases: 12,
                notificationTime: Date(),
                startDate: Date().addingTimeInterval(-86400 * 84),
                nextReminderDate: Date(),
                isActive: true,
                createdAt: Date()
            ),
            DCAReminder(
                id: UUID(),
                userId: UUID(),
                symbol: "ETH",
                name: "Ethereum",
                amount: 50,
                frequency: .biweekly,
                totalPurchases: 26,
                completedPurchases: 6,
                notificationTime: Date(),
                startDate: Date().addingTimeInterval(-86400 * 84),
                nextReminderDate: Date().addingTimeInterval(86400 * 7),
                isActive: true,
                createdAt: Date()
            )
        ]
    }

    private func fetchTodaysEvents() async throws -> [EconomicEvent] {
        try await Task.sleep(nanoseconds: 200_000_000)
        return [
            EconomicEvent(
                id: UUID(),
                title: "FOMC Meeting Minutes",
                country: "US",
                date: Date(),
                time: nil,
                impact: .high,
                forecast: nil,
                previous: nil,
                actual: nil,
                currency: "USD",
                description: "Federal Open Market Committee meeting minutes release"
            ),
            EconomicEvent(
                id: UUID(),
                title: "Initial Jobless Claims",
                country: "US",
                date: Date(),
                time: nil,
                impact: .medium,
                forecast: "210K",
                previous: "215K",
                actual: nil,
                currency: "USD",
                description: "Weekly unemployment claims"
            )
        ]
    }

    private func fetchMarketPrices() async throws -> (btc: Double, eth: Double, btcChange: Double, ethChange: Double) {
        try await Task.sleep(nanoseconds: 300_000_000)
        return (67234.50, 3456.78, 2.32, -1.29)
    }

    private func loadMockData() {
        userName = "Daniel"
        fearGreedIndex = FearGreedIndex(
            value: 65,
            classification: "Greed",
            timestamp: Date()
        )

        favoriteAssets = [
            CryptoAsset(
                id: "bitcoin",
                symbol: "BTC",
                name: "Bitcoin",
                currentPrice: 67234.50,
                priceChange24h: 1523.40,
                priceChangePercentage24h: 2.32,
                iconUrl: nil,
                marketCap: 1324500000000,
                marketCapRank: 1
            ),
            CryptoAsset(
                id: "ethereum",
                symbol: "ETH",
                name: "Ethereum",
                currentPrice: 3456.78,
                priceChange24h: -45.23,
                priceChangePercentage24h: -1.29,
                iconUrl: nil,
                marketCap: 415600000000,
                marketCapRank: 2
            )
        ]

        activeReminders = [
            DCAReminder(
                id: UUID(),
                userId: UUID(),
                symbol: "BTC",
                name: "Bitcoin",
                amount: 100,
                frequency: .weekly,
                totalPurchases: 52,
                completedPurchases: 12,
                notificationTime: Date(),
                startDate: Date().addingTimeInterval(-86400 * 84),
                nextReminderDate: Date(),
                isActive: true,
                createdAt: Date()
            )
        ]
        todayReminders = activeReminders.filter { $0.isDueToday }

        todaysEvents = [
            EconomicEvent(
                id: UUID(),
                title: "FOMC Meeting Minutes",
                country: "US",
                date: Date(),
                time: nil,
                impact: .high,
                forecast: nil,
                previous: nil,
                actual: nil,
                currency: "USD",
                description: "Federal Open Market Committee meeting minutes release"
            )
        ]

        btcPrice = 67234.50
        ethPrice = 3456.78
        btcChange24h = 2.32
        ethChange24h = -1.29

        // Portfolio mock data
        portfolioValue = 125432.67
        portfolioChange24h = 2341.23
        portfolioChangePercent = 1.89

        // Composite Risk Score (65 = Moderately Bullish)
        compositeRiskScore = 65

        // Top Gainers
        topGainers = [
            CryptoAsset(
                id: "solana",
                symbol: "SOL",
                name: "Solana",
                currentPrice: 145.67,
                priceChange24h: 12.34,
                priceChangePercentage24h: 9.25,
                iconUrl: nil,
                marketCap: 67800000000,
                marketCapRank: 5
            ),
            CryptoAsset(
                id: "avalanche",
                symbol: "AVAX",
                name: "Avalanche",
                currentPrice: 38.92,
                priceChange24h: 2.87,
                priceChangePercentage24h: 7.96,
                iconUrl: nil,
                marketCap: 15200000000,
                marketCapRank: 12
            ),
            CryptoAsset(
                id: "chainlink",
                symbol: "LINK",
                name: "Chainlink",
                currentPrice: 14.56,
                priceChange24h: 0.89,
                priceChangePercentage24h: 6.51,
                iconUrl: nil,
                marketCap: 8500000000,
                marketCapRank: 15
            )
        ]

        // Top Losers
        topLosers = [
            CryptoAsset(
                id: "dogecoin",
                symbol: "DOGE",
                name: "Dogecoin",
                currentPrice: 0.0823,
                priceChange24h: -0.0067,
                priceChangePercentage24h: -7.52,
                iconUrl: nil,
                marketCap: 11800000000,
                marketCapRank: 9
            ),
            CryptoAsset(
                id: "shiba-inu",
                symbol: "SHIB",
                name: "Shiba Inu",
                currentPrice: 0.00001234,
                priceChange24h: -0.00000089,
                priceChangePercentage24h: -6.73,
                iconUrl: nil,
                marketCap: 7200000000,
                marketCapRank: 18
            ),
            CryptoAsset(
                id: "cardano",
                symbol: "ADA",
                name: "Cardano",
                currentPrice: 0.456,
                priceChange24h: -0.023,
                priceChangePercentage24h: -4.80,
                iconUrl: nil,
                marketCap: 16100000000,
                marketCapRank: 10
            )
        ]
    }
}
