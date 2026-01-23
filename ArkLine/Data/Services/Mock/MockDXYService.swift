import Foundation

// MARK: - Mock DXY Service
/// Mock implementation of DXYServiceProtocol for development and testing.
final class MockDXYService: DXYServiceProtocol {
    // MARK: - Configuration
    /// Simulated network delay in nanoseconds
    var simulatedDelay: UInt64 = 500_000_000

    // MARK: - DXYServiceProtocol

    func fetchLatestDXY() async throws -> DXYData? {
        try await simulateNetworkDelay()
        return generateMockDXYData().first
    }

    func fetchDXYHistory(days: Int) async throws -> [DXYData] {
        try await simulateNetworkDelay()
        return Array(generateMockDXYData().prefix(days))
    }

    // MARK: - Private Helpers

    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: simulatedDelay)
    }

    /// Generates realistic mock DXY data
    /// DXY typically ranges from 95-110
    private func generateMockDXYData() -> [DXYData] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var data: [DXYData] = []
        var currentValue = Double.random(in: 102...106)
        var previousClose: Double? = nil

        for dayOffset in 0..<100 {
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            let dateString = dateFormatter.string(from: date)

            // Store previous close before updating current value
            let thisPreviousClose = previousClose
            previousClose = currentValue

            // Add some daily movement to DXY
            let dailyChange = Double.random(in: -0.8...0.8)
            currentValue = max(95, min(115, currentValue + dailyChange))

            // Calculate OHLC with some intraday variation
            let high = currentValue + Double.random(in: 0.2...0.6)
            let low = currentValue - Double.random(in: 0.2...0.6)
            let open = Double.random(in: low...high)

            data.append(DXYData(
                date: dateString,
                value: currentValue,
                open: open,
                high: high,
                low: low,
                close: currentValue,
                previousClose: thisPreviousClose
            ))
        }

        // First item won't have previous close from loop, set it manually
        if !data.isEmpty {
            let firstItem = data[0]
            data[0] = DXYData(
                date: firstItem.date,
                value: firstItem.value,
                open: firstItem.open,
                high: firstItem.high,
                low: firstItem.low,
                close: firstItem.close,
                previousClose: firstItem.value - Double.random(in: -0.5...0.5)
            )
        }

        return data
    }
}
