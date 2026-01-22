import Foundation

/// Risk level data from Into The Cryptoverse
struct ITCRiskLevel: Codable, Identifiable {
    let date: String
    let riskLevel: Double

    var id: String { date }

    /// Risk category based on risk level value (0.0 - 1.0)
    var riskCategory: String {
        if riskLevel < 0.3 { return "Low" }
        else if riskLevel < 0.7 { return "Medium" }
        else { return "High" }
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
