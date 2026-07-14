import Foundation

@Observable
class ModelPortfolioViewModel {
    private let service: ModelPortfolioServiceProtocol

    var portfolios: [ModelPortfolio] = []
    /// NAV + trade history keyed by portfolio id (all asset classes)
    var navByPortfolio: [UUID: [ModelPortfolioNav]] = [:]
    var tradesByPortfolio: [UUID: [ModelPortfolioTrade]] = [:]
    var benchmarkNav: [BenchmarkNav] = []
    var riskHistory: [ModelPortfolioRiskHistory] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Portfolio lookups

    private func sorted(_ list: [ModelPortfolio]) -> [ModelPortfolio] {
        list.sorted { ($0.displayOrder ?? .max, $0.strategy) < ($1.displayOrder ?? .max, $1.strategy) }
    }

    var cryptoPortfolios: [ModelPortfolio] { sorted(portfolios.filter { $0.isCrypto }) }
    var stockPortfolios: [ModelPortfolio] { sorted(portfolios.filter { $0.isStock }) }

    var corePortfolio: ModelPortfolio? { portfolios.first { $0.isCore } }
    var edgePortfolio: ModelPortfolio? { portfolios.first { $0.isEdge } }
    var alphaPortfolio: ModelPortfolio? { portfolios.first { $0.isAlpha } }

    func portfolio(forStrategy strategy: String) -> ModelPortfolio? {
        portfolios.first { $0.strategy == strategy }
    }

    // MARK: - NAV accessors

    func navHistory(for portfolio: ModelPortfolio) -> [ModelPortfolioNav] {
        navByPortfolio[portfolio.id] ?? []
    }

    func trades(for portfolio: ModelPortfolio) -> [ModelPortfolioTrade] {
        tradesByPortfolio[portfolio.id] ?? []
    }

    func latestNav(for portfolio: ModelPortfolio) -> ModelPortfolioNav? {
        navByPortfolio[portfolio.id]?.last
    }

    func returnPct(for portfolio: ModelPortfolio) -> Double {
        latestNav(for: portfolio)?.returnPct ?? 0
    }

    // Legacy crypto accessors (kept for existing views)
    var coreNav: [ModelPortfolioNav] { corePortfolio.map { navHistory(for: $0) } ?? [] }
    var edgeNav: [ModelPortfolioNav] { edgePortfolio.map { navHistory(for: $0) } ?? [] }
    var alphaNav: [ModelPortfolioNav] { alphaPortfolio.map { navHistory(for: $0) } ?? [] }
    var coreTrades: [ModelPortfolioTrade] { corePortfolio.map { trades(for: $0) } ?? [] }
    var edgeTrades: [ModelPortfolioTrade] { edgePortfolio.map { trades(for: $0) } ?? [] }
    var alphaTrades: [ModelPortfolioTrade] { alphaPortfolio.map { trades(for: $0) } ?? [] }

    var latestCoreNav: ModelPortfolioNav? { coreNav.last }
    var latestEdgeNav: ModelPortfolioNav? { edgeNav.last }
    var latestAlphaNav: ModelPortfolioNav? { alphaNav.last }
    var latestBenchmark: BenchmarkNav? { benchmarkNav.last }

    var coreReturn: Double { latestCoreNav?.returnPct ?? 0 }
    var edgeReturn: Double { latestEdgeNav?.returnPct ?? 0 }
    var alphaReturn: Double { latestAlphaNav?.returnPct ?? 0 }
    var benchmarkReturn: Double { latestBenchmark?.returnPct ?? 0 }

    // MARK: - Following (one portfolio per asset class)

    private static let followedStockPortfolioKey = "followedStockModelPortfolio"

