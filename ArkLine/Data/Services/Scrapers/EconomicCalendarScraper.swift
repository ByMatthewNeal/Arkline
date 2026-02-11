import Foundation

// MARK: - Economic Calendar Scraper
/// Provides economic calendar data using EconomicEventsData
final class EconomicCalendarScraper {

    // MARK: - Public Methods

    /// Fetches upcoming economic events from hardcoded data
    /// - Parameters:
    ///   - days: Number of days ahead to fetch
    ///   - impactFilter: Filter by impact levels
    /// - Returns: Array of EconomicEvent
    func fetchUpcomingEvents(days: Int, impactFilter: [EventImpact]) async throws -> [EconomicEvent] {
        // Use hardcoded data instead of scraping
        return EconomicEventsData.getUpcomingEvents(days: days, impactFilter: impactFilter)
    }

    /// Fetches today's events
    func fetchTodaysEvents(impactFilter: [EventImpact] = [.high, .medium]) async throws -> [EconomicEvent] {
        return EconomicEventsData.getTodaysEvents(impactFilter: impactFilter)
    }

}

// MARK: - Scraper Errors
enum ScraperError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError
    case parsingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError:
            return "Failed to decode response"
        case .parsingError:
            return "Failed to parse calendar data"
        }
    }
}
