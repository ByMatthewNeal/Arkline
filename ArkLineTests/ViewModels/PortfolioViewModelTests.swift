import XCTest
@testable import ArkLine

// MARK: - Failing Service Stub

/// Portfolio service that always throws, for testing error paths.
private final class FailingPortfolioService: PortfolioServiceProtocol {
    func fetchPortfolios(userId: UUID) async throws -> [Portfolio] { throw AppError.apiUnavailable }
    func fetchPortfolio(userId: UUID) async throws -> Portfolio? { throw AppError.apiUnavailable }
    func fetchHoldings(portfolioId: UUID) async throws -> [PortfolioHolding] { throw AppError.apiUnavailable }
    func fetchTransactions(portfolioId: UUID) async throws -> [Transaction] { throw AppError.apiUnavailable }
    func fetchPortfolioHistory(portfolioId: UUID, days: Int) async throws -> [PortfolioHistoryPoint] { throw AppError.apiUnavailable }
    func createPortfolio(_ portfolio: Portfolio) async throws -> Portfolio { throw AppError.apiUnavailable }
    func updatePortfolio(_ portfolio: Portfolio) async throws { throw AppError.apiUnavailable }
    func deletePortfolio(portfolioId: UUID) async throws { throw AppError.apiUnavailable }
    func addHolding(_ holding: PortfolioHolding) async throws -> PortfolioHolding { throw AppError.apiUnavailable }
    func updateHolding(_ holding: PortfolioHolding) async throws { throw AppError.apiUnavailable }
    func deleteHolding(holdingId: UUID) async throws { throw AppError.apiUnavailable }
    func addTransaction(_ transaction: Transaction) async throws -> Transaction { throw AppError.apiUnavailable }
    func deleteTransaction(transactionId: UUID) async throws { throw AppError.apiUnavailable }
    func refreshHoldingPrices(holdings: [PortfolioHolding]) async throws -> [PortfolioHolding] { throw AppError.apiUnavailable }
    func recordPortfolioSnapshot(portfolioId: UUID, totalValue: Double) async throws { throw AppError.apiUnavailable }
}

// MARK: - PortfolioViewModel Tests

@MainActor
final class PortfolioViewModelTests: XCTestCase {

    // MARK: - Factory

    /// Creates a PortfolioViewModel wired to zero-delay mock services.
    private func makeVM(
        portfolioService: PortfolioServiceProtocol? = nil
    ) -> PortfolioViewModel {
        let mockPortfolio = MockPortfolioService(); mockPortfolio.simulatedDelay = 0
        let mockMarket = MockMarketService(); mockMarket.simulatedDelay = 0
        return PortfolioViewModel(
            portfolioService: portfolioService ?? mockPortfolio,
            marketService: mockMarket
        )
    }

    // MARK: - Helpers

    private let testPortfolioId = UUID()

    private func makeHolding(
        portfolioId: UUID? = nil,
        assetType: String = "crypto",
        symbol: String = "BTC",
        name: String = "Bitcoin",
        quantity: Double = 1,
        averageBuyPrice: Double? = 50000,
        currentPrice: Double? = 60000,
        change24h: Double? = 2.0
    ) -> PortfolioHolding {
        var h = PortfolioHolding(
            portfolioId: portfolioId ?? testPortfolioId,
            assetType: assetType,
            symbol: symbol,
            name: name,
            quantity: quantity,
            averageBuyPrice: averageBuyPrice
        )
        h.currentPrice = currentPrice
        h.priceChangePercentage24h = change24h
        return h
    }

    private func makeTransaction(
        portfolioId: UUID? = nil,
        type: TransactionType = .buy,
        symbol: String = "BTC",
        quantity: Double = 1,
        pricePerUnit: Double = 50000,
        daysAgo: Int = 0
    ) -> Transaction {
        Transaction(
            portfolioId: portfolioId ?? testPortfolioId,
            type: type,
            assetType: "crypto",
            symbol: symbol,
            quantity: quantity,
            pricePerUnit: pricePerUnit,
            transactionDate: Date().addingTimeInterval(Double(-daysAgo * 86400))
        )
    }

