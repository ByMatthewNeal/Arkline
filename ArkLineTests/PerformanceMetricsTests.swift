import XCTest
@testable import ArkLine

final class PerformanceMetricsTests: XCTestCase {

    private let portfolioId = UUID()

    // MARK: - Helpers

    private func makeBuyTransaction(
        symbol: String = "BTC",
        quantity: Double = 1.0,
        pricePerUnit: Double = 40000,
        date: Date = Date()
    ) -> Transaction {
        Transaction(
            portfolioId: portfolioId,
            type: .buy,
            assetType: "crypto",
            symbol: symbol,
            quantity: quantity,
            pricePerUnit: pricePerUnit,
            transactionDate: date
        )
    }

    private func makeHistoryPoint(date: Date, value: Double) -> PortfolioHistoryPoint {
        PortfolioHistoryPoint(date: date, value: value)
    }

    private func makeHolding(
        symbol: String = "BTC",
        name: String = "Bitcoin",
        quantity: Double = 1.0,
        averageBuyPrice: Double = 40000,
        currentPrice: Double = 50000
    ) -> PortfolioHolding {
        var holding = PortfolioHolding(
            portfolioId: portfolioId,
            assetType: "crypto",
            symbol: symbol,
            name: name,
            quantity: quantity,
            averageBuyPrice: averageBuyPrice
        )
        holding.currentPrice = currentPrice
        return holding
    }

    // MARK: - Empty Input

    func testCalculate_noData() {
        let metrics = PerformanceMetricsCalculator.calculate(
            transactions: [],
            historyPoints: [],
            holdings: [],
            totalReturn: 0,
            totalReturnPercentage: 0
        )
        XCTAssertEqual(metrics.totalInvested, 0)
        XCTAssertEqual(metrics.currentValue, 0)
        XCTAssertEqual(metrics.numberOfAssets, 0)
        XCTAssertEqual(metrics.maxDrawdown, 0)
        XCTAssertEqual(metrics.sharpeRatio, 0)
        XCTAssertTrue(metrics.monthlyInvestments.isEmpty)
    }

    // MARK: - Total Invested & Current Value

    func testCalculate_totalInvestedFromBuys() {
        let transactions = [
            makeBuyTransaction(quantity: 1.0, pricePerUnit: 40000),
            makeBuyTransaction(quantity: 0.5, pricePerUnit: 50000),
        ]
        let holdings = [makeHolding(quantity: 1.5, averageBuyPrice: 43333, currentPrice: 55000)]
        let metrics = PerformanceMetricsCalculator.calculate(
            transactions: transactions,
            historyPoints: [],
            holdings: holdings,
            totalReturn: 17500,
            totalReturnPercentage: 26.9
        )
        // 1 * 40000 + 0.5 * 50000 = 65000
        XCTAssertEqual(metrics.totalInvested, 65000, accuracy: 0.01)
        // 1.5 * 55000 = 82500
        XCTAssertEqual(metrics.currentValue, 82500, accuracy: 0.01)
        XCTAssertEqual(metrics.numberOfAssets, 1)
    }

    // MARK: - Maximum Drawdown

    func testMaxDrawdown_noDrawdown() {
        let history = [
            makeHistoryPoint(date: Date().adding(days: -3), value: 1000),
            makeHistoryPoint(date: Date().adding(days: -2), value: 1100),
            makeHistoryPoint(date: Date().adding(days: -1), value: 1200),
        ]
        let metrics = PerformanceMetricsCalculator.calculate(
            transactions: [],
            historyPoints: history,
            holdings: [],
            totalReturn: 200,
            totalReturnPercentage: 20
        )
        XCTAssertEqual(metrics.maxDrawdown, 0, accuracy: 0.01)
    }

    func testMaxDrawdown_withDrawdown() {
        let history = [
            makeHistoryPoint(date: Date().adding(days: -4), value: 1000),
            makeHistoryPoint(date: Date().adding(days: -3), value: 1200), // Peak
            makeHistoryPoint(date: Date().adding(days: -2), value: 900),  // Trough
            makeHistoryPoint(date: Date().adding(days: -1), value: 1100),
        ]
        let metrics = PerformanceMetricsCalculator.calculate(
            transactions: [],
            historyPoints: history,
            holdings: [],
            totalReturn: 100,
            totalReturnPercentage: 10
        )
        // Drawdown from 1200 to 900 = 25%
        XCTAssertEqual(metrics.maxDrawdown, 25.0, accuracy: 0.01)
        XCTAssertEqual(metrics.maxDrawdownValue, 300.0, accuracy: 0.01)
    }

    func testMaxDrawdown_singlePoint() {
        let history = [
            makeHistoryPoint(date: Date(), value: 1000),
        ]
        let metrics = PerformanceMetricsCalculator.calculate(
            transactions: [],
            historyPoints: history,
            holdings: [],
            totalReturn: 0,
            totalReturnPercentage: 0
        )
        XCTAssertEqual(metrics.maxDrawdown, 0)
    }

    // MARK: - Sharpe Ratio

