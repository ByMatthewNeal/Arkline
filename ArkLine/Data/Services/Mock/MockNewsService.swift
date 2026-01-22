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
        // Returns data for the next upcoming meeting
        return generateFedWatchMeetings().first!
    }

    func fetchFedWatchMeetings() async throws -> [FedWatchData] {
        try await simulateNetworkDelay()
        return generateFedWatchMeetings()
    }

    private func generateFedWatchMeetings() -> [FedWatchData] {
        // FOMC meetings for 2026 with realistic probability curves
        // Further out meetings have more uncertainty (probabilities spread out more)
        let calendar = Calendar.current
        let currentRate = 3.625 // Mid-point of 3.50-3.75%

        return [
            // Jan 28, 2026 - Next meeting (high certainty of hold)
            FedWatchData(
                meetingDate: calendar.date(from: DateComponents(year: 2026, month: 1, day: 28))!,
                currentRate: currentRate,
                probabilities: [
                    RateProbability(targetRate: 3.375, change: -25, probability: 0.05),
                    RateProbability(targetRate: 3.625, change: 0, probability: 0.95),
                    RateProbability(targetRate: 3.875, change: 25, probability: 0.00)
                ],
                lastUpdated: Date()
            ),
            // Mar 18, 2026 - More uncertainty, slight cut bias
            FedWatchData(
                meetingDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 18))!,
                currentRate: currentRate,
                probabilities: [
                    RateProbability(targetRate: 3.125, change: -50, probability: 0.02),
                    RateProbability(targetRate: 3.375, change: -25, probability: 0.18),
                    RateProbability(targetRate: 3.625, change: 0, probability: 0.75),
                    RateProbability(targetRate: 3.875, change: 25, probability: 0.05)
                ],
                lastUpdated: Date()
            ),
            // May 6, 2026 - Growing cut expectations
            FedWatchData(
                meetingDate: calendar.date(from: DateComponents(year: 2026, month: 5, day: 6))!,
                currentRate: currentRate,
                probabilities: [
                    RateProbability(targetRate: 3.125, change: -50, probability: 0.08),
                    RateProbability(targetRate: 3.375, change: -25, probability: 0.32),
                    RateProbability(targetRate: 3.625, change: 0, probability: 0.55),
                    RateProbability(targetRate: 3.875, change: 25, probability: 0.05)
                ],
                lastUpdated: Date()
            ),
            // Jun 17, 2026 - Higher cut probability
            FedWatchData(
                meetingDate: calendar.date(from: DateComponents(year: 2026, month: 6, day: 17))!,
                currentRate: currentRate,
                probabilities: [
                    RateProbability(targetRate: 2.875, change: -75, probability: 0.05),
                    RateProbability(targetRate: 3.125, change: -50, probability: 0.15),
                    RateProbability(targetRate: 3.375, change: -25, probability: 0.42),
                    RateProbability(targetRate: 3.625, change: 0, probability: 0.35),
                    RateProbability(targetRate: 3.875, change: 25, probability: 0.03)
                ],
                lastUpdated: Date()
            ),
            // Jul 29, 2026 - Balanced expectations
            FedWatchData(
                meetingDate: calendar.date(from: DateComponents(year: 2026, month: 7, day: 29))!,
                currentRate: currentRate,
                probabilities: [
                    RateProbability(targetRate: 2.875, change: -75, probability: 0.08),
                    RateProbability(targetRate: 3.125, change: -50, probability: 0.22),
                    RateProbability(targetRate: 3.375, change: -25, probability: 0.38),
                    RateProbability(targetRate: 3.625, change: 0, probability: 0.28),
                    RateProbability(targetRate: 3.875, change: 25, probability: 0.04)
                ],
                lastUpdated: Date()
            ),
            // Sep 16, 2026 - 6 months out, more uncertainty
            FedWatchData(
                meetingDate: calendar.date(from: DateComponents(year: 2026, month: 9, day: 16))!,
                currentRate: currentRate,
                probabilities: [
                    RateProbability(targetRate: 2.625, change: -100, probability: 0.05),
                    RateProbability(targetRate: 2.875, change: -75, probability: 0.12),
                    RateProbability(targetRate: 3.125, change: -50, probability: 0.25),
                    RateProbability(targetRate: 3.375, change: -25, probability: 0.30),
                    RateProbability(targetRate: 3.625, change: 0, probability: 0.22),
                    RateProbability(targetRate: 3.875, change: 25, probability: 0.06)
                ],
                lastUpdated: Date()
            )
        ]
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

    func fetchUpcomingEvents(days: Int, impactFilter: [EventImpact]) async throws -> [EconomicEvent] {
        try await simulateNetworkDelay()
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: days, to: Date()) ?? Date()

        return generateUpcomingEconomicEvents()
            .filter { event in
                event.date >= Date() && event.date <= endDate && impactFilter.contains(event.impact)
            }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Private Helpers

    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: simulatedDelay)
    }

    // MARK: - Twitter News

    func fetchTwitterNews(accounts: [String]?, limit: Int) async throws -> [NewsItem] {
        try await simulateNetworkDelay()
        let allTwitterNews = generateMockTwitterNews()

        if let accounts = accounts {
            return allTwitterNews
                .filter { item in
                    guard let handle = item.twitterHandle else { return false }
                    return accounts.contains(handle)
                }
                .prefix(limit)
                .map { $0 }
        }

        return Array(allTwitterNews.prefix(limit))
    }

    // MARK: - Google News

    func fetchGoogleNews(query: String, limit: Int) async throws -> [NewsItem] {
        try await simulateNetworkDelay()
        return Array(generateMockGoogleNews(query: query).prefix(limit))
    }

    // MARK: - Combined News Feed

    func fetchCombinedNewsFeed(limit: Int, includeTwitter: Bool, includeGoogleNews: Bool) async throws -> [NewsItem] {
        try await simulateNetworkDelay()

        var allNews: [NewsItem] = generateMockNews()

        if includeTwitter {
            allNews.append(contentsOf: generateMockTwitterNews())
        }

        if includeGoogleNews {
            allNews.append(contentsOf: generateMockGoogleNews(query: "crypto"))
        }

        // Sort by published date and return limited results
        return Array(allNews.sorted { $0.publishedAt > $1.publishedAt }.prefix(limit))
    }

    // MARK: - Mock Data Generators

    private func generateMockNews() -> [NewsItem] {
        [
            NewsItem(
                id: UUID(),
                title: "Bitcoin Surges Past $67,000 Amid ETF Inflows",
                source: "CoinDesk",
                publishedAt: Date().addingTimeInterval(-3600),
                imageUrl: "https://example.com/bitcoin-surge.jpg",
                url: "https://coindesk.com/bitcoin-surge",
                sourceType: .traditional
            ),
            NewsItem(
                id: UUID(),
                title: "Ethereum Layer 2 Networks See Record Activity",
                source: "The Block",
                publishedAt: Date().addingTimeInterval(-7200),
                imageUrl: "https://example.com/ethereum-l2.jpg",
                url: "https://theblock.co/ethereum-l2",
                sourceType: .traditional
            ),
            NewsItem(
                id: UUID(),
                title: "Federal Reserve Signals Potential Rate Cut",
                source: "Reuters",
                publishedAt: Date().addingTimeInterval(-14400),
                imageUrl: "https://example.com/fed-rates.jpg",
                url: "https://reuters.com/fed-rates",
                sourceType: .traditional
            ),
            NewsItem(
                id: UUID(),
                title: "Solana DeFi TVL Reaches All-Time High",
                source: "DeFi Llama",
                publishedAt: Date().addingTimeInterval(-21600),
                imageUrl: "https://example.com/solana-defi.jpg",
                url: "https://defillama.com/solana",
                sourceType: .traditional
            ),
            NewsItem(
                id: UUID(),
                title: "BlackRock Bitcoin ETF Sees $500M Daily Inflow",
                source: "Bloomberg",
                publishedAt: Date().addingTimeInterval(-28800),
                imageUrl: nil,
                url: "https://bloomberg.com/blackrock-btc",
                sourceType: .traditional
            )
        ]
    }

    private func generateMockTwitterNews() -> [NewsItem] {
        [
            // Watcher.Guru - Breaking News
            NewsItem(
                id: UUID(),
                title: "JUST IN: 🇺🇸 Trump says he will sign an executive order on crypto TODAY",
                source: "Watcher.Guru",
                publishedAt: Date().addingTimeInterval(-120), // 2 min ago
                url: "https://twitter.com/WatcherGuru",
                sourceType: .twitter,
                twitterHandle: "WatcherGuru",
                isVerified: true
            ),
            // The Kobeissi Letter - Macro Analysis
            NewsItem(
                id: UUID(),
                title: "BREAKING: The 10-year Treasury yield just fell below 4.10% for the first time since December.\n\nThis is the largest 2-week drop in yields since the March 2023 banking crisis.\n\nBonds are pricing in a major economic slowdown.",
                source: "The Kobeissi Letter",
                publishedAt: Date().addingTimeInterval(-300), // 5 min ago
                url: "https://twitter.com/KobeissiLetter",
                sourceType: .twitter,
                twitterHandle: "KobeissiLetter",
                isVerified: true
            ),
            // BRICS News
            NewsItem(
                id: UUID(),
                title: "🇷🇺🇨🇳 BRICS: Russia and China complete first cross-border transaction using digital currencies, bypassing SWIFT entirely",
                source: "BRICS News",
                publishedAt: Date().addingTimeInterval(-480), // 8 min ago
                url: "https://twitter.com/BRICSinfo",
                sourceType: .twitter,
                twitterHandle: "BRICSinfo",
                isVerified: true
            ),
            // Mike Alfred
            NewsItem(
                id: UUID(),
                title: "Bitcoin mining difficulty just hit a new all-time high.\n\nThis is the most secure the network has ever been.\n\nPrice follows hashrate. Always has, always will.",
                source: "Mike Alfred",
                publishedAt: Date().addingTimeInterval(-600), // 10 min ago
                url: "https://twitter.com/mikealfred",
                sourceType: .twitter,
                twitterHandle: "mikealfred",
                isVerified: true
            ),
            // DeItaone - Breaking News
            NewsItem(
                id: UUID(),
                title: "*FED'S WALLER: INFLATION DATA 'QUITE FAVORABLE' RECENTLY",
                source: "DeItaone",
                publishedAt: Date().addingTimeInterval(-720), // 12 min ago
                url: "https://twitter.com/DeItaone",
                sourceType: .twitter,
                twitterHandle: "DeItaone",
                isVerified: true
            ),
            // ZeroHedge - Macro
            NewsItem(
                id: UUID(),
                title: "*CHINA PBOC INJECTS 800 BILLION YUAN VIA 7-DAY REVERSE REPOS",
                source: "ZeroHedge",
                publishedAt: Date().addingTimeInterval(-900), // 15 min ago
                url: "https://twitter.com/zerohedge",
                sourceType: .twitter,
                twitterHandle: "zerohedge",
                isVerified: true
            ),
            // Whale Alert - Crypto
            NewsItem(
                id: UUID(),
                title: "🚨 2,000 #BTC (134,521,842 USD) transferred from unknown wallet to Coinbase",
                source: "Whale Alert",
                publishedAt: Date().addingTimeInterval(-1200), // 20 min ago
                url: "https://twitter.com/whale_alert",
                sourceType: .twitter,
                twitterHandle: "whale_alert",
                isVerified: true
            ),
            // Documenting BTC
            NewsItem(
                id: UUID(),
                title: "JUST IN: 🇺🇸 US spot Bitcoin ETFs saw $580M in net inflows yesterday, the highest since December",
                source: "Documenting BTC",
                publishedAt: Date().addingTimeInterval(-1500), // 25 min ago
                url: "https://twitter.com/DocumentingBTC",
                sourceType: .twitter,
                twitterHandle: "DocumentingBTC",
                isVerified: true
            ),
            // Lookonchain
            NewsItem(
                id: UUID(),
                title: "A whale withdrew 15,000 ETH($50.4M) from Binance in the past 24 hours. Currently holds 127,500 ETH($428.9M)",
                source: "Lookonchain",
                publishedAt: Date().addingTimeInterval(-1800), // 30 min ago
                url: "https://twitter.com/lookonchain",
                sourceType: .twitter,
                twitterHandle: "lookonchain",
                isVerified: true
            ),
            // Unusual Whales
            NewsItem(
                id: UUID(),
                title: "🔔 Large $MSTR call sweep: $500 strike, Feb expiry, $2.3M premium",
                source: "Unusual Whales",
                publishedAt: Date().addingTimeInterval(-2400), // 40 min ago
                url: "https://twitter.com/unusual_whales",
                sourceType: .twitter,
                twitterHandle: "unusual_whales",
                isVerified: true
            ),
            // Wall St Jesus
            NewsItem(
                id: UUID(),
                title: "The S&P 500 is now up 12 days in a row.\n\nThis is the longest winning streak since 2017.\n\nBulls are in complete control.",
                source: "Wall St Jesus",
                publishedAt: Date().addingTimeInterval(-2700), // 45 min ago
                url: "https://twitter.com/WallStJesus",
                sourceType: .twitter,
                twitterHandle: "WallStJesus",
                isVerified: true
            ),
            // Bitcoin Magazine
            NewsItem(
                id: UUID(),
                title: "BREAKING: El Salvador's Bitcoin holdings now exceed $500 million in value",
                source: "Bitcoin Magazine",
                publishedAt: Date().addingTimeInterval(-3600), // 1 hour ago
                url: "https://twitter.com/BitcoinMagazine",
                sourceType: .twitter,
                twitterHandle: "BitcoinMagazine",
                isVerified: true
            ),
            // The Block
            NewsItem(
                id: UUID(),
                title: "Ethereum blob fees hit new all-time high as L2 activity surges",
                source: "The Block",
                publishedAt: Date().addingTimeInterval(-4200), // 70 min ago
                url: "https://twitter.com/TheBlock__",
                sourceType: .twitter,
                twitterHandle: "TheBlock__",
                isVerified: true
            )
        ]
    }

    private func generateMockGoogleNews(query: String) -> [NewsItem] {
        [
            NewsItem(
                id: UUID(),
                title: "Bitcoin Price Analysis: BTC Tests Key Resistance as Bulls Eye $70K",
                source: "Yahoo Finance",
                publishedAt: Date().addingTimeInterval(-1800), // 30 min ago
                url: "https://news.google.com/bitcoin-price",
                sourceType: .googleNews
            ),
            NewsItem(
                id: UUID(),
                title: "Crypto Market Cap Surpasses $3 Trillion for First Time Since 2021",
                source: "CNBC",
                publishedAt: Date().addingTimeInterval(-3000), // 50 min ago
                url: "https://news.google.com/crypto-market-cap",
                sourceType: .googleNews
            ),
            NewsItem(
                id: UUID(),
                title: "SEC Chair Gensler Comments on Crypto Regulation Framework",
                source: "Wall Street Journal",
                publishedAt: Date().addingTimeInterval(-4500), // 75 min ago
                url: "https://news.google.com/sec-crypto",
                sourceType: .googleNews
            ),
            NewsItem(
                id: UUID(),
                title: "Institutional Investors Increase Bitcoin Allocations, Survey Finds",
                source: "Financial Times",
                publishedAt: Date().addingTimeInterval(-5400), // 90 min ago
                url: "https://news.google.com/institutional-btc",
                sourceType: .googleNews
            ),
            NewsItem(
                id: UUID(),
                title: "Ethereum ETF Decision Expected This Week, Analysts Say",
                source: "Forbes",
                publishedAt: Date().addingTimeInterval(-7200), // 2 hours ago
                url: "https://news.google.com/eth-etf",
                sourceType: .googleNews
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
                description: "Federal Open Market Committee meeting minutes release",
                countryFlag: "🇺🇸"
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
                description: "Weekly unemployment claims",
                countryFlag: "🇺🇸"
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
                description: "Consumer Price Index year-over-year",
                countryFlag: "🇺🇸"
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
                description: "European Central Bank rate decision",
                countryFlag: "🇪🇺"
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
                description: "Monthly employment change",
                countryFlag: "🇺🇸"
            )
        ]
    }

    /// Generates upcoming economic events - USA and Japan only
    private func generateUpcomingEconomicEvents() -> [EconomicEvent] {
        let calendar = Calendar.current
        let today = Date()

        // Helper to create date with specific time
        func makeDateTime(daysFromNow: Int, hour: Int, minute: Int) -> (date: Date, time: Date) {
            let date = calendar.date(byAdding: .day, value: daysFromNow, to: today) ?? today
            let time = calendar.date(from: DateComponents(hour: hour, minute: minute)) ?? today
            return (date, time)
        }

        return [
            // Today's events - USA
            EconomicEvent(
                id: UUID(),
                title: "US President Trump Speaks",
                country: "US",
                date: makeDateTime(daysFromNow: 0, hour: 14, minute: 0).date,
                time: makeDateTime(daysFromNow: 0, hour: 14, minute: 0).time,
                impact: .high,
                forecast: nil,
                previous: nil,
                actual: nil,
                currency: "USD",
                description: "US President delivers remarks on economic policy",
                countryFlag: "🇺🇸"
            ),

            // Tomorrow's events - USA
            EconomicEvent(
                id: UUID(),
                title: "US Unemployment Claims",
                country: "US",
                date: makeDateTime(daysFromNow: 1, hour: 8, minute: 30).date,
                time: makeDateTime(daysFromNow: 1, hour: 8, minute: 30).time,
                impact: .medium,
                forecast: "217K",
                previous: "223K",
                actual: nil,
                currency: "USD",
                description: "Initial Jobless Claims weekly",
                countryFlag: "🇺🇸"
            ),

            // Day 2 events - USA
            EconomicEvent(
                id: UUID(),
                title: "US Final GDP q/q",
                country: "US",
                date: makeDateTime(daysFromNow: 2, hour: 8, minute: 30).date,
                time: makeDateTime(daysFromNow: 2, hour: 8, minute: 30).time,
                impact: .high,
                forecast: "3.1%",
                previous: "2.8%",
                actual: nil,
                currency: "USD",
                description: "Gross Domestic Product final estimate",
                countryFlag: "🇺🇸"
            ),

            // Day 3 events - USA
            EconomicEvent(
                id: UUID(),
                title: "US Core PCE Price Index m/m",
                country: "US",
                date: makeDateTime(daysFromNow: 3, hour: 8, minute: 30).date,
                time: makeDateTime(daysFromNow: 3, hour: 8, minute: 30).time,
                impact: .high,
                forecast: "0.2%",
                previous: "0.1%",
                actual: nil,
                currency: "USD",
                description: "Fed's preferred inflation measure",
                countryFlag: "🇺🇸"
            ),
            // Day 3 - Japan
            EconomicEvent(
                id: UUID(),
                title: "Japan CPI y/y",
                country: "JP",
                date: makeDateTime(daysFromNow: 3, hour: 19, minute: 30).date,
                time: makeDateTime(daysFromNow: 3, hour: 19, minute: 30).time,
                impact: .high,
                forecast: "2.9%",
                previous: "2.7%",
                actual: nil,
                currency: "JPY",
                description: "Consumer Price Index year-over-year",
                countryFlag: "🇯🇵"
            ),

            // Day 4 events - Japan
            EconomicEvent(
                id: UUID(),
                title: "BOJ Policy Rate",
                country: "JP",
                date: makeDateTime(daysFromNow: 4, hour: 3, minute: 0).date,
                time: makeDateTime(daysFromNow: 4, hour: 3, minute: 0).time,
                impact: .high,
                forecast: "0.50%",
                previous: "0.25%",
                actual: nil,
                currency: "JPY",
                description: "Bank of Japan interest rate decision",
                countryFlag: "🇯🇵"
            ),
            // Day 4 - USA
            EconomicEvent(
                id: UUID(),
                title: "US Durable Goods Orders m/m",
                country: "US",
                date: makeDateTime(daysFromNow: 4, hour: 8, minute: 30).date,
                time: makeDateTime(daysFromNow: 4, hour: 8, minute: 30).time,
                impact: .medium,
                forecast: "0.5%",
                previous: "-0.8%",
                actual: nil,
                currency: "USD",
                description: "Monthly durable goods orders",
                countryFlag: "🇺🇸"
            ),

            // Day 5 events - USA
            EconomicEvent(
                id: UUID(),
                title: "US Non-Farm Employment Change",
                country: "US",
                date: makeDateTime(daysFromNow: 5, hour: 8, minute: 30).date,
                time: makeDateTime(daysFromNow: 5, hour: 8, minute: 30).time,
                impact: .high,
                forecast: "180K",
                previous: "256K",
                actual: nil,
                currency: "USD",
                description: "Monthly employment data release",
                countryFlag: "🇺🇸"
            ),
            // Day 5 - Japan
            EconomicEvent(
                id: UUID(),
                title: "Japan Trade Balance",
                country: "JP",
                date: makeDateTime(daysFromNow: 5, hour: 19, minute: 50).date,
                time: makeDateTime(daysFromNow: 5, hour: 19, minute: 50).time,
                impact: .medium,
                forecast: "-¥240B",
                previous: "-¥117B",
                actual: nil,
                currency: "JPY",
                description: "Monthly trade balance",
                countryFlag: "🇯🇵"
            ),

            // Day 6 events - USA
            EconomicEvent(
                id: UUID(),
                title: "Fed Chair Powell Speaks",
                country: "US",
                date: makeDateTime(daysFromNow: 6, hour: 12, minute: 0).date,
                time: makeDateTime(daysFromNow: 6, hour: 12, minute: 0).time,
                impact: .high,
                forecast: nil,
                previous: nil,
                actual: nil,
                currency: "USD",
                description: "Federal Reserve Chair delivers speech",
                countryFlag: "🇺🇸"
            ),
            // Day 6 - Japan
            EconomicEvent(
                id: UUID(),
                title: "BOJ Governor Ueda Speaks",
                country: "JP",
                date: makeDateTime(daysFromNow: 6, hour: 5, minute: 0).date,
                time: makeDateTime(daysFromNow: 6, hour: 5, minute: 0).time,
                impact: .high,
                forecast: nil,
                previous: nil,
                actual: nil,
                currency: "JPY",
                description: "Bank of Japan Governor delivers speech",
                countryFlag: "🇯🇵"
            )
        ]
    }
}
