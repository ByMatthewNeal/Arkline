import Foundation

// MARK: - Economic Events Data
/// Hardcoded economic events data - no external API dependency
/// Data sourced from Investing.com Economic Calendar
/// Last updated: January 27, 2026
enum EconomicEventsData {

    // MARK: - Get Events

    /// Returns all hardcoded economic events
    static func getAllEvents() -> [EconomicEvent] {
        return allEvents
    }

    /// Returns events for a specific date range
    static func getEvents(from startDate: Date, to endDate: Date) -> [EconomicEvent] {
        return allEvents.filter { event in
            event.date >= startDate && event.date <= endDate
        }.sorted { $0.date < $1.date }
    }

    /// Returns upcoming events from today
    static func getUpcomingEvents(days: Int = 7, impactFilter: [EventImpact] = [.high, .medium]) -> [EconomicEvent] {
        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        guard let endDate = calendar.date(byAdding: .day, value: days, to: startOfToday) else {
            return []
        }

        return allEvents.filter { event in
            event.date >= startOfToday && event.date <= endDate && impactFilter.contains(event.impact)
        }.sorted { $0.date < $1.date }
    }

    /// Returns today's events
    static func getTodaysEvents(impactFilter: [EventImpact] = [.high, .medium]) -> [EconomicEvent] {
        let calendar = Calendar.current
        return allEvents.filter { event in
            calendar.isDateInToday(event.date) && impactFilter.contains(event.impact)
        }.sorted { $0.date < $1.date }
    }

    // MARK: - Helper

    private static func makeEvent(
        title: String,
        currency: String,
        dateString: String,
        timeString: String,
        impact: EventImpact,
        forecast: String? = nil,
        previous: String? = nil
    ) -> EconomicEvent {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        dateFormatter.timeZone = TimeZone(identifier: "America/New_York")

        let fullDateString = "\(dateString) \(timeString)"
        let date = dateFormatter.date(from: fullDateString) ?? Date()

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let time = timeFormatter.date(from: timeString)

        let countryFlags: [String: String] = [
            "USD": "🇺🇸", "EUR": "🇪🇺", "GBP": "🇬🇧", "JPY": "🇯🇵",
            "AUD": "🇦🇺", "CAD": "🇨🇦", "CHF": "🇨🇭", "CNY": "🇨🇳"
        ]

        let currencyCountryMap: [String: String] = [
            "USD": "US", "EUR": "EU", "GBP": "UK", "JPY": "JP",
            "AUD": "AU", "CAD": "CA", "CHF": "CH", "CNY": "CN"
        ]

        return EconomicEvent(
            id: UUID(),
            title: title,
            country: currencyCountryMap[currency] ?? currency,
            date: date,
            time: time,
            impact: impact,
            forecast: forecast,
            previous: previous,
            actual: nil,
            currency: currency,
            description: nil,
            countryFlag: countryFlags[currency]
        )
    }

    // MARK: - All Events Data

