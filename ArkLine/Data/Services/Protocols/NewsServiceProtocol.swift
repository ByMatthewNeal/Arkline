import Foundation

// MARK: - News Service Protocol
/// Protocol defining news and economic events operations.
protocol NewsServiceProtocol {
    /// Fetches crypto news items
    /// - Parameters:
    ///   - category: Optional category filter
    ///   - page: Page number for pagination
    ///   - perPage: Number of items per page
    /// - Returns: Array of NewsItem
    func fetchNews(category: String?, page: Int, perPage: Int) async throws -> [NewsItem]

    /// Fetches news for specific currencies
    /// - Parameters:
    ///   - currencies: Array of currency symbols (e.g., ["BTC", "ETH"])
    ///   - page: Page number for pagination
    /// - Returns: Array of NewsItem
    func fetchNewsForCurrencies(_ currencies: [String], page: Int) async throws -> [NewsItem]

    /// Searches news by query
    /// - Parameter query: Search query string
    /// - Returns: Array of matching NewsItem
    func searchNews(query: String) async throws -> [NewsItem]

    /// Fetches today's economic events
    /// - Returns: Array of EconomicEvent for today
    func fetchTodaysEvents() async throws -> [EconomicEvent]

    /// Fetches economic events for a date range
    /// - Parameters:
    ///   - startDate: Start of date range
    ///   - endDate: End of date range
    /// - Returns: Array of EconomicEvent
    func fetchEconomicEvents(from startDate: Date, to endDate: Date) async throws -> [EconomicEvent]

    /// Fetches Fed Watch data for the next meeting
    /// - Returns: FedWatchData with rate probabilities
    func fetchFedWatchData() async throws -> FedWatchData

    /// Fetches Fed Watch data for multiple upcoming meetings (3-6 months)
    /// - Returns: Array of FedWatchData for each upcoming FOMC meeting
    func fetchFedWatchMeetings() async throws -> [FedWatchData]

    /// Fetches upcoming Fed meetings
    /// - Returns: Array of FedMeeting
    func fetchUpcomingFedMeetings() async throws -> [FedMeeting]

    /// Fetches upcoming economic events filtered by impact
    /// - Parameters:
    ///   - days: Number of days ahead to fetch
    ///   - impactFilter: Array of impact levels to include (e.g., [.high, .medium])
    /// - Returns: Array of EconomicEvent sorted by date
    func fetchUpcomingEvents(days: Int, impactFilter: [EventImpact]) async throws -> [EconomicEvent]

    // MARK: - Twitter/X News

    /// Fetches latest tweets from tracked crypto Twitter accounts
    /// - Parameters:
    ///   - accounts: Optional array of specific accounts to fetch from
    ///   - limit: Maximum number of tweets to fetch
    /// - Returns: Array of NewsItem from Twitter
    func fetchTwitterNews(accounts: [String]?, limit: Int) async throws -> [NewsItem]

    // MARK: - Google News

    /// Fetches latest crypto news from Google News
    /// - Parameters:
    ///   - query: Search query (e.g., "Bitcoin", "cryptocurrency")
    ///   - limit: Maximum number of articles to fetch
    /// - Returns: Array of NewsItem from Google News
    func fetchGoogleNews(query: String, limit: Int) async throws -> [NewsItem]

    // MARK: - Combined News Feed

    /// Fetches combined news from all sources (Twitter, Google News, Traditional)
    /// - Parameters:
    ///   - limit: Maximum total items to return
    ///   - includeTwitter: Whether to include Twitter sources
    ///   - includeGoogleNews: Whether to include Google News
    ///   - topics: Optional set of pre-defined topics to filter by
    ///   - customKeywords: Optional array of custom keywords to include
    /// - Returns: Array of NewsItem sorted by publishedAt
    func fetchCombinedNewsFeed(
        limit: Int,
        includeTwitter: Bool,
        includeGoogleNews: Bool,
        topics: Set<Constants.NewsTopic>?,
        customKeywords: [String]?
    ) async throws -> [NewsItem]
}
