import Foundation

/// Risk level data from Into The Cryptoverse
struct ITCRiskLevel: Codable, Identifiable {
    let date: String
    let riskLevel: Double

    /// Optional price data (populated when calculated locally)
    var price: Double?
    var fairValue: Double?

    var id: String { date }

    // MARK: - Initializers

    init(date: String, riskLevel: Double, price: Double? = nil, fairValue: Double? = nil) {
        self.date = date
        self.riskLevel = riskLevel
        self.price = price
        self.fairValue = fairValue
    }

    /// Risk category based on risk level value (0.0 - 1.0) using 6-tier ITC system
    var riskCategory: String {
        switch riskLevel {
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

    /// Risk level as percentage (0-100)
    var riskPercentage: Double {
        riskLevel * 100
    }

    enum CodingKeys: String, CodingKey {
        case date
        case riskLevel = "risk_level"
        case price
        case fairValue = "fair_value"
    }
}

// MARK: - Conversion from RiskHistoryPoint
extension ITCRiskLevel {
    /// Create from enhanced RiskHistoryPoint
    init(from point: RiskHistoryPoint) {
        self.init(
            date: point.dateString,
            riskLevel: point.riskLevel,
            price: point.price,
            fairValue: point.fairValue
        )
    }
}

/// Response wrapper for ITC risk level API
struct ITCRiskLevelResponse: Codable {
    let widget: String
    let history: [ITCRiskLevel]
}
