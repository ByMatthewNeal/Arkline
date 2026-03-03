import SwiftUI

// MARK: - Global Economy Index (GEI) Data

/// A single component of the GEI composite indicator.
struct GEIComponent: Identifiable {
    let id = UUID()
    let name: String
    let seriesId: String
    let currentValue: Double
    let zScore: Double
    let isInverted: Bool

    /// Z-score contribution (sign-flipped for inverted components)
    var contribution: Double {
        isInverted ? -zScore : zScore
    }

    /// Formatted current value for display
    var formattedValue: String {
        switch seriesId {
        case "HG=F":
            return currentValue.asCurrency
        case "^TNX":
            return String(format: "%.2f%%", currentValue)
        case "T10Y2Y":
            return String(format: "%.2f%%", currentValue)
        case "BAMLH0A0HYM2":
            return String(format: "%.2f%%", currentValue)
        case "ICSA":
            return String(format: "%.0fK", currentValue / 1000)
        case "UMCSENT":
            return String(format: "%.1f", currentValue)
        default:
            return String(format: "%.2f", currentValue)
        }
    }

    /// Formatted z-score for display
    var formattedZScore: String {
        String(format: "%+.2f\u{03C3}", contribution)
    }

    /// Color for the contribution direction
    var contributionColor: Color {
        if contribution > 0.5 { return Color(hex: "22C55E") }
        if contribution < -0.5 { return Color(hex: "EF4444") }
        return Color(hex: "EAB308")
    }
}

/// Composite GEI result combining all 6 leading indicators.
struct GEIData {
    /// The composite GEI score (equal-weighted mean of z-scores, typically -3 to +3)
    let score: Double

    /// Individual component breakdowns
    let components: [GEIComponent]

    /// Overall economic signal
    let signal: GEISignal

    /// When this data was computed
    let timestamp: Date

    /// Whether |score| > 1.5 (extreme reading — contrarian signal)
    var isExtreme: Bool {
        abs(score) > 1.5
    }

    /// Human-readable signal description for the card subtitle
    var signalDescription: String {
        if score > 0.25 { return "Bullish" }
        if score > -0.25 { return "Neutral" }
        return "Bearish"
    }

    /// Formatted score for display (e.g. "+0.42" or "-1.23")
    var formattedScore: String {
        String(format: "%+.2f", score)
    }

    /// Color based on score
    var scoreColor: Color {
        switch score {
        case _ where score > 1.5: return Color(hex: "22C55E")
        case _ where score > 0.5: return Color(hex: "84CC16")
        case _ where score > -0.5: return Color(hex: "EAB308")
        case _ where score > -1.5: return Color(hex: "F97316")
        default: return Color(hex: "EF4444")
        }
    }
}

/// Economic signal derived from the GEI score.
enum GEISignal: String, CaseIterable {
    case expansion = "Expansion"
    case neutral = "Neutral"
    case contraction = "Contraction"

    var label: String { rawValue }

    var icon: String {
        switch self {
        case .expansion: return "arrow.up.right"
        case .neutral: return "minus"
        case .contraction: return "arrow.down.right"
        }
    }

    var color: Color {
        switch self {
        case .expansion: return Color(hex: "22C55E")
        case .neutral: return Color(hex: "EAB308")
        case .contraction: return Color(hex: "EF4444")
        }
    }

    /// Derive signal from a GEI score
    static func from(score: Double) -> GEISignal {
        if score > 0.25 { return .expansion }
        if score < -0.25 { return .contraction }
        return .neutral
    }
}
