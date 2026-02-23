import Foundation

// MARK: - Allocation Engine

/// Combines positioning signal + macro regime fit + risk level into a target allocation percentage.
/// Risk level is a first-class input — low risk during bearish trends creates DCA opportunities
/// rather than a flat 0% that contradicts the risk section of the app.
/// Pure computation — no network calls, no side effects.
enum AllocationEngine {

    // MARK: - Regime Fit Table

    /// How well each asset performs in each macro regime quadrant (0.0 – 1.0).
    private static let regimeFitTable: [String: [MacroRegimeQuadrant: Double]] = [
        "BTC":    [.riskOnDisinflation: 1.0, .riskOnInflation: 0.8, .riskOffInflation: 0.3, .riskOffDisinflation: 0.5],
        "ETH":    [.riskOnDisinflation: 1.0, .riskOnInflation: 0.7, .riskOffInflation: 0.2, .riskOffDisinflation: 0.4],
        "SOL":    [.riskOnDisinflation: 1.0, .riskOnInflation: 0.6, .riskOffInflation: 0.1, .riskOffDisinflation: 0.3],
        "BNB":    [.riskOnDisinflation: 0.9, .riskOnInflation: 0.7, .riskOffInflation: 0.2, .riskOffDisinflation: 0.4],
        "UNI":    [.riskOnDisinflation: 1.0, .riskOnInflation: 0.5, .riskOffInflation: 0.1, .riskOffDisinflation: 0.2],
        "RENDER": [.riskOnDisinflation: 1.0, .riskOnInflation: 0.5, .riskOffInflation: 0.1, .riskOffDisinflation: 0.2],
        "SUI":    [.riskOnDisinflation: 1.0, .riskOnInflation: 0.5, .riskOffInflation: 0.1, .riskOffDisinflation: 0.2],
        "ONDO":   [.riskOnDisinflation: 0.8, .riskOnInflation: 0.6, .riskOffInflation: 0.3, .riskOffDisinflation: 0.3],
    ]

    /// Default fit for unlisted assets
    private static let defaultFit: Double = 0.5

    // MARK: - Public API

    /// Compute allocation for a single asset.
    static func computeAllocation(
        assetId: String,
        displayName: String,
        iconUrl: String?,
        signal: PositioningSignal,
        regime: MacroRegimeResult,
        riskLevel: Double?
    ) -> AssetAllocation {
        let fit = regimeFitTable[assetId]?[regime.quadrant] ?? defaultFit
        let isDCA = isDCAOpportunity(signal: signal, riskLevel: riskLevel)
        let target = allocationTarget(signal: signal, fit: fit, isDCAOpportunity: isDCA)

        return AssetAllocation(
            assetId: assetId,
            displayName: displayName,
            iconUrl: iconUrl,
            signal: signal,
            regimeFit: fit,
            targetAllocation: target,
            riskLevel: riskLevel,
            isDCAOpportunity: isDCA
        )
    }

    /// Compute allocations for all assets at once.
    static func computeAll(
        signals: [(assetId: String, displayName: String, iconUrl: String?, signal: PositioningSignal, riskLevel: Double?)],
        regime: MacroRegimeResult
    ) -> AllocationSummary {
        let allocations = signals.map { item in
            computeAllocation(
                assetId: item.assetId,
                displayName: item.displayName,
                iconUrl: item.iconUrl,
                signal: item.signal,
                regime: regime,
                riskLevel: item.riskLevel
            )
        }

        return AllocationSummary(
            regime: regime,
            allocations: allocations,
            timestamp: Date()
        )
    }

    // MARK: - DCA Opportunity Detection

    /// A bearish trend with low risk is NOT the same as a bearish trend with high risk.
    /// Low risk means the asset has already corrected and stabilized — a potential DCA entry.
    /// High risk means it's still falling — a falling knife.
    private static func isDCAOpportunity(signal: PositioningSignal, riskLevel: Double?) -> Bool {
        guard signal == .bearish, let risk = riskLevel else { return false }
        return risk < 0.35
    }

    // MARK: - Allocation Matrix

    /// Signal × regime fit × DCA opportunity → target percentage.
    private static func allocationTarget(signal: PositioningSignal, fit: Double, isDCAOpportunity: Bool) -> Int {
        switch signal {
        case .bullish:
            if fit >= 0.7 { return 100 }
            if fit >= 0.4 { return 50 }
            return 25
        case .neutral:
            if fit >= 0.7 { return 50 }
            if fit >= 0.4 { return 25 }
            return 0
        case .bearish:
            // DCA opportunity: trend is bearish but risk is low — the asset has corrected.
            // Allow a small 25% position for DCA accumulation.
            if isDCAOpportunity { return 25 }
            return 0
        }
    }
}
