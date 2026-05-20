import Foundation

// MARK: - Rotation Signal Service

/// Fetches the daily crypto vs equities rotation signal and sector performance from Supabase.
final class RotationSignalService {
    static let shared = RotationSignalService()

    private var signalCache: RotationSignal?
    private var sectorsCache: [SectorPerformance] = []
    private var cacheTimestamp: Date?
    private let cacheTTL: TimeInterval = 3600 // 1 hour (updates daily)

    private init() {}

    // MARK: - Public API

    /// Fetch the latest rotation signal (today or most recent).
    func fetchLatestSignal() async -> RotationSignal? {
        if let ts = cacheTimestamp, Date().timeIntervalSince(ts) < cacheTTL, signalCache != nil {
            return signalCache
        }

        guard SupabaseManager.shared.isConfigured else { return nil }

        do {
            let signal: RotationSignal = try await SupabaseManager.shared.database
                .from(SupabaseTable.rotationSignals.rawValue)
                .select()
                .order("signal_date", ascending: false)
                .limit(1)
                .single()
                .execute()
                .value

            signalCache = signal
            cacheTimestamp = Date()
            logInfo("RotationSignalService: Loaded signal — score \(signal.rotationScore), regime \(signal.regime.rawValue)", category: .network)
            return signal
        } catch {
            logWarning("RotationSignalService: Failed to fetch signal: \(error)", category: .network)
            return signalCache // Return stale cache if available
        }
    }

    /// Fetch sector performance for the latest date, ranked by relative strength.
    func fetchLatestSectors() async -> [SectorPerformance] {
        if let ts = cacheTimestamp, Date().timeIntervalSince(ts) < cacheTTL, !sectorsCache.isEmpty {
            return sectorsCache
        }

        guard SupabaseManager.shared.isConfigured else { return [] }

        do {
            // Get the most recent date
            let latest: [SectorPerformance] = try await SupabaseManager.shared.database
                .from(SupabaseTable.sectorPerformance.rawValue)
                .select()
                .order("signal_date", ascending: false)
                .limit(1)
                .execute()
                .value

            guard let latestDate = latest.first?.signalDate else { return [] }

            // Fetch all sectors for that date
            let sectors: [SectorPerformance] = try await SupabaseManager.shared.database
                .from(SupabaseTable.sectorPerformance.rawValue)
                .select()
                .eq("signal_date", value: latestDate)
                .order("relative_strength_vs_spy", ascending: false)
                .execute()
                .value

            sectorsCache = sectors
            if cacheTimestamp == nil { cacheTimestamp = Date() }
            logInfo("RotationSignalService: Loaded \(sectors.count) sectors", category: .network)
            return sectors
        } catch {
            logWarning("RotationSignalService: Failed to fetch sectors: \(error)", category: .network)
            return sectorsCache
        }
    }

    /// Fetch rotation signal history for charting.
    func fetchSignalHistory(days: Int = 30) async -> [RotationSignal] {
        guard SupabaseManager.shared.isConfigured else { return [] }

        do {
            let signals: [RotationSignal] = try await SupabaseManager.shared.database
                .from(SupabaseTable.rotationSignals.rawValue)
                .select()
                .order("signal_date", ascending: false)
                .limit(days)
                .execute()
                .value

            return signals.reversed() // Chronological order
        } catch {
            logWarning("RotationSignalService: Failed to fetch history: \(error)", category: .network)
            return []
        }
    }

    func clearCache() {
        signalCache = nil
        sectorsCache = []
        cacheTimestamp = nil
    }
}
