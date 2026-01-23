import Foundation

// MARK: - Mock Market Service
/// Mock implementation of MarketServiceProtocol for development and testing.
final class MockMarketService: MarketServiceProtocol {
    // MARK: - Configuration
    /// Simulated network delay in nanoseconds
    var simulatedDelay: UInt64 = 500_000_000

    // MARK: - MarketServiceProtocol

    func fetchCryptoAssets(page: Int, perPage: Int) async throws -> [CryptoAsset] {
        try await simulateNetworkDelay()
        return generateMockCryptoAssets()
    }

    func fetchStockAssets(symbols: [String]) async throws -> [StockAsset] {
        try await simulateNetworkDelay()
        return generateMockStockAssets().filter { symbols.isEmpty || symbols.contains($0.symbol) }
    }

    func fetchMetalAssets(symbols: [String]) async throws -> [MetalAsset] {
        try await simulateNetworkDelay()
        return generateMockMetalAssets().filter { symbols.isEmpty || symbols.contains($0.symbol) }
    }

    func fetchGlobalMarketData() async throws -> CoinGeckoGlobalData {
        try await simulateNetworkDelay()
        return generateMockGlobalData()
    }

    func fetchTrendingCrypto() async throws -> [CryptoAsset] {
        try await simulateNetworkDelay()
        return Array(generateMockCryptoAssets().prefix(5))
    }

