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

    var icon: String {
        switch self {
        case .riskOnDisinflation: return "sun.max.fill"
        case .riskOnInflation: return "flame.fill"
        case .riskOffInflation: return "exclamationmark.triangle.fill"
        case .riskOffDisinflation: return "snowflake"
        }
    }

    var description: String {
        switch self {
        case .riskOnDisinflation:
            return "Growth with easing conditions — ideal for crypto"
        case .riskOnInflation:
            return "Growth with rising prices — mixed for crypto"
        case .riskOffInflation:
            return "Slowing growth with inflation — hostile for crypto"
        case .riskOffDisinflation:
            return "Slowing growth, easing conditions — defensive positioning"
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
}

// MARK: - Allocation Summary

/// Complete output: macro regime + per-asset allocations
struct AllocationSummary: Hashable {
    let regime: MacroRegimeResult
    let allocations: [AssetAllocation]
    let timestamp: Date
}
