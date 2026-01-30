import Foundation

// MARK: - Risk Factor Data
/// Container for all fetched risk factor values.
struct RiskFactorData {
    /// RSI (14-period) value (0-100)
    let rsi: Double?

    /// 200-day SMA value
    let sma200: Double?

    /// Current price (for SMA comparison)
    let currentPrice: Double?

    /// Bull Market Support Bands (20W SMA and 21W EMA)
    let bullMarketBands: BullMarketSupportBands?

    /// Funding rate (decimal, e.g., 0.0001 = 0.01%)
    let fundingRate: Double?

    /// Fear & Greed Index (0-100)
    let fearGreedValue: Double?

    /// VIX value
    let vixValue: Double?

    /// DXY value
    let dxyValue: Double?

    /// Timestamp when data was fetched
    let fetchedAt: Date

    /// Check if at least some supplementary data is available
    var hasAnyData: Bool {
        rsi != nil || fundingRate != nil || fearGreedValue != nil ||
        vixValue != nil || dxyValue != nil || sma200 != nil || bullMarketBands != nil
    }

    /// Number of available data points
    var availableCount: Int {
        var count = [rsi, sma200, fundingRate, fearGreedValue, vixValue, dxyValue]
            .compactMap { $0 }
            .count
        if bullMarketBands != nil { count += 1 }
        return count
    }

    // MARK: - Empty

    static let empty = RiskFactorData(
        rsi: nil,
        sma200: nil,
        currentPrice: nil,
        bullMarketBands: nil,
        fundingRate: nil,
        fearGreedValue: nil,
        vixValue: nil,
        dxyValue: nil,
        fetchedAt: Date()
    )
}

// MARK: - Risk Factor Normalizer
/// Static normalization formulas for converting raw values to 0-1 risk scale.
enum RiskFactorNormalizer {

    // MARK: - RSI Normalization

    /// Normalize RSI to risk (0-1 where 1 = highest risk/overbought)
    /// - Parameter rsi: RSI value (0-100)
    /// - Returns: Normalized value where 0 = oversold (low risk), 1 = overbought (high risk)
    ///
    /// Calibration based on historical BTC data:
    /// - RSI ~30 at major bottoms (Dec 2018, Nov 2022)
    /// - RSI ~70-88 at major tops (Dec 2017, Nov 2021)
    /// - Linear mapping from RSI 30 → 0.0 to RSI 70 → 1.0
    static func normalizeRSI(_ rsi: Double) -> Double {
        // RSI 30 = 0.0 risk, RSI 70 = 1.0 risk
        // Formula: (rsi - 30) / 40, clamped to [0, 1]
        let normalized = (rsi - 30.0) / 40.0
        return max(0.0, min(1.0, normalized))
    }

    // MARK: - SMA Position Normalization

    /// Normalize price position relative to 200 SMA
    /// - Parameters:
    ///   - price: Current price
    ///   - sma200: 200-period SMA value
    /// - Returns: Risk value (0.3 if above SMA = bullish, 0.7 if below = bearish)
    ///
    /// Calibration:
    /// - Above 200 SMA historically indicates bull market (lower risk)
    /// - Below 200 SMA historically indicates bear market (higher risk)
    static func normalizeSMAPosition(price: Double, sma200: Double) -> Double {
        guard sma200 > 0 else { return 0.5 }

        // Calculate percentage distance from SMA
        let percentFromSMA = (price - sma200) / sma200

        // Simple binary with gradient:
        // - Far above SMA (>20%): 0.2 (very low risk)
        // - Slightly above: 0.3-0.4
        // - At SMA: 0.5
        // - Slightly below: 0.6-0.7
        // - Far below SMA (<-20%): 0.8 (high risk for further downside, but good value)

        if percentFromSMA > 0.20 {
            return 0.2
        } else if percentFromSMA > 0.10 {
            return 0.3
        } else if percentFromSMA > 0 {
            return 0.4
        } else if percentFromSMA > -0.10 {
            return 0.6
        } else if percentFromSMA > -0.20 {
            return 0.7
        } else {
            return 0.8
        }
    }

    // MARK: - Funding Rate Normalization

    /// Normalize funding rate to risk (0-1)
    /// - Parameter rate: Funding rate (decimal, e.g., 0.0001 = 0.01%)
    /// - Returns: Normalized risk where high positive funding = high risk
    ///
    /// Calibration:
    /// - Funding rate typically ranges from -0.001 to +0.001 (extreme)
    /// - Neutral around 0.0001 (0.01%)
    /// - High positive = overleveraged longs = higher risk
    /// - Negative = shorts paying longs = lower risk
    static func normalizeFundingRate(_ rate: Double) -> Double {
        // Map from [-0.001, +0.001] to [0, 1]
        // -0.001 = 0.0 (very low risk, shorts paying)
        // 0 = 0.5 (neutral)
        // +0.001 = 1.0 (very high risk, longs paying heavily)
        let normalized = (rate + 0.001) / 0.002
        return max(0.0, min(1.0, normalized))
    }

    // MARK: - Fear & Greed Normalization

    /// Normalize Fear & Greed Index to risk (0-1)
    /// - Parameter fearGreed: Fear & Greed value (0-100)
    /// - Returns: Normalized risk where 100 (extreme greed) = 1.0 (high risk)
    ///
    /// Direct mapping: F&G already on 0-100 scale where:
    /// - 0-25 = Extreme Fear (low risk to buy)
    /// - 75-100 = Extreme Greed (high risk)
    static func normalizeFearGreed(_ fearGreed: Double) -> Double {
        return max(0.0, min(1.0, fearGreed / 100.0))
    }

