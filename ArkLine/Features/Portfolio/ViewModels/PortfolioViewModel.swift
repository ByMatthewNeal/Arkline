import SwiftUI
import Foundation

// MARK: - Portfolio Tab Selection
enum PortfolioTab: String, CaseIterable {
    case overview = "Overview"
    case holdings = "Holdings"
    case allocation = "Allocation"
    case transactions = "History"
}

// MARK: - Portfolio View Model
@Observable
final class PortfolioViewModel {
    // MARK: - State
    var selectedTab: PortfolioTab = .overview
    var portfolio: Portfolio?
    var holdings: [PortfolioHolding] = []
    var transactions: [Transaction] = []
    var allocations: [PortfolioAllocation] = []
    var historyPoints: [PortfolioHistoryPoint] = []

    var isLoading = false
    var error: AppError?

    // MARK: - Filters
    var holdingsSearchText = ""
    var selectedAssetType: Constants.AssetType?
    var transactionFilter: TransactionType?

    // MARK: - Computed Properties
    var totalValue: Double {
        holdings.reduce(0) { $0 + $1.currentValue }
    }

    var totalCost: Double {
        holdings.reduce(0) { $0 + $1.totalCost }
    }

    var totalProfitLoss: Double {
        totalValue - totalCost
    }

    var totalProfitLossPercentage: Double {
        guard totalCost > 0 else { return 0 }
        return ((totalValue - totalCost) / totalCost) * 100
    }

    var dayChange: Double {
        holdings.reduce(0) { total, holding in
            guard let change = holding.priceChangePercentage24h else { return total }
            let holdingDayChange = holding.currentValue * (change / 100)
            return total + holdingDayChange
        }
    }

    var dayChangePercentage: Double {
        let previousValue = totalValue - dayChange
        guard previousValue > 0 else { return 0 }
        return (dayChange / previousValue) * 100
    }

    var filteredHoldings: [PortfolioHolding] {
        var result = holdings

        if !holdingsSearchText.isEmpty {
            result = result.filter {
                $0.symbol.localizedCaseInsensitiveContains(holdingsSearchText) ||
                $0.name.localizedCaseInsensitiveContains(holdingsSearchText)
            }
        }

        if let type = selectedAssetType {
            result = result.filter { $0.assetType == type.rawValue }
        }

        return result.sorted { $0.currentValue > $1.currentValue }
    }

    var filteredTransactions: [Transaction] {
        var result = transactions

        if let filter = transactionFilter {
            result = result.filter { $0.type == filter }
        }

        return result.sorted { $0.transactionDate > $1.transactionDate }
    }

    var topPerformers: [PortfolioHolding] {
        holdings.sorted { $0.profitLossPercentage > $1.profitLossPercentage }.prefix(3).map { $0 }
    }

    var worstPerformers: [PortfolioHolding] {
        holdings.sorted { $0.profitLossPercentage < $1.profitLossPercentage }.prefix(3).map { $0 }
    }

    // MARK: - Initialization
    init() {
        loadMockData()
    }

    // MARK: - Data Loading
    func refresh() async {
        isLoading = true
        error = nil

        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        loadMockData()
        isLoading = false
    }

    private func loadMockData() {
        let portfolioId = UUID()

        // Mock holdings
        holdings = [
            PortfolioHolding(
                portfolioId: portfolioId,
                assetType: "crypto",
                symbol: "BTC",
                name: "Bitcoin",
                quantity: 0.5,
                averageBuyPrice: 45000
            ).withLiveData(currentPrice: 67500, change24h: 2.5),

            PortfolioHolding(
                portfolioId: portfolioId,
                assetType: "crypto",
                symbol: "ETH",
                name: "Ethereum",
                quantity: 3.2,
                averageBuyPrice: 2800
            ).withLiveData(currentPrice: 3450, change24h: -1.2),

            PortfolioHolding(
                portfolioId: portfolioId,
                assetType: "crypto",
                symbol: "SOL",
                name: "Solana",
                quantity: 25,
                averageBuyPrice: 120
            ).withLiveData(currentPrice: 175, change24h: 5.8),

            PortfolioHolding(
                portfolioId: portfolioId,
                assetType: "stock",
                symbol: "AAPL",
                name: "Apple Inc.",
                quantity: 10,
                averageBuyPrice: 175
            ).withLiveData(currentPrice: 195, change24h: 0.8),

            PortfolioHolding(
                portfolioId: portfolioId,
                assetType: "metal",
                symbol: "XAU",
                name: "Gold",
                quantity: 2,
                averageBuyPrice: 1950
            ).withLiveData(currentPrice: 2050, change24h: 0.3)
        ]

        // Calculate allocations
        allocations = PortfolioAllocation.calculate(from: holdings)

        // Mock transactions
        transactions = [
            Transaction(
                portfolioId: portfolioId,
                holdingId: holdings[0].id,
                type: .buy,
                assetType: "crypto",
                symbol: "BTC",
                quantity: 0.25,
                pricePerUnit: 43000,
                transactionDate: Date().addingTimeInterval(-86400 * 30)
            ),
            Transaction(
                portfolioId: portfolioId,
                holdingId: holdings[0].id,
                type: .buy,
                assetType: "crypto",
                symbol: "BTC",
                quantity: 0.25,
                pricePerUnit: 47000,
                transactionDate: Date().addingTimeInterval(-86400 * 15)
            ),
            Transaction(
                portfolioId: portfolioId,
                holdingId: holdings[1].id,
                type: .buy,
                assetType: "crypto",
                symbol: "ETH",
                quantity: 3.2,
                pricePerUnit: 2800,
                transactionDate: Date().addingTimeInterval(-86400 * 45)
            )
        ]

        // Mock history
        historyPoints = generateMockHistory()
    }

    private func generateMockHistory() -> [PortfolioHistoryPoint] {
        var points: [PortfolioHistoryPoint] = []
        let calendar = Calendar.current
        var value = totalValue * 0.85

        for i in (0..<30).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            let change = Double.random(in: -0.03...0.04)
            value = value * (1 + change)
            points.append(PortfolioHistoryPoint(date: date, value: value))
        }

        return points
    }

    // MARK: - Actions
    func selectTab(_ tab: PortfolioTab) {
        selectedTab = tab
    }

    func selectAssetType(_ type: Constants.AssetType?) {
        selectedAssetType = type
    }

    func selectTransactionFilter(_ filter: TransactionType?) {
        transactionFilter = filter
    }

    func toggleFavorite(_ holding: PortfolioHolding) {
        // TODO: Implement
    }

    func deleteHolding(_ holding: PortfolioHolding) {
        holdings.removeAll { $0.id == holding.id }
        allocations = PortfolioAllocation.calculate(from: holdings)
    }
}

// MARK: - PortfolioHolding Extension for Mock Data
extension PortfolioHolding {
    func withLiveData(currentPrice: Double, change24h: Double) -> PortfolioHolding {
        var holding = self
        holding.currentPrice = currentPrice
        holding.priceChangePercentage24h = change24h
        return holding
    }
}
