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
    // MARK: - Dependencies
    private let marketService: MarketServiceProtocol
    private let newsService: NewsServiceProtocol

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

    // Stock Assets (for segment control)
    var stockAssets: [StockAsset] = []

    // Metal Assets (for segment control)
    var metalAssets: [MetalAsset] = []

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
    init(
        marketService: MarketServiceProtocol = ServiceContainer.shared.marketService,
        newsService: NewsServiceProtocol = ServiceContainer.shared.newsService
    ) {
        self.marketService = marketService
        self.newsService = newsService
        Task { await loadInitialData() }
    }

    // MARK: - Public Methods
    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            async let cryptoTask = marketService.fetchCryptoAssets(page: 1, perPage: 50)
            async let stocksTask = marketService.fetchStockAssets(symbols: ["AAPL", "MSFT", "NVDA", "TSLA", "NOK", "PLUG"])
            async let metalsTask = marketService.fetchMetalAssets(symbols: ["XAU", "XAG", "XPT", "XPD"])
            async let globalTask = marketService.fetchGlobalMarketData()
            async let newsTask = newsService.fetchNews(category: nil, page: 1, perPage: 10)

            let (crypto, stocks, metals, global, news) = try await (cryptoTask, stocksTask, metalsTask, globalTask, newsTask)

            await MainActor.run {
                self.cryptoAssets = crypto
                self.stockAssets = stocks
                self.metalAssets = metals
                self.updateDerivedData()
                self.totalMarketCap = global.data.totalMarketCap["usd"] ?? 0
                self.total24hVolume = global.data.totalVolume["usd"] ?? 0
                self.btcDominance = global.data.marketCapPercentage["btc"] ?? 0
                self.marketCapChange24h = global.data.marketCapChangePercentage24hUsd
                self.newsItems = news
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

    func loadMoreCrypto() async {
        guard !isLoading else { return }

        let nextPage = (cryptoAssets.count / 50) + 1

        do {
            let moreAssets = try await marketService.fetchCryptoAssets(page: nextPage, perPage: 50)

            await MainActor.run {
                self.cryptoAssets.append(contentsOf: moreAssets)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func searchAssets(query: String) async {
        guard !query.isEmpty else {
            await MainActor.run {
                self.searchText = ""
            }
            return
        }

        do {
            let results = try await marketService.searchCrypto(query: query)

            await MainActor.run {
                self.cryptoAssets = results
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Private Methods
    private func loadInitialData() async {
        await refresh()
    }

    private func updateDerivedData() {
        trendingAssets = Array(cryptoAssets.prefix(5))
        topGainers = cryptoAssets.sorted { $0.priceChangePercentage24h > $1.priceChangePercentage24h }.prefix(5).map { $0 }
        topLosers = cryptoAssets.sorted { $0.priceChangePercentage24h < $1.priceChangePercentage24h }.prefix(5).map { $0 }
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
