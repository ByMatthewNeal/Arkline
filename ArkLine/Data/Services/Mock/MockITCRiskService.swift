import Foundation

// MARK: - Mock ITC Risk Service
/// Mock implementation of ITCRiskServiceProtocol for development and testing.
final class MockITCRiskService: ITCRiskServiceProtocol {
    // MARK: - Configuration
    /// Simulated network delay in nanoseconds
    var simulatedDelay: UInt64 = 300_000_000

    // MARK: - ITCRiskServiceProtocol

    func fetchRiskLevel(coin: String) async throws -> [ITCRiskLevel] {
        try await simulateNetworkDelay()
        return generateMockRiskHistory(for: coin)
    }

    func fetchLatestRiskLevel(coin: String) async throws -> ITCRiskLevel? {
        try await simulateNetworkDelay()
        return generateMockRiskHistory(for: coin).last
    }

    // MARK: - Private Helpers

    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: simulatedDelay)
    }

    private func generateMockRiskHistory(for coin: String) -> [ITCRiskLevel] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var history: [ITCRiskLevel] = []

        // Generate 30 days of mock data
        for i in (0..<30).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { continue }
            let dateString = dateFormatter.string(from: date)

            // Generate a somewhat realistic risk level that varies over time
            let baseRisk: Double
            switch coin.uppercased() {
            case "BTC":
                baseRisk = 0.45
            case "ETH":
                baseRisk = 0.52
            default:
                baseRisk = 0.50
            }

            // Add some variation based on day
            let variation = sin(Double(i) * 0.3) * 0.15
            let noise = Double.random(in: -0.05...0.05)
            let riskLevel = max(0.0, min(1.0, baseRisk + variation + noise))

            history.append(ITCRiskLevel(date: dateString, riskLevel: riskLevel))
        }

        return history
    }
}
