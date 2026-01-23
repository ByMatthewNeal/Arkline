import Foundation

// MARK: - Global Liquidity Service Protocol
protocol GlobalLiquidityServiceProtocol {
    /// Fetch current global liquidity data with multi-timeframe changes
    func fetchLiquidityChanges() async throws -> GlobalLiquidityChanges

    /// Fetch historical liquidity data
    func fetchLiquidityHistory(days: Int) async throws -> [GlobalLiquidityData]

    /// Get latest M2 money supply value
    func fetchLatestM2() async throws -> Double
}