    // MARK: - VIX Normalization

    /// Normalize VIX to risk for crypto (0-1)
    /// - Parameter vix: VIX value
    /// - Returns: Normalized risk (INVERSE - high VIX = low crypto risk, flight to safety)
    ///
    /// Calibration:
    /// - VIX < 15: Low volatility (risk-on, could be complacent = moderate risk)
    /// - VIX 15-25: Normal
    /// - VIX > 30: High fear (often good time to buy crypto as hedge)
    ///
    /// For crypto specifically, high VIX can mean:
    /// - Short term: Risk-off selling (bad)
    /// - Medium term: Money flows to alternative assets (good)
    /// We use a moderate inverse relationship
    static func normalizeVIX(_ vix: Double) -> Double {
        // Map VIX 10-40 to risk
        // VIX 10 = 0.6 risk (complacency)
        // VIX 20 = 0.5 risk (normal)
        // VIX 40 = 0.3 risk (fear = opportunity)
        let normalized = (40.0 - vix) / 30.0
        // Clamp and shift to make it less extreme
        let adjusted = 0.3 + (normalized * 0.4)
        return max(0.0, min(1.0, adjusted))
    }

    // MARK: - DXY Normalization

    /// Normalize DXY to risk for crypto (0-1)
    /// - Parameter dxy: DXY value
    /// - Returns: Normalized risk where high DXY = higher risk for crypto
    ///
    /// Calibration:
    /// - DXY typically ranges 90-110
    /// - Strong dollar (high DXY) = bearish for crypto
    /// - Weak dollar (low DXY) = bullish for crypto
    static func normalizeDXY(_ dxy: Double) -> Double {
        // Map DXY 90-110 to [0, 1]
        // DXY 90 = 0.0 risk (weak dollar, bullish)
        // DXY 100 = 0.5 risk (neutral)
        // DXY 110 = 1.0 risk (strong dollar, bearish)
        let normalized = (dxy - 90.0) / 20.0
        return max(0.0, min(1.0, normalized))
    }

    // MARK: - Macro Risk (Combined VIX + DXY)

    /// Calculate combined macro risk from VIX and DXY
    /// - Parameters:
    ///   - vix: VIX value (optional)
    ///   - dxy: DXY value (optional)
    /// - Returns: Average of available macro indicators, nil if both unavailable
    static func normalizeMacroRisk(vix: Double?, dxy: Double?) -> Double? {
        let vixNormalized = vix.map { normalizeVIX($0) }
        let dxyNormalized = dxy.map { normalizeDXY($0) }

        switch (vixNormalized, dxyNormalized) {
        case let (.some(v), .some(d)):
            return (v + d) / 2.0
        case let (.some(v), .none):
            return v
        case let (.none, .some(d)):
            return d
        case (.none, .none):
            return nil
        }
    }

    // MARK: - Bull Market Support Bands Normalization

    /// Normalize Bull Market Support Bands position to risk (0-1)
    /// - Parameter bands: Bull Market Support Bands data
    /// - Returns: Normalized risk where below bands = higher risk
    ///
    /// Calibration:
    /// - Above both bands: 0.2 (healthy bull market, low risk)
    /// - In the band (between SMA and EMA): 0.5 (testing support)
    /// - Below both bands: 0.8 (bull market structure broken, high risk)
    /// - Additional gradient based on % distance from bands
    static func normalizeBullMarketBands(_ bands: BullMarketSupportBands) -> Double {
        let avgBand = (bands.sma20Week + bands.ema21Week) / 2.0
        let percentFromAvg = (bands.currentPrice - avgBand) / avgBand

        switch bands.position {
        case .aboveBoth:
            // Above both: low risk, gradient based on distance
            // Far above (>20%): 0.1, slightly above: 0.3
            if percentFromAvg > 0.20 {
                return 0.1
            } else if percentFromAvg > 0.10 {
                return 0.2
            } else {
                return 0.3
            }
        case .inBand:
            // Testing support: moderate risk
            return 0.5
        case .belowBoth:
            // Below both: higher risk, gradient based on distance
            // Slightly below: 0.7, far below (<-20%): 0.9
            if percentFromAvg < -0.20 {
                return 0.9
            } else if percentFromAvg < -0.10 {
                return 0.8
            } else {
                return 0.7
            }
        }
    }

    // MARK: - Weight Renormalization

    /// Renormalize weights when some factors are unavailable
    /// - Parameters:
    ///   - factors: Array of risk factors (some may be unavailable)
    ///   - originalWeights: Original weight configuration
    /// - Returns: Array of factors with adjusted weights that sum to 1.0
    static func renormalizeWeights(
        factors: [RiskFactor],
        originalWeights: RiskFactorWeights
    ) -> [RiskFactor] {
        let availableWeight = factors
            .filter { $0.isAvailable }
            .reduce(0.0) { $0 + $1.weight }

        guard availableWeight > 0 else { return factors }

        return factors.map { factor in
            guard factor.isAvailable else { return factor }
            let scaleFactor = 1.0 / availableWeight
            let newWeight = factor.weight * scaleFactor
            return RiskFactor(
                type: factor.type,
                rawValue: factor.rawValue,
                normalizedValue: factor.normalizedValue,
                weight: newWeight
            )
        }
    }
}
