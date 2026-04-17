import Foundation

@Observable
class ModelPortfolioViewModel {
    private let service: ModelPortfolioServiceProtocol

    var portfolios: [ModelPortfolio] = []
    var coreNav: [ModelPortfolioNav] = []
    var edgeNav: [ModelPortfolioNav] = []
    var alphaNav: [ModelPortfolioNav] = []
    var benchmarkNav: [BenchmarkNav] = []
    var coreTrades: [ModelPortfolioTrade] = []
    var edgeTrades: [ModelPortfolioTrade] = []
    var alphaTrades: [ModelPortfolioTrade] = []
    var riskHistory: [ModelPortfolioRiskHistory] = []
    var isLoading = false
    var errorMessage: String?

    var corePortfolio: ModelPortfolio? { portfolios.first { $0.isCore } }
    var edgePortfolio: ModelPortfolio? { portfolios.first { $0.isEdge } }
    var alphaPortfolio: ModelPortfolio? { portfolios.first { $0.isAlpha } }

    var latestCoreNav: ModelPortfolioNav? { coreNav.last }
    var latestEdgeNav: ModelPortfolioNav? { edgeNav.last }
    var latestAlphaNav: ModelPortfolioNav? { alphaNav.last }
    var latestBenchmark: BenchmarkNav? { benchmarkNav.last }

    var coreReturn: Double { latestCoreNav?.returnPct ?? 0 }
    var edgeReturn: Double { latestEdgeNav?.returnPct ?? 0 }
    var alphaReturn: Double { latestAlphaNav?.returnPct ?? 0 }
    var benchmarkReturn: Double { latestBenchmark?.returnPct ?? 0 }

    var followedStrategy: String? {
        get { UserDefaults.standard.string(forKey: Constants.UserDefaults.followedModelPortfolio) }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.followedModelPortfolio)
            syncFollowedToServer(newValue)
        }
    }

    func isFollowing(_ portfolio: ModelPortfolio) -> Bool {
        followedStrategy == portfolio.strategy
    }

    func toggleFollow(_ portfolio: ModelPortfolio) {
        if isFollowing(portfolio) {
            followedStrategy = nil
        } else {
            followedStrategy = portfolio.strategy
        }
    }

    private struct FollowedPortfolioUpdate: Encodable {
        let followed_model_portfolio: String?
    }

    private func syncFollowedToServer(_ strategy: String?) {
        Task {
            guard let userId = try? await SupabaseManager.shared.client.auth.session.user.id else { return }
            do {
                try await SupabaseManager.shared.client
                    .from("profiles")
                    .update(FollowedPortfolioUpdate(followed_model_portfolio: strategy))
                    .eq("id", value: userId.uuidString)
                    .execute()
            } catch {
                logWarning("Failed to sync followed portfolio: \(error)", category: .network)
            }
        }
    }

    init(service: ModelPortfolioServiceProtocol? = nil) {
        self.service = service ?? ServiceContainer.shared.modelPortfolioService
    }

    func loadOverview() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            portfolios = try await service.fetchPortfolios()

            async let coreNavTask = loadNavForPortfolio(corePortfolio, limit: 90)
            async let edgeNavTask = loadNavForPortfolio(edgePortfolio, limit: 90)
            async let alphaNavTask = loadNavForPortfolio(alphaPortfolio, limit: 90)
            async let benchmarkTask = service.fetchBenchmarkNav(limit: 90)

            let (coreResult, edgeResult, alphaResult, benchResult) = await (
                try coreNavTask, try edgeNavTask, try alphaNavTask, try benchmarkTask
            )
            coreNav = coreResult
            edgeNav = edgeResult
            alphaNav = alphaResult
            benchmarkNav = benchResult
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
            async let benchmarkTask = service.fetchBenchmarkNav(limit: 3000)
            async let riskTask = service.fetchRiskHistory(asset: "BTC", limit: 3000)

            let (nav, trades, benchmark, risk) = try await (navTask, tradesTask, benchmarkTask, riskTask)

            if portfolio.isCore {
                coreNav = nav
                coreTrades = trades
            } else if portfolio.isEdge {
                edgeNav = nav
                edgeTrades = trades
            } else {
                alphaNav = nav
                alphaTrades = trades
            }
            benchmarkNav = benchmark
            riskHistory = risk
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingDetail = false
    }

    private func loadNavForPortfolio(_ portfolio: ModelPortfolio?, limit: Int) async throws -> [ModelPortfolioNav] {
        guard let portfolio else { return [] }
        return try await service.fetchNavHistory(portfolioId: portfolio.id, limit: limit)
    }
}
