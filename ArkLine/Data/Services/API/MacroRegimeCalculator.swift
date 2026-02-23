import Foundation

// MARK: - Macro Regime Calculator

/// Computes the current macro regime quadrant from VIX, DXY, Global M2, and z-scores.
/// Pure computation — no network calls, no side effects.
enum MacroRegimeCalculator {

    /// Compute the macro regime from available market data.
    /// All inputs are optional — missing values default to midpoint (50).
    static func computeRegime(
        vixData: VIXData?,
        dxyData: DXYData?,
        globalM2Data: GlobalLiquidityChanges?,
        macroZScores: [MacroIndicatorType: MacroZScoreData]
    ) -> MacroRegimeResult {
        let growthScore = computeGrowthScore(vixData: vixData, macroZScores: macroZScores)
        let inflationScore = computeInflationScore(dxyData: dxyData, globalM2Data: globalM2Data, macroZScores: macroZScores)

        let quadrant: MacroRegimeQuadrant
        if growthScore >= 50 && inflationScore < 50 {
            quadrant = .riskOnDisinflation
        } else if growthScore >= 50 && inflationScore >= 50 {
            quadrant = .riskOnInflation
        } else if growthScore < 50 && inflationScore >= 50 {
            quadrant = .riskOffInflation
        } else {
            quadrant = .riskOffDisinflation
        }

        return MacroRegimeResult(
            quadrant: quadrant,
            growthScore: growthScore,
            inflationScore: inflationScore,
            timestamp: Date()
        )
    }

    // MARK: - Growth Axis

    /// 0-100, higher = more risk-on.
    /// Based on VIX level with z-score adjustment.
    private static func computeGrowthScore(
        vixData: VIXData?,
        macroZScores: [MacroIndicatorType: MacroZScoreData]
    ) -> Double {
        guard let vix = vixData?.value else { return 50 }

        // Base score from VIX level
        let baseScore: Double
        switch vix {
        case ..<15:    baseScore = 85
        case 15..<20:  baseScore = 65
        case 20..<25:  baseScore = 45
        case 25..<30:  baseScore = 25
        default:       baseScore = 10
        }

        // Z-score adjustment: extreme negative VIX z-score = calm = boost growth;
        // extreme positive = fear = reduce growth
        var adjustment: Double = 0
        if let vixZScore = macroZScores[.vix] {
            let z = vixZScore.zScore.zScore
            if z < -2.0 {
                adjustment = 10   // Extreme calm → boost
            } else if z < -1.0 {
                adjustment = 5
            } else if z > 2.0 {
                adjustment = -10  // Extreme fear → reduce
            } else if z > 1.0 {
                adjustment = -5
            }
        }

        return max(0, min(100, baseScore + adjustment))
    }

    // MARK: - Inflation Axis

    /// 0-100, higher = more inflationary.
    /// Weighted: DXY z-score (60%) + M2 monthly change (40%).
    private static func computeInflationScore(
        dxyData: DXYData?,
        globalM2Data: GlobalLiquidityChanges?,
        macroZScores: [MacroIndicatorType: MacroZScoreData]
    ) -> Double {
        // DXY component (60% weight):
        // Positive z-score (strong dollar) = disinflation (low score)
        // Negative z-score (weak dollar) = inflation (high score)
        let dxyComponent: Double
        if let dxyZScore = macroZScores[.dxy] {
            let z = dxyZScore.zScore.zScore
            // Map z-score [-3, +3] → [90, 10] (inverted: strong dollar = low inflation)
            dxyComponent = max(10, min(90, 50 - z * 13.3))
        } else {
            dxyComponent = 50
        }

        // M2 component (40% weight):
        // Higher monthly change = more inflationary
        let m2Component: Double
        if let m2 = globalM2Data {
            let change = m2.monthlyChange
            if change > 2.0 {
                m2Component = 80
            } else if change > 0.5 {
                m2Component = 60
            } else if change > -0.5 {
                m2Component = 50
            } else {
                m2Component = 30
            }
        } else {
            m2Component = 50
        }

        return dxyComponent * 0.6 + m2Component * 0.4
    }
}
