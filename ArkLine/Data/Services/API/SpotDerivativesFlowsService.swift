import Foundation

// MARK: - Spot vs Derivatives Flows Service
/// Fetches the daily BTC spot/derivatives flow snapshot from Supabase
/// (computed by the compute-spot-derivatives-flows edge function daily).
final class SpotDerivativesFlowsService {
    private let supabase = SupabaseManager.shared

    func fetch() async throws -> SpotDerivativesFlowsData? {
        guard supabase.isConfigured else { return nil }
        let rows: [SpotDerivativesFlowsData] = try await supabase.database
            .from("spot_derivatives_flows")
            .select()
            .eq("asset", value: "BTC")
            .limit(1)
            .execute()
            .value
        return rows.first
    }
}
