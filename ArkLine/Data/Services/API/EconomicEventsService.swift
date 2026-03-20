import Foundation
import Supabase

// MARK: - Economic Events Service
/// Fetches economic events from Supabase `economic_events` table (synced from FMP via cron).
/// Falls back to direct FMP fetch via EconomicCalendarScraper if Supabase is unavailable.
final class EconomicEventsService {
    static let shared = EconomicEventsService()

    private var cachedEvents: [EconomicEvent] = []
    private var cacheTimestamp: Date?
    private let cacheTTL: TimeInterval = 600 // 10 minutes

    private let fallbackScraper = EconomicCalendarScraper()
    private let allowedCurrencies: Set<String> = ["USD", "JPY"]

    private init() {}

    // MARK: - Public API

    /// Fetch events for a date range, filtered by impact.
    func fetchEvents(from: Date, to: Date, impactFilter: [EventImpact]) async -> [EconomicEvent] {
        // Check cache
        if let ts = cacheTimestamp, Date().timeIntervalSince(ts) < cacheTTL, !cachedEvents.isEmpty {
            return filterEvents(cachedEvents, from: from, to: to, impactFilter: impactFilter)
        }

        // Try Supabase
        if SupabaseManager.shared.isConfigured {
            do {
                let events = try await fetchFromSupabase(from: from, to: to)
                if !events.isEmpty {
                    cachedEvents = events
                    cacheTimestamp = Date()
                    logInfo("EconomicEventsService: Loaded \(events.count) events from Supabase", category: .network)
                    return filterEvents(events, from: from, to: to, impactFilter: impactFilter)
                }
            } catch {
                logWarning("EconomicEventsService: Supabase fetch failed: \(error), falling back to FMP", category: .network)
            }
        }

        // Fallback to FMP direct
        do {
            let events = try await fallbackScraper.fetchUpcomingEvents(days: 7, impactFilter: impactFilter)
            cachedEvents = events
            cacheTimestamp = Date()
            return events
        } catch {
            logError("EconomicEventsService: FMP fallback also failed: \(error)", category: .network)
            return []
        }
    }

    /// Fetch a single event with analysis from Supabase (for EventInfoView).
    func fetchEventWithAnalysis(title: String, date: Date) async -> EconomicEvent? {
        guard SupabaseManager.shared.isConfigured else { return nil }

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        dateFmt.timeZone = TimeZone(identifier: "America/New_York")
        let dateStr = dateFmt.string(from: date)

        do {
            let rows: [SupabaseEconomicEventDTO] = try await SupabaseManager.shared.database
                .from(SupabaseTable.economicEvents.rawValue)
                .select()
                .eq("title", value: title)
                .eq("event_date", value: dateStr)
                .limit(1)
                .execute()
                .value

            return rows.first?.toEconomicEvent()
        } catch {
            logWarning("EconomicEventsService: Failed to fetch event analysis: \(error)", category: .network)
            return nil
        }
    }

    // MARK: - Private

    private func fetchFromSupabase(from: Date, to: Date) async throws -> [EconomicEvent] {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        dateFmt.timeZone = TimeZone(identifier: "America/New_York")

        let fromStr = dateFmt.string(from: from)
        let toStr = dateFmt.string(from: to)

        let rows: [SupabaseEconomicEventDTO] = try await SupabaseManager.shared.database
            .from(SupabaseTable.economicEvents.rawValue)
            .select()
            .gte("event_date", value: fromStr)
            .lte("event_date", value: toStr)
            .in("currency", values: Array(allowedCurrencies))
            .order("event_date")
            .order("event_time")
            .execute()
            .value

        return rows.compactMap { $0.toEconomicEvent() }
    }

    private func filterEvents(_ events: [EconomicEvent], from: Date, to: Date, impactFilter: [EventImpact]) -> [EconomicEvent] {
        let calendar = Calendar.current
        let startOfFrom = calendar.startOfDay(for: from)
        let endOfTo = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: to) ?? to)

        return events.filter { event in
            let currencyOk = event.currency.map { allowedCurrencies.contains($0) } ?? true
            return event.date >= startOfFrom && event.date < endOfTo && impactFilter.contains(event.impact) && currencyOk
        }.sorted { $0.date < $1.date }
    }
}
