import Foundation

// MARK: - Economic Calendar Scraper
/// Provides economic calendar data from hardcoded source
/// No longer relies on web scraping - uses EconomicEventsData instead
final class EconomicCalendarScraper {

    // MARK: - Legacy Properties (kept for compatibility with unused scraping code)
    private let baseURL = "https://www.investing.com/economic-calendar/"
    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

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

    // MARK: - Legacy Methods (kept for compatibility but no longer used)

    // Country code to flag emoji mapping
    private let countryFlags: [String: String] = [
        "USD": "🇺🇸", "EUR": "🇪🇺", "GBP": "🇬🇧", "JPY": "🇯🇵",
        "AUD": "🇦🇺", "CAD": "🇨🇦", "CHF": "🇨🇭", "CNY": "🇨🇳",
        "NZD": "🇳🇿", "SEK": "🇸🇪", "NOK": "🇳🇴", "MXN": "🇲🇽",
        "SGD": "🇸🇬", "HKD": "🇭🇰", "KRW": "🇰🇷", "TRY": "🇹🇷",
        "INR": "🇮🇳", "BRL": "🇧🇷", "ZAR": "🇿🇦", "RUB": "🇷🇺",
        "PLN": "🇵🇱", "THB": "🇹🇭", "IDR": "🇮🇩", "CZK": "🇨🇿",
        "ILS": "🇮🇱", "CLP": "🇨🇱", "PHP": "🇵🇭", "AED": "🇦🇪",
        "COP": "🇨🇴", "SAR": "🇸🇦", "MYR": "🇲🇾", "RON": "🇷🇴",
        "HUF": "🇭🇺", "ALL": "🌍"
    ]

    // MARK: - Private Methods

