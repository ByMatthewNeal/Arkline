import Foundation

// MARK: - Rainbow Chart Service Protocol
protocol RainbowChartServiceProtocol {
    /// Fetch current rainbow chart data with bands calculated for today
    func fetchCurrentRainbowData(btcPrice: Double) async throws -> RainbowChartData

    /// Calculate rainbow bands for a specific date
    func calculateBands(for date: Date) -> RainbowBands

    /// Fetch historical rainbow data for charting
    func fetchRainbowHistory(days: Int) async throws -> [RainbowHistoryPoint]

    /// Get the current band for a given BTC price
    func getCurrentBand(btcPrice: Double, date: Date) -> RainbowBand
}
