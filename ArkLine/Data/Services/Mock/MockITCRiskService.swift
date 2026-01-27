import Foundation

// MARK: - Mock ITC Risk Service
/// Mock implementation of ITCRiskServiceProtocol for development and testing.
final class MockITCRiskService: ITCRiskServiceProtocol {
    // MARK: - Configuration
    /// Simulated network delay in nanoseconds
    var simulatedDelay: UInt64 = 300_000_000

    // MARK: - ITCRiskServiceProtocol (Legacy)

    func fetchRiskLevel(coin: String) async throws -> [ITCRiskLevel] {
        try await simulateNetworkDelay()
        return generateMockRiskHistory(for: coin).map { ITCRiskLevel(from: $0) }
    }

    func fetchLatestRiskLevel(coin: String) async throws -> ITCRiskLevel? {
        try await simulateNetworkDelay()
        guard let latest = generateMockRiskHistory(for: coin).last else { return nil }
        return ITCRiskLevel(from: latest)
    }

    // MARK: - Enhanced Methods

    func fetchRiskHistory(coin: String, days: Int?) async throws -> [RiskHistoryPoint] {
        try await simulateNetworkDelay()
        let fullHistory = generateMockRiskHistory(for: coin)

        guard let days = days else { return fullHistory }
        return Array(fullHistory.suffix(days))
    }

    func calculateCurrentRisk(coin: String) async throws -> RiskHistoryPoint {
        try await simulateNetworkDelay()
        guard let latest = generateMockRiskHistory(for: coin).last else {
            throw RiskCalculationError.noDataAvailable(coin)
        }
        return latest
    }

    // MARK: - Multi-Factor Risk Methods

    func calculateMultiFactorRisk(
        coin: String,
        weights: RiskFactorWeights = .default
    ) async throws -> MultiFactorRiskPoint {
        try await simulateNetworkDelay()

        guard let baseRisk = generateMockRiskHistory(for: coin).last else {
            throw RiskCalculationError.noDataAvailable(coin)
        }

        // Generate mock factor data
        let mockFactors = generateMockFactors(baseRisk: baseRisk.riskLevel, weights: weights)

        return MultiFactorRiskPoint(
            date: baseRisk.date,
            riskLevel: baseRisk.riskLevel,
            price: baseRisk.price,
            fairValue: baseRisk.fairValue,
            deviation: baseRisk.deviation,
            factors: mockFactors,
            weights: weights
        )
    }

    func calculateEnhancedCurrentRisk(coin: String) async throws -> RiskHistoryPoint {
        let multiFactorRisk = try await calculateMultiFactorRisk(coin: coin)
        return multiFactorRisk.toRiskHistoryPoint()
    }

    // MARK: - Private Helpers

    private func generateMockFactors(baseRisk: Double, weights: RiskFactorWeights) -> [RiskFactor] {
        // Generate mock factors that approximately average to the base risk
        let rsiRaw = 30.0 + (baseRisk * 40.0) // 30-70 range
        let fundingRaw = -0.001 + (baseRisk * 0.002) // -0.001 to 0.001
        let fearGreedRaw = baseRisk * 100.0 // 0-100
        let macroRaw = 15.0 + (baseRisk * 25.0) // VIX-like, 15-40

        return [
            RiskFactor(
                type: .logRegression,
                rawValue: log10(baseRisk + 0.5) - 0.2,
                normalizedValue: baseRisk,
                weight: weights.logRegression
            ),
            RiskFactor(
                type: .rsi,
                rawValue: rsiRaw,
                normalizedValue: RiskFactorNormalizer.normalizeRSI(rsiRaw),
                weight: weights.rsi
            ),
            RiskFactor(
                type: .smaPosition,
                rawValue: baseRisk > 0.5 ? 0.7 : 0.3,
                normalizedValue: baseRisk > 0.5 ? 0.7 : 0.3,
                weight: weights.smaPosition
            ),
            RiskFactor(
                type: .fundingRate,
                rawValue: fundingRaw,
                normalizedValue: RiskFactorNormalizer.normalizeFundingRate(fundingRaw),
                weight: weights.fundingRate
            ),
            RiskFactor(
                type: .fearGreed,
                rawValue: fearGreedRaw,
                normalizedValue: RiskFactorNormalizer.normalizeFearGreed(fearGreedRaw),
                weight: weights.fearGreed
            ),
            RiskFactor(
                type: .macroRisk,
                rawValue: macroRaw,
                normalizedValue: RiskFactorNormalizer.normalizeVIX(macroRaw),
                weight: weights.macroRisk
            )
        ]
    }

    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: simulatedDelay)
    }

    private func generateMockRiskHistory(for coin: String) -> [RiskHistoryPoint] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var history: [RiskHistoryPoint] = []

        // Base values per coin for variety
        let (baseRisk, basePrice, baseFairValue): (Double, Double, Double)
        switch coin.uppercased() {
        case "BTC":
            baseRisk = 0.45
            basePrice = 95000
            baseFairValue = 85000
        case "ETH":
            baseRisk = 0.52
            basePrice = 3200
            baseFairValue = 2800
        case "SOL":
            baseRisk = 0.58
            basePrice = 180
            baseFairValue = 150
        case "XRP":
            baseRisk = 0.42
            basePrice = 2.50
            baseFairValue = 2.20
        case "DOGE":
            baseRisk = 0.48
            basePrice = 0.35
            baseFairValue = 0.30
        case "ADA":
            baseRisk = 0.40
            basePrice = 1.00
            baseFairValue = 0.90
        case "AVAX":
            baseRisk = 0.55
            basePrice = 35
            baseFairValue = 30
        case "LINK":
            baseRisk = 0.50
            basePrice = 22
            baseFairValue = 20
        case "DOT":
            baseRisk = 0.44
            basePrice = 8
            baseFairValue = 7.5
        case "MATIC":
            baseRisk = 0.46
            basePrice = 0.45
            baseFairValue = 0.42
        default:
            baseRisk = 0.50
            basePrice = 100
            baseFairValue = 90
        }

        // Generate 365 days of mock data
        for i in (0..<365).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { continue }
            let dateString = dateFormatter.string(from: date)

            // Generate variation based on day
            let variation = sin(Double(i) * 0.05) * 0.15
            let noise = Double.random(in: -0.05...0.05)
            let riskLevel = max(0.0, min(1.0, baseRisk + variation + noise))

            // Calculate price and fair value with corresponding variation
            let priceVariation = 1.0 + (sin(Double(i) * 0.05) * 0.2)
            let price = basePrice * priceVariation
            let fairValue = baseFairValue * (1.0 + sin(Double(i) * 0.03) * 0.1)
            let deviation = log10(price) - log10(fairValue)

            history.append(RiskHistoryPoint(
                dateString: dateString,
                date: date,
                riskLevel: riskLevel,
                price: price,
                fairValue: fairValue,
                deviation: deviation
            ))
        }

        return history
    }
}