    private func fetchCalendarHTML() async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw ScraperError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScraperError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ScraperError.httpError(statusCode: httpResponse.statusCode)
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw ScraperError.decodingError
        }

        return html
    }

    private func parseEvents(from html: String) -> [EconomicEvent] {
        var events: [EconomicEvent] = []

        // Parse table rows - Investing.com uses tr elements with class containing "js-event-item"
        // Each row has data attributes: data-event-datetime, data-event-currency, etc.

        // Find event rows using regex patterns
        // Alternative: Parse based on table structure
        // The calendar table has specific class patterns we can match

        // Split HTML by event rows
        let eventRowPattern = #"<tr[^>]*js-event-item[^>]*>(.*?)</tr>"#
        guard let eventRegex = try? NSRegularExpression(pattern: eventRowPattern, options: [.dotMatchesLineSeparators]) else {
            return fallbackMockEvents()
        }

        let matches = eventRegex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))

        for match in matches.prefix(50) { // Limit to 50 events
            guard let rowRange = Range(match.range(at: 0), in: html) else { continue }
            let rowHTML = String(html[rowRange])

            if let event = parseEventRow(rowHTML) {
                events.append(event)
            }
        }

        // If parsing failed, return fallback mock events
        if events.isEmpty {
            return fallbackMockEvents()
        }

        return events
    }

    private func parseEventRow(_ rowHTML: String) -> EconomicEvent? {
        // Extract datetime from data attribute
        let datetimePattern = #"data-event-datetime="([^"]*)""#
        let datetime = extractFirstMatch(pattern: datetimePattern, from: rowHTML)

        // Extract currency/country
        let currencyPattern = #"<td[^>]*class="[^"]*flagCur[^"]*"[^>]*>.*?<span[^>]*>([A-Z]{3})</span>"#
        let currency = extractFirstMatch(pattern: currencyPattern, from: rowHTML) ?? "USD"

        // Extract event name
        let eventNamePattern = #"<td[^>]*class="[^"]*event[^"]*"[^>]*>.*?<a[^>]*>([^<]+)</a>"#
        let eventName = extractFirstMatch(pattern: eventNamePattern, from: rowHTML)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract impact (count of bull icons or sentiment class)
        let impact = parseImpact(from: rowHTML)

        // Extract actual, forecast, previous values
        let actualPattern = #"<td[^>]*class="[^"]*act[^"]*"[^>]*>([^<]*)</td>"#
        let actual = extractFirstMatch(pattern: actualPattern, from: rowHTML)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let forecastPattern = #"<td[^>]*class="[^"]*fore[^"]*"[^>]*>([^<]*)</td>"#
        let forecast = extractFirstMatch(pattern: forecastPattern, from: rowHTML)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let previousPattern = #"<td[^>]*class="[^"]*prev[^"]*"[^>]*>([^<]*)</td>"#
        let previous = extractFirstMatch(pattern: previousPattern, from: rowHTML)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse the datetime
        guard let eventName = eventName, !eventName.isEmpty else { return nil }

        let (eventDate, eventTime) = parseDatetime(datetime)

        return EconomicEvent(
            id: UUID(),
            title: eventName,
            country: currencyToCountry(currency),
            date: eventDate,
            time: eventTime,
            impact: impact,
            forecast: forecast?.isEmpty == true ? nil : forecast,
            previous: previous?.isEmpty == true ? nil : previous,
            actual: actual?.isEmpty == true ? nil : actual,
            currency: currency,
            description: nil,
            countryFlag: countryFlags[currency]
        )
    }

    private func extractFirstMatch(pattern: String, from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }

        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[captureRange])
    }

    private func parseImpact(from rowHTML: String) -> EventImpact {
        // Count bull/impact icons or check for sentiment classes
        let highImpactPatterns = ["sentiment3", "icon--3", "high", "redFont", "bull3"]
        let mediumImpactPatterns = ["sentiment2", "icon--2", "medium", "orangeFont", "bull2"]

        let lowercaseHTML = rowHTML.lowercased()

        for pattern in highImpactPatterns {
            if lowercaseHTML.contains(pattern) {
                return .high
            }
        }

        for pattern in mediumImpactPatterns {
            if lowercaseHTML.contains(pattern) {
                return .medium
            }
        }

        return .low
    }

    private func parseDatetime(_ datetime: String?) -> (Date, Date?) {
        guard let datetime = datetime else {
            return (Date(), nil)
        }

        // Investing.com uses format like "2024-01-21 08:30:00"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "America/New_York") // ET timezone

        if let date = formatter.date(from: datetime) {
            // Extract just the time component for the time field
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: date)
            let timeOnly = calendar.date(from: components)

            return (date, timeOnly)
        }

        // Try alternative format
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        if let date = formatter.date(from: datetime) {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: date)
            let timeOnly = calendar.date(from: components)

            return (date, timeOnly)
        }

        return (Date(), nil)
    }

    private func currencyToCountry(_ currency: String) -> String {
        let currencyCountryMap: [String: String] = [
            "USD": "US", "EUR": "EU", "GBP": "UK", "JPY": "JP",
            "AUD": "AU", "CAD": "CA", "CHF": "CH", "CNY": "CN",
            "NZD": "NZ", "SEK": "SE", "NOK": "NO", "MXN": "MX"
        ]
        return currencyCountryMap[currency] ?? currency
    }

    /// Fallback mock events when scraping fails
    private func fallbackMockEvents() -> [EconomicEvent] {
        let calendar = Calendar.current
        let today = Date()

        func makeDateTime(daysFromNow: Int, hour: Int, minute: Int) -> (date: Date, time: Date) {
            let date = calendar.date(byAdding: .day, value: daysFromNow, to: today) ?? today
            let time = calendar.date(from: DateComponents(hour: hour, minute: minute)) ?? today
            return (date, time)
        }

        return [
            EconomicEvent(
                id: UUID(),
                title: "Fed Interest Rate Decision",
                country: "US",
                date: makeDateTime(daysFromNow: 0, hour: 14, minute: 0).date,
                time: makeDateTime(daysFromNow: 0, hour: 14, minute: 0).time,
                impact: .high,
                forecast: "5.50%",
                previous: "5.50%",
                actual: nil,
                currency: "USD",
                description: nil,
                countryFlag: "🇺🇸"
            ),
            EconomicEvent(
                id: UUID(),
                title: "UK CPI y/y",
                country: "UK",
                date: makeDateTime(daysFromNow: 0, hour: 7, minute: 0).date,
                time: makeDateTime(daysFromNow: 0, hour: 7, minute: 0).time,
                impact: .high,
                forecast: "2.6%",
                previous: "2.5%",
                actual: nil,
                currency: "GBP",
                description: nil,
                countryFlag: "🇬🇧"
            ),
            EconomicEvent(
                id: UUID(),
                title: "ECB President Lagarde Speaks",
                country: "EU",
                date: makeDateTime(daysFromNow: 1, hour: 9, minute: 30).date,
                time: makeDateTime(daysFromNow: 1, hour: 9, minute: 30).time,
                impact: .high,
                forecast: nil,
                previous: nil,
                actual: nil,
                currency: "EUR",
                description: nil,
                countryFlag: "🇪🇺"
            ),
            EconomicEvent(
                id: UUID(),
                title: "US Initial Jobless Claims",
                country: "US",
                date: makeDateTime(daysFromNow: 1, hour: 8, minute: 30).date,
                time: makeDateTime(daysFromNow: 1, hour: 8, minute: 30).time,
                impact: .medium,
                forecast: "217K",
                previous: "223K",
                actual: nil,
                currency: "USD",
                description: nil,
                countryFlag: "🇺🇸"
            ),
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
                description: nil,
                countryFlag: "🇺🇸"
            ),
            EconomicEvent(
                id: UUID(),
                title: "US Non-Farm Payrolls",
                country: "US",
                date: makeDateTime(daysFromNow: 5, hour: 8, minute: 30).date,
                time: makeDateTime(daysFromNow: 5, hour: 8, minute: 30).time,
                impact: .high,
                forecast: "180K",
                previous: "256K",
                actual: nil,
                currency: "USD",
                description: nil,
                countryFlag: "🇺🇸"
            )
        ]
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
