import Foundation
import SwiftUI

// MARK: - Macro Indicator Type

/// Types of macro indicators tracked for z-score analysis
enum MacroIndicatorType: String, CaseIterable, Codable, Identifiable {
    case vix = "VIX"
    case dxy = "DXY"
    case m2 = "M2"

    var id: String { rawValue }

    /// Display name for the indicator
    var displayName: String {
        switch self {
        case .vix: return "VIX"
        case .dxy: return "US Dollar"
        case .m2: return "M2 Supply"
        }
    }

    /// Full description of the indicator
    var fullName: String {
        switch self {
        case .vix: return "CBOE Volatility Index"
        case .dxy: return "US Dollar Index"
        case .m2: return "M2 Money Supply"
        }
    }

    /// How this indicator typically correlates with crypto
    var cryptoCorrelation: IndicatorCorrelation {
        switch self {
        case .vix: return .inverse  // High VIX = risk-off = bearish crypto
        case .dxy: return .inverse  // Strong dollar = headwind for crypto
        case .m2: return .positive  // More liquidity = bullish crypto
        }
    }

    /// Interpretation of a high z-score for this indicator
    func highZScoreInterpretation() -> String {
        switch self {
        case .vix:
            return "Elevated fear in equity markets - historically bearish for crypto in short term but can signal capitulation bottoms"
        case .dxy:
            return "Unusually strong dollar - creates headwind for risk assets including crypto"
        case .m2:
            return "Rapid liquidity expansion - historically bullish for crypto with 2-3 month lag"
        }
    }

    /// Interpretation of a low z-score for this indicator
    func lowZScoreInterpretation() -> String {
        switch self {
        case .vix:
            return "Complacency in equity markets - favorable for risk assets but watch for volatility expansion"
        case .dxy:
            return "Unusually weak dollar - historically bullish for crypto and risk assets"
        case .m2:
            return "Liquidity contraction - historically creates headwinds for crypto"
        }
    }

    /// Icon for the indicator
    var iconName: String {
        switch self {
        case .vix: return "waveform.path.ecg"
        case .dxy: return "dollarsign.circle"
        case .m2: return "banknote"
        }
    }
}

// MARK: - Indicator Correlation

/// How an indicator correlates with crypto prices
enum IndicatorCorrelation: String, Codable {
    case positive
    case inverse
    case neutral

    var description: String {
        switch self {
        case .positive: return "Positive correlation with crypto"
        case .inverse: return "Inverse correlation with crypto"
        case .neutral: return "Neutral correlation"
        }
    }
}

// MARK: - Macro Z-Score Data

/// Complete z-score analysis for a macro indicator
struct MacroZScoreData: Identifiable, Equatable {
    let id = UUID()
    let indicator: MacroIndicatorType
    let currentValue: Double
    let zScore: StatisticsCalculator.ZScoreResult
    let sdBands: StatisticsCalculator.SDBands
    let historyValues: [Double]
    let calculatedAt: Date

    /// Number of data points used in calculation
    var sampleSize: Int {
        historyValues.count
    }

    /// Whether current value is in an extreme zone
    var isExtreme: Bool {
        zScore.isExtreme
    }

    /// Whether current value is significant
    var isSignificant: Bool {
        zScore.isSignificant
    }

    /// Direction of the extreme (if any)
    var direction: ExtremeDirection? {
        guard isSignificant else { return nil }
        return zScore.zScore > 0 ? .high : .low
    }

    /// Color to use for displaying this z-score
    var displayColor: Color {
        // For inverse correlation indicators (VIX, DXY), high values are bearish
        // For positive correlation indicators (M2), high values are bullish
        let isHighBearish = indicator.cryptoCorrelation == .inverse

        if isExtreme {
            if zScore.zScore > 0 {
                return isHighBearish ? AppColors.error : AppColors.success
            } else {
                return isHighBearish ? AppColors.success : AppColors.error
            }
        } else if isSignificant {
            if zScore.zScore > 0 {
                return isHighBearish ? AppColors.warning : AppColors.info
            } else {
                return isHighBearish ? AppColors.info : AppColors.warning
            }
        } else {
            return AppColors.textSecondary
        }
    }

    /// Interpretation for the current reading
    var interpretation: String {
        if zScore.zScore > 2 {
            return indicator.highZScoreInterpretation()
        } else if zScore.zScore < -2 {
            return indicator.lowZScoreInterpretation()
        } else {
            return "\(indicator.displayName) is within normal historical range"
        }
    }

    /// Market implication based on z-score and correlation
    var marketImplication: MarketImplication {
        let isHighBearish = indicator.cryptoCorrelation == .inverse

        if isExtreme {
            if (zScore.zScore > 0 && isHighBearish) || (zScore.zScore < 0 && !isHighBearish) {
                return .bearish
            } else {
                return .bullish
            }
        } else if isSignificant {
            if (zScore.zScore > 0 && isHighBearish) || (zScore.zScore < 0 && !isHighBearish) {
                return .cautious
            } else {
                return .favorable
            }
        } else {
            return .neutral
        }
    }

    // Equatable conformance (ignoring id)
    static func == (lhs: MacroZScoreData, rhs: MacroZScoreData) -> Bool {
        lhs.indicator == rhs.indicator &&
        lhs.currentValue == rhs.currentValue &&
        lhs.zScore == rhs.zScore &&
        lhs.sdBands == rhs.sdBands
    }
}

// MARK: - Supporting Types

/// Direction of an extreme move
enum ExtremeDirection: String, Codable {
    case high
    case low

    var description: String {
        switch self {
        case .high: return "High"
        case .low: return "Low"
        }
    }
}

/// Market implication derived from z-score analysis
enum MarketImplication: String, Codable {
    case bullish
    case favorable
    case neutral
    case cautious
    case bearish

    var description: String {
        switch self {
        case .bullish: return "Bullish for crypto"
        case .favorable: return "Favorable conditions"
        case .neutral: return "Neutral conditions"
        case .cautious: return "Exercise caution"
        case .bearish: return "Bearish for crypto"
        }
    }

    var color: Color {
        switch self {
        case .bullish: return AppColors.success
        case .favorable: return AppColors.info
        case .neutral: return AppColors.textSecondary
        case .cautious: return AppColors.warning
        case .bearish: return AppColors.error
        }
    }

    var iconName: String {
        switch self {
        case .bullish: return "arrow.up.circle.fill"
        case .favorable: return "arrow.up.right.circle"
        case .neutral: return "minus.circle"
        case .cautious: return "exclamationmark.triangle"
        case .bearish: return "arrow.down.circle.fill"
        }
    }
}
