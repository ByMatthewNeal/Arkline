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
@MainActor
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

    // Allocation drill-down
    var selectedAllocationCategory: String?

    // Target allocation
    var showTargetEditor = false
    var showAddTransaction = false

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
        // Sum per-holding P/L so unknown-cost holdings (which return 0) stay
        // neutral. Using totalValue − totalCost would count their full value as
        // profit, because their cost is 0.
        holdings.reduce(0) { $0 + $1.profitLoss }
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

    /// Holdings merged by symbol — combines multiple purchases of the same asset into one row.
    var mergedHoldings: [PortfolioHolding] {
        PortfolioHolding.mergeBySymbol(holdings)
    }

    var filteredHoldings: [PortfolioHolding] {
        var result = mergedHoldings

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

    var detailAllocations: [PortfolioAllocation] {
        guard let category = selectedAllocationCategory else { return [] }
        return PortfolioAllocation.calculateByHolding(from: mergedHoldings, forAssetType: category)
    }

    var topPerformers: [PortfolioHolding] {
        mergedHoldings.filter { $0.profitLossPercentage > 0 }
            .sorted { $0.profitLossPercentage > $1.profitLossPercentage }.prefix(3).map { $0 }
    }

    var worstPerformers: [PortfolioHolding] {
        mergedHoldings.filter { $0.profitLossPercentage < 0 }
            .sorted { $0.profitLossPercentage < $1.profitLossPercentage }.prefix(3).map { $0 }
    }

    var hasTargetAllocations: Bool {
        mergedHoldings.contains { $0.targetPercentage != nil }
    }

    /// Computes allocations using targets (for pie chart) when available, otherwise by market value.
    private func computeAllocations(from holdings: [PortfolioHolding]) -> [PortfolioAllocation] {
        let merged = mergedHoldings
        let hasTargets = merged.contains { $0.targetPercentage != nil }
        if hasTargets {
            let total = merged.reduce(0) { $0 + $1.currentValue }
            return PortfolioAllocation.calculateWithTargets(from: merged, totalValue: total)
        } else {
            return PortfolioAllocation.calculate(from: merged)
        }
    }

    // MARK: - Performance Metrics
    var performanceMetrics: PerformanceMetrics {
        PerformanceMetricsCalculator.calculate(
            transactions: transactions,
            historyPoints: historyPoints,
            holdings: holdings,
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
        priceRefreshFailed = false
        selectedAllocationCategory = nil
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

            // Capture selected portfolio to prevent mid-flight mutation
            let portfolio = selectedPortfolio
            if let portfolio = portfolio {
                self.portfolioId = portfolio.id

                // Fetch holdings, transactions, and history concurrently
                // Each fetch is independent — one failure shouldn't block the others
                async let holdingsTask = portfolioService.fetchHoldings(portfolioId: portfolio.id)
                async let transactionsTask = portfolioService.fetchTransactions(portfolioId: portfolio.id)
                async let historyTask = portfolioService.fetchPortfolioHistory(portfolioId: portfolio.id, days: 30)

                var partialFailure = false

                let fetchedHoldings: [PortfolioHolding]
                do { fetchedHoldings = try await holdingsTask }
                catch {
                    logError("Failed to fetch holdings: \(error)", category: .data)
                    fetchedHoldings = self.holdings
                    partialFailure = true
                }

                let fetchedTransactions: [Transaction]
                do { fetchedTransactions = try await transactionsTask }
                catch {
                    logError("Failed to fetch transactions: \(error)", category: .data)
                    fetchedTransactions = self.transactions
                    partialFailure = true
                }

                let history: [PortfolioHistoryPoint]
                do { history = try await historyTask }
                catch {
                    logError("Failed to fetch portfolio history: \(error)", category: .data)
                    history = self.historyPoints
                    partialFailure = true
                }

                // Refresh live prices for holdings
                let holdingsWithPrices: [PortfolioHolding]
                do { holdingsWithPrices = try await portfolioService.refreshHoldingPrices(holdings: fetchedHoldings) }
                catch {
                    logError("Price refresh failed: \(error)", category: .data)
                    holdingsWithPrices = fetchedHoldings
                    partialFailure = true
                }

                await MainActor.run {
                    self.holdings = holdingsWithPrices
                    self.transactions = fetchedTransactions
                    self.historyPoints = history
                    self.allocations = self.computeAllocations(from: holdingsWithPrices)
                    self.priceRefreshFailed = partialFailure
                    self.isLoading = false
                }

                // Record daily portfolio snapshot for history charts (non-blocking).
                // Skip when pricing was incomplete: a held asset that failed to
                // price (currentPrice nil/0 while quantity > 0) would record a
                // partial total and poison the history chart with a false dip
                // (e.g. an FMP/CoinGecko outage dropping stocks/metals to $0).
                // Skipping a day is far better than persisting a corrupt point.
                let anyUnpriced = holdingsWithPrices.contains { ($0.currentPrice ?? 0) <= 0 && $0.quantity > 0 }
                let snapshotValue = holdingsWithPrices.reduce(0) { $0 + $1.currentValue }
                if snapshotValue > 0, !partialFailure, !anyUnpriced {
                    do {
                        try await portfolioService.recordPortfolioSnapshot(
                            portfolioId: portfolio.id,
                            totalValue: snapshotValue
                        )
                    } catch {
                        logError("Snapshot recording failed: \(error)", category: .data)
                    }
                } else if partialFailure || anyUnpriced {
                    logInfo("Skipping portfolio snapshot — incomplete pricing (partialFailure=\(partialFailure), unpriced=\(anyUnpriced))", category: .data)
                }
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
                self.error = AppError.from(error)
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
                self.allocations = self.computeAllocations(from: updatedHoldings)
                self.priceRefreshFailed = false
            }
        } catch {
            logError("Price refresh failed: \(error)", category: .data)
            await MainActor.run {
                self.priceRefreshFailed = true
            }
        }
    }

    /// Lightweight refresh that only re-fetches holdings + prices (skips transactions, history, portfolios).
    private func refreshHoldingsOnly() async {
        guard let portfolioId = portfolioId else { return }

        do {
            let fetchedHoldings = try await portfolioService.fetchHoldings(portfolioId: portfolioId)
            let holdingsWithPrices = try await portfolioService.refreshHoldingPrices(holdings: fetchedHoldings)

            await MainActor.run {
                self.holdings = holdingsWithPrices
                self.allocations = self.computeAllocations(from: holdingsWithPrices)
            }
        } catch {
            logError("Holdings refresh failed: \(error)", category: .data)
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

    func selectAllocationCategory(_ category: String?) {
        if selectedAllocationCategory == category {
            selectedAllocationCategory = nil
        } else {
            selectedAllocationCategory = category
        }
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

    func updatePortfolio(_ portfolio: Portfolio, name: String, isPublic: Bool) async throws {
        var mutable = portfolio
        mutable.name = name
        mutable.isPublic = isPublic
        let updated = mutable
        try await portfolioService.updatePortfolio(updated)

        await MainActor.run {
            if let index = self.portfolios.firstIndex(where: { $0.id == portfolio.id }) {
                self.portfolios[index] = updated
            }
            if self.selectedPortfolio?.id == portfolio.id {
                self.selectedPortfolio = updated
            }
            NotificationCenter.default.post(name: Constants.Notifications.portfolioUpdated, object: nil)
        }
    }

    func deletePortfolio(_ portfolio: Portfolio) async throws {
        try await portfolioService.deletePortfolio(portfolioId: portfolio.id)

        await MainActor.run {
            self.portfolios.removeAll { $0.id == portfolio.id }
            if self.selectedPortfolio?.id == portfolio.id {
                self.selectedPortfolio = self.portfolios.first
                if let first = self.selectedPortfolio {
                    self.portfolioId = first.id
                }
            }
            NotificationCenter.default.post(name: Constants.Notifications.portfolioUpdated, object: nil)
        }

        // Reload data for newly selected portfolio
        if selectedPortfolio != nil {
            await refresh()
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
                    // Blend the average over KNOWN-cost units only. If the existing
                    // position has an unknown cost basis, treat its units as
                    // unknown (0 known units) rather than fabricating a $0 cost,
                    // so the new average reflects only what was actually paid.
                    var mutableHolding = existing
                    let knownOldUnits = existing.hasCostBasis ? existing.quantity : 0
                    let oldKnownCost = knownOldUnits * (existing.averageBuyPrice ?? 0)
                    let newKnownUnits = knownOldUnits + quantity
                    mutableHolding.quantity = existing.quantity + quantity
                    mutableHolding.averageBuyPrice = newKnownUnits > 0 ? (oldKnownCost + quantity * pricePerUnit) / newKnownUnits : nil
                    let updatedHolding = mutableHolding
                    try await portfolioService.updateHolding(updatedHolding)
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

    func addOrUpdateHolding(
        portfolioId: UUID,
        symbol: String,
        name: String,
        assetType: String,
        quantity: Double
    ) async {
        // Holding mode = "I own this, I don't know the cost." Represent it as a
        // transfer-in (units in, unknown cost) and let addTransaction + the
        // projection handle create/merge, so a holding is always a pure
        // projection of its transactions — no separate, divergent code path.
        let transferIn = Transaction(
            portfolioId: portfolioId,
            type: .transferIn,
            assetType: assetType,
            symbol: symbol.uppercased(),
            quantity: quantity,
            pricePerUnit: 0,
            transactionDate: Date()
        )
        await addTransaction(transferIn, assetName: name)

        Task {
            await AnalyticsService.shared.track("holding_added", properties: [
                "coin": .string(symbol),
                "quantity": .double(quantity)
            ])
        }
    }

    func addTransaction(_ transaction: Transaction, assetName: String? = nil) async {
        do {
            guard let portfolioId = portfolioId else {
                self.error = .unknown(message: "No portfolio selected")
                return
            }

            // One holding row per symbol + asset type.
            let existingHoldings = try await portfolioService.fetchHoldings(portfolioId: portfolioId)
            let existingHolding = existingHoldings.first {
                $0.symbol.uppercased() == transaction.symbol.uppercased() &&
                $0.assetType == transaction.assetType
            }

            let targetHolding: PortfolioHolding
            if let existingHolding {
                targetHolding = existingHolding
            } else {
                // Only an incoming transaction can open a position. A sell /
                // transfer-out with nothing to reduce used to be saved as an
                // orphaned transaction (holdingId == nil); reject it instead.
                guard transaction.type.isIncoming else {
                    self.error = .custom(message: "You don't have a position in \(transaction.symbol.uppercased()) to \(transaction.type.displayName.lowercased()).")
                    return
                }
                // Create an empty shell; its quantity and average cost are derived
                // from its transactions below, so there's no fabricated value here.
                let shell = PortfolioHolding(
                    portfolioId: portfolioId,
                    assetType: transaction.assetType,
                    symbol: transaction.symbol.uppercased(),
                    name: assetName ?? transaction.symbol.uppercased(),
                    quantity: 0,
                    averageBuyPrice: nil
                )
                targetHolding = try await portfolioService.addHolding(shell)
            }

            // Persist the transaction, linked to its holding.
            let linkedTransaction = Transaction(
                id: transaction.id,
                portfolioId: transaction.portfolioId,
                holdingId: targetHolding.id,
                type: transaction.type,
                assetType: transaction.assetType,
                symbol: transaction.symbol,
                quantity: transaction.quantity,
                pricePerUnit: transaction.pricePerUnit,
                gasFee: transaction.gasFee,
                transactionDate: transaction.transactionDate,
                notes: transaction.notes,
                emotionalState: transaction.emotionalState,
                costBasisPerUnit: transaction.costBasisPerUnit,
                realizedProfitLoss: transaction.realizedProfitLoss
            )
            _ = try await portfolioService.addTransaction(linkedTransaction)

            // The holding is a projection of ALL its transactions — the single
            // source of truth for quantity and average cost. This replaces the
            // old incremental blend (which fabricated a $0 cost for unknown units)
            // and keeps it consistent with recalculateHolding on edit/delete.
            // Fetch the complete set fresh so a partially-loaded local array can
            // never cause an under-count.
            let allPortfolioTxs = try await portfolioService.fetchTransactions(portfolioId: portfolioId)
            self.transactions = allPortfolioTxs
            let holdingTxs = allPortfolioTxs.filter { $0.holdingId == targetHolding.id }
            let projection = projectHolding(from: holdingTxs)
            var updatedHolding = targetHolding
            updatedHolding.quantity = projection.quantity
            updatedHolding.averageBuyPrice = projection.averageBuyPrice
            try await portfolioService.updateHolding(updatedHolding)

            // Track portfolio action
            Task {
                await AnalyticsService.shared.track("portfolio_action", properties: [
                    "action": .string(transaction.type.rawValue),
                    "coin": .string(transaction.symbol),
                    "amount": .double(transaction.totalValue)
                ])
            }

            // Refresh holdings with live prices
            let updatedHoldings = try await portfolioService.fetchHoldings(portfolioId: portfolioId)
            let holdingsWithPrices = try await portfolioService.refreshHoldingPrices(holdings: updatedHoldings)
            self.holdings = holdingsWithPrices
            self.allocations = self.computeAllocations(from: holdingsWithPrices)
        } catch {
            self.error = error as? AppError ?? .transactionFailed
        }
    }

    /// Single source of truth for a holding's quantity and average cost, derived
    /// from its transactions. Quantity = incoming (buys + transfers-in) minus
    /// outgoing (sells + transfers-out). The average is computed over KNOWN-cost
    /// buys only (a buy with price > 0); transfers-in add quantity with unknown
    /// cost and never pollute the average. Returns a nil average when no
    /// known-cost units exist, which the UI renders as "—" instead of a $0.
    private func projectHolding(from transactions: [Transaction]) -> (quantity: Double, averageBuyPrice: Double?) {
        var incoming = 0.0
        var outgoing = 0.0
        var knownUnits = 0.0
        var knownSpend = 0.0
        for tx in transactions {
            switch tx.type {
            case .buy:
                incoming += tx.quantity
                if tx.pricePerUnit > 0 {
                    knownUnits += tx.quantity
                    knownSpend += tx.quantity * tx.pricePerUnit
                }
            case .transferIn:
                incoming += tx.quantity
            case .sell, .transferOut:
                outgoing += tx.quantity
            }
        }
        let quantity = max(0, incoming - outgoing)
        let averageBuyPrice = knownUnits > 0 ? knownSpend / knownUnits : nil
        return (quantity, averageBuyPrice)
    }

    func deleteTransaction(_ transaction: Transaction) async {
        do {
            try await portfolioService.deleteTransaction(transactionId: transaction.id)

            await MainActor.run {
                self.transactions.removeAll { $0.id == transaction.id }
            }

            // Recalculate or remove the holding after deleting the transaction
            if let holdingId = transaction.holdingId {
                try await recalculateHolding(holdingId: holdingId)
            }

            // Refresh holdings with live prices (no need for full refresh)
            await refreshHoldingsOnly()
        } catch {
            await MainActor.run {
                self.error = AppError.from(error)
            }
        }
    }

    func updateTransaction(_ transaction: Transaction) async {
        do {
            try await portfolioService.updateTransaction(transaction)

            await MainActor.run {
                if let index = self.transactions.firstIndex(where: { $0.id == transaction.id }) {
                    self.transactions[index] = transaction
                }
            }

            // Recalculate holding quantity/avg price from all its transactions
            if let holdingId = transaction.holdingId {
                try await recalculateHolding(holdingId: holdingId)
            }

            // Refresh holdings with live prices (no need for full refresh)
            await refreshHoldingsOnly()
        } catch {
            await MainActor.run {
                self.error = AppError.from(error)
            }
        }
    }

    /// Recalculates a holding's quantity and average buy price from its
    /// transactions, using the same projection as the add path. Deletes the
    /// holding if no incoming (buy / transfer-in) transactions remain.
    private func recalculateHolding(holdingId: UUID) async throws {
        let remainingForHolding = self.transactions.filter { $0.holdingId == holdingId }

        guard remainingForHolding.contains(where: { $0.type.isIncoming }) else {
            try await portfolioService.deleteHolding(holdingId: holdingId)
            return
        }

        let projection = projectHolding(from: remainingForHolding)
        if let holding = holdings.first(where: { $0.id == holdingId }) {
            var updatedHolding = holding
            updatedHolding.quantity = projection.quantity
            updatedHolding.averageBuyPrice = projection.averageBuyPrice
            try await portfolioService.updateHolding(updatedHolding)
        }
    }

    func editHolding(_ holding: PortfolioHolding) async {
        guard let portfolioId = portfolioId else { return }

        do {
            try await portfolioService.updateHolding(holding)

            // Refresh holdings with live prices
            let updatedHoldings = try await portfolioService.fetchHoldings(portfolioId: portfolioId)
            let holdingsWithPrices = try await portfolioService.refreshHoldingPrices(holdings: updatedHoldings)

            await MainActor.run {
                self.holdings = holdingsWithPrices
                self.allocations = self.computeAllocations(from: holdingsWithPrices)
            }

            Task {
                await AnalyticsService.shared.track("holding_edited", properties: [
                    "coin": .string(holding.symbol),
                    "quantity": .double(holding.quantity),
                    "has_cost_basis": .bool(holding.averageBuyPrice != nil)
                ])
            }
        } catch {
            await MainActor.run {
                self.error = AppError.from(error)
            }
        }
    }

    func deleteHolding(_ holding: PortfolioHolding) async {
        do {
            // Delete associated transactions first
            let holdingTransactions = transactions.filter { $0.holdingId == holding.id }
            for tx in holdingTransactions {
                try await portfolioService.deleteTransaction(transactionId: tx.id)
            }

            try await portfolioService.deleteHolding(holdingId: holding.id)

            await MainActor.run {
                self.holdings.removeAll { $0.id == holding.id }
                self.transactions.removeAll { $0.holdingId == holding.id }
                self.allocations = self.computeAllocations(from: self.holdings)
            }
        } catch {
            await MainActor.run {
                self.error = AppError.from(error)
            }
        }
    }

    func updateTargetAllocations(_ targets: [UUID: Double?]) async {
        // Update local state immediately (optimistic) so the UI reflects targets right away
        await MainActor.run {
            for (id, target) in targets {
                if let index = self.holdings.firstIndex(where: { $0.id == id }) {
                    self.holdings[index].targetPercentage = target
                }
            }
            self.allocations = self.computeAllocations(from: self.holdings)
        }

        // Persist to Supabase
        do {
            for holding in holdings {
                guard let target = targets[holding.id] else { continue }
                var updatedHolding = holding
                updatedHolding.targetPercentage = target
                try await portfolioService.updateHolding(updatedHolding)
            }
        } catch {
            await MainActor.run {
                self.error = AppError.from(error)
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
