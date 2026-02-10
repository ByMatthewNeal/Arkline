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
        // These dates should be updated periodically
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())

        // Example 2024 meeting dates (update as needed)
        let meetingDates: [(month: Int, day: Int, hasProjections: Bool)] = [
            (1, 31, false),
            (3, 20, true),
            (5, 1, false),
            (6, 12, true),
            (7, 31, false),
            (9, 18, true),
            (11, 7, false),
            (12, 18, true)
        ]

        return meetingDates.compactMap { dateInfo -> FedMeeting? in
            guard let date = calendar.date(from: DateComponents(year: year, month: dateInfo.month, day: dateInfo.day)) else {
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

// MARK: - Finnhub Economic Calendar Service
/// Fetches economic calendar data from Finnhub API
/// Free tier: 60 API calls/minute
/// Docs: https://finnhub.io/docs/api/economic-calendar
final class FinnhubEconomicCalendarService {

    private let baseURL = "https://finnhub.io/api/v1"

    private var apiKey: String {
        Constants.API.finnhubAPIKey
    }

    private var isConfigured: Bool {
        !apiKey.isEmpty
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

        guard let url = URL(string: "\(baseURL)/calendar/economic?from=\(fromStr)&to=\(toStr)&token=\(apiKey)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            logWarning("Finnhub returned status \(httpResponse.statusCode)", category: .network)
            throw URLError(.badServerResponse)
        }

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

        let (data, response) = try await URLSession.shared.data(for: request)

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

// MARK: - Google News RSS Service
/// Fetches and parses Google News RSS feeds for crypto and geopolitical news
final class GoogleNewsRSSService: NSObject, XMLParserDelegate {

    // MARK: - RSS Feed URLs
    private enum FeedURL {
        static let crypto = "https://news.google.com/rss/search?q=cryptocurrency+OR+bitcoin+OR+ethereum+OR+crypto&hl=en-US&gl=US&ceid=US:en"
        static let geopolitics = "https://news.google.com/rss/search?q=geopolitics+OR+world+news+OR+international+relations+OR+global+politics&hl=en-US&gl=US&ceid=US:en"
        static let world = "https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNRGx1YlY4U0FtVnVHZ0pWVXlnQVAB?hl=en-US&gl=US&ceid=US:en"

        static func search(_ query: String) -> String {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            return "https://news.google.com/rss/search?q=\(encoded)&hl=en-US&gl=US&ceid=US:en"
        }

        /// Build a combined query URL from user-selected topics and custom keywords
        static func fromTopics(_ topics: Set<Constants.NewsTopic>, customKeywords: [String]) -> String {
            var queryParts: [String] = []

            // Add search queries for each selected topic
            for topic in topics {
                queryParts.append("(\(topic.searchQuery))")
            }

            // Add custom keywords
            for keyword in customKeywords {
                let cleaned = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    queryParts.append("\"\(cleaned)\"")
                }
            }

            // Join with OR and encode
            let combinedQuery = queryParts.joined(separator: " OR ")
            let encoded = combinedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? combinedQuery
            return "https://news.google.com/rss/search?q=\(encoded)&hl=en-US&gl=US&ceid=US:en"
        }
    }

    // MARK: - Parser State
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentPubDate = ""
    private var currentSource = ""
    private var currentDescription = ""
    private var newsItems: [GoogleNewsRSSItem] = []
    private var isInItem = false

    // MARK: - Public Methods

    /// Fetch crypto news from Google News RSS
    func fetchCryptoNews(limit: Int = 20) async throws -> [NewsItem] {
        return try await fetchFromURL(FeedURL.crypto, category: "Crypto", limit: limit)
    }

    /// Fetch geopolitical/world news from Google News RSS
    func fetchGeopoliticalNews(limit: Int = 20) async throws -> [NewsItem] {
        // Combine world topic feed with geopolitics search for broader coverage
        async let worldNews = fetchFromURL(FeedURL.world, category: "World", limit: limit)
        async let geoNews = fetchFromURL(FeedURL.geopolitics, category: "Geopolitics", limit: limit)

        let (world, geo) = try await (worldNews, geoNews)

        // Combine and deduplicate by title
        var seen = Set<String>()
        var combined: [NewsItem] = []

        for item in (world + geo) {
            let normalizedTitle = item.title.lowercased()
            if !seen.contains(normalizedTitle) {
                seen.insert(normalizedTitle)
                combined.append(item)
            }
        }

        // Sort by date and limit
        combined.sort { $0.publishedAt > $1.publishedAt }
        return Array(combined.prefix(limit))
    }

    /// Fetch news for a custom search query
    func fetchNews(query: String, limit: Int = 20) async throws -> [NewsItem] {
        return try await fetchFromURL(FeedURL.search(query), category: "Search", limit: limit)
    }

    /// Fetch personalized news based on user-selected topics and custom keywords
    func fetchPersonalizedNews(
        topics: Set<Constants.NewsTopic>,
        customKeywords: [String],
        limit: Int = 20
    ) async throws -> [NewsItem] {
        var allNews: [NewsItem] = []

        // Calculate how to distribute the limit
        let hasCustomKeywords = !customKeywords.isEmpty
        let topicsLimit = hasCustomKeywords ? (limit * 2 / 3) : limit  // 2/3 for topics
        let keywordsLimit = hasCustomKeywords ? (limit / 3) : 0        // 1/3 for custom keywords

        // Fetch news for pre-defined topics
        if !topics.isEmpty {
            do {
                let topicNews = try await fetchFromURL(
                    FeedURL.fromTopics(topics, customKeywords: []),
                    category: "Topics",
                    limit: topicsLimit
                )
                allNews.append(contentsOf: topicNews)
                logDebug("Fetched \(topicNews.count) items for topics", category: .network)
            } catch {
                logWarning("Failed to fetch topic news: \(error)", category: .network)
            }
        }

        // Fetch news for EACH custom keyword separately to ensure representation
        if hasCustomKeywords {
            let perKeywordLimit = max(3, keywordsLimit / customKeywords.count)

            for keyword in customKeywords {
                do {
                    let keywordNews = try await fetchFromURL(
                        FeedURL.search(keyword),
                        category: "Keyword:\(keyword)",
                        limit: perKeywordLimit
                    )
                    allNews.append(contentsOf: keywordNews)
                    logDebug("Fetched \(keywordNews.count) items for keyword '\(keyword)'", category: .network)
                } catch {
                    logWarning("Failed to fetch news for keyword '\(keyword)': \(error)", category: .network)
                }
            }
        }

        // Deduplicate by title
        var seen = Set<String>()
        var deduplicated: [NewsItem] = []

        for item in allNews {
            let normalizedTitle = item.title.lowercased()
            if !seen.contains(normalizedTitle) {
                seen.insert(normalizedTitle)
                deduplicated.append(item)
            }
        }

        // Sort by date and limit
        deduplicated.sort { $0.publishedAt > $1.publishedAt }
        return Array(deduplicated.prefix(limit))
    }

    // MARK: - Private Methods

    private func fetchFromURL(_ urlString: String, category: String, limit: Int) async throws -> [NewsItem] {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("application/rss+xml, application/xml, text/xml", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            logWarning("Google News RSS returned status \(httpResponse.statusCode)", category: .network)
            throw URLError(.badServerResponse)
        }

        // Parse RSS XML
        let items = parseRSS(data: data)

        // Convert to NewsItem
        let newsItems = items.prefix(limit).map { item -> NewsItem in
            NewsItem(
                id: UUID(),
                title: cleanTitle(item.title),
                source: item.source.isEmpty ? "Google News" : item.source,
                publishedAt: parseRSSDate(item.pubDate) ?? Date(),
                imageUrl: nil, // Google News RSS doesn't include images
                url: item.link,
                sourceType: .googleNews,
                twitterHandle: nil,
                isVerified: false,
                description: cleanDescription(item.description)
            )
        }

        logDebug("[\(category)] Fetched \(newsItems.count) items from Google News RSS", category: .network)
        return Array(newsItems)
    }

    private func parseRSS(data: Data) -> [GoogleNewsRSSItem] {
        // Reset state
        newsItems = []
        currentElement = ""
        currentTitle = ""
        currentLink = ""
        currentPubDate = ""
        currentSource = ""
        currentDescription = ""
        isInItem = false

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        return newsItems
    }

    private func cleanTitle(_ title: String) -> String {
        // Remove " - Source Name" suffix that Google News adds
        if let dashRange = title.range(of: " - ", options: .backwards) {
            return String(title[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanDescription(_ description: String) -> String {
        // Remove HTML tags
        let cleaned = description
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned
    }

    private func parseRSSDate(_ dateString: String) -> Date? {
        // Google News uses RFC 822 date format: "Fri, 24 Jan 2026 12:30:00 GMT"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Try multiple formats
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName

        if elementName == "item" {
            isInItem = true
            currentTitle = ""
            currentLink = ""
            currentPubDate = ""
            currentSource = ""
            currentDescription = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInItem else { return }

        switch currentElement {
        case "title":
            currentTitle += string
        case "link":
            currentLink += string
        case "pubDate":
            currentPubDate += string
        case "source":
            currentSource += string
        case "description":
            currentDescription += string
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            isInItem = false

            // Extract source from title if not in source element
            var source = currentSource.trimmingCharacters(in: .whitespacesAndNewlines)
            if source.isEmpty {
                // Google News format: "Title - Source Name"
                if let dashRange = currentTitle.range(of: " - ", options: .backwards) {
                    source = String(currentTitle[dashRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            let item = GoogleNewsRSSItem(
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                link: currentLink.trimmingCharacters(in: .whitespacesAndNewlines),
                pubDate: currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines),
                source: source,
                description: currentDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            // Only add if we have a title and link
            if !item.title.isEmpty && !item.link.isEmpty {
                newsItems.append(item)
            }
        }
    }
}

// MARK: - Google News RSS Item
private struct GoogleNewsRSSItem {
    let title: String
    let link: String
    let pubDate: String
    let source: String
    let description: String
}