    private func makePortfolio(
        name: String = "Test Portfolio",
        isPublic: Bool = false
    ) -> Portfolio {
        Portfolio(userId: UUID(), name: name, isPublic: isPublic)
    }

    // MARK: - Group A: Initial State

    func testInitialState_emptyCollections() {
        let vm = makeVM()
        XCTAssertTrue(vm.holdings.isEmpty)
        XCTAssertTrue(vm.transactions.isEmpty)
        XCTAssertTrue(vm.allocations.isEmpty)
        XCTAssertTrue(vm.historyPoints.isEmpty)
    }

    func testInitialState_defaultTab() {
        let vm = makeVM()
        XCTAssertEqual(vm.selectedTab, .overview)
    }

    func testInitialState_noErrorNotLoading() {
        let vm = makeVM()
        XCTAssertNil(vm.error)
        XCTAssertFalse(vm.isLoading)
    }

    func testInitialState_totalsAreZero() {
        let vm = makeVM()
        XCTAssertEqual(vm.totalValue, 0)
        XCTAssertEqual(vm.totalCost, 0)
        XCTAssertEqual(vm.totalProfitLoss, 0)
    }

    func testInitialState_noSelectedPortfolio() {
        let vm = makeVM()
        XCTAssertNil(vm.selectedPortfolio)
    }

    // MARK: - Group B: Computed Properties — Totals

    func testTotalValue_sumsCurrentValues() {
        let vm = makeVM()
        vm.holdings = [
            makeHolding(symbol: "BTC", quantity: 2, currentPrice: 50000),
            makeHolding(symbol: "ETH", quantity: 10, currentPrice: 3000)
        ]
        // 2*50000 + 10*3000 = 130000
        XCTAssertEqual(vm.totalValue, 130_000, accuracy: 0.01)
    }

    func testTotalCost_sumsQuantityTimesAveragePrice() {
        let vm = makeVM()
        vm.holdings = [
            makeHolding(symbol: "BTC", quantity: 2, averageBuyPrice: 40000),
            makeHolding(symbol: "ETH", quantity: 10, averageBuyPrice: 2500)
        ]
        // 2*40000 + 10*2500 = 105000
        XCTAssertEqual(vm.totalCost, 105_000, accuracy: 0.01)
    }

    func testTotalProfitLoss_positiveWithPercentage() {
        let vm = makeVM()
        vm.holdings = [
            makeHolding(quantity: 2, averageBuyPrice: 40000, currentPrice: 50000)
        ]
        // value=100000, cost=80000, P/L=20000, pct=25%
        XCTAssertEqual(vm.totalProfitLoss, 20_000, accuracy: 0.01)
        XCTAssertEqual(vm.totalProfitLossPercentage, 25.0, accuracy: 0.01)
    }

    func testTotalProfitLoss_negativeWithPercentage() {
        let vm = makeVM()
        vm.holdings = [
            makeHolding(quantity: 2, averageBuyPrice: 60000, currentPrice: 50000)
        ]
        // value=100000, cost=120000, P/L=-20000, pct=-16.667%
        XCTAssertEqual(vm.totalProfitLoss, -20_000, accuracy: 0.01)
        XCTAssertEqual(vm.totalProfitLossPercentage, -16.667, accuracy: 0.01)
    }

    func testTotalProfitLossPercentage_returnsZeroWhenCostIsZero() {
        let vm = makeVM()
        vm.holdings = [
            makeHolding(quantity: 1, averageBuyPrice: nil, currentPrice: 50000)
        ]
        XCTAssertEqual(vm.totalProfitLossPercentage, 0)
    }

