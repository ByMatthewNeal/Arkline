import Foundation

// MARK: - Supply Profit DTO (for Supabase)
/// Database transfer object for storing supply in profit data
struct SupplyProfitDTO: Codable {
    let id: UUID
    let date: String           // "yyyy-MM-dd"
    let value: Double          // 0-100 percentage
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case value
        case createdAt = "created_at"
    }

    init(id: UUID = UUID(), date: String, value: Double, createdAt: Date? = nil) {
        self.id = id
        self.date = date
        self.value = value
        self.createdAt = createdAt
    }

    /// Convert from SupplyProfitData
    init(from data: SupplyProfitData) {
        self.id = UUID()
        self.date = data.date
        self.value = data.value
        self.createdAt = nil
    }

    /// Convert to SupplyProfitData
    func toSupplyProfitData() -> SupplyProfitData {
        SupplyProfitData(date: date, value: value)
    }
}

// MARK: - Supply Profit Signal
/// Signal based on Supply in Profit levels
enum SupplyProfitSignal: String, Codable {
    case buyZone = "buy_zone"
    case normal = "normal"
    case elevated = "elevated"
    case overheated = "overheated"

    var displayName: String {
        switch self {
        case .buyZone: return "Buy Zone"
        case .normal: return "Normal"
        case .elevated: return "Elevated"
        case .overheated: return "Overheated"
        }
    }
}

// MARK: - Supply Profit Data
/// Bitcoin Supply in Profit data with signal interpretation.
/// Shows the percentage of BTC supply that was last moved at a lower price than current.
struct SupplyProfitData: Codable, Identifiable {
    let date: String       // Format: "yyyy-MM-dd"
    let value: Double      // Percentage (0-100)

    var id: String { date }

    /// Converts date string to Date object
    var dateObject: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }

    /// Signal based on Supply in Profit levels:
    /// - Below 50%: Bottom zone (historically great buy opportunity)
    /// - 50-85%: Normal range
    /// - 85-97%: Elevated (late cycle)
    /// - Above 97%: Overheated (historically precedes corrections)
    var signal: SupplyProfitSignal {
        switch value {
        case ..<50:
            return .buyZone
        case 50..<85:
            return .normal
        case 85..<97:
            return .elevated
        default:
            return .overheated
        }
    }

    var signalDescription: String {
        signal.displayName
    }

    var formattedValue: String {
        String(format: "%.1f%%", value)
    }
}