    private static let allEvents: [EconomicEvent] = [
        // ==================== JANUARY 2026 ====================

        // Jan 27, 2026 (Tuesday)
        makeEvent(title: "CB Consumer Confidence", currency: "USD", dateString: "2026-01-27", timeString: "10:00", impact: .high, forecast: "90.6", previous: "94.2"),

        // Jan 28, 2026 (Wednesday) - FOMC DAY
        makeEvent(title: "Fed Interest Rate Decision", currency: "USD", dateString: "2026-01-28", timeString: "14:00", impact: .high, forecast: "3.75%", previous: "3.75%"),
        makeEvent(title: "FOMC Statement", currency: "USD", dateString: "2026-01-28", timeString: "14:00", impact: .high),
        makeEvent(title: "FOMC Press Conference", currency: "USD", dateString: "2026-01-28", timeString: "14:30", impact: .high),
        makeEvent(title: "Crude Oil Inventories", currency: "USD", dateString: "2026-01-28", timeString: "10:30", impact: .medium),

        // Jan 29, 2026 (Thursday)
        makeEvent(title: "Initial Jobless Claims", currency: "USD", dateString: "2026-01-29", timeString: "08:30", impact: .high, forecast: "202K", previous: "200K"),
        makeEvent(title: "GDP (QoQ) (Q4) Advance", currency: "USD", dateString: "2026-01-29", timeString: "08:30", impact: .high),
        makeEvent(title: "Nonfarm Productivity (QoQ)", currency: "USD", dateString: "2026-01-29", timeString: "08:30", impact: .medium, forecast: "4.9%", previous: "4.9%"),
        makeEvent(title: "Factory Orders (MoM)", currency: "USD", dateString: "2026-01-29", timeString: "10:00", impact: .medium, forecast: "0.5%", previous: "-1.3%"),

        // Jan 30, 2026 (Friday)
        makeEvent(title: "Core PPI (MoM)", currency: "USD", dateString: "2026-01-30", timeString: "08:30", impact: .high, forecast: "0.3%", previous: "0.0%"),
        makeEvent(title: "PPI (MoM)", currency: "USD", dateString: "2026-01-30", timeString: "08:30", impact: .high, forecast: "0.2%", previous: "0.2%"),
        makeEvent(title: "Chicago PMI", currency: "USD", dateString: "2026-01-30", timeString: "09:45", impact: .high, forecast: "43.3", previous: "42.7"),

        // ==================== FEBRUARY 2026 ====================

        // Feb 2, 2026 (Monday)
        makeEvent(title: "ISM Manufacturing PMI", currency: "USD", dateString: "2026-02-02", timeString: "10:00", impact: .high, previous: "47.9"),
        makeEvent(title: "ISM Manufacturing Prices", currency: "USD", dateString: "2026-02-02", timeString: "10:00", impact: .high, previous: "58.5"),
        makeEvent(title: "ISM Manufacturing Employment", currency: "USD", dateString: "2026-02-02", timeString: "10:00", impact: .medium, previous: "44.9"),

        // Feb 3, 2026 (Tuesday)
        makeEvent(title: "JOLTS Job Openings", currency: "USD", dateString: "2026-02-03", timeString: "10:00", impact: .high, previous: "7.146M"),

        // Feb 4, 2026 (Wednesday)
        makeEvent(title: "ADP Nonfarm Employment Change", currency: "USD", dateString: "2026-02-04", timeString: "08:15", impact: .high, previous: "41K"),
        makeEvent(title: "ISM Non-Manufacturing PMI", currency: "USD", dateString: "2026-02-04", timeString: "10:00", impact: .high, previous: "54.4"),
        makeEvent(title: "ISM Non-Manufacturing Prices", currency: "USD", dateString: "2026-02-04", timeString: "10:00", impact: .high, previous: "64.3"),

        // Feb 5, 2026 (Thursday)
        makeEvent(title: "Initial Jobless Claims", currency: "USD", dateString: "2026-02-05", timeString: "08:30", impact: .high),
        makeEvent(title: "Nonfarm Productivity (QoQ) (Q4)", currency: "USD", dateString: "2026-02-05", timeString: "08:30", impact: .medium, previous: "3.3%"),
        makeEvent(title: "Unit Labor Costs (QoQ) (Q4)", currency: "USD", dateString: "2026-02-05", timeString: "08:30", impact: .medium, previous: "1.0%"),

        // Feb 6, 2026 (Friday) - NFP DAY
        makeEvent(title: "Nonfarm Payrolls", currency: "USD", dateString: "2026-02-06", timeString: "08:30", impact: .high, previous: "50K"),
        makeEvent(title: "Unemployment Rate", currency: "USD", dateString: "2026-02-06", timeString: "08:30", impact: .high, previous: "4.4%"),
        makeEvent(title: "Average Hourly Earnings (MoM)", currency: "USD", dateString: "2026-02-06", timeString: "08:30", impact: .high, previous: "0.3%"),
        makeEvent(title: "Average Hourly Earnings (YoY)", currency: "USD", dateString: "2026-02-06", timeString: "08:30", impact: .high, previous: "3.8%"),
        makeEvent(title: "Michigan Consumer Sentiment", currency: "USD", dateString: "2026-02-06", timeString: "10:00", impact: .high, previous: "56.4"),
        makeEvent(title: "Michigan Inflation Expectations", currency: "USD", dateString: "2026-02-06", timeString: "10:00", impact: .medium, previous: "4.0%"),

        // Feb 10, 2026 (Tuesday)
        makeEvent(title: "NFIB Small Business Optimism", currency: "USD", dateString: "2026-02-10", timeString: "06:00", impact: .medium, previous: "99.5"),
        makeEvent(title: "Employment Cost Index (QoQ)", currency: "USD", dateString: "2026-02-10", timeString: "08:30", impact: .high, previous: "0.8%"),

        // Feb 11, 2026 (Wednesday) - CPI DAY
        makeEvent(title: "CPI (YoY)", currency: "USD", dateString: "2026-02-11", timeString: "08:30", impact: .high, previous: "2.7%"),
        makeEvent(title: "CPI (MoM)", currency: "USD", dateString: "2026-02-11", timeString: "08:30", impact: .high, previous: "0.3%"),
        makeEvent(title: "Core CPI (YoY)", currency: "USD", dateString: "2026-02-11", timeString: "08:30", impact: .high, previous: "2.6%"),
        makeEvent(title: "Core CPI (MoM)", currency: "USD", dateString: "2026-02-11", timeString: "08:30", impact: .high, previous: "0.2%"),
        makeEvent(title: "Federal Budget Balance", currency: "USD", dateString: "2026-02-11", timeString: "14:00", impact: .medium, previous: "-145.0B"),

        // Feb 12, 2026 (Thursday)
        makeEvent(title: "Initial Jobless Claims", currency: "USD", dateString: "2026-02-12", timeString: "08:30", impact: .high),
        makeEvent(title: "Existing Home Sales", currency: "USD", dateString: "2026-02-12", timeString: "10:00", impact: .high, previous: "4.35M"),

        // Feb 17, 2026 (Tuesday)
        makeEvent(title: "NY Empire State Manufacturing Index", currency: "USD", dateString: "2026-02-17", timeString: "08:30", impact: .medium, previous: "7.70"),
        makeEvent(title: "NAHB Housing Market Index", currency: "USD", dateString: "2026-02-17", timeString: "10:00", impact: .medium, previous: "37"),

        // ==================== MARCH 2026 ====================

        // Mar 6, 2026 (Friday) - NFP DAY
        makeEvent(title: "Nonfarm Payrolls", currency: "USD", dateString: "2026-03-06", timeString: "08:30", impact: .high),
        makeEvent(title: "Unemployment Rate", currency: "USD", dateString: "2026-03-06", timeString: "08:30", impact: .high),
        makeEvent(title: "Average Hourly Earnings (MoM)", currency: "USD", dateString: "2026-03-06", timeString: "08:30", impact: .high),

        // Mar 11, 2026 (Wednesday) - CPI DAY
        makeEvent(title: "CPI (YoY)", currency: "USD", dateString: "2026-03-11", timeString: "08:30", impact: .high),
        makeEvent(title: "CPI (MoM)", currency: "USD", dateString: "2026-03-11", timeString: "08:30", impact: .high),
        makeEvent(title: "Core CPI (YoY)", currency: "USD", dateString: "2026-03-11", timeString: "08:30", impact: .high),
        makeEvent(title: "Core CPI (MoM)", currency: "USD", dateString: "2026-03-11", timeString: "08:30", impact: .high),

        // Mar 18, 2026 (Wednesday) - FOMC DAY
        makeEvent(title: "Fed Interest Rate Decision", currency: "USD", dateString: "2026-03-18", timeString: "14:00", impact: .high),
        makeEvent(title: "FOMC Statement", currency: "USD", dateString: "2026-03-18", timeString: "14:00", impact: .high),
        makeEvent(title: "FOMC Press Conference", currency: "USD", dateString: "2026-03-18", timeString: "14:30", impact: .high),
        makeEvent(title: "FOMC Economic Projections", currency: "USD", dateString: "2026-03-18", timeString: "14:00", impact: .high),

        // ==================== APRIL 2026 ====================

        // Apr 3, 2026 (Friday) - NFP DAY
        makeEvent(title: "Nonfarm Payrolls", currency: "USD", dateString: "2026-04-03", timeString: "08:30", impact: .high),
        makeEvent(title: "Unemployment Rate", currency: "USD", dateString: "2026-04-03", timeString: "08:30", impact: .high),
        makeEvent(title: "Average Hourly Earnings (MoM)", currency: "USD", dateString: "2026-04-03", timeString: "08:30", impact: .high),

        // Apr 10, 2026 (Friday) - CPI DAY
        makeEvent(title: "CPI (YoY)", currency: "USD", dateString: "2026-04-10", timeString: "08:30", impact: .high),
        makeEvent(title: "CPI (MoM)", currency: "USD", dateString: "2026-04-10", timeString: "08:30", impact: .high),
        makeEvent(title: "Core CPI (YoY)", currency: "USD", dateString: "2026-04-10", timeString: "08:30", impact: .high),
        makeEvent(title: "Core CPI (MoM)", currency: "USD", dateString: "2026-04-10", timeString: "08:30", impact: .high),

        // Apr 29, 2026 (Wednesday) - FOMC DAY
        makeEvent(title: "Fed Interest Rate Decision", currency: "USD", dateString: "2026-04-29", timeString: "14:00", impact: .high),
        makeEvent(title: "FOMC Statement", currency: "USD", dateString: "2026-04-29", timeString: "14:00", impact: .high),
        makeEvent(title: "FOMC Press Conference", currency: "USD", dateString: "2026-04-29", timeString: "14:30", impact: .high),

        // ==================== MAY 2026 ====================

        // May 1, 2026 (Friday) - NFP DAY
        makeEvent(title: "Nonfarm Payrolls", currency: "USD", dateString: "2026-05-01", timeString: "08:30", impact: .high),
        makeEvent(title: "Unemployment Rate", currency: "USD", dateString: "2026-05-01", timeString: "08:30", impact: .high),
        makeEvent(title: "Average Hourly Earnings (MoM)", currency: "USD", dateString: "2026-05-01", timeString: "08:30", impact: .high),

        // May 13, 2026 (Wednesday) - CPI DAY
        makeEvent(title: "CPI (YoY)", currency: "USD", dateString: "2026-05-13", timeString: "08:30", impact: .high),
        makeEvent(title: "CPI (MoM)", currency: "USD", dateString: "2026-05-13", timeString: "08:30", impact: .high),
        makeEvent(title: "Core CPI (YoY)", currency: "USD", dateString: "2026-05-13", timeString: "08:30", impact: .high),
        makeEvent(title: "Core CPI (MoM)", currency: "USD", dateString: "2026-05-13", timeString: "08:30", impact: .high),

        // ==================== JUNE 2026 ====================

        // Jun 5, 2026 (Friday) - NFP DAY
        makeEvent(title: "Nonfarm Payrolls", currency: "USD", dateString: "2026-06-05", timeString: "08:30", impact: .high),
        makeEvent(title: "Unemployment Rate", currency: "USD", dateString: "2026-06-05", timeString: "08:30", impact: .high),
        makeEvent(title: "Average Hourly Earnings (MoM)", currency: "USD", dateString: "2026-06-05", timeString: "08:30", impact: .high),

        // Jun 10, 2026 (Wednesday) - CPI DAY
        makeEvent(title: "CPI (YoY)", currency: "USD", dateString: "2026-06-10", timeString: "08:30", impact: .high),
        makeEvent(title: "CPI (MoM)", currency: "USD", dateString: "2026-06-10", timeString: "08:30", impact: .high),
        makeEvent(title: "Core CPI (YoY)", currency: "USD", dateString: "2026-06-10", timeString: "08:30", impact: .high),
        makeEvent(title: "Core CPI (MoM)", currency: "USD", dateString: "2026-06-10", timeString: "08:30", impact: .high),

        // Jun 17, 2026 (Wednesday) - FOMC DAY
        makeEvent(title: "Fed Interest Rate Decision", currency: "USD", dateString: "2026-06-17", timeString: "14:00", impact: .high),
        makeEvent(title: "FOMC Statement", currency: "USD", dateString: "2026-06-17", timeString: "14:00", impact: .high),
        makeEvent(title: "FOMC Press Conference", currency: "USD", dateString: "2026-06-17", timeString: "14:30", impact: .high),
        makeEvent(title: "FOMC Economic Projections", currency: "USD", dateString: "2026-06-17", timeString: "14:00", impact: .high),

        // ==================== HOLIDAYS ====================

        // US Holidays (Markets Closed)
        makeEvent(title: "US Holiday - Washington's Birthday", currency: "USD", dateString: "2026-02-16", timeString: "00:00", impact: .low),
        makeEvent(title: "US Holiday - Good Friday", currency: "USD", dateString: "2026-04-03", timeString: "00:00", impact: .low),
        makeEvent(title: "US Holiday - Memorial Day", currency: "USD", dateString: "2026-05-25", timeString: "00:00", impact: .low),
        makeEvent(title: "US Holiday - Juneteenth", currency: "USD", dateString: "2026-06-19", timeString: "00:00", impact: .low),
    ]
}
