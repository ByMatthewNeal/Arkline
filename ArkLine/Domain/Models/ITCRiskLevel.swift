import Foundation

/// Risk level data from Into The Cryptoverse
struct ITCRiskLevel: Codable, Identifiable {
    let date: String
    let riskLevel: Double

    var id: String { date }

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
    }
}

/// Response wrapper for ITC risk level API
struct ITCRiskLevelResponse: Codable {
    let widget: String
    let history: [ITCRiskLevel]
}
