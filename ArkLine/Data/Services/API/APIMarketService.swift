import Foundation

// MARK: - API Market Service
/// Real API implementation of MarketServiceProtocol.
/// Uses CoinGecko, FMP, and Metals API for data.
final class APIMarketService: MarketServiceProtocol {
    // MARK: - Dependencies
    private let networkManager = NetworkManager.shared
    private let cache = APICache.shared
    private let sharedCache = SharedCacheService.shared
    private let fmpService = FMPService.shared

    // MARK: - MarketServiceProtocol

    func fetchCryptoAssets(page: Int, perPage: Int) async throws -> [CryptoAsset] {
        let cacheKey = CacheKey.cryptoAssets(page: page, perPage: perPage)

        return try await sharedCache.getOrFetch(cacheKey, ttl: APICache.TTL.medium) { [networkManager] in
            let endpoint = CoinGeckoEndpoint.coinMarkets(
                currency: "usd",
                page: page,
                perPage: perPage,
                sparkline: true
            )
            let assets: [CryptoAsset] = try await networkManager.request(endpoint)
            return assets
        }
    }

    func fetchStockAssets(symbols: [String]) async throws -> [StockAsset] {
        let cacheKey = CacheKey.stockAssets(symbols: symbols)

        return try await sharedCache.getOrFetch(cacheKey, ttl: APICache.TTL.long) { [fmpService] in
            do {
                let quotes = try await fmpService.fetchStockQuotes(symbols: symbols)
                return quotes.map { $0.toStockAsset() }
            } catch {
                logError("Failed to fetch stocks via FMP: \(error)")
                throw error
            }
        }
    }

    func fetchMetalAssets(symbols: [String]) async throws -> [MetalAsset] {
        let cacheKey = CacheKey.metalAssets(symbols: symbols)

        return try await sharedCache.getOrFetch(cacheKey, ttl: APICache.TTL.long) { [networkManager] in
            let endpoint = MetalsAPIEndpoint.latest(base: "USD", symbols: symbols)

            let response: MetalsAPIResponse = try await networkManager.request(endpoint)

            let metalNames = ["XAU": "Gold", "XAG": "Silver", "XPT": "Platinum", "XPD": "Palladium"]

            return symbols.compactMap { symbol -> MetalAsset? in
                guard let rate = response.rates[symbol] else { return nil }

                // Metals API returns rates per USD, we need to invert for price per unit
                let price = 1.0 / rate

                return MetalAsset(
                    id: symbol.lowercased(),
                    symbol: symbol,
                    name: metalNames[symbol] ?? symbol,
                    currentPrice: price,
                    priceChange24h: 0, // Would need historical data
                    priceChangePercentage24h: 0,
                    iconUrl: nil,
                    unit: "oz",
                    currency: "USD",
                    timestamp: Date()
                )
            }
        }
    }

    func fetchGlobalMarketData() async throws -> CoinGeckoGlobalData {
        return try await sharedCache.getOrFetch(CacheKey.globalMarketData, ttl: APICache.TTL.medium) { [networkManager] in
            let endpoint = CoinGeckoEndpoint.globalData
            return try await networkManager.request(endpoint)
        }
    }

    func fetchTrendingCrypto() async throws -> [CryptoAsset] {
        return try await sharedCache.getOrFetch(CacheKey.trendingCoins, ttl: APICache.TTL.long) { [networkManager] in
            let endpoint = CoinGeckoEndpoint.trendingCoins
            let response: CoinGeckoTrendingResponse = try await networkManager.request(endpoint)

            // Convert trending coins to CryptoAsset
            // Note: Trending endpoint doesn't include price data, would need additional calls
            let coinIds = response.coins.map { $0.item.id }

            // Fetch price data for trending coins
            let filterEndpoint = CoinGeckoEndpoint.coinMarketsFiltered(
                currency: "usd",
                ids: coinIds,
                sparkline: false
            )
            return try await networkManager.request(filterEndpoint)
        }
    }

    func searchCrypto(query: String) async throws -> [CryptoAsset] {
        let endpoint = CoinGeckoEndpoint.searchCoins(query: query)
        let response: CoinGeckoSearchResponse = try await networkManager.request(endpoint)

        // Search endpoint returns minimal data, fetch full market data for top results
        let topIds = response.coins.prefix(20).map { $0.id }

        guard !topIds.isEmpty else { return [] }

        return try await fetchCryptoAssets(ids: Array(topIds))
    }

    func searchStocks(query: String) async throws -> [StockSearchResult] {
        return try await fmpService.searchStocks(query: query)
    }

    func fetchCoinMarketChart(id: String, currency: String, days: Int) async throws -> CoinGeckoMarketChart {
        let endpoint = CoinGeckoEndpoint.coinMarketChart(id: id, currency: currency, days: days)
        return try await networkManager.request(endpoint)
    }

    // MARK: - Private Helpers

    private func fetchCryptoAssets(ids: [String]) async throws -> [CryptoAsset] {
        let endpoint = CoinGeckoEndpoint.coinMarketsFiltered(
            currency: "usd",
            ids: ids,
            sparkline: false
        )
        return try await networkManager.request(endpoint)
    }

    private func metalName(for symbol: String) -> String {
        switch symbol {
        case "XAU": return "Gold"
        case "XAG": return "Silver"
        case "XPT": return "Platinum"
        case "XPD": return "Palladium"
        default: return symbol
        }
    }
}
