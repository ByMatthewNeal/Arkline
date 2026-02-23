import Foundation

// MARK: - Allocation Engine

/// Combines positioning signal + macro regime fit into a target allocation percentage.
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
        regime: MacroRegimeResult
    ) -> AssetAllocation {
        let fit = regimeFitTable[assetId]?[regime.quadrant] ?? defaultFit
        let target = allocationTarget(signal: signal, fit: fit)

        return AssetAllocation(
            assetId: assetId,
            displayName: displayName,
            iconUrl: iconUrl,
            signal: signal,
            regimeFit: fit,
            targetAllocation: target
        )
    }

    /// Compute allocations for all assets at once.
    static func computeAll(
        signals: [(assetId: String, displayName: String, iconUrl: String?, signal: PositioningSignal)],
        regime: MacroRegimeResult
    ) -> AllocationSummary {
        let allocations = signals.map { item in
            computeAllocation(
                assetId: item.assetId,
                displayName: item.displayName,
                iconUrl: item.iconUrl,
                signal: item.signal,
                regime: regime
            )
        }

        return AllocationSummary(
            regime: regime,
            allocations: allocations,
            timestamp: Date()
        )
    }

    // MARK: - Allocation Matrix

    /// Signal × regime fit → target percentage.
    private static func allocationTarget(signal: PositioningSignal, fit: Double) -> Int {
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
            return 0
        }
    }
}