    func testDayChange_computesFromHoldings() {
        let vm = makeVM()
        vm.holdings = [
            makeHolding(symbol: "BTC", quantity: 1, currentPrice: 50000, change24h: 5.0),
            makeHolding(symbol: "ETH", quantity: 10, currentPrice: 3000, change24h: -2.0)
        ]
        // BTC: 50000*0.05=2500, ETH: 30000*(-0.02)=-600, total=1900
        XCTAssertEqual(vm.dayChange, 1_900, accuracy: 0.01)
        // previousValue = 80000-1900 = 78100, pct = 1900/78100*100 ≈ 2.4327
        XCTAssertEqual(vm.dayChangePercentage, 2.4327, accuracy: 0.01)
    }

    // MARK: - Group C: Filtering

    func testFilteredHoldings_returnsAllWhenNoFilter() {
        let vm = makeVM()
        vm.holdings = [
            makeHolding(symbol: "BTC"),
            makeHolding(symbol: "ETH"),
            makeHolding(symbol: "SOL")
        ]
        XCTAssertEqual(vm.filteredHoldings.count, 3)
    }

    func testFilteredHoldings_searchBySymbol_caseInsensitive() {
        let vm = makeVM()
        vm.holdings = [
            makeHolding(symbol: "BTC", name: "Bitcoin"),
            makeHolding(symbol: "ETH", name: "Ethereum"),
            makeHolding(symbol: "SOL", name: "Solana")
        ]
        vm.holdingsSearchText = "btc"
        XCTAssertEqual(vm.filteredHoldings.count, 1)
        XCTAssertEqual(vm.filteredHoldings.first?.symbol, "BTC")
    }

    func testFilteredHoldings_searchByName_caseInsensitive() {
        let vm = makeVM()
        vm.holdings = [
            makeHolding(symbol: "BTC", name: "Bitcoin"),
            makeHolding(symbol: "ETH", name: "Ethereum")
        ]
        vm.holdingsSearchText = "ethereum"
        XCTAssertEqual(vm.filteredHoldings.count, 1)
        XCTAssertEqual(vm.filteredHoldings.first?.symbol, "ETH")
    }

    func testFilteredHoldings_filterByAssetType() {
        let vm = makeVM()
        vm.holdings = [
            makeHolding(assetType: "crypto", symbol: "BTC"),
            makeHolding(assetType: "stock", symbol: "AAPL", name: "Apple"),
            makeHolding(assetType: "metal", symbol: "XAU", name: "Gold")
        ]
        vm.selectedAssetType = .crypto
        XCTAssertEqual(vm.filteredHoldings.count, 1)
        XCTAssertEqual(vm.filteredHoldings.first?.symbol, "BTC")
    }

    func testFilteredHoldings_combinedSearchAndFilter() {
        let vm = makeVM()
        vm.holdings = [
            makeHolding(assetType: "crypto", symbol: "BTC", name: "Bitcoin"),
            makeHolding(assetType: "crypto", symbol: "ETH", name: "Ethereum"),
            makeHolding(assetType: "stock", symbol: "AAPL", name: "Apple")
        ]
        vm.selectedAssetType = .crypto
        vm.holdingsSearchText = "eth"
        XCTAssertEqual(vm.filteredHoldings.count, 1)
        XCTAssertEqual(vm.filteredHoldings.first?.symbol, "ETH")
    }

    func testFilteredHoldings_sortedByValueDescending() {
        let vm = makeVM()
        vm.holdings = [
            makeHolding(symbol: "SOL", quantity: 100, currentPrice: 100),   // 10000
            makeHolding(symbol: "BTC", quantity: 1, currentPrice: 50000),   // 50000
            makeHolding(symbol: "ETH", quantity: 10, currentPrice: 3000)    // 30000
        ]
        let symbols = vm.filteredHoldings.map(\.symbol)
        XCTAssertEqual(symbols, ["BTC", "ETH", "SOL"])
    }

    func testFilteredTransactions_returnsAllWhenNoFilter() {
        let vm = makeVM()
        vm.transactions = [
            makeTransaction(type: .buy, symbol: "BTC"),
            makeTransaction(type: .sell, symbol: "ETH"),
            makeTransaction(type: .buy, symbol: "SOL")
        ]
        XCTAssertEqual(vm.filteredTransactions.count, 3)
    }

