import Foundation

// MARK: - Positioning Signal Calculator

/// Computes a positioning signal from technical analysis trend score and ITC risk level.
/// Pure computation — no network calls, no side effects.
enum PositioningSignalCalculator {

    /// Compute signal for a single asset.
    /// - Parameters:
    ///   - trendScore: 0-100 from `TechnicalAnalysis.trendScore`
    ///   - riskLevel: 0-1 from `ITCRiskLevel.riskLevel` (optional — nil treated as no cap)
    /// - Returns: `.bullish`, `.neutral`, or `.bearish`
    static func computeSignal(trendScore: Int, riskLevel: Double?) -> PositioningSignal {
        // Base signal from trend score
        let baseSignal: PositioningSignal
        if trendScore >= 70 {
            baseSignal = .bullish
        } else if trendScore >= 40 {
            baseSignal = .neutral
        } else {
            baseSignal = .bearish
        }

        // Risk cap: if risk is elevated (>0.75), clamp to at most neutral
        if let risk = riskLevel, risk > 0.75, baseSignal == .bullish {
            return .neutral
        }

        return baseSignal
    }
}
