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

    /// Fetches Fed Watch data
    /// - Returns: FedWatchData with rate probabilities
    func fetchFedWatchData() async throws -> FedWatchData

    /// Fetches upcoming Fed meetings
    /// - Returns: Array of FedMeeting
    func fetchUpcomingFedMeetings() async throws -> [FedMeeting]
}