    func testFilteredTransactions_filtersByType() {
        let vm = makeVM()
        vm.transactions = [
            makeTransaction(type: .buy, symbol: "BTC"),
            makeTransaction(type: .sell, symbol: "ETH"),
            makeTransaction(type: .buy, symbol: "SOL")
        ]
        vm.transactionFilter = .sell
        XCTAssertEqual(vm.filteredTransactions.count, 1)
        XCTAssertEqual(vm.filteredTransactions.first?.symbol, "ETH")
    }

    // MARK: - Group D: Top/Worst Performers

    func testTopPerformers_returnsTop3() {
        let vm = makeVM()
        vm.holdings = [
            makeHolding(symbol: "A", averageBuyPrice: 100, currentPrice: 200),  // +100%
            makeHolding(symbol: "B", averageBuyPrice: 100, currentPrice: 150),  // +50%
            makeHolding(symbol: "C", averageBuyPrice: 100, currentPrice: 130),  // +30%
            makeHolding(symbol: "D", averageBuyPrice: 100, currentPrice: 110)   // +10%
        ]
        let top = vm.topPerformers
        XCTAssertEqual(top.count, 3)
        XCTAssertEqual(top[0].symbol, "A")
        XCTAssertEqual(top[1].symbol, "B")
        XCTAssertEqual(top[2].symbol, "C")
    }

    func testWorstPerformers_returnsBottom3() {
        let vm = makeVM()
        vm.holdings = [
            makeHolding(symbol: "A", averageBuyPrice: 100, currentPrice: 200),  // +100%
            makeHolding(symbol: "B", averageBuyPrice: 100, currentPrice: 90),   // -10%
            makeHolding(symbol: "C", averageBuyPrice: 100, currentPrice: 70),   // -30%
            makeHolding(symbol: "D", averageBuyPrice: 100, currentPrice: 50)    // -50%
        ]
        let worst = vm.worstPerformers
        XCTAssertEqual(worst.count, 3)
        XCTAssertEqual(worst[0].symbol, "D")
        XCTAssertEqual(worst[1].symbol, "C")
        XCTAssertEqual(worst[2].symbol, "B")
    }

    func testPerformers_handlesFewerThan3() {
        let vm = makeVM()
        vm.holdings = [
            makeHolding(symbol: "A", averageBuyPrice: 100, currentPrice: 200)
        ]
        XCTAssertEqual(vm.topPerformers.count, 1)
        XCTAssertEqual(vm.worstPerformers.count, 1)
    }

    // MARK: - Group E: Tab & Selection Actions

    func testSelectTab_updatesSelectedTab() {
        let vm = makeVM()
        vm.selectTab(.holdings)
        XCTAssertEqual(vm.selectedTab, .holdings)
        vm.selectTab(.allocation)
        XCTAssertEqual(vm.selectedTab, .allocation)
    }

    func testSelectAssetType_updatesFilter() {
        let vm = makeVM()
        vm.selectAssetType(.crypto)
        XCTAssertEqual(vm.selectedAssetType, .crypto)
        vm.selectAssetType(nil)
        XCTAssertNil(vm.selectedAssetType)
    }

    func testSelectTransactionFilter_updatesFilter() {
        let vm = makeVM()
        vm.selectTransactionFilter(.sell)
        XCTAssertEqual(vm.transactionFilter, .sell)
        vm.selectTransactionFilter(nil)
        XCTAssertNil(vm.transactionFilter)
    }

    func testDismissError_clearsError() {
        let vm = makeVM()
        vm.error = .apiUnavailable
        XCTAssertNotNil(vm.error)
        vm.dismissError()
        XCTAssertNil(vm.error)
    }

