import Foundation

// MARK: - Liquidation Heatmap Service
/// Fetches the projected BTC liquidation heatmap from Supabase
/// (computed by the compute-liquidation-heatmap edge function daily).
final class LiquidationHeatmapService {
    private let supabase = SupabaseManager.shared

    func fetch() async throws -> LiquidationHeatmapData? {
        guard supabase.isConfigured else { return nil }
        let rows: [LiquidationHeatmapData] = try await supabase.database
            .from("liquidation_heatmap")
            .select()
            .eq("asset", value: "BTC")
            .limit(1)
            .execute()
            .value
        return rows.first
    }
}
