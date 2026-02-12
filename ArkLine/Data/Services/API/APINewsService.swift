import Foundation

// MARK: - API News Service
/// Real API implementation of NewsServiceProtocol.
/// Uses various news APIs for crypto and economic news.
final class APINewsService: NewsServiceProtocol {
    // MARK: - Dependencies
    private let networkManager = NetworkManager.shared
    private let finnhubService = FinnhubEconomicCalendarService()
    private let calendarScraper = InvestingComScraper() // Fallback
    private let fedWatchScraper = CMEFedWatchScraper()

    // MARK: - NewsServiceProtocol

    func fetchNews(category: String?, page: Int, perPage: Int) async throws -> [NewsItem] {
        // Use Google News RSS for crypto news
        let rssService = GoogleNewsRSSService()
        return try await rssService.fetchCryptoNews(limit: perPage)
    }

    func fetchNewsForCurrencies(_ currencies: [String], page: Int) async throws -> [NewsItem] {
        // Build query from currencies
        let query = currencies.joined(separator: " OR ")
        let rssService = GoogleNewsRSSService()
        return try await rssService.fetchNews(query: query, limit: 20)
    }

    func searchNews(query: String) async throws -> [NewsItem] {
        let rssService = GoogleNewsRSSService()
        return try await rssService.fetchNews(query: query, limit: 20)
    }

    func fetchTodaysEvents() async throws -> [EconomicEvent] {
        // Use Finnhub API for today's events
        return try await finnhubService.fetchTodaysEvents()
    }

    func fetchEconomicEvents(from startDate: Date, to endDate: Date) async throws -> [EconomicEvent] {
        // Use Finnhub API for date range
        return try await finnhubService.fetchEvents(from: startDate, to: endDate)
    }

    func fetchFedWatchData() async throws -> FedWatchData {
        return try await fedWatchScraper.fetchFedWatchData()
    }

    func fetchFedWatchMeetings() async throws -> [FedWatchData] {
        return try await fedWatchScraper.fetchFedWatchMeetings()
    }

    func fetchUpcomingFedMeetings() async throws -> [FedMeeting] {
        // TODO: Implement with Fed meeting schedule
        // Could be hardcoded with known FOMC meeting dates
        let meetings = generateKnownFOMCMeetings()
        return meetings.filter { $0.date > Date() }
    }

    func fetchUpcomingEvents(days: Int, impactFilter: [EventImpact]) async throws -> [EconomicEvent] {
        // Use Investing.com scraper with US market holidays as reliable backup
        logDebug("APINewsService.fetchUpcomingEvents called - days: \(days)", category: .network)
        let events = try await calendarScraper.fetchUpcomingEvents(days: days, impactFilter: impactFilter)
        logDebug("APINewsService: Got \(events.count) upcoming events", category: .network)
        return events
    }

    // MARK: - Twitter/X News

    func fetchTwitterNews(accounts: [String]?, limit: Int) async throws -> [NewsItem] {
        // Twitter/X API v2 requires Developer Account and Bearer Token
        // Return empty array for graceful degradation
        logInfo("Twitter news requires API credentials", category: .network)
        return []
    }

    // MARK: - Google News RSS

    func fetchGoogleNews(query: String, limit: Int) async throws -> [NewsItem] {
        let rssService = GoogleNewsRSSService()
        return try await rssService.fetchNews(query: query, limit: limit)
    }

    /// Fetch crypto news from Google News RSS
    func fetchCryptoNews(limit: Int = 20) async throws -> [NewsItem] {
        let rssService = GoogleNewsRSSService()
        return try await rssService.fetchCryptoNews(limit: limit)
    }

    /// Fetch geopolitical/world news from Google News RSS
    func fetchGeopoliticalNews(limit: Int = 20) async throws -> [NewsItem] {
        let rssService = GoogleNewsRSSService()
        return try await rssService.fetchGeopoliticalNews(limit: limit)
    }

    // MARK: - Combined News Feed

    func fetchCombinedNewsFeed(
        limit: Int,
        includeTwitter: Bool,
        includeGoogleNews: Bool,
        topics: Set<Constants.NewsTopic>? = nil,
        customKeywords: [String]? = nil
    ) async throws -> [NewsItem] {
        var allNews: [NewsItem] = []

        // Fetch Google News based on user preferences
        if includeGoogleNews {
            let rssService = GoogleNewsRSSService()

            // If user has selected specific topics, use those
            if let topics = topics, !topics.isEmpty {
                let personalizedNews = try await rssService.fetchPersonalizedNews(
                    topics: topics,
                    customKeywords: customKeywords ?? [],
                    limit: limit
                )
                allNews.append(contentsOf: personalizedNews)
                logDebug("Fetched \(personalizedNews.count) personalized news items", category: .network)
            } else {
                // Default behavior: crypto + geopolitical
                async let cryptoNews = fetchCryptoNews(limit: limit / 2)
                async let geoNews = fetchGeopoliticalNews(limit: limit / 2)

                do {
                    let (crypto, geo) = try await (cryptoNews, geoNews)
                    allNews.append(contentsOf: crypto)
                    allNews.append(contentsOf: geo)
                    logDebug("Fetched \(crypto.count) crypto + \(geo.count) geopolitical news items", category: .network)
                } catch {
                    logWarning("Failed to fetch Google News: \(error.localizedDescription)", category: .network)
                }
            }
        }

        // Sort by date (newest first) and limit
        allNews.sort { $0.publishedAt > $1.publishedAt }
        return Array(allNews.prefix(limit))
    }

    // MARK: - Private Helpers

    private func generateKnownFOMCMeetings() -> [FedMeeting] {
        // FOMC typically meets 8 times per year
        // These are the announced 2026 FOMC meeting dates (decision day)
        let calendar = Calendar.current

        let meetingDates: [(year: Int, month: Int, day: Int, hasProjections: Bool)] = [
            // 2026 FOMC meetings
            (2026, 1, 29, false),   // Jan 28-29
            (2026, 3, 19, true),    // Mar 18-19 (SEP)
            (2026, 5, 7, false),    // May 6-7
            (2026, 6, 18, true),    // Jun 17-18 (SEP)
            (2026, 7, 30, false),   // Jul 29-30
            (2026, 9, 17, true),    // Sep 16-17 (SEP)
            (2026, 11, 5, false),   // Nov 4-5
            (2026, 12, 17, true),   // Dec 16-17 (SEP)
        ]

        return meetingDates.compactMap { dateInfo -> FedMeeting? in
            guard let date = calendar.date(from: DateComponents(year: dateInfo.year, month: dateInfo.month, day: dateInfo.day)) else {
                return nil
            }

            return FedMeeting(
                date: date,
                type: .fomc,
                hasProjections: dateInfo.hasProjections
            )
        }
    }
}

// MARK: - News API Response Models
/// Response model for CryptoCompare News API
struct CryptoCompareNewsResponse: Codable {
    let type: Int
    let message: String
    let data: [CryptoCompareNewsItem]

    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case message = "Message"
        case data = "Data"
    }
}

struct CryptoCompareNewsItem: Codable {
    let id: String
    let guid: String
    let publishedOn: Int
    let imageurl: String?
    let title: String
    let url: String
    let source: String
    let body: String
    let tags: String
    let categories: String
    let upvotes: String?
    let downvotes: String?
    let lang: String

    func toNewsItem() -> NewsItem {
        NewsItem(
            id: UUID(),
            title: title,
            source: source,
            publishedAt: Date(timeIntervalSince1970: TimeInterval(publishedOn)),
            imageUrl: imageurl,
            url: url
        )
    }
}