    func testSelectPortfolio_updatesSelectedPortfolio() {
        let vm = makeVM()
        let p = makePortfolio(name: "My Portfolio")
        vm.selectPortfolio(p)
        XCTAssertEqual(vm.selectedPortfolio?.name, "My Portfolio")
    }

    // MARK: - Group F: Refresh Behavior

    func testRefresh_returnsEarlyWithNoAuth() async {
        let vm = makeVM()
        await vm.refresh()
        XCTAssertFalse(vm.isLoading, "isLoading should be false after early return")
        XCTAssertFalse(vm.isRefreshing)
        XCTAssertTrue(vm.holdings.isEmpty, "Holdings should remain empty with no auth")
    }

    func testRefresh_preventsReentrantCalls() async {
        let vm = makeVM()
        async let r1: () = vm.refresh()
        async let r2: () = vm.refresh()
        _ = await (r1, r2)
        XCTAssertFalse(vm.isLoading, "Should not be loading after both complete")
        XCTAssertFalse(vm.isRefreshing)
    }

    func testRefreshPrices_noOpsWithEmptyHoldings() async {
        let vm = makeVM()
        await vm.refreshPrices()
        XCTAssertTrue(vm.holdings.isEmpty)
        XCTAssertFalse(vm.priceRefreshFailed)
    }

    // MARK: - Group G: Portfolio CRUD

    func testDeletePortfolio_removesFromList() async throws {
        let vm = makeVM()
        let p1 = makePortfolio(name: "Portfolio 1")
        let p2 = makePortfolio(name: "Portfolio 2")
        vm.portfolios = [p1, p2]
        vm.selectedPortfolio = p1

        try await vm.deletePortfolio(p2)

        XCTAssertEqual(vm.portfolios.count, 1)
        XCTAssertEqual(vm.portfolios.first?.name, "Portfolio 1")
    }

    func testDeletePortfolio_selectedSwitchesToFirst() async throws {
        let vm = makeVM()
        let p1 = makePortfolio(name: "Portfolio 1")
        let p2 = makePortfolio(name: "Portfolio 2")
        vm.portfolios = [p1, p2]
        vm.selectedPortfolio = p2

        try await vm.deletePortfolio(p2)

        XCTAssertEqual(vm.selectedPortfolio?.id, p1.id, "Should switch to first remaining portfolio")
    }

    func testUpdatePortfolio_updatesNameAndPublicFlag() async throws {
        let vm = makeVM()
        let p = makePortfolio(name: "Original", isPublic: false)
        vm.portfolios = [p]
        vm.selectedPortfolio = p

        try await vm.updatePortfolio(p, name: "Renamed", isPublic: true)

        XCTAssertEqual(vm.portfolios.first?.name, "Renamed")
        XCTAssertEqual(vm.portfolios.first?.isPublic, true)
        XCTAssertEqual(vm.selectedPortfolio?.name, "Renamed")
    }

    func testDeleteHolding_removesAndRecalculatesAllocations() async {
        let vm = makeVM()
        let h1 = makeHolding(assetType: "crypto", symbol: "BTC", currentPrice: 50000)
        let h2 = makeHolding(assetType: "stock", symbol: "AAPL", name: "Apple", currentPrice: 200)
        vm.holdings = [h1, h2]

        await vm.deleteHolding(h1)

        XCTAssertEqual(vm.holdings.count, 1)
        XCTAssertEqual(vm.holdings.first?.symbol, "AAPL")
        XCTAssertEqual(vm.allocations.count, 1, "Should recalculate with one asset type")
    }

    // MARK: - Group H: Sell Asset Validation

    func testSellAsset_throwsWhenNoPortfolioSelected() async {
        let vm = makeVM()
        let holding = makeHolding(quantity: 10)

        do {
            try await vm.sellAsset(
                holding: holding, quantity: 1, pricePerUnit: 100, fee: 0,
                date: Date(), notes: nil, emotionalState: nil,
                transferToPortfolio: nil, convertToCash: false
            )
            XCTFail("Expected error for no portfolio selected")
        } catch {
            XCTAssertTrue("\(error)".contains("No portfolio selected"))
        }
    }

