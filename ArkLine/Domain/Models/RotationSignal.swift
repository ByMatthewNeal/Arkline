import Foundation

// MARK: - Rotation Signal

/// Daily crypto vs equities rotation score with regime classification.
struct RotationSignal: Codable, Identifiable {
    let id: UUID
    let signalDate: String
    let rotationScore: Int
    let regime: RotationRegime
    let narrative: String?
    let btc30dReturn: Double?
    let spy30dReturn: Double?
    let btcRiskLevel: String?
    let spyRiskLevel: String?
    let fearGreedValue: Int?
    let fearGreedTrend: String?
    let dxyTrend: String?
    let dxyValue: Double?
    let vixLevel: Double?
    let btcDominance: Double?
    let btcDominanceTrend: String?

    enum CodingKeys: String, CodingKey {
        case id
        case signalDate = "signal_date"
        case rotationScore = "rotation_score"
        case regime, narrative
        case btc30dReturn = "btc_30d_return"
        case spy30dReturn = "spy_30d_return"
        case btcRiskLevel = "btc_risk_level"
        case spyRiskLevel = "spy_risk_level"
        case fearGreedValue = "fear_greed_value"
        case fearGreedTrend = "fear_greed_trend"
        case dxyTrend = "dxy_trend"
        case dxyValue = "dxy_value"
        case vixLevel = "vix_level"
        case btcDominance = "btc_dominance"
        case btcDominanceTrend = "btc_dominance_trend"
    }
}

// MARK: - Rotation Regime

enum RotationRegime: String, Codable {
    case cryptoFavored = "crypto_favored"
    case equityFavored = "equity_favored"
    case neutral
    case riskOff = "risk_off"

    var displayName: String {
        switch self {
        case .cryptoFavored: return "Crypto Favored"
        case .equityFavored: return "Equities Favored"
        case .neutral: return "Neutral"
        case .riskOff: return "Risk Off"
        }
    }

    var icon: String {
        switch self {
        case .cryptoFavored: return "bitcoinsign.circle.fill"
        case .equityFavored: return "chart.line.uptrend.xyaxis"
        case .neutral: return "equal.circle.fill"
        case .riskOff: return "exclamationmark.shield.fill"
        }
    }
}
