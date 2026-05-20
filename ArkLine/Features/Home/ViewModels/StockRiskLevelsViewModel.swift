import Foundation

/// Fetches risk history for all stock assets, buckets by risk band,
/// and exposes 7D / 30D trend deltas.
@MainActor
@Observable
class StockRiskLevelsViewModel {
    private let itcRiskService: ITCRiskServiceProtocol

    struct StockRiskRow {
        let config: AssetRiskConfig
        let current: ITCRiskLevel
        let delta7d: Double?
        let delta30d: Double?
    }

    enum TrendWindow: Hashable {
        case sevenDay, thirtyDay
    }

    var rows: [StockRiskRow] = []
    var failedStocks: [AssetRiskConfig] = []
    var isLoading = false
    var selectedTrendWindow: TrendWindow = .sevenDay

    /// Total catalog size — always matches stockConfigs.count
    var totalAssetCount: Int { AssetRiskConfig.stockConfigs.count }

    /// Ordered risk band names matching ITCRiskLevel.riskCategory
    static let bandOrder = ["Very Low Risk", "Low Risk", "Neutral", "Elevated Risk", "High Risk", "Extreme Risk"]

    /// Max concurrent fetches
    private static let maxConcurrency = 4

    init(itcRiskService: ITCRiskServiceProtocol = ServiceContainer.shared.itcRiskService) {
        self.itcRiskService = itcRiskService
    }

    /// Bucketed rows sorted by band order, ascending risk within each band.
    var bucketed: [(band: String, items: [StockRiskRow])] {
        let grouped = Dictionary(grouping: rows) { $0.current.riskCategory }
        return Self.bandOrder.compactMap { band in
            guard let items = grouped[band], !items.isEmpty else { return nil }
            let sorted = items.sorted { $0.current.riskLevel < $1.current.riskLevel }
            return (band, sorted)
        }
    }

    func delta(for row: StockRiskRow) -> Double? {
        switch selectedTrendWindow {
        case .sevenDay:  return row.delta7d
        case .thirtyDay: return row.delta30d
        }
    }

    func loadAll() async {
        isLoading = true

        let configs = AssetRiskConfig.stockConfigs
        var fetched: [StockRiskRow] = []
        var failed: [AssetRiskConfig] = []

        for batch in configs.chunked(into: Self.maxConcurrency) {
            await withTaskGroup(of: (AssetRiskConfig, StockRiskRow?).self) { group in
                for config in batch {
                    group.addTask { [itcRiskService] in
                        if let row = await Self.fetchRow(config: config, service: itcRiskService) {
                            return (config, row)
                        }
                        try? await Task.sleep(for: .milliseconds(500))
                        let retryRow = await Self.fetchRow(config: config, service: itcRiskService)
                        return (config, retryRow)
                    }
                }

                for await (config, row) in group {
                    if let row {
                        fetched.append(row)
                    } else {
                        failed.append(config)
                    }
                }
            }

            // Update UI progressively after each batch
            rows = fetched
            failedStocks = failed
        }

        isLoading = false
    }

    func refresh() async {
        rows = []
        failedStocks = []
        await loadAll()
    }

    // MARK: - Private

    nonisolated private static func fetchRow(config: AssetRiskConfig, service: ITCRiskServiceProtocol) async -> StockRiskRow? {
        guard let stockService = service as? APIITCRiskService else { return nil }
        do {
            let history = try await stockService.fetchStockRiskHistory(symbol: config.assetId, days: 30)
            guard let latest = history.last else { return nil }

            let current = ITCRiskLevel(date: latest.dateString, riskLevel: latest.riskLevel, price: latest.price)
            let delta7d = computeDelta(history: history, daysBack: 7, current: latest.riskLevel)
            let delta30d = computeDelta(history: history, daysBack: 30, current: latest.riskLevel)

            return StockRiskRow(config: config, current: current, delta7d: delta7d, delta30d: delta30d)
        } catch {
            logError("Stock risk history fetch failed for \(config.assetId): \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    /// Compute delta between current risk and the value ~N days ago.
    nonisolated private static func computeDelta(history: [RiskHistoryPoint], daysBack: Int, current: Double) -> Double? {
        guard history.count > 1 else { return nil }
        let cutoff = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
        let past = history.first { $0.date >= cutoff }
        guard let pastValue = past?.riskLevel else { return nil }
        let oldestDate = history.first?.date ?? Date()
        guard oldestDate <= cutoff else { return nil }
        return current - pastValue
    }
}

// MARK: - Array Chunking

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
