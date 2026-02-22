import Foundation

// MARK: - DCA Reminder Model
struct DCAReminder: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    var symbol: String
    var name: String
    var amount: Double
    var frequency: DCAFrequency
    var totalPurchases: Int?
    var completedPurchases: Int
    var notificationTime: Date
    var startDate: Date
    var nextReminderDate: Date?
    var isActive: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case symbol
        case name
        case amount
        case frequency
        case totalPurchases = "total_purchases"
        case completedPurchases = "completed_purchases"
        case notificationTime = "notification_time"
        case startDate = "start_date"
        case nextReminderDate = "next_reminder_date"
        case isActive = "is_active"
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        userId: UUID,
        symbol: String,
        name: String,
        amount: Double,
        frequency: DCAFrequency,
        totalPurchases: Int? = nil,
        completedPurchases: Int = 0,
        notificationTime: Date,
        startDate: Date = Date(),
        nextReminderDate: Date? = nil,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.symbol = symbol
        self.name = name
        self.amount = amount
        self.frequency = frequency
        self.totalPurchases = totalPurchases
        self.completedPurchases = completedPurchases
        self.notificationTime = notificationTime
        self.startDate = startDate
        self.nextReminderDate = nextReminderDate ?? Self.calculateNextReminder(from: startDate, frequency: frequency)
        self.isActive = isActive
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        symbol = try container.decode(String.self, forKey: .symbol)
        name = try container.decode(String.self, forKey: .name)
        amount = try container.decode(Double.self, forKey: .amount)
        frequency = try container.decode(DCAFrequency.self, forKey: .frequency)
        totalPurchases = try container.decodeIfPresent(Int.self, forKey: .totalPurchases)
        completedPurchases = try container.decode(Int.self, forKey: .completedPurchases)

        // notification_time comes as a bare "HH:mm:ss" string from PostgreSQL's time column
        if let timeString = try? container.decode(String.self, forKey: .notificationTime) {
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss"
            f.locale = Locale(identifier: "en_US_POSIX")
            notificationTime = f.date(from: timeString) ?? Date()
        } else {
            notificationTime = try container.decode(Date.self, forKey: .notificationTime)
        }

        startDate = try container.decode(Date.self, forKey: .startDate)
        nextReminderDate = try container.decodeIfPresent(Date.self, forKey: .nextReminderDate)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

// MARK: - DCA Frequency
enum DCAFrequency: String, Codable, CaseIterable {
    case daily
    case twiceWeekly = "twice_weekly"
    case weekly
    case biweekly
    case monthly

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .twiceWeekly: return "Twice Weekly"
        case .weekly: return "Weekly"
        case .biweekly: return "Bi-weekly"
        case .monthly: return "Monthly"
        }
    }

    var daysInterval: Int {
        switch self {
        case .daily: return 1
        case .twiceWeekly: return 3 // approximately
        case .weekly: return 7
        case .biweekly: return 14
        case .monthly: return 30
        }
    }
}

// MARK: - DCA Reminder Extensions
extension DCAReminder {
    var formattedAmount: String {
        amount.asCurrency
    }

    var progress: Double {
        guard let total = totalPurchases, total > 0 else { return 0 }
        return Double(completedPurchases) / Double(total)
    }

    var progressText: String {
        if let total = totalPurchases {
            return "\(completedPurchases)/\(total)"
        }
        return "\(completedPurchases) purchases"
    }

    var totalInvested: Double {
        Double(completedPurchases) * amount
    }

    var totalInvestedFormatted: String {
        totalInvested.asCurrency
    }

    var isCompleted: Bool {
        guard let total = totalPurchases else { return false }
        return completedPurchases >= total
    }

    var isDueToday: Bool {
        guard let nextReminder = nextReminderDate else { return false }
        return Calendar.current.isDateInToday(nextReminder)
    }

    var nextReminderFormatted: String {
        guard let date = nextReminderDate else { return "Not scheduled" }
        if date.isToday {
            return "Today at \(date.displayTime)"
        } else if date.isTomorrow {
            return "Tomorrow at \(date.displayTime)"
        }
        return date.smartDisplay
    }

    static func calculateNextReminder(from date: Date, frequency: DCAFrequency) -> Date {
        Calendar.current.date(byAdding: .day, value: frequency.daysInterval, to: date) ?? date
    }

    func calculateNextReminder() -> Date {
        guard let current = nextReminderDate else { return startDate }
        return Self.calculateNextReminder(from: current, frequency: frequency)
    }
}

// MARK: - DCA Investment Record
struct DCAInvestment: Codable, Identifiable {
    let id: UUID
    let reminderId: UUID
    let amount: Double
    let priceAtPurchase: Double
    let quantity: Double
    let purchaseDate: Date

    enum CodingKeys: String, CodingKey {
        case id
        case reminderId = "reminder_id"
        case amount
        case priceAtPurchase = "price_at_purchase"
        case quantity
        case purchaseDate = "purchase_date"
    }

    var formattedAmount: String {
        amount.asCurrency
    }

    var formattedPrice: String {
        priceAtPurchase.asCryptoPrice
    }

    var formattedQuantity: String {
        quantity.asQuantity
    }
}

// MARK: - Create DCA Reminder Request
struct CreateDCARequest: Encodable {
    let userId: UUID
    let symbol: String
    let name: String
    let amount: Double
    let frequency: String
    let totalPurchases: Int?
    let notificationTime: String // PostgreSQL "time" column expects "HH:mm:ss"
    let startDate: Date
    let nextReminderDate: Date

    /// Format a Date as a time-only string for PostgreSQL's `time` column.
    static func timeString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case symbol
        case name
        case amount
        case frequency
        case totalPurchases = "total_purchases"
        case notificationTime = "notification_time"
        case startDate = "start_date"
        case nextReminderDate = "next_reminder_date"
    }
}
