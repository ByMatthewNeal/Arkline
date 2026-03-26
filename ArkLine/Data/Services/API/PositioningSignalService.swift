import Foundation

/// Reads daily positioning signals from Supabase
final class PositioningSignalService {
    private let supabase = SupabaseManager.shared

    // MARK: - Cache
    private static var latestCache: [DailyPositioningSignal]?
    private static var latestCacheTime: Date?
    private static let cacheTTL: TimeInterval = 3600 // 1 hour (signals change once daily)

    /// Fetch latest signals for all assets (today or most recent)
    func fetchLatestSignals(forceRefresh: Bool = false) async throws -> [DailyPositioningSignal] {
        if !forceRefresh, let cached = Self.latestCache,
           let cacheTime = Self.latestCacheTime,
           Date().timeIntervalSince(cacheTime) < Self.cacheTTL {
            return cached
        }

        // Get today's date in UTC
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let today = formatter.string(from: Date())

        // Try today first
        var signals: [DailyPositioningSignal] = try await supabase.database
            .from("positioning_signals")
            .select()
            .eq("signal_date", value: today)
            .order("asset", ascending: true)
            .execute()
            .value

        // If no data for today (cron hasn't run yet), fetch most recent date
        if signals.isEmpty {
            signals = try await fetchMostRecentSignals()
        }

        Self.latestCache = signals
        Self.latestCacheTime = Date()
        return signals
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
    func fetchRecentSignalChanges(days: Int = 30) async throws -> [DailyPositioningSignal] {
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
