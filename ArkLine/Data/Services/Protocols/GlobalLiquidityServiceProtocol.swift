import Foundation

// MARK: - Global Liquidity Service Protocol
protocol GlobalLiquidityServiceProtocol {
    /// Fetch current global liquidity data with multi-timeframe changes
    func fetchLiquidityChanges() async throws -> GlobalLiquidityChanges

    /// Fetch historical liquidity data
    func fetchLiquidityHistory(days: Int) async throws -> [GlobalLiquidityData]

    /// Get latest M2 money supply value
    func fetchLatestM2() async throws -> Double

    /// Fetch US Net Liquidity (Fed balance sheet − TGA − RRP) with changes
    func fetchNetLiquidityChanges() async throws -> NetLiquidityChanges

    /// Fetch composite Global Liquidity Index (BIS + FRED) from server cache
    func fetchGlobalLiquidityIndex() async throws -> GlobalLiquidityIndex
}
