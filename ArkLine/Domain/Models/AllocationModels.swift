import Foundation
import SwiftUI

// MARK: - Positioning Signal

/// Asset-level signal derived from technical analysis trend score + ITC risk level
enum PositioningSignal: String, CaseIterable {
    case bullish = "Bullish"
    case neutral = "Neutral"
    case bearish = "Bearish"

    var color: Color {
        switch self {
        case .bullish: return AppColors.success
        case .neutral: return AppColors.warning
        case .bearish: return AppColors.error
        }
    }

    var icon: String {
        switch self {
        case .bullish: return "arrow.up.right.circle.fill"
        case .neutral: return "minus.circle.fill"
        case .bearish: return "arrow.down.right.circle.fill"
        }
    }

    var label: String { rawValue }
}

// MARK: - Macro Regime Quadrant

/// Four macro regime quadrants based on growth and inflation axes.
/// Named `MacroRegimeQuadrant` to avoid collision with existing `MarketRegime`.
enum MacroRegimeQuadrant: String, CaseIterable {
    case riskOnDisinflation = "Risk-On Disinflation"
    case riskOnInflation = "Risk-On Inflation"
    case riskOffInflation = "Risk-Off Inflation"
    case riskOffDisinflation = "Risk-Off Disinflation"

    var color: Color {
        switch self {
        case .riskOnDisinflation: return AppColors.success
        case .riskOnInflation: return AppColors.warning
        case .riskOffInflation: return AppColors.error
        case .riskOffDisinflation: return Color(hex: "3B82F6")
        }
    }

    var description: String {
        switch self {
        case .riskOnDisinflation:
            return "Economic growth with easing monetary conditions. Historically the best environment for crypto assets."
        case .riskOnInflation:
            return "Economic growth with rising prices. Crypto can still perform but gains may be capped by tightening expectations."
        case .riskOffInflation:
            return "Slowing growth with persistent inflation. The most challenging environment for risk assets including crypto."
        case .riskOffDisinflation:
            return "Slowing growth with easing conditions. Defensive positioning recommended until growth signals improve."
        }
    }

    /// Short label for the regime, used in the summary card
    var shortLabel: String {
        switch self {
        case .riskOnDisinflation: return "Favorable"
        case .riskOnInflation: return "Mixed"
        case .riskOffInflation: return "Unfavorable"
        case .riskOffDisinflation: return "Cautious"
        }
    }

    /// Crypto-specific positioning guidance for the AI daily briefing
    var cryptoPositioning: String {
        switch self {
        case .riskOnDisinflation:
            return "Full exposure — growth is strong and liquidity conditions are easing. Historically the best regime for crypto."
        case .riskOnInflation:
            return "Selective exposure — growth is solid but inflation may trigger tightening. Favor large-caps (BTC, ETH), trim alts."
        case .riskOffInflation:
            return "Defensive — growth is slowing while inflation persists. Reduce crypto exposure, favor stablecoins and cash."
        case .riskOffDisinflation:
            return "Cautious accumulation — growth is weak but easing conditions are building. Small DCA positions, watch for regime shift."
        }
    }
}

// MARK: - Macro Regime Result

/// Output of the macro regime calculator with quadrant and axis scores
struct MacroRegimeResult: Hashable {
    let quadrant: MacroRegimeQuadrant
    /// 0-100, higher = more risk-on
    let growthScore: Double
    /// 0-100, higher = more inflationary
    let inflationScore: Double
    let timestamp: Date

    /// Simple 3-state regime derived from the growth axis, used as the
    /// single source of truth for all widgets (Macro Dashboard, Daily Briefing).
    var baseRegime: MarketRegime {
        if growthScore >= 55 { return .riskOn }
        if growthScore <= 35 { return .riskOff }
        return .mixed
    }
}

// MARK: - Asset Allocation

/// Per-asset allocation recommendation combining signal, regime fit, risk level, and target %
struct AssetAllocation: Identifiable, Hashable {
    let assetId: String
    let displayName: String
    let iconUrl: String?
    let signal: PositioningSignal
    let regimeFit: Double
    let targetAllocation: Int // 0, 25, 50, or 100
    let riskLevel: Double? // 0-1 from ITC risk, nil if unavailable
    let isDCAOpportunity: Bool // true when bearish trend + low risk = accumulation window

    var id: String { assetId }

    /// Plain-English interpretation synthesizing trend, risk, and macro into one clear message
    var interpretation: String {
        // DCA opportunity: trend is weak but risk level says the asset has corrected enough
        if isDCAOpportunity {
            let riskLabel = riskLevel.map { String(format: "%.2f", $0) } ?? "low"
            return "Trend is weak but risk is low (\(riskLabel)). Small DCA positions may be favorable."
        }

        switch (signal, targetAllocation) {
        case (.bullish, 100):
            return "Strong trend in a favorable macro regime. Full position supported."
        case (.bullish, 50):
            return "Strong trend but macro fit is moderate. Half position appropriate."
        case (.bullish, 25):
            return "Strong trend but current regime limits upside. Small position only."
        case (.neutral, let pct) where pct > 0:
            if let risk = riskLevel, risk < 0.35 {
                return "Mixed trend with low risk (\(String(format: "%.2f", risk))). Partial position if thesis is strong."
            }
            return "Mixed signals. Partial position if your long-term thesis is strong."
        case (.bearish, _):
            if let risk = riskLevel, risk > 0.7 {
                return "Weak trend with elevated risk. Avoid new positions."
            }
            return "Trend doesn't support new positions right now."
        default:
            return "Conditions don't favor this position right now."
        }
    }
}

// MARK: - Allocation Summary

/// Complete output: macro regime + per-asset allocations
struct AllocationSummary: Hashable {
    let regime: MacroRegimeResult
    let allocations: [AssetAllocation]
    let timestamp: Date
}
