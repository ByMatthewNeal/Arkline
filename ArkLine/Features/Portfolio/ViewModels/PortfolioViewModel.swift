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
    // MARK: - Dependencies
    private let portfolioService: PortfolioServiceProtocol
    private let marketService: MarketServiceProtocol

    // MARK: - State
    var selectedTab: PortfolioTab = .overview
    var holdings: [PortfolioHolding] = []
    var transactions: [Transaction] = []
    var allocations: [PortfolioAllocation] = []
    var historyPoints: [PortfolioHistoryPoint] = []

    var isLoading = false
    var error: AppError?

    // User context
    private var currentUserId: UUID?
    private var portfolioId: UUID?

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
    init(
        portfolioService: PortfolioServiceProtocol = ServiceContainer.shared.portfolioService,
        marketService: MarketServiceProtocol = ServiceContainer.shared.marketService
    ) {
        self.portfolioService = portfolioService
        self.marketService = marketService
        Task { await loadInitialData() }
    }

    // MARK: - Data Loading
    func refresh() async {
        isLoading = true
        error = nil

        do {
            // In a real app, get userId from auth service
            let userId = currentUserId ?? UUID()

            // Fetch portfolio
            if let portfolio = try await portfolioService.fetchPortfolio(userId: userId) {
                self.portfolioId = portfolio.id

                // Fetch holdings and transactions concurrently
                async let holdingsTask = portfolioService.fetchHoldings(portfolioId: portfolio.id)
                async let transactionsTask = portfolioService.fetchTransactions(portfolioId: portfolio.id)
                async let historyTask = portfolioService.fetchPortfolioHistory(portfolioId: portfolio.id, days: 30)

                let (fetchedHoldings, fetchedTransactions, history) = try await (holdingsTask, transactionsTask, historyTask)

                // Refresh live prices for holdings
                let holdingsWithPrices = try await portfolioService.refreshHoldingPrices(holdings: fetchedHoldings)

                await MainActor.run {
                    self.holdings = holdingsWithPrices
                    self.transactions = fetchedTransactions
                    self.historyPoints = history
                    self.allocations = PortfolioAllocation.calculate(from: holdingsWithPrices)
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.error = error as? AppError ?? .unknown(message: error.localizedDescription)
                self.isLoading = false
            }
        }
    }

    func refreshPrices() async {
        guard !holdings.isEmpty else { return }

        do {
            let updatedHoldings = try await portfolioService.refreshHoldingPrices(holdings: holdings)

            await MainActor.run {
                self.holdings = updatedHoldings
                self.allocations = PortfolioAllocation.calculate(from: updatedHoldings)
            }
        } catch {
            // Silently fail - prices will update on next full refresh
        }
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

    func dismissError() {
        error = nil
    }

    func addTransaction(_ transaction: Transaction) async {
        do {
            let createdTransaction = try await portfolioService.addTransaction(transaction)

            await MainActor.run {
                self.transactions.append(createdTransaction)
            }

            // Update holdings after transaction
            if let portfolioId = portfolioId {
                let updatedHoldings = try await portfolioService.fetchHoldings(portfolioId: portfolioId)
                let holdingsWithPrices = try await portfolioService.refreshHoldingPrices(holdings: updatedHoldings)

                await MainActor.run {
                    self.holdings = holdingsWithPrices
                    self.allocations = PortfolioAllocation.calculate(from: holdingsWithPrices)
                }
            }
        } catch {
            await MainActor.run {
                self.error = error as? AppError ?? .transactionFailed
            }
        }
    }

    func deleteHolding(_ holding: PortfolioHolding) async {
        do {
            try await portfolioService.deleteHolding(holdingId: holding.id)

            await MainActor.run {
                self.holdings.removeAll { $0.id == holding.id }
                self.allocations = PortfolioAllocation.calculate(from: self.holdings)
            }
        } catch {
            await MainActor.run {
                self.error = error as? AppError ?? .unknown(message: error.localizedDescription)
            }
        }
    }

    // MARK: - Private Methods
    private func loadInitialData() async {
        await refresh()
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
