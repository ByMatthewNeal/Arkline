import Foundation

// MARK: - Allocation View Model

/// Orchestrates the three allocation calculators to produce a unified AllocationSummary.
/// Reads macro data from an existing SentimentViewModel to avoid duplicate fetches.
/// TA fetches are sequential with 16s delays to respect Taapi.io rate limits (1 req/15s).
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

    /// TA results cache — survives across refreshes until replaced
    private var taCache: [String: TechnicalAnalysis] = [:]
    private var taCacheTimestamp: Date?
    private let taCacheTTL: TimeInterval = 300 // 5 minutes

    /// Taapi.io rate limit: 1 request per 15 seconds
    private static let taapiDelay: UInt64 = 16_000_000_000 // 16s in nanoseconds

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

        let configs = AssetRiskConfig.allConfigs

        // 1. Compute regime from macro data (instant, no network)
        let regime = MacroRegimeCalculator.computeRegime(
            vixData: sentimentViewModel.vixData,
            dxyData: sentimentViewModel.dxyData,
            globalM2Data: sentimentViewModel.globalM2Data,
            macroZScores: sentimentViewModel.macroZScores
        )

        // 2. Build signals for ALL assets — use cached TA if available, risk-level fallback otherwise
        var signals: [(assetId: String, displayName: String, iconUrl: String?, signal: PositioningSignal)] = []

        for config in configs {
            let riskLevel = sentimentViewModel.riskLevels[config.assetId]?.riskLevel
            let signal: PositioningSignal

            if let ta = taCache[config.assetId] {
                signal = PositioningSignalCalculator.computeSignal(
                    trendScore: ta.trendScore,
                    riskLevel: riskLevel
                )
            } else {
                // Fallback: use risk level alone when TA is unavailable
                signal = signalFromRiskLevel(riskLevel)
            }

            let iconUrl = "https://assets.coingecko.com/coins/images/\(coinGeckoImageId(for: config.geckoId))"
            signals.append((
                assetId: config.assetId,
                displayName: config.displayName,
                iconUrl: iconUrl,
                signal: signal
            ))
        }

        // 3. Publish initial summary immediately (with whatever data we have)
        allocationSummary = AllocationEngine.computeAll(signals: signals, regime: regime)

        // 4. Fetch TA sequentially in background, updating summary as each completes
        let isCacheStale = taCacheTimestamp.map { Date().timeIntervalSince($0) > taCacheTTL } ?? true
        if isCacheStale {
            await fetchTASequentially(configs: configs, regime: regime)
        }
    }

    /// Refresh — alias for loadAllocations for pull-to-refresh consistency
    func refresh() async {
        // Clear cache on manual refresh so TA is re-fetched
        taCache.removeAll()
        taCacheTimestamp = nil
        await loadAllocations()
    }

    // MARK: - Sequential TA Fetching

    /// Fetches TA for each asset one at a time with rate limit delays.
    /// Updates the summary after each successful fetch for progressive loading.
    private func fetchTASequentially(configs: [AssetRiskConfig], regime: MacroRegimeResult) async {
        var isFirst = true

        for config in configs {
            guard let binanceSymbol = config.binanceSymbol else { continue }

            // Rate limit delay (skip for first request)
            if !isFirst {
                try? await Task.sleep(nanoseconds: Self.taapiDelay)
            }
            isFirst = false

            let symbol = binanceSymbol.replacingOccurrences(of: "USDT", with: "/USDT")

            do {
                let ta = try await technicalAnalysisService.fetchTechnicalAnalysis(
                    symbol: symbol,
                    exchange: "binance",
                    interval: .daily
                )
                taCache[config.assetId] = ta

                // Rebuild and publish updated summary
                rebuildSummary(configs: configs, regime: regime)
            } catch {
                // Keep fallback signal for this asset
            }
        }

        taCacheTimestamp = Date()
    }

    /// Rebuild the allocation summary from current cache + fallbacks.
    private func rebuildSummary(configs: [AssetRiskConfig], regime: MacroRegimeResult) {
        var signals: [(assetId: String, displayName: String, iconUrl: String?, signal: PositioningSignal)] = []

        for config in configs {
            let riskLevel = sentimentViewModel.riskLevels[config.assetId]?.riskLevel
            let signal: PositioningSignal

            if let ta = taCache[config.assetId] {
                signal = PositioningSignalCalculator.computeSignal(
                    trendScore: ta.trendScore,
                    riskLevel: riskLevel
                )
            } else {
                signal = signalFromRiskLevel(riskLevel)
            }

            let iconUrl = "https://assets.coingecko.com/coins/images/\(coinGeckoImageId(for: config.geckoId))"
            signals.append((
                assetId: config.assetId,
                displayName: config.displayName,
                iconUrl: iconUrl,
                signal: signal
            ))
        }

        allocationSummary = AllocationEngine.computeAll(signals: signals, regime: regime)
    }

    // MARK: - Fallback Signal

    /// Derive a signal from risk level alone when TA data is unavailable.
    /// Low risk → bullish, high risk → bearish, otherwise neutral.
    private func signalFromRiskLevel(_ riskLevel: Double?) -> PositioningSignal {
        guard let risk = riskLevel else { return .neutral }
        if risk <= 0.3 { return .bullish }
        if risk >= 0.7 { return .bearish }
        return .neutral
    }

    // MARK: - Icon URL

    /// Map geckoId to CoinGecko image path segment.
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
