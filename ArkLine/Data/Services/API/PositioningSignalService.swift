import Foundation

/// Reads daily positioning signals from Supabase
final class PositioningSignalService {
    private let supabase = SupabaseManager.shared

    // MARK: - Cache
    private static var latestCache: [DailyPositioningSignal]?
    private static var latestCacheTime: Date?
    private static let cacheTTL: TimeInterval = 3600 // 1 hour (signals change once daily)

    /// Fetch the latest signal for every asset.
    ///
    /// Asset classes don't share a single signal_date: crypto/commodities/macro
    /// update every day (incl. weekends) on the UTC calendar, while stocks and
    /// indices are dated to the last US *trading* day. Keying off one shared
    /// "today" date silently drops whichever class lags — most often stocks and
    /// indices. So we pull a short recent window and keep each asset's most
    /// recent row, which keeps every class present regardless of date skew.
    func fetchLatestSignals(forceRefresh: Bool = false) async throws -> [DailyPositioningSignal] {
        if !forceRefresh, let cached = Self.latestCache,
           let cacheTime = Self.latestCacheTime,
           Date().timeIntervalSince(cacheTime) < Self.cacheTTL {
            return cached
        }

        // Window wide enough to cover weekends + market holidays (when stocks
        // can lag crypto by several days) but small enough to stay well under
        // PostgREST's default row cap. ~10 days x ~75 assets ≈ 750 rows.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let cutoff = Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date()
        let cutoffStr = formatter.string(from: cutoff)

        // Ordered newest-first so the first row seen per asset is its latest.
        let recent: [DailyPositioningSignal] = try await supabase.database
            .from("positioning_signals")
            .select()
            .gte("signal_date", value: cutoffStr)
            .order("signal_date", ascending: false)
            .limit(1500)
            .execute()
            .value

        var latestByAsset: [String: DailyPositioningSignal] = [:]
        for signal in recent where latestByAsset[signal.asset] == nil {
            latestByAsset[signal.asset] = signal
        }
        let signals = latestByAsset.values.sorted { $0.asset < $1.asset }

        // Fallback: if the window somehow came back empty, use the old
        // most-recent-date probe rather than showing nothing.
        let result = signals.isEmpty ? try await fetchMostRecentSignals() : signals

        Self.latestCache = result
        Self.latestCacheTime = Date()
        return result
    }

    /// Fetch signal history for a specific asset
    func fetchSignalHistory(asset: String, days: Int = 30) async throws -> [DailyPositioningSignal] {
        let signals: [DailyPositioningSignal] = try await supabase.database
            .from("positioning_signals")
            .select()
            .eq("asset", value: asset)
            .order("signal_date", ascending: false)
            .limit(days)
            .execute()
            .value

        return signals.reversed() // Chronological order
    }

    /// Fetch recent signal changes across all assets (where signal != prev_signal)
    func fetchRecentSignalChanges(days: Int = 90) async throws -> [DailyPositioningSignal] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let cutoffStr = formatter.string(from: cutoff)

        let signals: [DailyPositioningSignal] = try await supabase.database
            .from("positioning_signals")
            .select()
            .not("prev_signal", operator: .is, value: "null")
            .gte("signal_date", value: cutoffStr)
            .order("signal_date", ascending: false)
            .execute()
            .value

        // Filter client-side: only rows where signal actually changed
        return signals.filter { $0.hasChanged }
    }

    /// Fetch signal changes for a specific date
    func fetchSignalChangesForDate(_ date: Date) async throws -> [DailyPositioningSignal] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let dateStr = formatter.string(from: date)

        let signals: [DailyPositioningSignal] = try await supabase.database
            .from("positioning_signals")
            .select()
            .eq("signal_date", value: dateStr)
            .not("prev_signal", operator: .is, value: "null")
            .order("asset", ascending: true)
            .execute()
            .value

        return signals.filter { $0.hasChanged }
    }

    /// Fetch the most recent date that has signals
    private func fetchMostRecentSignals() async throws -> [DailyPositioningSignal] {
        // Get one row to find the latest date
        let probe: [DailyPositioningSignal] = try await supabase.database
            .from("positioning_signals")
            .select()
            .order("signal_date", ascending: false)
            .limit(1)
            .execute()
            .value

        guard let latestDate = probe.first else { return [] }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let dateStr = formatter.string(from: latestDate.signalDate)

        let signals: [DailyPositioningSignal] = try await supabase.database
            .from("positioning_signals")
            .select()
            .eq("signal_date", value: dateStr)
            .order("asset", ascending: true)
            .execute()
            .value

        return signals
    }
}
