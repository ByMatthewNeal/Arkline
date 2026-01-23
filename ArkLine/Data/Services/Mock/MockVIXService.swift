import Foundation

// MARK: - Mock VIX Service
/// Mock implementation of VIXServiceProtocol for development and testing.
final class MockVIXService: VIXServiceProtocol {
    // MARK: - Configuration
    /// Simulated network delay in nanoseconds
    var simulatedDelay: UInt64 = 500_000_000

    // MARK: - VIXServiceProtocol

    func fetchLatestVIX() async throws -> VIXData? {
        try await simulateNetworkDelay()
        return generateMockVIXData().first
    }

    func fetchVIXHistory(days: Int) async throws -> [VIXData] {
        try await simulateNetworkDelay()
        return Array(generateMockVIXData().prefix(days))
    }

    // MARK: - Private Helpers

    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: simulatedDelay)
    }

    /// Generates realistic mock VIX data
    /// VIX typically ranges from 12-35, with spikes during market stress
    private func generateMockVIXData() -> [VIXData] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var data: [VIXData] = []
        var currentValue = Double.random(in: 18...25)

        for dayOffset in 0..<100 {
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            let dateString = dateFormatter.string(from: date)

            // Add some volatility to the VIX value
            let dailyChange = Double.random(in: -2.5...2.5)
            currentValue = max(12, min(45, currentValue + dailyChange))

            // Calculate OHLC with some intraday variation
            let high = currentValue + Double.random(in: 0.5...2.0)
            let low = currentValue - Double.random(in: 0.5...2.0)
            let open = Double.random(in: low...high)

            data.append(VIXData(
                date: dateString,
                value: currentValue,
                open: open,
                high: high,
                low: low,
                close: currentValue
            ))
        }

        return data
    }
}
