import Foundation

// MARK: - Finnhub Economic Calendar Service
/// Fetches economic calendar data from Finnhub API
/// Free tier: 60 API calls/minute
/// Docs: https://finnhub.io/docs/api/economic-calendar
final class FinnhubEconomicCalendarService {

    // API key injected server-side by api-proxy Edge Function

    private var isConfigured: Bool {
        SupabaseManager.shared.isConfigured
    }

    // Country code to currency mapping
    private let countryCurrencyMap: [String: String] = [
        "US": "USD", "EU": "EUR", "GB": "GBP", "JP": "JPY",
        "AU": "AUD", "CA": "CAD", "CH": "CHF", "CN": "CNY",
        "NZ": "NZD", "SE": "SEK", "NO": "NOK", "MX": "MXN"
    ]

    // Country code to flag mapping
    private let countryFlags: [String: String] = [
        "US": "🇺🇸", "EU": "🇪🇺", "GB": "🇬🇧", "JP": "🇯🇵",
        "AU": "🇦🇺", "CA": "🇨🇦", "CH": "🇨🇭", "CN": "🇨🇳",
        "NZ": "🇳🇿", "SE": "🇸🇪", "NO": "🇳🇴", "MX": "🇲🇽",
        "DE": "🇩🇪", "FR": "🇫🇷", "IT": "🇮🇹", "ES": "🇪🇸"
    ]

    // Countries to show (USA and Japan for market-moving events)
    private let allowedCountries: Set<String> = ["US", "JP"]

    // MARK: - Public Methods

    /// Fetch today's economic events
    func fetchTodaysEvents() async throws -> [EconomicEvent] {
        let calendar = Calendar.current
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return try await fetchEvents(from: today, to: tomorrow)
    }

    /// Fetch upcoming events for a number of days
    func fetchUpcomingEvents(days: Int, impactFilter: [EventImpact]) async throws -> [EconomicEvent] {
        guard isConfigured else {
            logWarning("Finnhub API key not configured - using fallback", category: .network)
            return try await fallbackToHardcodedData(days: days, impactFilter: impactFilter)
        }

        let calendar = Calendar.current
        let today = Date()
        let endDate = calendar.date(byAdding: .day, value: days, to: today) ?? today

        do {
            var events = try await fetchEvents(from: today, to: endDate)

            // Filter by country and impact
            events = events.filter { event in
                let countryMatch = allowedCountries.contains(event.country)
                let impactMatch = impactFilter.contains(event.impact)
                return countryMatch && impactMatch
            }

            // Add US market holidays
            let holidays = getUSMarketHolidays(days: days)
            events.append(contentsOf: holidays)

            // Sort by date
            events.sort { $0.date < $1.date }

            logDebug("Finnhub: Fetched \(events.count) economic events", category: .network)
            return events
        } catch {
            logWarning("Finnhub API failed: \(error.localizedDescription) - using fallback", category: .network)
            return try await fallbackToHardcodedData(days: days, impactFilter: impactFilter)
        }
    }

    /// Fetch events for a date range
    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [EconomicEvent] {
        guard isConfigured else {
            // Return hardcoded events when not configured
            return try await fallbackToHardcodedData(days: 30, impactFilter: [])
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let fromStr = formatter.string(from: startDate)
        let toStr = formatter.string(from: endDate)

        // X-Finnhub-Token header injected server-side by api-proxy Edge Function
        let data = try await APIProxy.shared.request(
            service: .finnhub,
            path: "/calendar/economic",
            queryItems: [
                "from": fromStr,
                "to": toStr
            ]
        )

        // Parse response
        let finnhubResponse = try JSONDecoder().decode(FinnhubEconomicCalendarResponse.self, from: data)

        // Convert to EconomicEvent
        return finnhubResponse.economicCalendar.compactMap { item -> EconomicEvent? in
            convertToEconomicEvent(item)
        }
    }

    // MARK: - Private Helpers

    private func convertToEconomicEvent(_ item: FinnhubEconomicEvent) -> EconomicEvent? {
        // Parse the timestamp
        guard let eventDate = parseEventTime(item.time) else {
            return nil
        }

        // Map impact string to EventImpact
        let impact = mapImpact(item.impact)

        // Get currency from country
        let currency = countryCurrencyMap[item.country] ?? "USD"
        let flag = countryFlags[item.country]

        // Format values
        let actualStr = item.actual.map { formatValue($0, unit: item.unit) }
        let forecastStr = item.estimate.map { formatValue($0, unit: item.unit) }
        let previousStr = item.prev.map { formatValue($0, unit: item.unit) }

        return EconomicEvent(
            id: UUID(),
            title: item.event,
            country: item.country,
            date: eventDate,
            time: eventDate,
            impact: impact,
            forecast: forecastStr,
            previous: previousStr,
            actual: actualStr,
            currency: currency,
            description: nil,
            countryFlag: flag
        )
    }

    private func parseEventTime(_ timeString: String) -> Date? {
        // Finnhub uses ISO 8601 format: "2026-01-27 13:30:00"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: timeString) {
                return date
            }
        }

