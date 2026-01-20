import SwiftUI

// MARK: - Market Tab
enum MarketTab: String, CaseIterable {
    case overview = "Overview"
    case sentiment = "Sentiment"
    case assets = "Assets"
    case news = "News"
}

// MARK: - Asset Category Filter
enum AssetCategoryFilter: String, CaseIterable {
    case all = "All"
    case crypto = "Crypto"
    case stocks = "Stocks"
    case metals = "Metals"
}

// MARK: - Market View Model
@Observable
class MarketViewModel {
    // MARK: - Properties
    var selectedTab: MarketTab = .overview
    var selectedCategory: AssetCategoryFilter = .all
    var searchText: String = ""
    var isLoading = false
    var errorMessage: String?

    // Crypto Assets
    var cryptoAssets: [CryptoAsset] = []
    var trendingAssets: [CryptoAsset] = []
    var topGainers: [CryptoAsset] = []
    var topLosers: [CryptoAsset] = []

    // Market Stats
    var totalMarketCap: Double = 0
    var total24hVolume: Double = 0
    var btcDominance: Double = 0
    var marketCapChange24h: Double = 0

    // News
    var newsItems: [NewsItem] = []

    // MARK: - Computed Properties
    var filteredAssets: [CryptoAsset] {
        var assets = cryptoAssets

        if !searchText.isEmpty {
            assets = assets.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.symbol.localizedCaseInsensitiveContains(searchText)
            }
        }

        return assets
    }

    // MARK: - Initialization
    init() {
        loadMockData()
    }

    // MARK: - Public Methods
    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            async let assets = fetchCryptoAssets()
            async let stats = fetchMarketStats()
            async let news = fetchNews()

            let (a, s, n) = try await (assets, stats, news)

            await MainActor.run {
                self.cryptoAssets = a
                self.updateDerivedData()
                self.totalMarketCap = s.marketCap
                self.total24hVolume = s.volume
                self.btcDominance = s.btcDominance
                self.marketCapChange24h = s.change
                self.newsItems = n
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func selectCategory(_ category: AssetCategoryFilter) {
        selectedCategory = category
    }

    // MARK: - Private Methods
    private func fetchCryptoAssets() async throws -> [CryptoAsset] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return generateMockCryptoAssets()
    }

    private func fetchMarketStats() async throws -> (marketCap: Double, volume: Double, btcDominance: Double, change: Double) {
        try await Task.sleep(nanoseconds: 300_000_000)
        return (2_450_000_000_000, 98_500_000_000, 52.3, 1.8)
    }

    private func fetchNews() async throws -> [NewsItem] {
        try await Task.sleep(nanoseconds: 400_000_000)
        return generateMockNews()
    }

    private func updateDerivedData() {
        trendingAssets = Array(cryptoAssets.prefix(5))
        topGainers = cryptoAssets.sorted { $0.priceChangePercentage24h > $1.priceChangePercentage24h }.prefix(5).map { $0 }
        topLosers = cryptoAssets.sorted { $0.priceChangePercentage24h < $1.priceChangePercentage24h }.prefix(5).map { $0 }
    }

    private func loadMockData() {
        cryptoAssets = generateMockCryptoAssets()
        updateDerivedData()
        totalMarketCap = 2_450_000_000_000
        total24hVolume = 98_500_000_000
        btcDominance = 52.3
        marketCapChange24h = 1.8
        newsItems = generateMockNews()
    }

    private func generateMockCryptoAssets() -> [CryptoAsset] {
        [
            CryptoAsset(id: "bitcoin", symbol: "BTC", name: "Bitcoin", currentPrice: 67234.50, priceChange24h: 1523.40, priceChangePercentage24h: 2.32, iconUrl: nil, marketCap: 1324500000000, marketCapRank: 1),
            CryptoAsset(id: "ethereum", symbol: "ETH", name: "Ethereum", currentPrice: 3456.78, priceChange24h: -45.23, priceChangePercentage24h: -1.29, iconUrl: nil, marketCap: 415600000000, marketCapRank: 2),
            CryptoAsset(id: "tether", symbol: "USDT", name: "Tether", currentPrice: 1.00, priceChange24h: 0.001, priceChangePercentage24h: 0.01, iconUrl: nil, marketCap: 112000000000, marketCapRank: 3),
            CryptoAsset(id: "binancecoin", symbol: "BNB", name: "BNB", currentPrice: 598.45, priceChange24h: 12.34, priceChangePercentage24h: 2.11, iconUrl: nil, marketCap: 89200000000, marketCapRank: 4),
            CryptoAsset(id: "solana", symbol: "SOL", name: "Solana", currentPrice: 145.67, priceChange24h: 8.92, priceChangePercentage24h: 6.52, iconUrl: nil, marketCap: 67800000000, marketCapRank: 5),
            CryptoAsset(id: "ripple", symbol: "XRP", name: "XRP", currentPrice: 0.52, priceChange24h: -0.02, priceChangePercentage24h: -3.71, iconUrl: nil, marketCap: 28500000000, marketCapRank: 6),
            CryptoAsset(id: "cardano", symbol: "ADA", name: "Cardano", currentPrice: 0.45, priceChange24h: 0.03, priceChangePercentage24h: 7.14, iconUrl: nil, marketCap: 16200000000, marketCapRank: 8),
            CryptoAsset(id: "dogecoin", symbol: "DOGE", name: "Dogecoin", currentPrice: 0.12, priceChange24h: 0.008, priceChangePercentage24h: 7.14, iconUrl: nil, marketCap: 17500000000, marketCapRank: 9),
            CryptoAsset(id: "avalanche", symbol: "AVAX", name: "Avalanche", currentPrice: 35.67, priceChange24h: -1.23, priceChangePercentage24h: -3.33, iconUrl: nil, marketCap: 14200000000, marketCapRank: 10),
            CryptoAsset(id: "polkadot", symbol: "DOT", name: "Polkadot", currentPrice: 7.23, priceChange24h: 0.45, priceChangePercentage24h: 6.63, iconUrl: nil, marketCap: 10500000000, marketCapRank: 11)
        ]
    }

    private func generateMockNews() -> [NewsItem] {
        [
            NewsItem(id: UUID(), title: "Bitcoin Surges Past $67,000 Amid ETF Inflows", source: "CoinDesk", publishedAt: Date().addingTimeInterval(-3600), imageUrl: nil, url: "https://coindesk.com"),
            NewsItem(id: UUID(), title: "Ethereum Layer 2 Networks See Record Activity", source: "The Block", publishedAt: Date().addingTimeInterval(-7200), imageUrl: nil, url: "https://theblock.co"),
            NewsItem(id: UUID(), title: "Federal Reserve Signals Potential Rate Cut", source: "Reuters", publishedAt: Date().addingTimeInterval(-14400), imageUrl: nil, url: "https://reuters.com"),
            NewsItem(id: UUID(), title: "Solana DeFi TVL Reaches All-Time High", source: "DeFi Llama", publishedAt: Date().addingTimeInterval(-21600), imageUrl: nil, url: "https://defillama.com")
        ]
    }
}

// MARK: - News Item Model
struct NewsItem: Identifiable {
    let id: UUID
    let title: String
    let source: String
    let publishedAt: Date
    let imageUrl: String?
    let url: String
}
