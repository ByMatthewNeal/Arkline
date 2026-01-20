import Foundation

extension Date {
    // MARK: - Formatters (cached for performance)
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    private static let displayDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter
    }()

    private static let timeOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private static let chartDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    // MARK: - Formatting
    var iso8601String: String {
        Date.iso8601Formatter.string(from: self)
    }

    var displayDate: String {
        Date.displayDateFormatter.string(from: self)
    }

    var displayDateTime: String {
        Date.displayDateTimeFormatter.string(from: self)
    }

    var displayTime: String {
        Date.timeOnlyFormatter.string(from: self)
    }

    var chartDate: String {
        Date.chartDateFormatter.string(from: self)
    }

    var relativeTime: String {
        Date.relativeDateFormatter.localizedString(for: self, relativeTo: Date())
    }

    // MARK: - Parsing
    static func from(iso8601String: String) -> Date? {
        iso8601Formatter.date(from: iso8601String)
    }

    // MARK: - Date Components
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }

    var startOfWeek: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)) ?? self
    }

    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) ?? self
    }

    var startOfYear: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year], from: self)) ?? self
    }

    // MARK: - Comparison
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }

    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }

    var isThisMonth: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }

    var isThisYear: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .year)
    }

    var isPast: Bool {
        self < Date()
    }

    var isFuture: Bool {
        self > Date()
    }

    // MARK: - Date Arithmetic
    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    func adding(weeks: Int) -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: self) ?? self
    }

    func adding(months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }

    func adding(years: Int) -> Date {
        Calendar.current.date(byAdding: .year, value: years, to: self) ?? self
    }

    func adding(hours: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: hours, to: self) ?? self
    }

    func adding(minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: self) ?? self
    }

    // MARK: - Days Between
    func daysBetween(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startOfDay, to: date.startOfDay)
        return components.day ?? 0
    }

    // MARK: - Smart Display
    var smartDisplay: String {
        if isToday {
            return "Today, \(displayTime)"
        } else if isYesterday {
            return "Yesterday, \(displayTime)"
        } else if isTomorrow {
            return "Tomorrow, \(displayTime)"
        } else if isThisWeek {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, h:mm a"
            return formatter.string(from: self)
        } else if isThisYear {
            return chartDate + ", " + displayTime
        } else {
            return displayDateTime
        }
    }

    // MARK: - Trading Hours (simplified)
    var isMarketOpen: Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: self)
        guard let hour = components.hour, let weekday = components.weekday else { return false }

        // Weekday: 1 = Sunday, 7 = Saturday
        let isWeekday = weekday >= 2 && weekday <= 6

        // Market hours: 9:30 AM - 4:00 PM ET (simplified)
        let isMarketHours = hour >= 9 && hour < 16

        return isWeekday && isMarketHours
    }
}

// MARK: - Time Interval Extensions
extension TimeInterval {
    var seconds: Int {
        Int(self) % 60
    }

    var minutes: Int {
        (Int(self) / 60) % 60
    }

    var hours: Int {
        Int(self) / 3600
    }

    var displayDuration: String {
        if self < 60 {
            return "\(Int(self))s"
        } else if self < 3600 {
            return "\(minutes)m"
        } else {
            return "\(hours)h \(minutes)m"
        }
    }
}
