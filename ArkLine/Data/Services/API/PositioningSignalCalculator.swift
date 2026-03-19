import Foundation

// MARK: - Positioning Signal Calculator

/// Applies risk-based caps on top of a base positioning signal.
/// The base signal comes from the server-side QPS pipeline (SMA position framework).
/// Pure computation — no network calls, no side effects.
enum PositioningSignalCalculator {

    /// Apply risk cap to a QPS signal.
    /// - Parameters:
    ///   - baseSignal: The signal from the server-side QPS pipeline (bullish/neutral/bearish)
    ///   - riskLevel: 0-1 from `ITCRiskLevel.riskLevel` (optional — nil treated as no cap)
    /// - Returns: `.bullish`, `.neutral`, or `.bearish`
    static func applyRiskCap(baseSignal: PositioningSignal, riskLevel: Double?) -> PositioningSignal {
        // Risk cap: if risk is elevated (>0.7), clamp bullish to at most neutral
        if let risk = riskLevel, risk > 0.7, baseSignal == .bullish {
            return .neutral
        }
        return baseSignal
    }
}
