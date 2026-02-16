import Foundation

// MARK: - Capital Rotation Service
/// Computes a capital rotation signal (0-100) from multi-dominance analysis.
///
/// Detects where money is flowing across the crypto market:
///   BTC ↔ Alts ↔ Stablecoins
///
/// Three sub-signals, weighted:
///   - USDT Dominance inverted (35%) — high USDT dom = risk-off sidelines
///   - BTC Dominance direction (35%) — falling BTC dom = capital rotating to alts
///   - Alt Market Share (30%) — higher alt share of total = more speculation
///
/// Score interpretation:
///   0-25: Risk Off — capital fleeing to stablecoins
///   25-50: BTC Accumulation — money entering via BTC
///   50-75: Alt Rotation — capital flowing from BTC to alts
///   75-100: Peak Speculation — max alt exposure, USDT at lows
enum CapitalRotationService {

    private static let snapshotKey = "capitalRotation_previousSnapshot"

    // MARK: - Sub-signal Weights

    private struct Weights {
        static let usdtDominance: Double = 0.35
        static let btcDirection: Double = 0.35
        static let altShare: Double = 0.30
    }

    // MARK: - Public API

    /// Computes the capital rotation signal from current and previous dominance snapshots.
    /// - Parameters:
    ///   - current: Latest dominance data from CoinGecko /global
    ///   - previous: Prior session's snapshot for rate-of-change (nil = first run)
    /// - Returns: CapitalRotationSignal with score, phase, and dominance data
    static func computeRotationSignal(
        current: DominanceSnapshot,
        previous: DominanceSnapshot?
    ) -> CapitalRotationSignal {

        // 1. USDT Dominance (inverted): high USDT dom = risk-off = low score
        // Typical range: 3-8%. Map to 0-100 inverted.
        let usdtScore = max(0, min(100, (8.0 - current.usdtDominance) / 5.0 * 100.0))

        // 2. BTC Dominance direction
        let btcScore: Double
        if let prev = previous {
            // Rate of change: falling BTC dom = capital rotating out = high score
            let delta = prev.btcDominance - current.btcDominance // positive = falling dom = good for alts
            // Typical daily delta: -2 to +2 percentage points
            // Map via sigmoid-like: delta of +2 → ~90, delta of 0 → 50, delta of -2 → ~10
            btcScore = max(0, min(100, 50.0 + delta * 25.0))
        } else {
            // No previous data — use level as fallback (40-70% range, inverted)
            btcScore = max(0, min(100, (70.0 - current.btcDominance) / 30.0 * 100.0))
        }

        // 3. Alt Market Share: higher alt share = more speculation
        // altMarketCap / totalMarketCap as percentage, typical range: 30-60%
        let altSharePct = current.totalMarketCap > 0
            ? (current.altMarketCap / current.totalMarketCap) * 100.0
            : 40.0
        // Map 30-60% to 0-100
        let altScore = max(0, min(100, (altSharePct - 30.0) / 30.0 * 100.0))

        // Weighted composite
        let score = usdtScore * Weights.usdtDominance
            + btcScore * Weights.btcDirection
            + altScore * Weights.altShare

        let clampedScore = max(0, min(100, score))

        return CapitalRotationSignal(
            score: clampedScore,
            phase: RotationPhase.from(score: clampedScore),
            dominance: current,
            timestamp: Date()
        )
    }

    // MARK: - Persistence

    /// Loads the previous dominance snapshot from UserDefaults.
    static func loadPreviousSnapshot() -> DominanceSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(DominanceSnapshot.self, from: data)
    }

    /// Saves the current dominance snapshot for next session's rate-of-change calculation.
    static func savePreviousSnapshot(_ snapshot: DominanceSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: snapshotKey)
        }
    }
}
