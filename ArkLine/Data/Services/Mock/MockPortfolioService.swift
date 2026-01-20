import Foundation

// MARK: - Mock Portfolio Service
/// Mock implementation of PortfolioServiceProtocol for development and testing.
final class MockPortfolioService: PortfolioServiceProtocol {
    // MARK: - Configuration
    var simulatedDelay: UInt64 = 500_000_000

    // MARK: - Mock Storage
    private var mockPortfolio: Portfolio?
    private var mockHoldings: [PortfolioHolding] = []
    private var mockTransactions: [Transaction] = []

    // MARK: - Initialization
    init() {
        setupMockData()
    }

    // MARK: - PortfolioServiceProtocol

    func fetchPortfolio(userId: UUID) async throws -> Portfolio? {
        try await simulateNetworkDelay()
        return mockPortfolio
    }

    func fetchHoldings(portfolioId: UUID) async throws -> [PortfolioHolding] {
        try await simulateNetworkDelay()
        return mockHoldings.filter { $0.portfolioId == portfolioId }
    }

    func fetchTransactions(portfolioId: UUID) async throws -> [Transaction] {
        try await simulateNetworkDelay()
        return mockTransactions.filter { $0.portfolioId == portfolioId }
    }

    func fetchPortfolioHistory(portfolioId: UUID, days: Int) async throws -> [PortfolioHistoryPoint] {
        try await simulateNetworkDelay()
        return generateMockHistory(days: days)
    }

    func createPortfolio(_ portfolio: Portfolio) async throws -> Portfolio {
        try await simulateNetworkDelay()
        mockPortfolio = portfolio
        return portfolio
    }

    func updatePortfolio(_ portfolio: Portfolio) async throws {
        try await simulateNetworkDelay()
        mockPortfolio = portfolio
    }

    func deletePortfolio(portfolioId: UUID) async throws {
        try await simulateNetworkDelay()
        if mockPortfolio?.id == portfolioId {
            mockPortfolio = nil
            mockHoldings.removeAll()
            mockTransactions.removeAll()
        }
    }

    func addHolding(_ holding: PortfolioHolding) async throws -> PortfolioHolding {
        try await simulateNetworkDelay()
        mockHoldings.append(holding)
        return holding
    }

    func updateHolding(_ holding: PortfolioHolding) async throws {
        try await simulateNetworkDelay()
        if let index = mockHoldings.firstIndex(where: { $0.id == holding.id }) {
            mockHoldings[index] = holding
        }
    }

    func deleteHolding(holdingId: UUID) async throws {
        try await simulateNetworkDelay()
        mockHoldings.removeAll { $0.id == holdingId }
    }

    func addTransaction(_ transaction: Transaction) async throws -> Transaction {
        try await simulateNetworkDelay()
        mockTransactions.append(transaction)
        return transaction
    }

    func deleteTransaction(transactionId: UUID) async throws {
        try await simulateNetworkDelay()
        mockTransactions.removeAll { $0.id == transactionId }
    }

    func refreshHoldingPrices(holdings: [PortfolioHolding]) async throws -> [PortfolioHolding] {
        try await simulateNetworkDelay()

        // Mock live prices
        let mockPrices: [String: (price: Double, change: Double)] = [
            "BTC": (67500, 2.5),
            "ETH": (3450, -1.2),
            "SOL": (175, 5.8),
            "AAPL": (195, 0.8),
            "NVDA": (210, 1.2),
            "XAU": (2050, 0.3),
            "XAG": (28.5, 1.1)
        ]

        return holdings.map { holding in
            var updated = holding
            if let priceData = mockPrices[holding.symbol.uppercased()] {
                updated.currentPrice = priceData.price
                updated.priceChangePercentage24h = priceData.change
            }
            return updated
        }
    }

    // MARK: - Private Helpers

    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: simulatedDelay)
    }

    private func setupMockData() {
        let userId = UUID()
        let portfolioId = UUID()

        mockPortfolio = Portfolio(
            id: portfolioId,
            userId: userId,
            name: "Main Portfolio",
            isPublic: false,
            createdAt: Date().addingTimeInterval(-86400 * 90)
        )

        mockHoldings = [
            createHolding(portfolioId: portfolioId, assetType: "crypto", symbol: "BTC", name: "Bitcoin", quantity: 0.5, avgPrice: 45000, currentPrice: 67500, change: 2.5),
            createHolding(portfolioId: portfolioId, assetType: "crypto", symbol: "ETH", name: "Ethereum", quantity: 3.2, avgPrice: 2800, currentPrice: 3450, change: -1.2),
            createHolding(portfolioId: portfolioId, assetType: "crypto", symbol: "SOL", name: "Solana", quantity: 25, avgPrice: 120, currentPrice: 175, change: 5.8),
            createHolding(portfolioId: portfolioId, assetType: "stock", symbol: "AAPL", name: "Apple Inc.", quantity: 10, avgPrice: 175, currentPrice: 195, change: 0.8),
            createHolding(portfolioId: portfolioId, assetType: "metal", symbol: "XAU", name: "Gold", quantity: 2, avgPrice: 1950, currentPrice: 2050, change: 0.3)
        ]

        mockTransactions = [
            Transaction(
                portfolioId: portfolioId,
                holdingId: mockHoldings[0].id,
                type: .buy,
                assetType: "crypto",
                symbol: "BTC",
                quantity: 0.25,
                pricePerUnit: 43000,
                transactionDate: Date().addingTimeInterval(-86400 * 30)
            ),
            Transaction(
                portfolioId: portfolioId,
                holdingId: mockHoldings[0].id,
                type: .buy,
                assetType: "crypto",
                symbol: "BTC",
                quantity: 0.25,
                pricePerUnit: 47000,
                transactionDate: Date().addingTimeInterval(-86400 * 15)
            ),
            Transaction(
                portfolioId: portfolioId,
                holdingId: mockHoldings[1].id,
                type: .buy,
                assetType: "crypto",
                symbol: "ETH",
                quantity: 3.2,
                pricePerUnit: 2800,
                transactionDate: Date().addingTimeInterval(-86400 * 45)
            )
        ]
    }

    private func createHolding(
        portfolioId: UUID,
        assetType: String,
        symbol: String,
        name: String,
        quantity: Double,
        avgPrice: Double,
        currentPrice: Double,
        change: Double
    ) -> PortfolioHolding {
        var holding = PortfolioHolding(
            portfolioId: portfolioId,
            assetType: assetType,
            symbol: symbol,
            name: name,
            quantity: quantity,
            averageBuyPrice: avgPrice
        )
        holding.currentPrice = currentPrice
        holding.priceChangePercentage24h = change
        return holding
    }

    private func generateMockHistory(days: Int) -> [PortfolioHistoryPoint] {
        var points: [PortfolioHistoryPoint] = []
        let calendar = Calendar.current
        let totalValue = mockHoldings.reduce(0.0) { $0 + ($1.currentPrice ?? 0) * $1.quantity }
        var value = totalValue * 0.85

        for i in (0..<days).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            let change = Double.random(in: -0.03...0.04)
            value = value * (1 + change)
            points.append(PortfolioHistoryPoint(date: date, value: value))
        }

        return points
    }
}