    func searchCrypto(query: String) async throws -> [CryptoAsset] {
        try await simulateNetworkDelay()
        let allAssets = generateMockCryptoAssets()
        guard !query.isEmpty else { return allAssets }
        return allAssets.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.symbol.localizedCaseInsensitiveContains(query)
        }
    }

    func searchStocks(query: String) async throws -> [AlphaVantageSearchMatch] {
        try await simulateNetworkDelay()
        // Return mock stock search results
        let mockStocks = [
            AlphaVantageSearchMatch(symbol: "AAPL", name: "Apple Inc", type: "Equity", region: "United States", marketOpen: "09:30", marketClose: "16:00", timezone: "UTC-04", currency: "USD", matchScore: "1.0"),
            AlphaVantageSearchMatch(symbol: "NVDA", name: "NVIDIA Corporation", type: "Equity", region: "United States", marketOpen: "09:30", marketClose: "16:00", timezone: "UTC-04", currency: "USD", matchScore: "1.0"),
            AlphaVantageSearchMatch(symbol: "MSFT", name: "Microsoft Corporation", type: "Equity", region: "United States", marketOpen: "09:30", marketClose: "16:00", timezone: "UTC-04", currency: "USD", matchScore: "1.0"),
            AlphaVantageSearchMatch(symbol: "GOOGL", name: "Alphabet Inc", type: "Equity", region: "United States", marketOpen: "09:30", marketClose: "16:00", timezone: "UTC-04", currency: "USD", matchScore: "1.0"),
            AlphaVantageSearchMatch(symbol: "AMZN", name: "Amazon.com Inc", type: "Equity", region: "United States", marketOpen: "09:30", marketClose: "16:00", timezone: "UTC-04", currency: "USD", matchScore: "1.0"),
        ]
        guard !query.isEmpty else { return mockStocks }
        return mockStocks.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.symbol.localizedCaseInsensitiveContains(query)
        }
    }

    func fetchCoinMarketChart(id: String, currency: String, days: Int) async throws -> CoinGeckoMarketChart {
        try await simulateNetworkDelay()
        return generateMockMarketChart(days: days)
    }

    // MARK: - Private Helpers

    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: simulatedDelay)
    }

    private func generateMockCryptoAssets() -> [CryptoAsset] {
        [
            CryptoAsset(
                id: "bitcoin",
                symbol: "BTC",
                name: "Bitcoin",
                currentPrice: 67234.50,
                priceChange24h: 1523.40,
                priceChangePercentage24h: 2.32,
                iconUrl: "https://assets.coingecko.com/coins/images/1/large/bitcoin.png",
                marketCap: 1324500000000,
                marketCapRank: 1,
                sparklineIn7d: generateSparklineData()
            ),
            CryptoAsset(
                id: "ethereum",
                symbol: "ETH",
                name: "Ethereum",
                currentPrice: 3456.78,
                priceChange24h: -45.23,
                priceChangePercentage24h: -1.29,
                iconUrl: "https://assets.coingecko.com/coins/images/279/large/ethereum.png",
                marketCap: 415600000000,
                marketCapRank: 2,
                sparklineIn7d: generateSparklineData()
            ),
            CryptoAsset(
                id: "tether",
                symbol: "USDT",
                name: "Tether",
                currentPrice: 1.00,
                priceChange24h: 0.001,
                priceChangePercentage24h: 0.01,
                iconUrl: "https://assets.coingecko.com/coins/images/325/large/Tether.png",
                marketCap: 112000000000,
                marketCapRank: 3,
                sparklineIn7d: generateSparklineData(basePrice: 1.0, volatility: 0.001)
            ),
            CryptoAsset(
                id: "binancecoin",
                symbol: "BNB",
                name: "BNB",
                currentPrice: 598.45,
                priceChange24h: 12.34,
                priceChangePercentage24h: 2.11,
                iconUrl: "https://assets.coingecko.com/coins/images/825/large/bnb-icon2_2x.png",
                marketCap: 89200000000,
                marketCapRank: 4,
                sparklineIn7d: generateSparklineData()
            ),
            CryptoAsset(
                id: "solana",
                symbol: "SOL",
                name: "Solana",
                currentPrice: 145.67,
                priceChange24h: 8.92,
                priceChangePercentage24h: 6.52,
                iconUrl: "https://assets.coingecko.com/coins/images/4128/large/solana.png",
                marketCap: 67800000000,
                marketCapRank: 5,
                sparklineIn7d: generateSparklineData()
            ),
            CryptoAsset(
                id: "ripple",
                symbol: "XRP",
                name: "XRP",
                currentPrice: 0.52,
                priceChange24h: -0.02,
                priceChangePercentage24h: -3.71,
                iconUrl: "https://assets.coingecko.com/coins/images/44/large/xrp-symbol-white-128.png",
                marketCap: 28500000000,
                marketCapRank: 6,
                sparklineIn7d: generateSparklineData()
            ),
            CryptoAsset(
                id: "cardano",
                symbol: "ADA",
                name: "Cardano",
                currentPrice: 0.45,
                priceChange24h: 0.03,
                priceChangePercentage24h: 7.14,
                iconUrl: "https://assets.coingecko.com/coins/images/975/large/cardano.png",
                marketCap: 16200000000,
                marketCapRank: 8,
                sparklineIn7d: generateSparklineData()
            ),
            CryptoAsset(
                id: "dogecoin",
                symbol: "DOGE",
                name: "Dogecoin",
                currentPrice: 0.12,
                priceChange24h: 0.008,
                priceChangePercentage24h: 7.14,
                iconUrl: "https://assets.coingecko.com/coins/images/5/large/dogecoin.png",
                marketCap: 17500000000,
                marketCapRank: 9,
                sparklineIn7d: generateSparklineData()
            ),
            CryptoAsset(
                id: "avalanche",
                symbol: "AVAX",
                name: "Avalanche",
                currentPrice: 35.67,
                priceChange24h: -1.23,
                priceChangePercentage24h: -3.33,
                iconUrl: "https://assets.coingecko.com/coins/images/12559/large/Avalanche_Circle_RedWhite_Trans.png",
                marketCap: 14200000000,
                marketCapRank: 10,
                sparklineIn7d: generateSparklineData()
            ),
            CryptoAsset(
                id: "polkadot",
                symbol: "DOT",
                name: "Polkadot",
                currentPrice: 7.23,
                priceChange24h: 0.45,
                priceChangePercentage24h: 6.63,
                iconUrl: "https://assets.coingecko.com/coins/images/12171/large/polkadot.png",
                marketCap: 10500000000,
                marketCapRank: 11,
                sparklineIn7d: generateSparklineData()
            )
        ]
    }

    private func generateMockStockAssets() -> [StockAsset] {
        [
            StockAsset(
                id: "nvda",
                symbol: "NVDA",
                name: "NVIDIA Corporation",
                currentPrice: 208.29,
                priceChange24h: -2.00,
                priceChangePercentage24h: -0.95,
                iconUrl: nil
            ),
            StockAsset(
                id: "nok",
                symbol: "NOK",
                name: "Nokia Oyj",
                currentPrice: 4.52,
                priceChange24h: -0.04,
                priceChangePercentage24h: -0.95,
                iconUrl: nil
            ),
            StockAsset(
                id: "plug",
                symbol: "PLUG",
                name: "Plug Power Inc.",
                currentPrice: 7.46,
                priceChange24h: 0.33,
                priceChangePercentage24h: 4.63,
                iconUrl: nil
            ),
            StockAsset(
                id: "aapl",
                symbol: "AAPL",
                name: "Apple Inc.",
                currentPrice: 189.95,
                priceChange24h: 1.25,
                priceChangePercentage24h: 0.66,
                iconUrl: nil
            ),
            StockAsset(
                id: "msft",
                symbol: "MSFT",
                name: "Microsoft Corp.",
                currentPrice: 415.50,
                priceChange24h: -3.20,
                priceChangePercentage24h: -0.76,
                iconUrl: nil
            ),
            StockAsset(
                id: "tsla",
                symbol: "TSLA",
                name: "Tesla Inc.",
                currentPrice: 248.75,
                priceChange24h: 5.40,
                priceChangePercentage24h: 2.22,
                iconUrl: nil
            )
        ]
    }

    private func generateMockMetalAssets() -> [MetalAsset] {
        [
            MetalAsset(
                id: "gold",
                symbol: "XAU",
                name: "Gold",
                currentPrice: 2345.80,
                priceChange24h: 12.50,
                priceChangePercentage24h: 0.54,
                iconUrl: nil,
                unit: "oz",
                currency: "USD"
            ),
            MetalAsset(
                id: "silver",
                symbol: "XAG",
                name: "Silver",
                currentPrice: 27.85,
                priceChange24h: 0.35,
                priceChangePercentage24h: 1.27,
                iconUrl: nil,
                unit: "oz",
                currency: "USD"
            ),
            MetalAsset(
                id: "platinum",
                symbol: "XPT",
                name: "Platinum",
                currentPrice: 985.40,
                priceChange24h: -8.20,
                priceChangePercentage24h: -0.83,
                iconUrl: nil,
                unit: "oz",
                currency: "USD"
            ),
            MetalAsset(
                id: "palladium",
                symbol: "XPD",
                name: "Palladium",
                currentPrice: 1025.60,
                priceChange24h: 15.30,
                priceChangePercentage24h: 1.51,
                iconUrl: nil,
                unit: "oz",
                currency: "USD"
            )
        ]
    }

    private func generateMockGlobalData() -> CoinGeckoGlobalData {
        CoinGeckoGlobalData(
            data: CoinGeckoGlobalData.GlobalMarketData(
                activeCryptocurrencies: 15234,
                upcomingIcos: 0,
                ongoingIcos: 0,
                endedIcos: 3376,
                markets: 1089,
                totalMarketCap: ["usd": 2450000000000],
                totalVolume: ["usd": 98500000000],
                marketCapPercentage: ["btc": 52.3, "eth": 17.1],
                marketCapChangePercentage24hUsd: 1.8,
                updatedAt: Int(Date().timeIntervalSince1970)
            )
        )
    }

    private func generateMockMarketChart(days: Int) -> CoinGeckoMarketChart {
        var prices: [[Double]] = []
        let basePrice = 67000.0
        let now = Date().timeIntervalSince1970 * 1000

        for i in 0..<(days * 24) {
            let timestamp = now - Double((days * 24 - i) * 3600 * 1000)
            let change = Double.random(in: -0.02...0.02)
            let price = basePrice * (1 + change * Double(i) / Double(days * 24))
            prices.append([timestamp, price])
        }

        return CoinGeckoMarketChart(
            prices: prices,
            marketCaps: prices.map { [$0[0], $0[1] * 19_500_000] },
            totalVolumes: prices.map { [$0[0], Double.random(in: 20_000_000_000...50_000_000_000)] }
        )
    }

    private func generateSparklineData(basePrice: Double = 100, volatility: Double = 0.03) -> SparklineData {
        var data: [Double] = []
        var price = basePrice
        for _ in 0..<168 { // 7 days * 24 hours
            let change = Double.random(in: -volatility...volatility)
            price *= (1 + change)
            data.append(price)
        }
        return SparklineData(price: data)
    }
}
