import Foundation
import SwiftUI

// MARK: - Allocation Target

struct AllocationTarget: Identifiable {
    let id = UUID()
    let assetClass: String
    let rangeLow: Int
    let rangeHigh: Int
    let icon: String
    let color: Color
}

// MARK: - Rotation Signal

/// Daily crypto vs equities rotation score with regime classification.
struct RotationSignal: Codable, Identifiable {
    let id: UUID
    let signalDate: String
    let rotationScore: Int
    let regime: RotationRegime
    let narrative: String?
    let btc7dReturn: Double?
    let spy7dReturn: Double?
    let btc30dReturn: Double?
    let spy30dReturn: Double?
    let btc90dReturn: Double?
    let spy90dReturn: Double?
    let btcYtdReturn: Double?
    let spyYtdReturn: Double?
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
        case btc7dReturn = "btc_7d_return"
        case spy7dReturn = "spy_7d_return"
        case btc30dReturn = "btc_30d_return"
        case spy30dReturn = "spy_30d_return"
        case btc90dReturn = "btc_90d_return"
        case spy90dReturn = "spy_90d_return"
        case btcYtdReturn = "btc_ytd_return"
        case spyYtdReturn = "spy_ytd_return"
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

// MARK: - Rotation Timeframe

enum RotationTimeframe: String, CaseIterable, Identifiable {
    case sevenDay = "7D"
    case thirtyDay = "30D"
    case ninetyDay = "90D"
    case ytd = "YTD"

    var id: String { rawValue }
}

extension RotationSignal {
    func btcReturn(for timeframe: RotationTimeframe) -> Double? {
        switch timeframe {
        case .sevenDay: return btc7dReturn
        case .thirtyDay: return btc30dReturn
        case .ninetyDay: return btc90dReturn
        case .ytd: return btcYtdReturn
        }
    }

    func spyReturn(for timeframe: RotationTimeframe) -> Double? {
        switch timeframe {
        case .sevenDay: return spy7dReturn
        case .thirtyDay: return spy30dReturn
        case .ninetyDay: return spy90dReturn
        case .ytd: return spyYtdReturn
        }
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
        case .cryptoFavored: return "Favor Crypto"
        case .equityFavored: return "Favor Equities"
        case .neutral: return "Neutral"
        case .riskOff: return "Risk Off"
        }
    }

    var actionLabel: String {
        switch self {
        case .cryptoFavored: return "Overweight Crypto"
        case .equityFavored: return "Overweight Equities"
        case .neutral: return "Balanced Allocation"
        case .riskOff: return "Reduce Risk"
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

// MARK: - Rotation Action Guidance

extension RotationSignal {
    /// Actionable guidance bullets based on current regime and inputs
    var actionBullets: [String] {
        switch regime {
        case .equityFavored:
            var bullets = ["Equities outperforming — consider overweighting stocks vs crypto"]
            if let spy = spy30dReturn, spy > 5 {
                bullets.append("SPY momentum is strong. Look at leading sectors for targeted exposure")
            }
            if let btc = btc30dReturn, btc < 0 {
                bullets.append("Crypto is pulling back — trim or hold, don't add until momentum returns")
            } else {
                bullets.append("Crypto still positive but lagging — reduce relative allocation")
            }
            return bullets

        case .cryptoFavored:
            var bullets = ["Crypto leading — consider overweighting BTC and high-conviction alts"]
            if let btc = btc30dReturn, btc > 10 {
                bullets.append("BTC momentum is strong. Watch for altcoin rotation as dominance shifts")
            }
            bullets.append("Equities may underperform near-term — reduce equity overweight")
            return bullets

        case .neutral:
            var bullets = ["Neither asset class has clear leadership — maintain balanced allocation"]
            if let btc30 = btc30dReturn, let spy30 = spy30dReturn {
                let delta = spy30 - btc30
                if delta > 5 {
                    bullets.append("Equities slightly leading — lean equities if momentum continues")
                } else if delta < -5 {
                    bullets.append("Crypto slightly leading — lean crypto if momentum continues")
                } else {
                    bullets.append("Performance is converging — wait for a clearer signal before rotating")
                }
            }
            bullets.append("Focus on sector selection within equities and quality within crypto")
            return bullets

        case .riskOff:
            return [
                "Elevated volatility — reduce exposure across both crypto and equities",
                "Defensive sectors (utilities, staples, healthcare) outperforming growth",
                "Preserve capital. Raise cash or add hedges until VIX subsides"
            ]
        }
    }

    /// Suggested allocation ranges based on regime and score magnitude.
    /// Respects durable asset floors: Crypto never below 10% (BTC floor), Gold never below 5% (PAXG floor).
    var allocationTargets: [AllocationTarget] {
        // Score magnitude (0-100) determines where within the range to lean
        // Higher magnitude = more conviction in the regime direction
        let magnitude = abs(rotationScore)

        let crypto: (Int, Int)
        let equities: (Int, Int)
        let gold: (Int, Int)
        let cash: (Int, Int)

        switch regime {
        case .cryptoFavored:
            // Strong crypto: scale up with conviction
            if magnitude >= 60 {
                crypto = (50, 60); equities = (15, 20); gold = (5, 10); cash = (10, 25)
            } else {
                crypto = (40, 50); equities = (20, 25); gold = (5, 10); cash = (15, 30)
            }

        case .equityFavored:
            if magnitude >= 60 {
                crypto = (10, 15); equities = (50, 60); gold = (5, 10); cash = (15, 25)
            } else {
                crypto = (15, 20); equities = (45, 55); gold = (5, 10); cash = (20, 30)
            }

        case .neutral:
            // Balanced — slight lean toward whichever is performing better
            if let btc30 = btc30dReturn, let spy30 = spy30dReturn, spy30 - btc30 > 5 {
                crypto = (20, 30); equities = (30, 40); gold = (5, 15); cash = (20, 35)
            } else if let btc30 = btc30dReturn, let spy30 = spy30dReturn, btc30 - spy30 > 5 {
                crypto = (30, 40); equities = (20, 30); gold = (5, 15); cash = (20, 35)
            } else {
                crypto = (25, 35); equities = (25, 35); gold = (5, 15); cash = (20, 40)
            }

        case .riskOff:
            crypto = (10, 15); equities = (10, 15); gold = (10, 15); cash = (60, 70)
        }

        return [
            AllocationTarget(assetClass: "Crypto", rangeLow: crypto.0, rangeHigh: crypto.1, icon: "bitcoinsign.circle.fill", color: .orange),
            AllocationTarget(assetClass: "Equities", rangeLow: equities.0, rangeHigh: equities.1, icon: "chart.line.uptrend.xyaxis", color: .blue),
            AllocationTarget(assetClass: "Gold", rangeLow: gold.0, rangeHigh: gold.1, icon: "circle.fill", color: Color(hex: "FFD700")),
            AllocationTarget(assetClass: "Cash", rangeLow: cash.0, rangeHigh: cash.1, icon: "banknote.fill", color: .green),
        ]
    }
}
