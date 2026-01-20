import Foundation

// MARK: - Mock News Service
/// Mock implementation of NewsServiceProtocol for development and testing.
final class MockNewsService: NewsServiceProtocol {
    // MARK: - Configuration
    var simulatedDelay: UInt64 = 400_000_000

    // MARK: - NewsServiceProtocol

    func fetchNews(category: String?, page: Int, perPage: Int) async throws -> [NewsItem] {
        try await simulateNetworkDelay()
        let allNews = generateMockNews()

        if let category = category {
            return allNews.filter { $0.source.lowercased().contains(category.lowercased()) }
        }

        let startIndex = (page - 1) * perPage
        let endIndex = min(startIndex + perPage, allNews.count)

        guard startIndex < allNews.count else { return [] }

        return Array(allNews[startIndex..<endIndex])
    }

    func fetchNewsForCurrencies(_ currencies: [String], page: Int) async throws -> [NewsItem] {
        try await simulateNetworkDelay()
        let allNews = generateMockNews()

        return allNews.filter { news in
            currencies.contains { currency in
                news.title.lowercased().contains(currency.lowercased())
            }
        }
    }

    func searchNews(query: String) async throws -> [NewsItem] {
        try await simulateNetworkDelay()
        let allNews = generateMockNews()

        guard !query.isEmpty else { return allNews }

        return allNews.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.source.localizedCaseInsensitiveContains(query)
        }
    }

    func fetchTodaysEvents() async throws -> [EconomicEvent] {
        try await simulateNetworkDelay()
        return generateMockEconomicEvents().filter { Calendar.current.isDateInToday($0.date) }
    }

    func fetchEconomicEvents(from startDate: Date, to endDate: Date) async throws -> [EconomicEvent] {
        try await simulateNetworkDelay()
        return generateMockEconomicEvents().filter { event in
            event.date >= startDate && event.date <= endDate
        }
    }

    func fetchFedWatchData() async throws -> FedWatchData {
        try await simulateNetworkDelay()
        return FedWatchData(
            meetingDate: Calendar.current.date(byAdding: .day, value: 21, to: Date()) ?? Date(),
            currentRate: 5.25,
            probabilities: [
                RateProbability(targetRate: 5.25, change: 0, probability: 0.72),
                RateProbability(targetRate: 5.00, change: -25, probability: 0.28),
                RateProbability(targetRate: 5.50, change: 25, probability: 0.00)
            ],
            lastUpdated: Date()
        )
    }

    func fetchUpcomingFedMeetings() async throws -> [FedMeeting] {
        try await simulateNetworkDelay()
        let calendar = Calendar.current

        return [
            FedMeeting(
                date: calendar.date(byAdding: .day, value: 21, to: Date()) ?? Date(),
                type: .fomc,
                hasProjections: true
            ),
            FedMeeting(
                date: calendar.date(byAdding: .day, value: 35, to: Date()) ?? Date(),
                type: .minutes,
                hasProjections: false
            ),
            FedMeeting(
                date: calendar.date(byAdding: .day, value: 56, to: Date()) ?? Date(),
                type: .fomc,
                hasProjections: false
            )
        ]
    }

    // MARK: - Private Helpers

    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: simulatedDelay)
    }

    private func generateMockNews() -> [NewsItem] {
        [
            NewsItem(
                id: UUID(),
                title: "Bitcoin Surges Past $67,000 Amid ETF Inflows",
                source: "CoinDesk",
                publishedAt: Date().addingTimeInterval(-3600),
                imageUrl: "https://example.com/bitcoin-surge.jpg",
                url: "https://coindesk.com/bitcoin-surge"
            ),
            NewsItem(
                id: UUID(),
                title: "Ethereum Layer 2 Networks See Record Activity",
                source: "The Block",
                publishedAt: Date().addingTimeInterval(-7200),
                imageUrl: "https://example.com/ethereum-l2.jpg",
                url: "https://theblock.co/ethereum-l2"
            ),
            NewsItem(
                id: UUID(),
                title: "Federal Reserve Signals Potential Rate Cut",
                source: "Reuters",
                publishedAt: Date().addingTimeInterval(-14400),
                imageUrl: "https://example.com/fed-rates.jpg",
                url: "https://reuters.com/fed-rates"
            ),
            NewsItem(
                id: UUID(),
                title: "Solana DeFi TVL Reaches All-Time High",
                source: "DeFi Llama",
                publishedAt: Date().addingTimeInterval(-21600),
                imageUrl: "https://example.com/solana-defi.jpg",
                url: "https://defillama.com/solana"
            ),
            NewsItem(
                id: UUID(),
                title: "BlackRock Bitcoin ETF Sees $500M Daily Inflow",
                source: "Bloomberg",
                publishedAt: Date().addingTimeInterval(-28800),
                imageUrl: nil,
                url: "https://bloomberg.com/blackrock-btc"
            ),
            NewsItem(
                id: UUID(),
                title: "Cardano Announces Major Network Upgrade",
                source: "CryptoSlate",
                publishedAt: Date().addingTimeInterval(-36000),
                imageUrl: nil,
                url: "https://cryptoslate.com/cardano"
            ),
            NewsItem(
                id: UUID(),
                title: "SEC Delays Decision on Ethereum ETF Applications",
                source: "CoinTelegraph",
                publishedAt: Date().addingTimeInterval(-43200),
                imageUrl: nil,
                url: "https://cointelegraph.com/sec-eth"
            ),
            NewsItem(
                id: UUID(),
                title: "MicroStrategy Adds Another 5,000 BTC to Holdings",
                source: "Bitcoin Magazine",
                publishedAt: Date().addingTimeInterval(-50400),
                imageUrl: nil,
                url: "https://bitcoinmagazine.com/microstrategy"
            )
        ]
    }

    private func generateMockEconomicEvents() -> [EconomicEvent] {
        let calendar = Calendar.current

        return [
            EconomicEvent(
                id: UUID(),
                title: "FOMC Meeting Minutes",
                country: "US",
                date: Date(),
                time: calendar.date(from: DateComponents(hour: 14, minute: 0)),
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
                time: calendar.date(from: DateComponents(hour: 8, minute: 30)),
                impact: .medium,
                forecast: "210K",
                previous: "215K",
                actual: nil,
                currency: "USD",
                description: "Weekly unemployment claims"
            ),
            EconomicEvent(
                id: UUID(),
                title: "CPI Data Release",
                country: "US",
                date: calendar.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
                time: calendar.date(from: DateComponents(hour: 8, minute: 30)),
                impact: .high,
                forecast: "3.2%",
                previous: "3.4%",
                actual: nil,
                currency: "USD",
                description: "Consumer Price Index year-over-year"
            ),
            EconomicEvent(
                id: UUID(),
                title: "ECB Interest Rate Decision",
                country: "EU",
                date: calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                time: calendar.date(from: DateComponents(hour: 7, minute: 45)),
                impact: .high,
                forecast: "4.25%",
                previous: "4.50%",
                actual: nil,
                currency: "EUR",
                description: "European Central Bank rate decision"
            ),
            EconomicEvent(
                id: UUID(),
                title: "Non-Farm Payrolls",
                country: "US",
                date: calendar.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
                time: calendar.date(from: DateComponents(hour: 8, minute: 30)),
                impact: .high,
                forecast: "185K",
                previous: "175K",
                actual: nil,
                currency: "USD",
                description: "Monthly employment change"
            )
        ]
    }
}
