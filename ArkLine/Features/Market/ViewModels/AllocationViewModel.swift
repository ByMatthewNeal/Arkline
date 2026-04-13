import Foundation

// MARK: - Allocation View Model

/// Orchestrates macro regime + positioning signals + allocation engine to produce AllocationSummary.
/// Signals now come from the server-side QPS pipeline (Daily Positioning), unified across the app.
/// Risk caps and DCA detection are still applied on top of QPS signals.
@MainActor
@Observable
class AllocationViewModel {
    // MARK: - Dependencies
    private let sentimentViewModel: SentimentViewModel
    private let positioningService = PositioningSignalService()

    // MARK: - State
    var allocationSummary: AllocationSummary?
    var isLoading = false
    var errorMessage: String?

    // MARK: - Init

    init(sentimentViewModel: SentimentViewModel) {
        self.sentimentViewModel = sentimentViewModel
    }

    // MARK: - Load

    func loadAllocations() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let configs = AssetRiskConfig.allConfigs

        // 1. Compute regime from macro data (instant, no network)
        let regime = MacroRegimeCalculator.computeRegime(
            vixData: sentimentViewModel.vixData,
            dxyData: sentimentViewModel.dxyData,
            globalM2Data: sentimentViewModel.globalM2Data,
            crudeOilData: sentimentViewModel.crudeOilData,
            macroZScores: sentimentViewModel.macroZScores
        )

        // 2. Fetch QPS signals from Supabase (single fast query, 1-hour cache)
        var qpsSignals: [DailyPositioningSignal] = []
        do {
            qpsSignals = try await positioningService.fetchLatestSignals()
        } catch {
            logWarning("QPS fetch failed for allocation: \(error)", category: .network)
        }

        // Index QPS signals by ticker for fast lookup
        let qpsByTicker = Dictionary(uniqueKeysWithValues: qpsSignals.map { ($0.asset, $0) })

        // 3. Build signals for each asset — QPS base signal + risk cap
        var signals: [(assetId: String, displayName: String, iconUrl: String?, signal: PositioningSignal, riskLevel: Double?)] = []

        for config in configs {
            let riskLevel = sentimentViewModel.riskLevels[config.assetId]?.riskLevel
            let signal: PositioningSignal

            if let qps = qpsByTicker[config.assetId] {
                // Use QPS signal as base, apply risk cap on top
                signal = PositioningSignalCalculator.applyRiskCap(
                    baseSignal: qps.positioningSignal,
                    riskLevel: riskLevel
                )
            } else {
                // Conservative fallback: default to bearish when QPS data unavailable
                signal = .bearish
            }

            let iconUrl = config.logoURL?.absoluteString
                ?? "https://assets.coingecko.com/coins/images/\(coinGeckoImageId(for: config.geckoId))"
            signals.append((
                assetId: config.assetId,
                displayName: config.displayName,
                iconUrl: iconUrl,
                signal: signal,
                riskLevel: riskLevel
            ))
        }

        // 4. Compute allocations and publish
        allocationSummary = AllocationEngine.computeAll(signals: signals, regime: regime)
    }

    /// Refresh — clears QPS cache so fresh data is fetched
    func refresh() async {
        do {
            _ = try await positioningService.fetchLatestSignals(forceRefresh: true)
        } catch {
            logWarning("QPS refresh failed: \(error)", category: .network)
        }
        await loadAllocations()
    }

    // MARK: - Icon URL

    /// Map geckoId to CoinGecko image path segment.
    private func coinGeckoImageId(for geckoId: String) -> String {
        let mapping: [String: String] = [
            "bitcoin": "1/large/bitcoin.png",
            "ethereum": "279/large/ethereum.png",
            "solana": "4128/large/solana.png",
            "binancecoin": "825/large/bnb-icon2_2x.png",
            "uniswap": "12504/large/uniswap-logo.png",
            "render-token": "11636/large/rndr.png",
            "sui": "26375/large/sui_asset.jpeg",
            "ondo-finance": "26580/large/ONDO.png",
        ]
        return mapping[geckoId] ?? "1/large/bitcoin.png"
    }
}
