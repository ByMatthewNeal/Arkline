import SwiftUI
import Foundation

// MARK: - Portfolio Tab Selection
enum PortfolioTab: String, CaseIterable {
    case overview = "Overview"
    case holdings = "Holdings"
    case allocation = "Allocation"
    case dcaCalculator = "DCA"
    case performance = "Performance"
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
    var portfolios: [Portfolio] = []
    var selectedPortfolio: Portfolio?
    var holdings: [PortfolioHolding] = []
    var transactions: [Transaction] = []
    var allocations: [PortfolioAllocation] = []
    var historyPoints: [PortfolioHistoryPoint] = []

    var isLoading = false
    var isRefreshing = false
    var error: AppError?
    var priceRefreshFailed = false

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

    // MARK: - Performance Metrics
    var performanceMetrics: PerformanceMetrics {
        PerformanceMetricsCalculator.calculate(
            transactions: transactions,
            historyPoints: historyPoints,
            totalReturn: totalProfitLoss,
            totalReturnPercentage: totalProfitLossPercentage
        )
    }

    // MARK: - Initialization
    init(
        portfolioService: PortfolioServiceProtocol = ServiceContainer.shared.portfolioService,
        marketService: MarketServiceProtocol = ServiceContainer.shared.marketService
    ) {
        self.portfolioService = portfolioService
        self.marketService = marketService
    }

    // MARK: - Data Loading
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        isLoading = true
        error = nil
        defer { isRefreshing = false }

        do {
            // Get userId from Supabase auth
            let userId = await MainActor.run { SupabaseAuthManager.shared.currentUserId }
            guard let userId = userId else {
                logWarning("No authenticated user for portfolio refresh", category: .data)
                await MainActor.run { isLoading = false }
                return
            }
            currentUserId = userId

            // Fetch all portfolios
            let fetchedPortfolios = try await portfolioService.fetchPortfolios(userId: userId)

            await MainActor.run {
                self.portfolios = fetchedPortfolios
                // Select first portfolio if none selected
                if self.selectedPortfolio == nil, let first = fetchedPortfolios.first {
                    self.selectedPortfolio = first
                }
            }

            // Load data for selected portfolio
            if let portfolio = selectedPortfolio {
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

                // Record daily portfolio snapshot for history charts
                let snapshotValue = holdingsWithPrices.reduce(0) { $0 + $1.currentValue }
                let snapshotCost = holdingsWithPrices.reduce(0) { $0 + $1.totalCost }
                let snapshotDayChange = holdingsWithPrices.reduce(0.0) { total, holding in
                    guard let change = holding.priceChangePercentage24h else { return total }
                    return total + holding.currentValue * (change / 100)
                }
                let previousValue = snapshotValue - snapshotDayChange
                let snapshotDayChangePercentage = previousValue > 0 ? (snapshotDayChange / previousValue) * 100 : 0

                try await portfolioService.recordPortfolioSnapshot(
                    portfolioId: portfolio.id,
                    totalValue: snapshotValue,
                    totalCost: snapshotCost > 0 ? snapshotCost : nil,
                    dayChange: snapshotDayChange,
                    dayChangePercentage: snapshotDayChangePercentage
                )
            } else {
                await MainActor.run {
                    self.holdings = []
                    self.transactions = []
                    self.historyPoints = []
                    self.allocations = []
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
                self.priceRefreshFailed = false
            }
        } catch {
            logError("Price refresh failed: \(error)", category: .data)
            await MainActor.run {
                self.priceRefreshFailed = true
            }
        }
    }

    // MARK: - Actions
    func selectTab(_ tab: PortfolioTab) {
        selectedTab = tab
    }

