import Foundation

// MARK: - Economic Calendar Scraper
/// Provides economic calendar data from FMP API with static data fallback.
final class EconomicCalendarScraper {

    /// In-memory cache to avoid repeated API calls
    private var cachedEvents: [EconomicEvent] = []
    private var cacheTimestamp: Date?
    private let cacheTTL: TimeInterval = 3600 // 1 hour

    // MARK: - Public Methods

    /// Fetches upcoming economic events from FMP API (falls back to static data)
    func fetchUpcomingEvents(days: Int, impactFilter: [EventImpact]) async throws -> [EconomicEvent] {
        let events = await fetchFromFMPOrCache(days: days)

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let endDate = calendar.date(byAdding: .day, value: days, to: Date()) else {
            return []
        }

        return events.filter { event in
            event.date >= startOfToday && event.date <= endDate && impactFilter.contains(event.impact)
        }.sorted { $0.date < $1.date }
    }

    /// Fetches today's events from FMP API (falls back to static data)
    func fetchTodaysEvents(impactFilter: [EventImpact] = [.high, .medium]) async throws -> [EconomicEvent] {
        let events = await fetchFromFMPOrCache(days: 1)

        return events.filter { event in
            Calendar.current.isDateInToday(event.date) && impactFilter.contains(event.impact)
        }.sorted { $0.date < $1.date }
    }

    // MARK: - Private

    private func fetchFromFMPOrCache(days: Int) async -> [EconomicEvent] {
        // Return cache if fresh
        if let ts = cacheTimestamp, Date().timeIntervalSince(ts) < cacheTTL, !cachedEvents.isEmpty {
            return cachedEvents
        }

        // Try FMP API
        do {
            let from = Calendar.current.startOfDay(for: Date())
            guard let to = Calendar.current.date(byAdding: .day, value: max(days, 7), to: from) else {
                return fallbackToStatic()
            }

            let events = try await FMPService.shared.fetchEconomicCalendar(from: from, to: to)
            if !events.isEmpty {
                cachedEvents = events
                cacheTimestamp = Date()
                logInfo("EconomicCalendar: Loaded \(events.count) events from FMP", category: .network)
                return events
            }
        } catch {
            logWarning("EconomicCalendar: FMP fetch failed, using static data: \(error)", category: .network)
        }

        return fallbackToStatic()
    }

    private func fallbackToStatic() -> [EconomicEvent] {
        EconomicEventsData.allEvents
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
