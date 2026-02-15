import Foundation

// MARK: - Investing.com Economic Calendar Scraper
/// Scrapes economic calendar data from Investing.com (fallback)
final class InvestingComScraper {

    private let baseURL = "https://www.investing.com/economic-calendar/"
    private let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

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

    // Countries to show (USA and Japan only)
    private let allowedCurrencies: Set<String> = ["USD", "JPY"]

    func fetchUpcomingEvents(days: Int, impactFilter: [EventImpact]) async throws -> [EconomicEvent] {
        // Use hardcoded data instead of scraping Investing.com
        var allEvents = EconomicEventsData.getUpcomingEvents(days: days, impactFilter: impactFilter)

        // Add US market holidays
        let holidays = getUSMarketHolidays(days: days)
        allEvents.append(contentsOf: holidays)

        // Sort by date
        allEvents.sort { $0.date < $1.date }

        logDebug("Loaded \(allEvents.count) economic events from hardcoded data", category: .network)
        return allEvents
    }

    // MARK: - US Market Holidays
    /// Returns US market holidays within the specified number of days
    private func getUSMarketHolidays(days: Int) -> [EconomicEvent] {
        let calendar = Calendar.current
        let today = Date()
        let endDate = calendar.date(byAdding: .day, value: days, to: today) ?? today

        // Get holidays for current year and next year
        let currentYear = calendar.component(.year, from: today)
        var holidays: [EconomicEvent] = []

        for year in [currentYear, currentYear + 1] {
            holidays.append(contentsOf: generateHolidaysForYear(year))
        }

        // Filter to only holidays within the date range
        return holidays.filter { holiday in
            holiday.date >= today && holiday.date <= endDate
        }
    }

    /// Generate US market holidays for a specific year
    private func generateHolidaysForYear(_ year: Int) -> [EconomicEvent] {
        var holidays: [EconomicEvent] = []
        let calendar = Calendar.current

        // Helper to create holiday event
        func makeHoliday(title: String, date: Date, earlyClose: Bool = false) -> EconomicEvent {
            let displayTitle = earlyClose ? "\(title) (Early Close 1pm ET)" : "\(title) - Markets Closed"
            return EconomicEvent(
                id: UUID(),
                title: displayTitle,
                country: "US",
                date: date,
                time: earlyClose ? calendar.date(from: DateComponents(hour: 13, minute: 0)) : nil,
                impact: .high,
                forecast: nil,
                previous: nil,
                actual: nil,
                currency: "USD",
                description: earlyClose ? "US markets close early at 1:00 PM ET" : "US stock and bond markets are closed",
                countryFlag: "🇺🇸"
            )
        }

        // New Year's Day - Jan 1 (observed on nearest weekday if falls on weekend)
        if let newYears = observedDate(month: 1, day: 1, year: year) {
            holidays.append(makeHoliday(title: "New Year's Day", date: newYears))
        }

        // Martin Luther King Jr. Day - 3rd Monday of January
        if let mlk = nthWeekdayOf(nth: 3, weekday: .monday, month: 1, year: year) {
            holidays.append(makeHoliday(title: "Martin Luther King Jr. Day", date: mlk))
        }

        // Presidents' Day - 3rd Monday of February
        if let presidents = nthWeekdayOf(nth: 3, weekday: .monday, month: 2, year: year) {
            holidays.append(makeHoliday(title: "Presidents' Day", date: presidents))
        }

        // Good Friday - Friday before Easter (varies)
        if let goodFriday = calculateGoodFriday(year: year) {
            holidays.append(makeHoliday(title: "Good Friday", date: goodFriday))
        }

        // Memorial Day - Last Monday of May
        if let memorial = lastWeekdayOf(weekday: .monday, month: 5, year: year) {
            holidays.append(makeHoliday(title: "Memorial Day", date: memorial))
        }

        // Juneteenth - June 19 (observed on nearest weekday if falls on weekend)
        if let juneteenth = observedDate(month: 6, day: 19, year: year) {
            holidays.append(makeHoliday(title: "Juneteenth", date: juneteenth))
        }

        // Independence Day - July 4 (observed on nearest weekday if falls on weekend)
        if let july4 = observedDate(month: 7, day: 4, year: year) {
            holidays.append(makeHoliday(title: "Independence Day", date: july4))
            // July 3rd early close if July 4th is on Thursday
            if let july4Date = calendar.date(from: DateComponents(year: year, month: 7, day: 4)),
               calendar.component(.weekday, from: july4Date) == 5, // Thursday
               let july3 = calendar.date(from: DateComponents(year: year, month: 7, day: 3)) {
                holidays.append(makeHoliday(title: "Independence Day Eve", date: july3, earlyClose: true))
            }
        }

        // Labor Day - 1st Monday of September
        if let labor = nthWeekdayOf(nth: 1, weekday: .monday, month: 9, year: year) {
            holidays.append(makeHoliday(title: "Labor Day", date: labor))
        }

        // Thanksgiving Day - 4th Thursday of November
        if let thanksgiving = nthWeekdayOf(nth: 4, weekday: .thursday, month: 11, year: year) {
            holidays.append(makeHoliday(title: "Thanksgiving Day", date: thanksgiving))
            // Day after Thanksgiving - early close
            if let dayAfter = calendar.date(byAdding: .day, value: 1, to: thanksgiving) {
                holidays.append(makeHoliday(title: "Day After Thanksgiving", date: dayAfter, earlyClose: true))
            }
        }

        // Christmas Day - Dec 25 (observed on nearest weekday if falls on weekend)
        if let christmas = observedDate(month: 12, day: 25, year: year) {
            holidays.append(makeHoliday(title: "Christmas Day", date: christmas))
            // Christmas Eve early close if Christmas is on weekday
            if let christmasEve = calendar.date(byAdding: .day, value: -1, to: christmas) {
                let weekday = calendar.component(.weekday, from: christmasEve)
                if weekday >= 2 && weekday <= 6 { // Monday-Friday
                    holidays.append(makeHoliday(title: "Christmas Eve", date: christmasEve, earlyClose: true))
                }
            }
        }

        return holidays
    }