    func testSellAsset_throwsWhenQuantityZeroOrNegative() async {
        let vm = makeVM()
        vm.selectPortfolio(makePortfolio())
        let holding = makeHolding(quantity: 10)

        for qty in [0.0, -1.0] {
            do {
                try await vm.sellAsset(
                    holding: holding, quantity: qty, pricePerUnit: 100, fee: 0,
                    date: Date(), notes: nil, emotionalState: nil,
                    transferToPortfolio: nil, convertToCash: false
                )
                XCTFail("Expected error for quantity \(qty)")
            } catch {
                XCTAssertTrue("\(error)".contains("positive"), "quantity=\(qty) should mention 'positive'")
            }
        }
    }

    func testSellAsset_throwsWhenPriceZeroOrNegative() async {
        let vm = makeVM()
        vm.selectPortfolio(makePortfolio())
        let holding = makeHolding(quantity: 10)

        for price in [0.0, -5.0] {
            do {
                try await vm.sellAsset(
                    holding: holding, quantity: 1, pricePerUnit: price, fee: 0,
                    date: Date(), notes: nil, emotionalState: nil,
                    transferToPortfolio: nil, convertToCash: false
                )
                XCTFail("Expected error for price \(price)")
            } catch {
                XCTAssertTrue("\(error)".contains("Price must be positive"), "price=\(price)")
            }
        }
    }

    func testSellAsset_throwsWhenFeeNegative() async {
        let vm = makeVM()
        vm.selectPortfolio(makePortfolio())
        let holding = makeHolding(quantity: 10)

        do {
            try await vm.sellAsset(
                holding: holding, quantity: 1, pricePerUnit: 100, fee: -5,
                date: Date(), notes: nil, emotionalState: nil,
                transferToPortfolio: nil, convertToCash: false
            )
            XCTFail("Expected error for negative fee")
        } catch {
            XCTAssertTrue("\(error)".contains("negative"))
        }
    }

    func testSellAsset_throwsWhenQuantityExceedsHolding() async {
        let vm = makeVM()
        vm.selectPortfolio(makePortfolio())
        let holding = makeHolding(quantity: 5)

        do {
            try await vm.sellAsset(
                holding: holding, quantity: 10, pricePerUnit: 100, fee: 0,
                date: Date(), notes: nil, emotionalState: nil,
                transferToPortfolio: nil, convertToCash: false
            )
            XCTFail("Expected error for quantity exceeding holding")
        } catch {
            XCTAssertTrue("\(error)".contains("more than you hold"))
        }
    }

    func testSellAsset_throwsWhenFeeExceedsProceeds() async {
        let vm = makeVM()
        vm.selectPortfolio(makePortfolio())
        let holding = makeHolding(quantity: 10)

        do {
            try await vm.sellAsset(
                holding: holding, quantity: 1, pricePerUnit: 10, fee: 15,
                date: Date(), notes: nil, emotionalState: nil,
                transferToPortfolio: nil, convertToCash: false
            )
            XCTFail("Expected error for fee exceeding proceeds")
        } catch {
            XCTAssertTrue("\(error)".contains("Fee exceeds"))
        }
    }

    // MARK: - Group I: Error Handling

    func testAddTransaction_setsErrorOnServiceFailure() async {
        let vm = makeVM(portfolioService: FailingPortfolioService())
        let tx = makeTransaction()

        await vm.addTransaction(tx)

        XCTAssertNotNil(vm.error, "Error should be set when addTransaction fails")
    }

    func testDeleteHolding_setsErrorOnServiceFailure() async {
        let vm = makeVM(portfolioService: FailingPortfolioService())
        let holding = makeHolding()
        vm.holdings = [holding]

        await vm.deleteHolding(holding)

        XCTAssertNotNil(vm.error, "Error should be set when deleteHolding fails")
        XCTAssertEqual(vm.holdings.count, 1, "Holdings should not be modified on failure")
    }
}
