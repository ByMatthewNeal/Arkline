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
}

// MARK: - Asset Allocation

/// Per-asset allocation recommendation combining signal, regime fit, and target %
struct AssetAllocation: Identifiable, Hashable {
    let assetId: String
    let displayName: String
    let iconUrl: String?
    let signal: PositioningSignal
    let regimeFit: Double
    let targetAllocation: Int // 0, 25, 50, or 100

    var id: String { assetId }

    /// Plain-English interpretation of what this allocation means for the user
    var interpretation: String {
        switch targetAllocation {
        case 100:
            return "Strong trend in a favorable regime. Full position supported."
        case 50:
            return regimeFit >= 0.7
                ? "Trend is neutral but regime is favorable. Consider a half position."
                : "Trend is strong but regime fit is moderate. Consider a half position."
        case 25:
            return "Weak regime fit limits upside. A small position may be appropriate."
        default:
            return signal == .bearish
                ? "Trend is negative. Consider staying on the sidelines."
                : "Low regime fit and weak signals. No position recommended."
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
