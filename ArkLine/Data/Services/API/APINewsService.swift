import Foundation

// MARK: - API News Service
/// Real API implementation of NewsServiceProtocol.
/// Uses various news APIs for crypto and economic news.
final class APINewsService: NewsServiceProtocol {
    // MARK: - Dependencies
    private let networkManager = NetworkManager.shared
    private let finnhubService = FinnhubEconomicCalendarService()
    private let calendarScraper = EconomicCalendarScraper()
    private let fedWatchScraper = CMEFedWatchScraper()
    /// Creates a fresh instance per call — GoogleNewsRSSService holds mutable XML parser
    /// state and is not safe to reuse across concurrent calls.
    private func makeRSSService() -> GoogleNewsRSSService { GoogleNewsRSSService() }

    // MARK: - NewsServiceProtocol

    func fetchNews(category: String?, page: Int, perPage: Int) async throws -> [NewsItem] {
        // Use Google News RSS for crypto news
        return try await makeRSSService().fetchCryptoNews(limit: perPage)
    }

    func fetchNewsForCurrencies(_ currencies: [String], page: Int) async throws -> [NewsItem] {
        // Build query from currencies
        let query = currencies.joined(separator: " OR ")
        return try await makeRSSService().fetchNews(query: query, limit: 20)
    }

    func searchNews(query: String) async throws -> [NewsItem] {
        return try await makeRSSService().fetchNews(query: query, limit: 20)
    }

    func fetchTodaysEvents() async throws -> [EconomicEvent] {
        let today = Date()
        // Use same date for from/to so fetchFromSupabase queries only today's date
        return await EconomicEventsService.shared.fetchEvents(from: today, to: today, impactFilter: [.high, .medium])
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
        let meetings = generateKnownFOMCMeetings()
        return meetings.filter { $0.date > Date() }
    }

    func fetchUpcomingEvents(days: Int, impactFilter: [EventImpact]) async throws -> [EconomicEvent] {
        logDebug("APINewsService.fetchUpcomingEvents called - days: \(days)", category: .network)
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
        let events = await EconomicEventsService.shared.fetchEvents(from: start, to: end, impactFilter: impactFilter)
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
        return try await makeRSSService().fetchNews(query: query, limit: limit)
    }

    /// Fetch crypto news from Google News RSS
    func fetchCryptoNews(limit: Int = 20) async throws -> [NewsItem] {
        return try await makeRSSService().fetchCryptoNews(limit: limit)
    }

    /// Fetch geopolitical/world news from Google News RSS
    func fetchGeopoliticalNews(limit: Int = 20) async throws -> [NewsItem] {
        return try await makeRSSService().fetchGeopoliticalNews(limit: limit)
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
            // If user has selected specific topics, use those
            if let topics = topics, !topics.isEmpty {
                let personalizedNews = try await makeRSSService().fetchPersonalizedNews(
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
        // Source: https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm
        // Decision day = second day of each 2-day meeting
        let calendar = Calendar.current

        let meetingDates: [(year: Int, month: Int, day: Int, hasProjections: Bool)] = [
            // 2026 FOMC meetings (decision day)
            (2026, 1, 28, false),   // Jan 27-28
            (2026, 3, 18, true),    // Mar 17-18 (SEP)
            (2026, 4, 29, false),   // Apr 28-29
            (2026, 6, 17, true),    // Jun 16-17 (SEP)
            (2026, 7, 29, false),   // Jul 28-29
            (2026, 9, 16, true),    // Sep 15-16 (SEP)
            (2026, 10, 28, false),  // Oct 27-28
            (2026, 12, 9, true),    // Dec 8-9 (SEP)
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
            url: url,
            sourceType: .googleNews,
            twitterHandle: nil,
            isVerified: false,
            description: nil
        )
    }
}

