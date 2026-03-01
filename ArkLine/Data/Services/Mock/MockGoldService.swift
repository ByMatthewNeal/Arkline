import Foundation

// MARK: - Mock Gold Service
/// Mock implementation of GoldServiceProtocol for development and testing.
final class MockGoldService: GoldServiceProtocol {
    var simulatedDelay: UInt64 = 500_000_000

    func fetchLatestGold() async throws -> GoldData? {
        try await Task.sleep(nanoseconds: simulatedDelay)
        return generateMockData().first
    }

    func fetchGoldHistory(days: Int) async throws -> [GoldData] {
        try await Task.sleep(nanoseconds: simulatedDelay)
        return Array(generateMockData().prefix(days))
    }

    private func generateMockData() -> [GoldData] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var data: [GoldData] = []
        var currentValue = 3100.0

        for dayOffset in 0..<100 {
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            let dateString = dateFormatter.string(from: date)
            let dailyChange = Double.random(in: -25.0...25.0)
            currentValue = max(2500, min(3500, currentValue + dailyChange))

            let high = currentValue + Double.random(in: 5...20)
            let low = currentValue - Double.random(in: 5...20)
            let open = Double.random(in: low...high)

            data.append(GoldData(
                date: dateString,
                value: currentValue,
                open: open,
                high: high,
                low: low,
                close: currentValue,
                previousClose: currentValue - dailyChange
            ))
        }
        return data
    }
}
