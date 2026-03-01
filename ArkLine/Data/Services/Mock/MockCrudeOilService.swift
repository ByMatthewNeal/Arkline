import Foundation

// MARK: - Mock Crude Oil Service
/// Mock implementation of CrudeOilServiceProtocol for development and testing.
final class MockCrudeOilService: CrudeOilServiceProtocol {
    var simulatedDelay: UInt64 = 500_000_000

    func fetchLatestCrudeOil() async throws -> CrudeOilData? {
        try await Task.sleep(nanoseconds: simulatedDelay)
        return generateMockData().first
    }

    func fetchCrudeOilHistory(days: Int) async throws -> [CrudeOilData] {
        try await Task.sleep(nanoseconds: simulatedDelay)
        return Array(generateMockData().prefix(days))
    }

    private func generateMockData() -> [CrudeOilData] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var data: [CrudeOilData] = []
        var currentValue = 72.0

        for dayOffset in 0..<100 {
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            let dateString = dateFormatter.string(from: date)
            let dailyChange = Double.random(in: -2.0...2.0)
            currentValue = max(55, min(100, currentValue + dailyChange))

            let high = currentValue + Double.random(in: 0.3...1.5)
            let low = currentValue - Double.random(in: 0.3...1.5)
            let open = Double.random(in: low...high)

            data.append(CrudeOilData(
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
