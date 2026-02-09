import Foundation

// MARK: - Market Data Collector

/// Collects and archives market data to Supabase for historical analysis.
/// Fire-and-forget saves — never blocks UI. Uses in-memory dedup to avoid redundant writes.
actor MarketDataCollector {
    // MARK: - Singleton
    static let shared = MarketDataCollector()

    // MARK: - Properties
    private var savedToday: Set<String> = []
    private var currentDay: String = ""

    private var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }

    // MARK: - Init
    private init() {}

    // MARK: - Dedup

    /// Resets the dedup set if the day has changed
    private func resetIfNewDay() {
        let today = todayString
        if today != currentDay {
            savedToday.removeAll()
            currentDay = today
        }
    }

    /// Returns true if this key has already been saved today
    private func alreadySaved(_ key: String) -> Bool {
        resetIfNewDay()
        return savedToday.contains(key)
    }

    /// Marks a key as saved for today
    private func markSaved(_ key: String) {
        savedToday.insert(key)
    }

    // MARK: - Record Crypto Assets

    /// Archives daily snapshots for a batch of crypto assets
    func recordCryptoAssets(_ assets: [CryptoAsset]) async {
        guard SupabaseManager.shared.isConfigured else { return }
        let date = todayString
        let key = "market_\(date)"
        guard !alreadySaved(key) else { return }

        let dtos = assets.map { MarketSnapshotDTO(from: $0, date: date) }
        do {
            try await SupabaseManager.shared.client
                .from(SupabaseTable.marketSnapshots.rawValue)
                .upsert(dtos, onConflict: "recorded_date,coin_id")
                .execute()
            markSaved(key)
            logInfo("Archived \(dtos.count) market snapshots", category: .network)
        } catch {
            logError("Failed to archive market snapshots: \(error.localizedDescription)", category: .network)
        }
    }

    // MARK: - Record Indicator

    /// Archives a single indicator value (VIX, DXY, M2, Fear/Greed, funding, etc.)
    func recordIndicator(name: String, value: Double, metadata: [String: AnyCodableValue]? = nil) async {
        guard SupabaseManager.shared.isConfigured else { return }
        let date = todayString
        let key = "indicator_\(name)_\(date)"
        guard !alreadySaved(key) else { return }

        let dto = IndicatorSnapshotDTO(indicator: name, date: date, value: value, metadata: metadata)
        do {
            try await SupabaseManager.shared.client
                .from(SupabaseTable.indicatorSnapshots.rawValue)
                .upsert([dto], onConflict: "recorded_date,indicator")
                .execute()
            markSaved(key)
            logInfo("Archived indicator: \(name) = \(value)", category: .network)
        } catch {
            logError("Failed to archive indicator \(name): \(error.localizedDescription)", category: .network)
        }
    }

    // MARK: - Record Technicals

    /// Archives technical analysis data for a coin
    func recordTechnicals(_ ta: TechnicalAnalysis) async {
        guard SupabaseManager.shared.isConfigured else { return }
        let date = todayString
        let key = "technicals_\(ta.assetId)_\(date)"
        guard !alreadySaved(key) else { return }

        let dto = TechnicalsSnapshotDTO(from: ta, date: date)
        do {
            try await SupabaseManager.shared.client
                .from(SupabaseTable.technicalsSnapshots.rawValue)
                .upsert([dto], onConflict: "recorded_date,coin_id")
                .execute()
            markSaved(key)
            logInfo("Archived technicals for \(ta.assetSymbol)", category: .network)
        } catch {
            logError("Failed to archive technicals for \(ta.assetSymbol): \(error.localizedDescription)", category: .network)
        }
    }

    // MARK: - Record Risk Score

    /// Archives the daily composite risk score with component breakdown
    func recordRiskScore(_ riskScore: ArkLineRiskScore) async {
        guard SupabaseManager.shared.isConfigured else { return }
        let date = todayString
        let key = "risk_\(date)"
        guard !alreadySaved(key) else { return }

        let dto = RiskSnapshotDTO(from: riskScore, date: date)
        do {
            try await SupabaseManager.shared.client
                .from(SupabaseTable.riskSnapshots.rawValue)
                .upsert([dto], onConflict: "recorded_date")
                .execute()
            markSaved(key)
            logInfo("Archived risk score: \(riskScore.score)", category: .network)
        } catch {
            logError("Failed to archive risk score: \(error.localizedDescription)", category: .network)
        }
    }

    // MARK: - Batch Record Indicators

    /// Convenience method to record multiple indicators at once
    func recordIndicators(_ indicators: [(name: String, value: Double, metadata: [String: AnyCodableValue]?)]) async {
        for indicator in indicators {
            await recordIndicator(name: indicator.name, value: indicator.value, metadata: indicator.metadata)
        }
    }
}
