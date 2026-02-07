import Foundation

// MARK: - Mock Global Liquidity Service
final class MockGlobalLiquidityService: GlobalLiquidityServiceProtocol {
    // MARK: - Mock Data

    /// Current approximate Global M2 (5 economies: US, China, Eurozone, Japan, UK)
    private let currentM2: Double = 92_000_000_000_000 // ~$92T global M2

    func fetchLiquidityChanges() async throws -> GlobalLiquidityChanges {
        let history = try await fetchLiquidityHistory(days: 400)

        return GlobalLiquidityChanges(
            current: currentM2,
            dailyChange: 0.018,      // ~0.018% daily increase (~$3.9B)
            weeklyChange: 0.15,      // ~0.15% weekly increase (~$32B)
            monthlyChange: 0.45,     // ~0.45% monthly increase (~$97B)
            yearlyChange: 3.2,       // ~3.2% YoY increase (~$688B)
            history: history
        )
    }

    func fetchLiquidityHistory(days: Int) async throws -> [GlobalLiquidityData] {
        var history: [GlobalLiquidityData] = []
        let calendar = Calendar.current
        let now = Date()

        // Generate realistic M2 growth pattern
        // M2 typically grows at ~5-7% annually with some variation
        let dailyGrowthRate = 0.0001 // ~3.65% annual growth
        var currentValue = currentM2

        // Work backwards from today
        for daysAgo in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) else { continue }

            // Add some noise to make it realistic
            let noise = Double.random(in: -0.001...0.001)
            let adjustment = 1 + dailyGrowthRate + noise

            // Calculate value for this day (going backwards)
            currentValue = currentValue / adjustment

            let previousValue = currentValue / (1 + dailyGrowthRate)

            history.append(GlobalLiquidityData(
                date: date,
                value: currentValue,
                previousValue: previousValue
            ))
        }

        // Sort by date ascending
        return history.sorted { $0.date < $1.date }
    }

    func fetchLatestM2() async throws -> Double {
        return currentM2
    }
}
