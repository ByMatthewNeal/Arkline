import Foundation

// MARK: - Risk History Point
/// Enhanced data model for risk level with additional context.
/// Includes price, fair value, and deviation information.
struct RiskHistoryPoint: Identifiable, Codable {
    /// Unique identifier (date-based)
    var id: String { dateString }

    /// Date string in ISO format (yyyy-MM-dd)
    let dateString: String

    /// Actual date
    let date: Date

    /// Risk level (0.0 - 1.0)
    let riskLevel: Double

    /// Actual price at this point
    let price: Double

    /// Calculated fair value from regression
    let fairValue: Double

    /// Log deviation from fair value
    let deviation: Double

    // MARK: - Computed Properties

    /// Risk category based on risk level
    var riskCategory: String {
        RiskHistoryPoint.category(for: riskLevel)
    }

    /// Whether the asset is overvalued
    var isOvervalued: Bool {
        deviation > 0
    }

    /// Percentage deviation from fair value
    var deviationPercentage: Double {
        guard fairValue > 0 else { return 0 }
        return ((price - fairValue) / fairValue) * 100
    }

    // MARK: - Category Helpers

    static func category(for level: Double) -> String {
        switch level {
        case 0..<0.20:
            return "Very Low Risk"
        case 0.20..<0.40:
            return "Low Risk"
        case 0.40..<0.55:
            return "Neutral"
        case 0.55..<0.70:
            return "Elevated Risk"
        case 0.70..<0.90:
            return "High Risk"
        default:
            return "Extreme Risk"
        }
    }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case dateString = "date"
        case riskLevel = "risk_level"
        case price
        case fairValue = "fair_value"
        case deviation
    }

    // MARK: - Custom Decoding

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dateString = try container.decode(String.self, forKey: .dateString)
        riskLevel = try container.decode(Double.self, forKey: .riskLevel)
        price = try container.decode(Double.self, forKey: .price)
        fairValue = try container.decode(Double.self, forKey: .fairValue)
        deviation = try container.decode(Double.self, forKey: .deviation)

        // Parse date from string
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        date = formatter.date(from: dateString) ?? Date()
    }

    // MARK: - Initializers

    init(dateString: String, date: Date, riskLevel: Double, price: Double, fairValue: Double, deviation: Double) {
        self.dateString = dateString
        self.date = date
        self.riskLevel = riskLevel
        self.price = price
        self.fairValue = fairValue
        self.deviation = deviation
    }

    init(date: Date, riskLevel: Double, price: Double, fairValue: Double, deviation: Double) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.dateString = formatter.string(from: date)
        self.date = date
        self.riskLevel = riskLevel
        self.price = price
        self.fairValue = fairValue
        self.deviation = deviation
    }
}

// MARK: - Conversion from ITCRiskLevel

extension RiskHistoryPoint {
    /// Convert from legacy ITCRiskLevel (for backwards compatibility)
    init(from itcRiskLevel: ITCRiskLevel, price: Double = 0, fairValue: Double = 0) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let parsedDate = formatter.date(from: itcRiskLevel.date) ?? Date()

        self.init(
            dateString: itcRiskLevel.date,
            date: parsedDate,
            riskLevel: itcRiskLevel.riskLevel,
            price: price,
            fairValue: fairValue,
            deviation: 0
        )
    }
}

