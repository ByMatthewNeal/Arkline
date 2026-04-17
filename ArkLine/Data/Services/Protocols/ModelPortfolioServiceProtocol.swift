import Foundation

// MARK: - Model Portfolio Service Protocol

protocol ModelPortfolioServiceProtocol {
    /// Fetches both model portfolios (Core and Edge)
    func fetchPortfolios() async throws -> [ModelPortfolio]

    /// Fetches NAV history for a portfolio
    func fetchNavHistory(portfolioId: UUID, limit: Int) async throws -> [ModelPortfolioNav]

    /// Fetches the latest NAV snapshot for a portfolio
    func fetchLatestNav(portfolioId: UUID) async throws -> ModelPortfolioNav?

    /// Fetches trade log for a portfolio
    func fetchTrades(portfolioId: UUID, limit: Int) async throws -> [ModelPortfolioTrade]

    /// Fetches SPY benchmark NAV history
    func fetchBenchmarkNav(limit: Int) async throws -> [BenchmarkNav]

    /// Fetches BTC risk history
    func fetchRiskHistory(asset: String, limit: Int) async throws -> [ModelPortfolioRiskHistory]
}
