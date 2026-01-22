import Foundation

// MARK: - Mock Technical Analysis Service
/// Mock implementation of TechnicalAnalysisServiceProtocol for development and testing.
/// Uses the TechnicalAnalysisGenerator to create realistic mock data.
final class MockTechnicalAnalysisService: TechnicalAnalysisServiceProtocol {
    // MARK: - Configuration
    var simulatedDelay: UInt64 = 500_000_000 // 0.5 seconds

    // MARK: - TechnicalAnalysisServiceProtocol

    func fetchTechnicalAnalysis(symbol: String, exchange: String) async throws -> TechnicalAnalysis {
        try await simulateNetworkDelay()

        // Create a mock CryptoAsset to use with the generator
        let assetSymbol = symbol.split(separator: "/").first.map(String.init) ?? symbol
        let mockAsset = CryptoAsset(
            id: assetSymbol.lowercased(),
            symbol: assetSymbol,
            name: assetSymbol,
            currentPrice: mockPrice(for: assetSymbol),
            priceChange24h: mockPriceChange(for: assetSymbol),
            priceChangePercentage24h: mockPriceChangePercent(for: assetSymbol),
            iconUrl: nil,
            marketCap: 0,
            marketCapRank: 0
        )

        return TechnicalAnalysisGenerator.generate(for: mockAsset)
    }

    func fetchSMAValues(symbol: String, exchange: String, periods: [Int], interval: String) async throws -> [Int: Double] {
        try await simulateNetworkDelay()

        let assetSymbol = symbol.split(separator: "/").first.map(String.init) ?? symbol
        let currentPrice = mockPrice(for: assetSymbol)
        let isPositive = mockPriceChangePercent(for: assetSymbol) >= 0

        var results: [Int: Double] = [:]
        for period in periods {
            let offset: Double
            switch period {
            case 21:
                offset = isPositive ? 0.97 : 1.03
            case 50:
                offset = isPositive ? 0.92 : 1.08
            case 200:
                offset = isPositive ? 0.85 : 1.15
            default:
                offset = 1.0
            }
            results[period] = currentPrice * offset
        }
        return results
    }

    func fetchBollingerBands(symbol: String, exchange: String, interval: String) async throws -> BollingerBandData {
        try await simulateNetworkDelay()

        let assetSymbol = symbol.split(separator: "/").first.map(String.init) ?? symbol
        let currentPrice = mockPrice(for: assetSymbol)
        let isPositive = mockPriceChangePercent(for: assetSymbol) >= 0

        let timeframe: BollingerTimeframe
        let volatility: Double
        switch interval {
        case "1w":
            timeframe = .weekly
            volatility = 0.08
        case "1M":
            timeframe = .monthly
            volatility = 0.12
        default:
            timeframe = .daily
            volatility = 0.05
        }

        let middleBand = currentPrice * (isPositive ? 0.98 : 1.02)
        let upperBand = middleBand * (1 + volatility)
        let lowerBand = middleBand * (1 - volatility)

        let position: BollingerPosition
        let percentB = (currentPrice - lowerBand) / (upperBand - lowerBand)
        if percentB > 1.0 {
            position = .aboveUpper
        } else if percentB > 0.8 {
            position = .nearUpper
        } else if percentB > 0.2 {
            position = .middle
        } else if percentB > 0 {
            position = .nearLower
        } else {
            position = .belowLower
        }

        return BollingerBandData(
            timeframe: timeframe,
            upperBand: upperBand,
            middleBand: middleBand,
            lowerBand: lowerBand,
            currentPrice: currentPrice,
            bandwidth: (upperBand - lowerBand) / middleBand,
            position: position
        )
    }

    func fetchCurrentPrice(symbol: String, exchange: String) async throws -> Double {
        try await simulateNetworkDelay()
        let assetSymbol = symbol.split(separator: "/").first.map(String.init) ?? symbol
        return mockPrice(for: assetSymbol)
    }

    func fetchRSI(symbol: String, exchange: String, interval: String, period: Int) async throws -> Double {
        try await simulateNetworkDelay()
        let assetSymbol = symbol.split(separator: "/").first.map(String.init) ?? symbol
        let isPositive = mockPriceChangePercent(for: assetSymbol) >= 0
        // RSI tends to be higher in uptrends, lower in downtrends
        return isPositive ? Double.random(in: 55...75) : Double.random(in: 25...45)
    }

    // MARK: - Private Helpers

    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: simulatedDelay)
    }

    private func mockPrice(for symbol: String) -> Double {
        switch symbol.uppercased() {
        case "BTC":
            return 97234.50
        case "ETH":
            return 3456.78
        case "SOL":
            return 245.32
        case "DOGE":
            return 0.42
        case "XRP":
            return 2.85
        case "ADA":
            return 1.12
        case "AVAX":
            return 42.50
        case "DOT":
            return 8.75
        case "LINK":
            return 18.90
        case "MATIC":
            return 0.95
        default:
            return 100.0
        }
    }

    private func mockPriceChange(for symbol: String) -> Double {
        switch symbol.uppercased() {
        case "BTC":
            return 1523.40
        case "ETH":
            return -45.23
        case "SOL":
            return 12.50
        case "DOGE":
            return 0.015
        default:
            return Double.random(in: -10...10)
        }
    }

    private func mockPriceChangePercent(for symbol: String) -> Double {
        switch symbol.uppercased() {
        case "BTC":
            return 2.32
        case "ETH":
            return -1.29
        case "SOL":
            return 5.45
        case "DOGE":
            return 3.71
        case "XRP":
            return -0.85
        case "ADA":
            return 1.20
        default:
            return Double.random(in: -5...5)
        }
    }
}