    var followedStrategy: String? {
        get { UserDefaults.standard.string(forKey: Constants.UserDefaults.followedModelPortfolio) }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.followedModelPortfolio)
            syncFollowedCryptoToServer(newValue)
        }
    }

    var followedStockStrategy: String? {
        get { UserDefaults.standard.string(forKey: Self.followedStockPortfolioKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.followedStockPortfolioKey)
            syncFollowedStockToServer(newValue)
        }
    }

    func isFollowing(_ portfolio: ModelPortfolio) -> Bool {
        portfolio.isStock
            ? followedStockStrategy == portfolio.strategy
            : followedStrategy == portfolio.strategy
    }

    func toggleFollow(_ portfolio: ModelPortfolio) {
        if portfolio.isStock {
            followedStockStrategy = isFollowing(portfolio) ? nil : portfolio.strategy
        } else {
            followedStrategy = isFollowing(portfolio) ? nil : portfolio.strategy
        }
    }

    private struct FollowedCryptoUpdate: Encodable {
        let followed_model_portfolio: String?
    }

    private struct FollowedStockUpdate: Encodable {
        let followed_stock_portfolio: String?
    }

    private func syncFollowedCryptoToServer(_ strategy: String?) {
        Task {
            guard let userId = try? await SupabaseManager.shared.client.auth.session.user.id else { return }
            do {
                try await SupabaseManager.shared.client
                    .from("profiles")
                    .update(FollowedCryptoUpdate(followed_model_portfolio: strategy))
                    .eq("id", value: userId.uuidString)
                    .execute()
            } catch {
                logWarning("Failed to sync followed portfolio: \(error)", category: .network)
            }
        }
    }

    private func syncFollowedStockToServer(_ strategy: String?) {
        Task {
            guard let userId = try? await SupabaseManager.shared.client.auth.session.user.id else { return }
            do {
                try await SupabaseManager.shared.client
                    .from("profiles")
                    .update(FollowedStockUpdate(followed_stock_portfolio: strategy))
                    .eq("id", value: userId.uuidString)
                    .execute()
            } catch {
                logWarning("Failed to sync followed stock portfolio: \(error)", category: .network)
            }
        }
    }

    init(service: ModelPortfolioServiceProtocol? = nil) {
        self.service = service ?? ServiceContainer.shared.modelPortfolioService
    }

    // MARK: - Loading

    func loadOverview() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            portfolios = try await service.fetchPortfolios()

            try await withThrowingTaskGroup(of: (UUID, [ModelPortfolioNav]).self) { group in
                for portfolio in portfolios {
                    group.addTask { [service] in
                        (portfolio.id, try await service.fetchNavHistory(portfolioId: portfolio.id, limit: 90))
                    }
                }
                for try await (id, nav) in group {
                    navByPortfolio[id] = nav
                }
            }

            benchmarkNav = try await service.fetchBenchmarkNav(limit: 90)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var isLoadingDetail = false

    func loadDetail(for portfolio: ModelPortfolio) async {
        isLoadingDetail = true
        do {
            async let navTask = service.fetchNavHistory(portfolioId: portfolio.id, limit: 3000)
            async let tradesTask = service.fetchTrades(portfolioId: portfolio.id, limit: 1000)

            let (nav, trades) = try await (navTask, tradesTask)
            navByPortfolio[portfolio.id] = nav
            tradesByPortfolio[portfolio.id] = trades
        } catch {
            errorMessage = error.localizedDescription
        }

        // Benchmark and risk history are supplemental — fetch independently
        // so failures don't prevent nav/trades from loading
        async let benchmarkTask: Void = {
            if let benchmark = try? await service.fetchBenchmarkNav(limit: 3000) {
                benchmarkNav = benchmark
            }
        }()
        async let riskTask: Void = {
            // Per-asset risk history only exists for crypto (BTC log-regression model)
            if portfolio.isCrypto, let risk = try? await service.fetchRiskHistory(asset: "BTC", limit: 3000) {
                riskHistory = risk
            }
        }()
        _ = await (benchmarkTask, riskTask)

        isLoadingDetail = false
    }
}