        return nil
    }

    private func mapImpact(_ impactString: String?) -> EventImpact {
        guard let impact = impactString?.lowercased() else {
            return .low
        }

        switch impact {
        case "high", "3":
            return .high
        case "medium", "2":
            return .medium
        default:
            return .low
        }
    }

    private func formatValue(_ value: Double, unit: String?) -> String {
        if let unit = unit, !unit.isEmpty {
            if unit == "%" {
                return String(format: "%.2f%%", value)
            }
            return "\(value) \(unit)"
        }
        return String(format: "%.2f", value)
    }

    private func fallbackToHardcodedData(days: Int, impactFilter: [EventImpact]) async throws -> [EconomicEvent] {
        // Use hardcoded data instead of scraping
        return EconomicEventsData.getUpcomingEvents(days: days, impactFilter: impactFilter)
    }

    // MARK: - US Market Holidays
    private func getUSMarketHolidays(days: Int) -> [EconomicEvent] {
        let calendar = Calendar.current
        let today = Date()
        let endDate = calendar.date(byAdding: .day, value: days, to: today) ?? today

        let currentYear = calendar.component(.year, from: today)
        var holidays: [EconomicEvent] = []

        for year in [currentYear, currentYear + 1] {
            holidays.append(contentsOf: generateHolidaysForYear(year))
        }

        return holidays.filter { $0.date >= today && $0.date <= endDate }
    }

    private func generateHolidaysForYear(_ year: Int) -> [EconomicEvent] {
        var holidays: [EconomicEvent] = []

        func makeHoliday(title: String, date: Date) -> EconomicEvent {
            EconomicEvent(
                id: UUID(),
                title: "\(title) - Markets Closed",
                country: "US",
                date: date,
                time: nil,
                impact: .high,
                forecast: nil,
                previous: nil,
                actual: nil,
                currency: "USD",
                description: "US stock and bond markets are closed",
                countryFlag: "🇺🇸"
            )
        }

        // Presidents' Day - 3rd Monday of February
        if let presidentsDay = nthWeekday(nth: 3, weekday: 2, month: 2, year: year) {
            holidays.append(makeHoliday(title: "Presidents' Day", date: presidentsDay))
        }

        // Good Friday
        if let goodFriday = calculateGoodFriday(year: year) {
            holidays.append(makeHoliday(title: "Good Friday", date: goodFriday))
        }

        // Memorial Day - Last Monday of May
        if let memorialDay = lastWeekday(weekday: 2, month: 5, year: year) {
            holidays.append(makeHoliday(title: "Memorial Day", date: memorialDay))
        }

        // Juneteenth - June 19
        if let juneteenth = observedDate(month: 6, day: 19, year: year) {
            holidays.append(makeHoliday(title: "Juneteenth", date: juneteenth))
        }

        // Independence Day - July 4
        if let july4 = observedDate(month: 7, day: 4, year: year) {
            holidays.append(makeHoliday(title: "Independence Day", date: july4))
        }

        // Labor Day - 1st Monday of September
        if let laborDay = nthWeekday(nth: 1, weekday: 2, month: 9, year: year) {
            holidays.append(makeHoliday(title: "Labor Day", date: laborDay))
        }

        // Thanksgiving - 4th Thursday of November
        if let thanksgiving = nthWeekday(nth: 4, weekday: 5, month: 11, year: year) {
            holidays.append(makeHoliday(title: "Thanksgiving", date: thanksgiving))
        }

        // Christmas - December 25
        if let christmas = observedDate(month: 12, day: 25, year: year) {
            holidays.append(makeHoliday(title: "Christmas Day", date: christmas))
        }

        // New Year's Day - January 1
        if let newYears = observedDate(month: 1, day: 1, year: year) {
            holidays.append(makeHoliday(title: "New Year's Day", date: newYears))
        }

        return holidays
    }

    private func nthWeekday(nth: Int, weekday: Int, month: Int, year: Int) -> Date? {
        let calendar = Calendar.current
        let components = DateComponents(year: year, month: month, weekday: weekday, weekdayOrdinal: nth)
        return calendar.date(from: components)
    }

    private func lastWeekday(weekday: Int, month: Int, year: Int) -> Date? {
        let calendar = Calendar.current
        let components = DateComponents(year: year, month: month, weekday: weekday, weekdayOrdinal: -1)
        return calendar.date(from: components)
    }

    private func observedDate(month: Int, day: Int, year: Int) -> Date? {
        let calendar = Calendar.current
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            return nil
        }
        let weekday = calendar.component(.weekday, from: date)
        switch weekday {
        case 1: return calendar.date(byAdding: .day, value: 1, to: date) // Sunday -> Monday
        case 7: return calendar.date(byAdding: .day, value: -1, to: date) // Saturday -> Friday
        default: return date
        }
    }

    private func calculateGoodFriday(year: Int) -> Date? {
        // Easter calculation (Anonymous Gregorian algorithm)
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1

        let calendar = Calendar.current
        guard let easter = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            return nil
        }
        return calendar.date(byAdding: .day, value: -2, to: easter)
    }
}

// MARK: - Finnhub API Response Models
struct FinnhubEconomicCalendarResponse: Codable {
    let economicCalendar: [FinnhubEconomicEvent]
}

struct FinnhubEconomicEvent: Codable {
    let country: String
    let event: String
    let impact: String?
    let time: String
    let actual: Double?
    let estimate: Double?
    let prev: Double?
    let unit: String?
}
