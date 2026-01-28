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

    // MARK: - Search Debouncing
    private var searchTask: Task<Void, Never>?
    private let searchDebounceInterval: UInt64 = 500_000_000 // 500ms in nanoseconds

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

    // Fed Watch
    var fedWatchData: FedWatchData?
    var fedWatchMeetings: [FedWatchData] = []

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

        // Fetch Fed Watch independently (doesn't depend on other APIs)
        let meetings = await fetchFedWatchMeetingsSafe()
        await MainActor.run {
            self.fedWatchMeetings = meetings ?? []
            self.fedWatchData = meetings?.first
        }

        // Fetch news independently (doesn't depend on other APIs)
        let news = await fetchNewsSafe()
        await MainActor.run {
            self.newsItems = news
        }

        do {
            async let cryptoTask = marketService.fetchCryptoAssets(page: 1, perPage: 50)
            async let stocksTask = marketService.fetchStockAssets(symbols: ["AAPL", "NVDA"])
            async let metalsTask = marketService.fetchMetalAssets(symbols: ["XAU", "XAG", "XPT", "XPD"])
            async let globalTask = marketService.fetchGlobalMarketData()

            let (crypto, stocks, metals, global) = try await (cryptoTask, stocksTask, metalsTask, globalTask)

            await MainActor.run {
                self.cryptoAssets = crypto
                self.stockAssets = stocks
                self.metalAssets = metals
                self.updateDerivedData()
                self.totalMarketCap = global.data.totalMarketCap["usd"] ?? 0
                self.total24hVolume = global.data.totalVolume["usd"] ?? 0
                self.btcDominance = global.data.marketCapPercentage["btc"] ?? 0
                self.marketCapChange24h = global.data.marketCapChangePercentage24hUsd
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    /// Safely fetches news without throwing errors
    /// Uses user's topic preferences from Settings if available
    private func fetchNewsSafe() async -> [NewsItem] {
        // Load user's news topic preferences from UserDefaults
        var selectedTopics: Set<Constants.NewsTopic>? = nil
        var customKeywords: [String]? = nil

        if let data = UserDefaults.standard.data(forKey: Constants.UserDefaults.selectedNewsTopics),
           let topics = try? JSONDecoder().decode(Set<Constants.NewsTopic>.self, from: data),
           !topics.isEmpty {
            selectedTopics = topics
        }

        if let custom = UserDefaults.standard.stringArray(forKey: Constants.UserDefaults.customNewsTopics),
           !custom.isEmpty {
            customKeywords = custom
        }

        // Increase limit when user has custom keywords to ensure coverage
        let hasCustomization = selectedTopics != nil || customKeywords != nil
        let fetchLimit = hasCustomization ? 30 : 15

        do {
            return try await newsService.fetchCombinedNewsFeed(
                limit: fetchLimit,
                includeTwitter: true,
                includeGoogleNews: true,
                topics: selectedTopics,
                customKeywords: customKeywords
            )
        } catch {
            print("⚠️ News fetch failed: \(error)")
            return []
        }
    }

    private func fetchFedWatchMeetingsSafe() async -> [FedWatchData]? {
        print("🏛️ MarketVM: Fetching Fed Watch meetings...")
        do {
            let meetings = try await newsService.fetchFedWatchMeetings()
            print("🏛️ MarketVM: Got \(meetings.count) meetings")
            return meetings
        } catch {
            print("🏛️ MarketVM: Error fetching Fed Watch: \(error)")
            return nil
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

    func searchAssets(query: String) {
        // Cancel any pending search
        searchTask?.cancel()

        guard !query.isEmpty else {
            searchText = ""
            return
        }

        // Debounce: wait before executing search
        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: searchDebounceInterval)

                // Check if cancelled during sleep
                guard !Task.isCancelled else { return }

                let results = try await marketService.searchCrypto(query: query)

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.cryptoAssets = results
                }
            } catch is CancellationError {
                // Search was cancelled, ignore
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
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
    let sourceType: NewsSourceType
    let twitterHandle: String? // For Twitter sources
    let isVerified: Bool // Twitter verified badge
    let description: String? // Full content/body of the news

    init(
        id: UUID,
        title: String,
        source: String,
        publishedAt: Date,
        imageUrl: String? = nil,
        url: String,
        sourceType: NewsSourceType = .traditional,
        twitterHandle: String? = nil,
        isVerified: Bool = false,
        description: String? = nil
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.publishedAt = publishedAt
        self.imageUrl = imageUrl
        self.url = url
        self.sourceType = sourceType
        self.twitterHandle = twitterHandle
        self.isVerified = isVerified
        self.description = description
    }
}

// MARK: - News Source Type
enum NewsSourceType: String, CaseIterable {
    case twitter = "Twitter"
    case googleNews = "Google News"
    case traditional = "News"

    var icon: String {
        switch self {
        case .twitter: return "bird" // X logo approximation
        case .googleNews: return "g.circle.fill"
        case .traditional: return "newspaper"
        }
    }

    var accentColor: String {
        switch self {
        case .twitter: return "#1DA1F2" // Twitter blue
        case .googleNews: return "#4285F4" // Google blue
        case .traditional: return "#6366F1"
        }
    }

    var displayName: String {
        switch self {
        case .twitter: return "X"
        case .googleNews: return "Google"
        case .traditional: return "News"
        }
    }
}

// MARK: - Tracked Twitter Accounts
/// Key crypto Twitter accounts to monitor for news
enum TrackedTwitterAccount: String, CaseIterable {
    // Breaking News & Alerts
    case watcherguru = "WatcherGuru"
    case zerohedge = "zerohedge"
    case deltaone = "DeItaone"
    case whale_alert = "whale_alert"

    // Market & Macro Analysis
    case kobeissiletter = "KobeissiLetter"
    case brics = "BRICSinfo"
    case mikealfred = "mikealfred"
    case unusual_whales = "unusual_whales"
    case wallstjesus = "WallStJesus"

    // Crypto News & Analysis
    case documentingbtc = "DocumentingBTC"
    case bitcoinmagazine = "BitcoinMagazine"
    case lookonchain = "lookonchain"
    case theblock__ = "TheBlock__"

    var displayName: String {
        switch self {
        case .watcherguru: return "Watcher.Guru"
        case .zerohedge: return "ZeroHedge"
        case .deltaone: return "DeItaone"
        case .whale_alert: return "Whale Alert"
        case .kobeissiletter: return "The Kobeissi Letter"
        case .brics: return "BRICS News"
        case .mikealfred: return "Mike Alfred"
        case .unusual_whales: return "Unusual Whales"
        case .wallstjesus: return "Wall St Jesus"
        case .documentingbtc: return "Documenting BTC"
        case .bitcoinmagazine: return "Bitcoin Magazine"
        case .lookonchain: return "Lookonchain"
        case .theblock__: return "The Block"
        }
    }

    var isVerified: Bool {
        // Most major accounts are verified
        true
    }

    var category: TwitterAccountCategory {
        switch self {
        case .watcherguru, .zerohedge, .deltaone, .whale_alert:
            return .breakingNews
        case .kobeissiletter, .brics, .mikealfred, .unusual_whales, .wallstjesus:
            return .macro
        case .documentingbtc, .bitcoinmagazine, .lookonchain, .theblock__:
            return .crypto
        }
    }
}

enum TwitterAccountCategory: String {
    case breakingNews = "Breaking"
    case macro = "Macro"
    case crypto = "Crypto"

    var color: String {
        switch self {
        case .breakingNews: return "#EF4444" // Red for breaking news
        case .macro: return "#22C55E"        // Green for macro
        case .crypto: return "#F7931A"       // Orange for crypto
        }
    }
}
