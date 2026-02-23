import Foundation

// MARK: - Allocation View Model

/// Orchestrates the three allocation calculators to produce a unified AllocationSummary.
/// Reads macro data from an existing SentimentViewModel to avoid duplicate fetches.
@MainActor
@Observable
class AllocationViewModel {
    // MARK: - Dependencies
    private let technicalAnalysisService: TechnicalAnalysisServiceProtocol
    private let sentimentViewModel: SentimentViewModel

    // MARK: - State
    var allocationSummary: AllocationSummary?
    var isLoading = false
    var errorMessage: String?

    // MARK: - Init

    init(sentimentViewModel: SentimentViewModel) {
        self.sentimentViewModel = sentimentViewModel
        self.technicalAnalysisService = ServiceContainer.shared.technicalAnalysisService
    }

    // MARK: - Load

    func loadAllocations() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // 1. Fetch TA for all 8 assets in parallel
            let configs = AssetRiskConfig.allConfigs
            let technicalResults = await fetchAllTA(configs: configs)

            // 2. Read macro data from sentimentViewModel (already loaded)
            let regime = MacroRegimeCalculator.computeRegime(
                vixData: sentimentViewModel.vixData,
                dxyData: sentimentViewModel.dxyData,
                globalM2Data: sentimentViewModel.globalM2Data,
                macroZScores: sentimentViewModel.macroZScores
            )

            // 3. Compute signals for each asset that has TA data
            var signals: [(assetId: String, displayName: String, iconUrl: String?, signal: PositioningSignal)] = []

            for config in configs {
                guard let ta = technicalResults[config.assetId] else { continue }

                let riskLevel = sentimentViewModel.riskLevels[config.assetId]?.riskLevel
                let signal = PositioningSignalCalculator.computeSignal(
                    trendScore: ta.trendScore,
                    riskLevel: riskLevel
                )

                let iconUrl = "https://assets.coingecko.com/coins/images/\(coinGeckoImageId(for: config.geckoId))"

                signals.append((
                    assetId: config.assetId,
                    displayName: config.displayName,
                    iconUrl: iconUrl,
                    signal: signal
                ))
            }

            // 4. Compute allocations
            allocationSummary = AllocationEngine.computeAll(
                signals: signals,
                regime: regime
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Refresh — alias for loadAllocations for pull-to-refresh consistency
    func refresh() async {
        await loadAllocations()
    }

    // MARK: - Private

    /// Fetch technical analysis for all configs, returning results keyed by assetId.
    /// Individual failures are silently skipped (asset omitted from results).
    private func fetchAllTA(configs: [AssetRiskConfig]) async -> [String: TechnicalAnalysis] {
        await withTaskGroup(of: (String, TechnicalAnalysis?).self) { group in
            for config in configs {
                guard let binanceSymbol = config.binanceSymbol else { continue }
                let symbol = binanceSymbol.replacingOccurrences(of: "USDT", with: "/USDT")
                let assetId = config.assetId

                group.addTask { [technicalAnalysisService] in
                    do {
                        let ta = try await technicalAnalysisService.fetchTechnicalAnalysis(
                            symbol: symbol,
                            exchange: "binance",
                            interval: .daily
                        )
                        return (assetId, ta)
                    } catch {
                        return (assetId, nil)
                    }
                }
            }

            var results: [String: TechnicalAnalysis] = [:]
            for await (assetId, ta) in group {
                if let ta { results[assetId] = ta }
            }
            return results
        }
    }

    /// Map geckoId to CoinGecko image path segment.
    /// Uses a static lookup since CoinGecko image IDs don't follow a predictable pattern.
    private func coinGeckoImageId(for geckoId: String) -> String {
        let mapping: [String: String] = [
            "bitcoin": "1/large/bitcoin.png",
            "ethereum": "279/large/ethereum.png",
            "solana": "4128/large/solana.png",
            "binancecoin": "825/large/bnb-icon2_2x.png",
            "uniswap": "12504/large/uni.png",
            "render-token": "11636/large/rndr.png",
            "sui": "26375/large/sui_asset.jpeg",
            "ondo-finance": "26580/large/ONDO.png",
        ]
        return mapping[geckoId] ?? "1/large/bitcoin.png"
    }
}
