import Foundation

// MARK: - Mock Santiment Service
/// Mock implementation for development and testing.
final class MockSantimentService: SantimentServiceProtocol {
    var simulatedDelay: UInt64 = 500_000_000

    func fetchLatestSupplyInProfit() async throws -> SupplyProfitData? {
        try await simulateNetworkDelay()
        return generateMockData().first
    }

    func fetchSupplyInProfitHistory(days: Int) async throws -> [SupplyProfitData] {
        try await simulateNetworkDelay()
        return Array(generateMockData().prefix(days))
    }

    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: simulatedDelay)
    }

    /// Generates realistic mock data based on historical patterns.
    /// Supply in Profit typically ranges 40-99%.
    private func generateMockData() -> [SupplyProfitData] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var data: [SupplyProfitData] = []
        var currentValue = Double.random(in: 65...80)

        for dayOffset in 0..<100 {
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            let dateString = dateFormatter.string(from: date)

            // Add volatility with mean reversion toward 70%
            let meanReversion = (70 - currentValue) * 0.05
            let dailyChange = Double.random(in: -2...2) + meanReversion
            currentValue = max(35, min(99, currentValue + dailyChange))

            data.append(SupplyProfitData(date: dateString, value: currentValue))
        }

        return data
    }
}