    func selectPortfolio(_ portfolio: Portfolio) {
        selectedPortfolio = portfolio
        portfolioId = portfolio.id
        // Reload data for the new portfolio
        Task { await refresh() }
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

    func createPortfolio(name: String, isPublic: Bool) async throws {
        // Get userId from Supabase auth
        let userId = await MainActor.run { SupabaseAuthManager.shared.currentUserId }
        guard let userId = userId else {
            throw AppError.authenticationRequired
        }

        let portfolio = Portfolio(
            userId: userId,
            name: name,
            isPublic: isPublic
        )

        let createdPortfolio = try await portfolioService.createPortfolio(portfolio)

        await MainActor.run {
            self.portfolios.append(createdPortfolio)
            self.selectedPortfolio = createdPortfolio
            self.portfolioId = createdPortfolio.id
            // Clear data for the new empty portfolio
            self.holdings = []
            self.transactions = []
            self.historyPoints = []
            self.allocations = []
        }
    }

    func addRealEstateProperty(
        propertyName: String,
        address: String,
        propertyType: PropertyType,
        squareFootage: Double?,
        purchasePrice: Double,
        purchaseDate: Date,
        currentEstimatedValue: Double,
        monthlyRentalIncome: Double?,
        monthlyExpenses: Double?,
        notes: String?
    ) async throws {
        guard let portfolioId = portfolioId else {
            throw AppError.unknown(message: "No portfolio selected")
        }

        // Create a holding for the real estate property
        // Using property name as the "symbol" and address as identifier
        let holding = PortfolioHolding(
            portfolioId: portfolioId,
            assetType: Constants.AssetType.realEstate.rawValue,
            symbol: propertyName,
            name: address,
            quantity: 1, // Each property is 1 unit
            averageBuyPrice: purchasePrice
        )

        let createdHolding = try await portfolioService.addHolding(holding)

        // Update the holding with current estimated value (manual valuation)
        var updatedHolding = createdHolding
        updatedHolding.currentPrice = currentEstimatedValue

        // Create a transaction for the purchase
        let transaction = Transaction(
            portfolioId: portfolioId,
            holdingId: createdHolding.id,
            type: .buy,
            assetType: Constants.AssetType.realEstate.rawValue,
            symbol: propertyName,
            quantity: 1,
            pricePerUnit: purchasePrice,
            transactionDate: purchaseDate,
            notes: notes
        )

        _ = try await portfolioService.addTransaction(transaction)

        // Refresh to load the updated data
        await refresh()
    }

    func sellAsset(
        holding: PortfolioHolding,
        quantity: Double,
        pricePerUnit: Double,
        fee: Double,
        date: Date,
        notes: String?,
        emotionalState: EmotionalState?,
        transferToPortfolio: Portfolio?,
        convertToCash: Bool
    ) async throws {
        guard let portfolioId = portfolioId else {
            throw AppError.unknown(message: "No portfolio selected")
        }

        // Validate inputs
        guard quantity > 0 else {
            throw AppError.unknown(message: "Quantity must be positive")
        }
        guard pricePerUnit > 0 else {
            throw AppError.unknown(message: "Price must be positive")
        }
        guard fee >= 0 else {
            throw AppError.unknown(message: "Fee cannot be negative")
        }
        guard quantity <= holding.quantity else {
            throw AppError.unknown(message: "Cannot sell more than you hold")
        }

        // Calculate profit/loss using average cost basis
        let costBasisPerUnit = holding.averageBuyPrice ?? 0
        let totalProceeds = (quantity * pricePerUnit) - fee

        guard totalProceeds > 0 else {
            throw AppError.unknown(message: "Fee exceeds sale proceeds")
        }
        let totalCostBasis = quantity * costBasisPerUnit
        let realizedProfitLoss = totalProceeds - totalCostBasis

        // 1. Create sell transaction in source portfolio
        let sellTransaction = Transaction(
            portfolioId: portfolioId,
            holdingId: holding.id,
            type: .sell,
            assetType: holding.assetType,
            symbol: holding.symbol,
            quantity: quantity,
            pricePerUnit: pricePerUnit,
            gasFee: fee,
            transactionDate: date,
            notes: notes,
            emotionalState: emotionalState,
            costBasisPerUnit: costBasisPerUnit,
            realizedProfitLoss: realizedProfitLoss,
            destinationPortfolioId: transferToPortfolio?.id
        )

        _ = try await portfolioService.addTransaction(sellTransaction)

        // 2. Update the holding quantity
        let remainingQuantity = holding.quantity - quantity
        if remainingQuantity <= 0.00000001 { // Effectively zero
            // Remove the holding entirely
            try await portfolioService.deleteHolding(holdingId: holding.id)
        } else {
            // Update the holding with reduced quantity
            var updatedHolding = holding
            updatedHolding.quantity = remainingQuantity
            try await portfolioService.updateHolding(updatedHolding)
        }

        // 3. If transferring to another portfolio, create the buy transaction there
        if let destinationPortfolio = transferToPortfolio {
            if convertToCash {
                // Add as cash/USDT in destination portfolio
                // First check if there's an existing cash holding
                let destHoldings = try await portfolioService.fetchHoldings(portfolioId: destinationPortfolio.id)
                let existingCash = destHoldings.first { $0.symbol.uppercased() == "USDT" || $0.symbol.uppercased() == "USD" }

                if let cashHolding = existingCash {
                    // Update existing cash holding
                    var updatedCash = cashHolding
                    let newQuantity = cashHolding.quantity + totalProceeds
                    // Recalculate average (for cash it's always 1:1)
                    updatedCash.quantity = newQuantity
                    updatedCash.averageBuyPrice = 1.0
                    try await portfolioService.updateHolding(updatedCash)
                } else {
                    // Create new USDT holding
                    let cashHolding = PortfolioHolding(
                        portfolioId: destinationPortfolio.id,
                        assetType: "crypto",
                        symbol: "USDT",
                        name: "Tether USD",
                        quantity: totalProceeds,
                        averageBuyPrice: 1.0
                    )
                    _ = try await portfolioService.addHolding(cashHolding)
                }

                // Create transfer-in transaction
                let transferInTransaction = Transaction(
                    portfolioId: destinationPortfolio.id,
                    type: .transferIn,
                    assetType: "crypto",
                    symbol: "USDT",
                    quantity: totalProceeds,
                    pricePerUnit: 1.0,
                    transactionDate: date,
                    notes: "Transfer from \(selectedPortfolio?.name ?? "portfolio") - Sale of \(holding.symbol)",
                    relatedTransactionId: sellTransaction.id
                )
                _ = try await portfolioService.addTransaction(transferInTransaction)
            } else {
                // Buy the same asset in destination portfolio
                let destHoldings = try await portfolioService.fetchHoldings(portfolioId: destinationPortfolio.id)
                let existingHolding = destHoldings.first { $0.symbol.uppercased() == holding.symbol.uppercased() }

                if let existing = existingHolding {
                    // Update existing holding with new weighted average
                    var updated = existing
                    let oldTotal = existing.quantity * (existing.averageBuyPrice ?? 0)
                    let newTotal = quantity * pricePerUnit
                    let newQuantity = existing.quantity + quantity
                    updated.quantity = newQuantity
                    updated.averageBuyPrice = (oldTotal + newTotal) / newQuantity
                    try await portfolioService.updateHolding(updated)
                } else {
                    // Create new holding
                    let newHolding = PortfolioHolding(
                        portfolioId: destinationPortfolio.id,
                        assetType: holding.assetType,
                        symbol: holding.symbol,
                        name: holding.name,
                        quantity: quantity,
                        averageBuyPrice: pricePerUnit
                    )
                    _ = try await portfolioService.addHolding(newHolding)
                }

                // Create transfer-in/buy transaction
                let buyTransaction = Transaction(
                    portfolioId: destinationPortfolio.id,
                    type: .transferIn,
                    assetType: holding.assetType,
                    symbol: holding.symbol,
                    quantity: quantity,
                    pricePerUnit: pricePerUnit,
                    transactionDate: date,
                    notes: "Transfer from \(selectedPortfolio?.name ?? "portfolio")",
                    relatedTransactionId: sellTransaction.id
                )
                _ = try await portfolioService.addTransaction(buyTransaction)
            }
        }

        // Refresh to update the UI
        await refresh()
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