    func testSharpeRatio_withHistory() {
        // Create history with consistent positive returns
        var history: [PortfolioHistoryPoint] = []
        var value = 10000.0
        for i in 0..<30 {
            history.append(makeHistoryPoint(date: Date().adding(days: -30 + i), value: value))
            value *= 1.005 // ~0.5% daily return
        }
        let metrics = PerformanceMetricsCalculator.calculate(
            transactions: [],
            historyPoints: history,
            holdings: [],
            totalReturn: value - 10000,
            totalReturnPercentage: ((value - 10000) / 10000) * 100
        )
        // Should have positive Sharpe
        XCTAssertGreaterThan(metrics.sharpeRatio, 0)
    }

    func testSharpeRatio_insufficientData() {
        let history = [
            makeHistoryPoint(date: Date().adding(days: -1), value: 1000),
            makeHistoryPoint(date: Date(), value: 1100),
        ]
        let metrics = PerformanceMetricsCalculator.calculate(
            transactions: [],
            historyPoints: history,
            holdings: [],
            totalReturn: 100,
            totalReturnPercentage: 10
        )
        XCTAssertEqual(metrics.sharpeRatio, 0)
    }

    func testSharpeRatio_zeroVolatility() {
        let history = (0..<10).map { i in
            makeHistoryPoint(date: Date().adding(days: -10 + i), value: 1000)
        }
        let metrics = PerformanceMetricsCalculator.calculate(
            transactions: [],
            historyPoints: history,
            holdings: [],
            totalReturn: 0,
            totalReturnPercentage: 0
        )
        XCTAssertEqual(metrics.sharpeRatio, 0)
    }

    // MARK: - Sharpe Rating

    func testSharpeRating() {
        let poor = PerformanceMetrics(
            totalReturn: 0, totalReturnPercentage: 0,
            totalInvested: 0, currentValue: 0, numberOfAssets: 0,
            maxDrawdown: 0, maxDrawdownValue: 0, sharpeRatio: -0.5,
            monthlyInvestments: []
        )
        XCTAssertEqual(poor.sharpeRating, "Poor")

        let good = PerformanceMetrics(
            totalReturn: 0, totalReturnPercentage: 0,
            totalInvested: 0, currentValue: 0, numberOfAssets: 0,
            maxDrawdown: 0, maxDrawdownValue: 0, sharpeRatio: 1.5,
            monthlyInvestments: []
        )
        XCTAssertEqual(good.sharpeRating, "Good")

        let excellent = PerformanceMetrics(
            totalReturn: 0, totalReturnPercentage: 0,
            totalInvested: 0, currentValue: 0, numberOfAssets: 0,
            maxDrawdown: 0, maxDrawdownValue: 0, sharpeRatio: 3.5,
            monthlyInvestments: []
        )
        XCTAssertEqual(excellent.sharpeRating, "Excellent")
    }

    // MARK: - Monthly Investments

    func testMonthlyInvestments_groupsByMonth() {
        let now = Date()
        let transactions = [
            makeBuyTransaction(symbol: "BTC", quantity: 0.1, pricePerUnit: 50000, date: now),
            makeBuyTransaction(symbol: "ETH", quantity: 2.0, pricePerUnit: 3000, date: now.adding(days: -5)),
            makeBuyTransaction(symbol: "BTC", quantity: 0.05, pricePerUnit: 48000, date: now.adding(days: -2)),
        ]
        let result = PerformanceMetricsCalculator.calculateMonthlyInvestments(transactions)

        // All 3 buys are in the same month, so should be 1 entry
        XCTAssertEqual(result.count, 1)

        // Total = 0.1*50000 + 2*3000 + 0.05*48000 = 5000 + 6000 + 2400 = 13400
        XCTAssertEqual(result.first?.amount ?? 0, 13400, accuracy: 0.01)
    }

    func testMonthlyInvestments_limitsToSixMonths() {
        var transactions: [Transaction] = []
        for i in 0..<10 {
            transactions.append(
                makeBuyTransaction(
                    quantity: 0.1,
                    pricePerUnit: 50000,
                    date: Date().adding(months: -i)
                )
            )
        }
        let result = PerformanceMetricsCalculator.calculateMonthlyInvestments(transactions)
        XCTAssertLessThanOrEqual(result.count, 6)
    }

    func testMonthlyInvestments_emptyForNoBuys() {
        // Only sell transactions
        let transactions = [
            Transaction(
                portfolioId: portfolioId,
                type: .sell,
                assetType: "crypto",
                symbol: "BTC",
                quantity: 1.0,
                pricePerUnit: 50000,
                transactionDate: Date()
            )
        ]
        let result = PerformanceMetricsCalculator.calculateMonthlyInvestments(transactions)
        XCTAssertTrue(result.isEmpty)
    }

    func testMonthlyInvestments_orderedOldestFirst() {
        let transactions = [
            makeBuyTransaction(quantity: 0.1, pricePerUnit: 50000, date: Date().adding(months: -2)),
            makeBuyTransaction(quantity: 0.1, pricePerUnit: 50000, date: Date().adding(months: -1)),
            makeBuyTransaction(quantity: 0.1, pricePerUnit: 50000, date: Date()),
        ]
        let result = PerformanceMetricsCalculator.calculateMonthlyInvestments(transactions)

        XCTAssertEqual(result.count, 3)
        // First entry should be the oldest month
        XCTAssertTrue(result.first!.monthKey < result.last!.monthKey)
    }
}
