import Foundation

// MARK: - Portfolio Service Protocol
/// Protocol defining portfolio management operations.
protocol PortfolioServiceProtocol {
    /// Fetches all portfolios for a user
    /// - Parameter userId: User identifier
    /// - Returns: Array of Portfolio
    func fetchPortfolios(userId: UUID) async throws -> [Portfolio]

    /// Fetches the user's portfolio
    /// - Parameter userId: User identifier
    /// - Returns: Portfolio if exists, nil otherwise
    func fetchPortfolio(userId: UUID) async throws -> Portfolio?

    /// Fetches all holdings for a portfolio
    /// - Parameter portfolioId: Portfolio identifier
    /// - Returns: Array of PortfolioHolding
    func fetchHoldings(portfolioId: UUID) async throws -> [PortfolioHolding]

    /// Fetches all transactions for a portfolio
    /// - Parameter portfolioId: Portfolio identifier
    /// - Returns: Array of Transaction
    func fetchTransactions(portfolioId: UUID) async throws -> [Transaction]

    /// Fetches portfolio value history
    /// - Parameters:
    ///   - portfolioId: Portfolio identifier
    ///   - days: Number of days of history
    /// - Returns: Array of PortfolioHistoryPoint
    func fetchPortfolioHistory(portfolioId: UUID, days: Int) async throws -> [PortfolioHistoryPoint]

    /// Creates a new portfolio
    /// - Parameter portfolio: Portfolio to create
    /// - Returns: Created Portfolio
    func createPortfolio(_ portfolio: Portfolio) async throws -> Portfolio

    /// Updates an existing portfolio
    /// - Parameter portfolio: Portfolio with updated values
    func updatePortfolio(_ portfolio: Portfolio) async throws

    /// Deletes a portfolio
    /// - Parameter portfolioId: Portfolio identifier to delete
    func deletePortfolio(portfolioId: UUID) async throws

    /// Adds a new holding to a portfolio
    /// - Parameter holding: PortfolioHolding to add
    /// - Returns: Created PortfolioHolding
    func addHolding(_ holding: PortfolioHolding) async throws -> PortfolioHolding

    /// Updates an existing holding
    /// - Parameter holding: PortfolioHolding with updated values
    func updateHolding(_ holding: PortfolioHolding) async throws

    /// Deletes a holding
    /// - Parameter holdingId: Holding identifier to delete
    func deleteHolding(holdingId: UUID) async throws

    /// Adds a transaction to a portfolio
    /// - Parameter transaction: Transaction to add
    /// - Returns: Created Transaction
    func addTransaction(_ transaction: Transaction) async throws -> Transaction

    /// Deletes a transaction
    /// - Parameter transactionId: Transaction identifier to delete
    func deleteTransaction(transactionId: UUID) async throws

    /// Fetches live prices for holdings to calculate current values
    /// - Parameter holdings: Holdings to get prices for
    /// - Returns: Holdings with updated current prices
    func refreshHoldingPrices(holdings: [PortfolioHolding]) async throws -> [PortfolioHolding]
}
