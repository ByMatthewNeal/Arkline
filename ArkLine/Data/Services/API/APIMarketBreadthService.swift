import Foundation

// MARK: - Market Breadth Service
/// Fetches market breadth data from Supabase (computed by edge function daily).
final class MarketBreadthService {
    private let supabase = SupabaseManager.shared

    /// Fetch the latest breadth reading
    func fetchLatest() async throws -> MarketBreadthPoint? {
        guard supabase.isConfigured else { return nil }

        let results: [MarketBreadthPoint] = try await supabase.database
            .from(SupabaseTable.marketBreadth.rawValue)
            .select()
            .order("signal_date", ascending: false)
            .limit(1)
            .execute()
            .value

        return results.first
    }

    /// Fetch breadth history for charting (default 90 days)
    func fetchHistory(days: Int = 90) async throws -> [MarketBreadthPoint] {
        guard supabase.isConfigured else { return [] }

        let results: [MarketBreadthPoint] = try await supabase.database
            .from(SupabaseTable.marketBreadth.rawValue)
            .select()
            .order("signal_date", ascending: false)
            .limit(days)
            .execute()
            .value

        // Return sorted ascending for charting
        return results.reversed()
    }

    /// Fetch recent crossover events
    func fetchRecentCrossovers(limit: Int = 5) async throws -> [MarketBreadthPoint] {
        guard supabase.isConfigured else { return [] }

        let results: [MarketBreadthPoint] = try await supabase.database
            .from(SupabaseTable.marketBreadth.rawValue)
            .select()
            .not("crossover", operator: .is, value: "null")
            .order("signal_date", ascending: false)
            .limit(limit)
            .execute()
            .value

        return results
    }
}
