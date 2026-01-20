import Foundation

// MARK: - Economic Event
struct EconomicEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let country: String
    let date: Date
    let time: Date?
    let impact: EventImpact
    let forecast: String?
    let previous: String?
    let actual: String?
    let currency: String?
    let description: String?

    var isHighImpact: Bool {
        impact == .high
    }

    var isPast: Bool {
        date < Date()
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var dateFormatted: String {
        date.displayDate
    }

    var timeFormatted: String? {
        time?.displayTime
    }
}

// MARK: - Event Impact Level
enum EventImpact: String, Codable, CaseIterable {
    case low
    case medium
    case high

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .low: return "circle.fill"
        case .medium: return "circle.fill"
        case .high: return "exclamationmark.circle.fill"
        }
    }
}

// MARK: - Fed Watch Data
struct FedWatchData: Codable, Equatable {
    let meetingDate: Date
    let currentRate: Double
    let probabilities: [RateProbability]
    let lastUpdated: Date

    var nextMeetingFormatted: String {
        meetingDate.displayDate
    }

    var currentRateFormatted: String {
        "\(currentRate)%"
    }

    var mostLikelyOutcome: RateProbability? {
        probabilities.max(by: { $0.probability < $1.probability })
    }
}

struct RateProbability: Codable, Identifiable, Equatable {
    var id: String { "\(targetRate)" }
    let targetRate: Double
    let change: Int // basis points change from current
    let probability: Double

    var targetRateFormatted: String {
        "\(targetRate)%"
    }

    var changeFormatted: String {
        if change > 0 { return "+\(change) bps" }
        if change < 0 { return "\(change) bps" }
        return "No Change"
    }

    var probabilityFormatted: String {
        "\(Int(probability * 100))%"
    }
}

// MARK: - Economic Calendar Response (from API)
struct EconomicCalendarResponse: Codable {
    let events: [EconomicEventDTO]
}

struct EconomicEventDTO: Codable {
    let title: String
    let country: String
    let date: String
    let time: String?
    let impact: String
    let forecast: String?
    let previous: String?
    let actual: String?
    let currency: String?

    func toEconomicEvent() -> EconomicEvent? {
        let dateFormatter = ISO8601DateFormatter()
        guard let eventDate = dateFormatter.date(from: date) else { return nil }

        var eventTime: Date? = nil
        if let timeStr = time {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            eventTime = timeFormatter.date(from: timeStr)
        }

        let eventImpact = EventImpact(rawValue: impact.lowercased()) ?? .low

        return EconomicEvent(
            id: UUID(),
            title: title,
            country: country,
            date: eventDate,
            time: eventTime,
            impact: eventImpact,
            forecast: forecast,
            previous: previous,
            actual: actual,
            currency: currency,
            description: nil
        )
    }
}

// MARK: - Interest Rate History
struct InterestRateHistory: Codable, Identifiable {
    var id: Date { date }
    let date: Date
    let rate: Double
    let change: Double

    var rateFormatted: String {
        "\(rate)%"
    }

    var changeFormatted: String {
        if change > 0 { return "+\(change)%" }
        if change < 0 { return "\(change)%" }
        return "0%"
    }
}

// MARK: - Upcoming Meeting
struct FedMeeting: Codable, Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let type: MeetingType
    let hasProjections: Bool

    var dateFormatted: String {
        date.displayDate
    }

    var daysUntil: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
    }
}

enum MeetingType: String, Codable {
    case fomc = "FOMC"
    case minutes = "Minutes"
    case speech = "Speech"

    var displayName: String {
        rawValue
    }
}
