import Foundation

// MARK: - Positioning Signal Calculator

/// Computes a positioning signal from technical analysis trend score, ITC risk level,
/// and 200 SMA position. Pure computation — no network calls, no side effects.
enum PositioningSignalCalculator {

    /// Compute signal for a single asset.
    /// - Parameters:
    ///   - trendScore: 0-100 from `TechnicalAnalysis.trendScore`
    ///   - riskLevel: 0-1 from `ITCRiskLevel.riskLevel` (optional — nil treated as no cap)
    ///   - isAbove200SMA: whether price is above the 200-day SMA (optional — nil = no gate)
    /// - Returns: `.bullish`, `.neutral`, or `.bearish`
    static func computeSignal(trendScore: Int, riskLevel: Double?, isAbove200SMA: Bool? = nil) -> PositioningSignal {
        // Base signal from trend score (tighter thresholds)
        let baseSignal: PositioningSignal
        if trendScore >= 75 {
            baseSignal = .bullish
        } else if trendScore >= 55 {
            baseSignal = .neutral
        } else {
            baseSignal = .bearish
        }

        // 200 SMA gate: if price is below the 200-day SMA, cap signal at neutral.
        // Being below the 200 SMA is the single most respected bear market indicator.
        if let above200 = isAbove200SMA, !above200, baseSignal == .bullish {
            return .neutral
        }

        // Risk cap: if risk is elevated (>0.7), clamp to at most neutral
        if let risk = riskLevel, risk > 0.7, baseSignal == .bullish {
            return .neutral
        }

        return baseSignal
    }
}