    /// Calculate the observed date (moves weekend holidays to nearest weekday)
    private func observedDate(month: Int, day: Int, year: Int) -> Date? {
        let calendar = Calendar.current
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            return nil
        }

        let weekday = calendar.component(.weekday, from: date)
        switch weekday {
        case 1: // Sunday -> Monday
            return calendar.date(byAdding: .day, value: 1, to: date)
        case 7: // Saturday -> Friday
            return calendar.date(byAdding: .day, value: -1, to: date)
        default:
            return date
        }
    }

    /// Get the nth occurrence of a weekday in a month
    private func nthWeekdayOf(nth: Int, weekday: Weekday, month: Int, year: Int) -> Date? {
        let calendar = Calendar.current
        let components = DateComponents(year: year, month: month, weekday: weekday.rawValue, weekdayOrdinal: nth)
        return calendar.date(from: components)
    }

    /// Get the last occurrence of a weekday in a month
    private func lastWeekdayOf(weekday: Weekday, month: Int, year: Int) -> Date? {
        let calendar = Calendar.current
        let components = DateComponents(year: year, month: month, weekday: weekday.rawValue, weekdayOrdinal: -1)
        return calendar.date(from: components)
    }

    /// Calculate Good Friday (Friday before Easter)
    private func calculateGoodFriday(year: Int) -> Date? {
        // Easter calculation using the Anonymous Gregorian algorithm
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

        // Good Friday is 2 days before Easter
        return calendar.date(byAdding: .day, value: -2, to: easter)
    }

    private enum Weekday: Int {
        case sunday = 1
        case monday = 2
        case tuesday = 3
        case wednesday = 4
        case thursday = 5
        case friday = 6
        case saturday = 7
    }

    private func fetchCalendarHTML() async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = 15

        let (data, response) = try await PinnedURLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }

        return html
    }

    private func parseEvents(from html: String) -> [EconomicEvent] {
        var events: [EconomicEvent] = []

        // Pattern to match event rows with data attributes
        let rowPattern = #"<tr[^>]*class="[^"]*js-event-item[^"]*"[^>]*data-event-datetime="([^"]*)"[^>]*>(.*?)</tr>"#

        guard let regex = try? NSRegularExpression(pattern: rowPattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }

        let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))

        for match in matches.prefix(100) {
            guard let datetimeRange = Range(match.range(at: 1), in: html),
                  let rowRange = Range(match.range(at: 2), in: html) else { continue }

            let datetime = String(html[datetimeRange])
            let rowHTML = String(html[rowRange])

            if let event = parseEventRow(rowHTML, datetime: datetime) {
                events.append(event)
            }
        }

        return events
    }

    private func parseEventRow(_ rowHTML: String, datetime: String) -> EconomicEvent? {
        // Extract currency
        let currency = extractMatch(pattern: #">([A-Z]{3})</span>"#, from: rowHTML) ?? "USD"

        // Extract event name - look for the event link text
        var eventName = extractMatch(pattern: #"<a[^>]*event[^>]*>([^<]+)</a>"#, from: rowHTML)
        if eventName == nil {
            eventName = extractMatch(pattern: #"class="event"[^>]*>([^<]+)<"#, from: rowHTML)
        }

        guard let name = eventName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return nil }

        // Parse impact
        let impact = parseImpact(from: rowHTML)

        // Extract values
        let actual = extractMatch(pattern: #"class="[^"]*act[^"]*"[^>]*>([^<]*)<"#, from: rowHTML)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let forecast = extractMatch(pattern: #"class="[^"]*fore[^"]*"[^>]*>([^<]*)<"#, from: rowHTML)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let previous = extractMatch(pattern: #"class="[^"]*prev[^"]*"[^>]*>([^<]*)<"#, from: rowHTML)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let (eventDate, eventTime) = parseDatetime(datetime)

        return EconomicEvent(
            id: UUID(),
            title: cleanEventName(name),
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

    private func extractMatch(pattern: String, from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
    }

    private func parseImpact(from rowHTML: String) -> EventImpact {
        let html = rowHTML.lowercased()

        // Check for 3 bulls (high impact)
        if html.contains("sentiment3") || html.contains("bull3") || html.contains("grayFullBull498") {
            return .high
        }

        // Check for 2 bulls (medium impact)
        if html.contains("sentiment2") || html.contains("bull2") {
            return .medium
        }

        // Count bull icons
        let bullCount = html.components(separatedBy: "grayFullBullish").count - 1
        if bullCount >= 3 { return .high }
        if bullCount >= 2 { return .medium }

        return .low
    }

    private func parseDatetime(_ datetime: String) -> (Date, Date?) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "America/New_York")

        if let date = formatter.date(from: datetime) {
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
        let map: [String: String] = [
            "USD": "US", "EUR": "EU", "GBP": "UK", "JPY": "JP",
            "AUD": "AU", "CAD": "CA", "CHF": "CH", "CNY": "CN",
            "NZD": "NZ", "SEK": "SE", "NOK": "NO", "MXN": "MX"
        ]
        return map[currency] ?? currency
    }

    private func cleanEventName(_ name: String) -> String {
        // Remove HTML entities and extra whitespace
        let cleaned = name
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned
    }

    private func fallbackMockEvents(impactFilter: [EventImpact]) -> [EconomicEvent] {
        let calendar = Calendar.current
        let today = Date()

        func makeDateTime(daysFromNow: Int, hour: Int, minute: Int) -> (date: Date, time: Date) {
            let date = calendar.date(byAdding: .day, value: daysFromNow, to: today) ?? today
            let time = calendar.date(from: DateComponents(hour: hour, minute: minute)) ?? today
            return (date, time)
        }

        // Only USA and Japan events
        let allEvents = [
            // USA Events
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
            ),
            EconomicEvent(
                id: UUID(),
                title: "US GDP q/q",
                country: "US",
                date: makeDateTime(daysFromNow: 2, hour: 8, minute: 30).date,
                time: makeDateTime(daysFromNow: 2, hour: 8, minute: 30).time,
                impact: .high,
                forecast: "3.1%",
                previous: "2.8%",
                actual: nil,
                currency: "USD",
                description: nil,
                countryFlag: "🇺🇸"
            ),
            EconomicEvent(
                id: UUID(),
                title: "Fed Chair Powell Speaks",
                country: "US",
                date: makeDateTime(daysFromNow: 4, hour: 13, minute: 0).date,
                time: makeDateTime(daysFromNow: 4, hour: 13, minute: 0).time,
                impact: .high,
                forecast: nil,
                previous: nil,
                actual: nil,
                currency: "USD",
                description: nil,
                countryFlag: "🇺🇸"
            ),
            // Japan Events
            EconomicEvent(
                id: UUID(),
                title: "BOJ Policy Rate",
                country: "JP",
                date: makeDateTime(daysFromNow: 1, hour: 3, minute: 0).date,
                time: makeDateTime(daysFromNow: 1, hour: 3, minute: 0).time,
                impact: .high,
                forecast: "0.50%",
                previous: "0.25%",
                actual: nil,
                currency: "JPY",
                description: nil,
                countryFlag: "🇯🇵"
            ),
            EconomicEvent(
                id: UUID(),
                title: "Japan CPI y/y",
                country: "JP",
                date: makeDateTime(daysFromNow: 2, hour: 23, minute: 30).date,
                time: makeDateTime(daysFromNow: 2, hour: 23, minute: 30).time,
                impact: .high,
                forecast: "2.9%",
                previous: "2.7%",
                actual: nil,
                currency: "JPY",
                description: nil,
                countryFlag: "🇯🇵"
            ),
            EconomicEvent(
                id: UUID(),
                title: "Japan Trade Balance",
                country: "JP",
                date: makeDateTime(daysFromNow: 3, hour: 23, minute: 50).date,
                time: makeDateTime(daysFromNow: 3, hour: 23, minute: 50).time,
                impact: .medium,
                forecast: "-¥240B",
                previous: "-¥117B",
                actual: nil,
                currency: "JPY",
                description: nil,
                countryFlag: "🇯🇵"
            ),
            EconomicEvent(
                id: UUID(),
                title: "BOJ Governor Ueda Speaks",
                country: "JP",
                date: makeDateTime(daysFromNow: 5, hour: 5, minute: 0).date,
                time: makeDateTime(daysFromNow: 5, hour: 5, minute: 0).time,
                impact: .high,
                forecast: nil,
                previous: nil,
                actual: nil,
                currency: "JPY",
                description: nil,
                countryFlag: "🇯🇵"
            )
        ]

        return allEvents.filter { impactFilter.contains($0.impact) }
    }
}
