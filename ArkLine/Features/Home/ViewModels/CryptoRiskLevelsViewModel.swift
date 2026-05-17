import Foundation

/// Fetches regression risk history for all crypto assets, buckets by risk band,
/// and exposes 7D / 30D trend deltas.
@MainActor
@Observable
class CryptoRiskLevelsViewModel {
    private let itcRiskService: ITCRiskServiceProtocol

    struct CoinRiskRow {
        let config: AssetRiskConfig
        let current: ITCRiskLevel
        let delta7d: Double?
        let delta30d: Double?
    }

    enum TrendWindow: Hashable {
        case sevenDay, thirtyDay
    }

    var rows: [CoinRiskRow] = []
    var failedCoins: [AssetRiskConfig] = []
    var isLoading = false
    var selectedTrendWindow: TrendWindow = .sevenDay

    /// Total catalog size — always matches cryptoConfigs.count
    var totalAssetCount: Int { AssetRiskConfig.cryptoConfigs.count }

    /// Ordered risk band names matching ITCRiskLevel.riskCategory
    static let bandOrder = ["Very Low Risk", "Low Risk", "Neutral", "Elevated Risk", "High Risk", "Extreme Risk"]

    init(itcRiskService: ITCRiskServiceProtocol = ServiceContainer.shared.itcRiskService) {
        self.itcRiskService = itcRiskService
    }

    /// Bucketed rows sorted by band order, ascending risk within each band.
    var bucketed: [(band: String, items: [CoinRiskRow])] {
        let grouped = Dictionary(grouping: rows) { $0.current.riskCategory }
        return Self.bandOrder.compactMap { band in
            guard let items = grouped[band], !items.isEmpty else { return nil }
            let sorted = items.sorted { $0.current.riskLevel < $1.current.riskLevel }
            return (band, sorted)
        }
    }

    func delta(for row: CoinRiskRow) -> Double? {
        switch selectedTrendWindow {
        case .sevenDay:  return row.delta7d
        case .thirtyDay: return row.delta30d
        }
    }

    func loadAll() async {
        isLoading = true
        defer { isLoading = false }

        let configs = AssetRiskConfig.cryptoConfigs

        await withTaskGroup(of: (AssetRiskConfig, CoinRiskRow?).self) { group in
            for config in configs {
                group.addTask { [itcRiskService] in
                    if let row = await Self.fetchRow(config: config, service: itcRiskService) {
                        return (config, row)
                    }
                    // Single retry after 500ms
                    try? await Task.sleep(for: .milliseconds(500))
                    let retryRow = await Self.fetchRow(config: config, service: itcRiskService)
                    return (config, retryRow)
                }
            }

            var fetched: [CoinRiskRow] = []
            var failed: [AssetRiskConfig] = []
            for await (config, row) in group {
                if let row {
                    fetched.append(row)
                } else {
                    failed.append(config)
                }
            }
            rows = fetched
            failedCoins = failed
        }
    }

    func refresh() async {
        rows = []
        failedCoins = []
        await loadAll()
    }

    // MARK: - Private

    nonisolated private static func fetchRow(config: AssetRiskConfig, service: ITCRiskServiceProtocol) async -> CoinRiskRow? {
        do {
            let history = try await service.fetchRiskHistory(coin: config.assetId, days: 30)
            guard let latest = history.last else { return nil }

            let current = ITCRiskLevel(date: latest.dateString, riskLevel: latest.riskLevel, price: latest.price)
            let delta7d = computeDelta(history: history, daysBack: 7, current: latest.riskLevel)
            let delta30d = computeDelta(history: history, daysBack: 30, current: latest.riskLevel)

            return CoinRiskRow(config: config, current: current, delta7d: delta7d, delta30d: delta30d)
        } catch {
            logError("Risk history fetch failed for \(config.assetId): \(error.localizedDescription)", category: .network)
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
