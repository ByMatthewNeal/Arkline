import XCTest
@testable import ArkLine

final class PerformanceMetricsTests: XCTestCase {

    private let portfolioId = UUID()

    // MARK: - Helpers

    private func makeSellTransaction(
        symbol: String = "BTC",
        quantity: Double = 1.0,
        pricePerUnit: Double = 50000,
        costBasisPerUnit: Double? = nil,
        realizedProfitLoss: Double? = nil,
        date: Date = Date()
    ) -> Transaction {
        Transaction(
            portfolioId: portfolioId,
            type: .sell,
            assetType: "crypto",
            symbol: symbol,
            quantity: quantity,
            pricePerUnit: pricePerUnit,
            transactionDate: date,
            costBasisPerUnit: costBasisPerUnit,
            realizedProfitLoss: realizedProfitLoss
        )
    }

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

    // MARK: - Empty Input

    func testCalculate_noTransactions() {
        let metrics = PerformanceMetricsCalculator.calculate(
            transactions: [],
            historyPoints: [],
            totalReturn: 0,
            totalReturnPercentage: 0
        )
        XCTAssertEqual(metrics.numberOfTrades, 0)
        XCTAssertEqual(metrics.winRate, 0)
        XCTAssertEqual(metrics.profitFactor, 0)
        XCTAssertEqual(metrics.maxDrawdown, 0)
        XCTAssertEqual(metrics.sharpeRatio, 0)
    }

    // MARK: - Win Rate

    func testCalculate_allWinning() {
        let transactions = [
            makeSellTransaction(realizedProfitLoss: 1000),
            makeSellTransaction(realizedProfitLoss: 500),
            makeSellTransaction(realizedProfitLoss: 200),
        ]
        let metrics = PerformanceMetricsCalculator.calculate(
            transactions: transactions,
            historyPoints: [],
            totalReturn: 1700,
            totalReturnPercentage: 10
        )
        XCTAssertEqual(metrics.winRate, 100.0, accuracy: 0.01)
        XCTAssertEqual(metrics.winningTrades, 3)
        XCTAssertEqual(metrics.losingTrades, 0)
    }

    func testCalculate_allLosing() {
        let transactions = [
            makeSellTransaction(realizedProfitLoss: -500),
            makeSellTransaction(realizedProfitLoss: -300),
        ]
        let metrics = PerformanceMetricsCalculator.calculate(
            transactions: transactions,
            historyPoints: [],
            totalReturn: -800,
            totalReturnPercentage: -10
        )
        XCTAssertEqual(metrics.winRate, 0.0, accuracy: 0.01)
        XCTAssertEqual(metrics.winningTrades, 0)
        XCTAssertEqual(metrics.losingTrades, 2)
    }

    func testCalculate_mixedTrades() {
        let transactions = [
            makeSellTransaction(realizedProfitLoss: 1000),
            makeSellTransaction(realizedProfitLoss: -500),
            makeSellTransaction(realizedProfitLoss: 800),
            makeSellTransaction(realizedProfitLoss: -200),
        ]
        let metrics = PerformanceMetricsCalculator.calculate(
            transactions: transactions,
            historyPoints: [],
            totalReturn: 1100,
            totalReturnPercentage: 5
        )
        XCTAssertEqual(metrics.winRate, 50.0, accuracy: 0.01)
        XCTAssertEqual(metrics.winningTrades, 2)
        XCTAssertEqual(metrics.losingTrades, 2)
    }

    // MARK: - Average Win/Loss

    func testCalculate_averageWinAndLoss() {
        let transactions = [
            makeSellTransaction(realizedProfitLoss: 1000),
            makeSellTransaction(realizedProfitLoss: 2000),
            makeSellTransaction(realizedProfitLoss: -500),
            makeSellTransaction(realizedProfitLoss: -300),
        ]
        let metrics = PerformanceMetricsCalculator.calculate(
            transactions: transactions,
            historyPoints: [],
            totalReturn: 2200,
            totalReturnPercentage: 10
        )
        XCTAssertEqual(metrics.averageWin, 1500.0, accuracy: 0.01)
        XCTAssertEqual(metrics.averageLoss, 400.0, accuracy: 0.01)
    }

    // MARK: - Profit Factor

    func testCalculate_profitFactor() {
        let transactions = [
            makeSellTransaction(realizedProfitLoss: 1500),
            makeSellTransaction(realizedProfitLoss: -500),
        ]
        let metrics = PerformanceMetricsCalculator.calculate(
            transactions: transactions,
            historyPoints: [],
            totalReturn: 1000,
            totalReturnPercentage: 5
        )
        // profitFactor = avgWin / avgLoss = 1500 / 500 = 3.0
        XCTAssertEqual(metrics.profitFactor, 3.0, accuracy: 0.01)
    }

    // MARK: - Cost Basis Fallback

    func testCalculate_costBasisFallback() {
        let transactions = [
            makeSellTransaction(
                quantity: 1.0,
                pricePerUnit: 60000,
                costBasisPerUnit: 40000,
                realizedProfitLoss: nil
            ),
        ]
        let metrics = PerformanceMetricsCalculator.calculate(
            transactions: transactions,
            historyPoints: [],
            totalReturn: 20000,
            totalReturnPercentage: 50
        )
        XCTAssertEqual(metrics.winningTrades, 1)
        XCTAssertEqual(metrics.averageWin, 20000, accuracy: 0.01)
    }

    // MARK: - Only Sell Transactions Counted

    func testCalculate_onlySellsAreTrades() {
        let transactions = [
            makeBuyTransaction(quantity: 1.0, pricePerUnit: 40000),
            makeBuyTransaction(quantity: 0.5, pricePerUnit: 45000),
            makeSellTransaction(realizedProfitLoss: 5000),
        ]
        let metrics = PerformanceMetricsCalculator.calculate(
            transactions: transactions,
            historyPoints: [],
            totalReturn: 5000,
            totalReturnPercentage: 10
        )
        XCTAssertEqual(metrics.numberOfTrades, 1) // Only the sell
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
            totalReturn: 0,
            totalReturnPercentage: 0
        )
        XCTAssertEqual(metrics.sharpeRatio, 0)
    }

    // MARK: - Holding Period

    func testHoldingPeriod_basic() {
        let buyDate = Date().adding(days: -30)
        let sellDate = Date()
        let transactions = [
            makeBuyTransaction(symbol: "BTC", quantity: 1.0, pricePerUnit: 40000, date: buyDate),
            makeSellTransaction(symbol: "BTC", quantity: 1.0, pricePerUnit: 50000, realizedProfitLoss: 10000, date: sellDate),
        ]
        let metrics = PerformanceMetricsCalculator.calculate(
            transactions: transactions,
            historyPoints: [],
            totalReturn: 10000,
            totalReturnPercentage: 25
        )
        XCTAssertEqual(metrics.averageHoldingPeriodDays, 30, accuracy: 1)
    }

    func testHoldingPeriod_noMatchingPairs() {
        let transactions = [
            makeBuyTransaction(symbol: "BTC", quantity: 1.0, pricePerUnit: 40000),
        ]
        let metrics = PerformanceMetricsCalculator.calculate(
            transactions: transactions,
            historyPoints: [],
            totalReturn: 0,
            totalReturnPercentage: 0
        )
        XCTAssertEqual(metrics.averageHoldingPeriodDays, 0)
    }

    // MARK: - PerformanceMetrics Model Properties

    func testSharpeRating() {
        let poor = PerformanceMetrics(
            totalReturn: 0, totalReturnPercentage: 0, winRate: 0,
            averageWin: 0, averageLoss: 0, profitFactor: 0,
            maxDrawdown: 0, maxDrawdownValue: 0, sharpeRatio: -0.5,
            numberOfTrades: 0, winningTrades: 0, losingTrades: 0,
            averageHoldingPeriodDays: 0
        )
        XCTAssertEqual(poor.sharpeRating, "Poor")

        let good = PerformanceMetrics(
            totalReturn: 0, totalReturnPercentage: 0, winRate: 0,
            averageWin: 0, averageLoss: 0, profitFactor: 0,
            maxDrawdown: 0, maxDrawdownValue: 0, sharpeRatio: 1.5,
            numberOfTrades: 0, winningTrades: 0, losingTrades: 0,
            averageHoldingPeriodDays: 0
        )
        XCTAssertEqual(good.sharpeRating, "Good")

        let excellent = PerformanceMetrics(
            totalReturn: 0, totalReturnPercentage: 0, winRate: 0,
            averageWin: 0, averageLoss: 0, profitFactor: 0,
            maxDrawdown: 0, maxDrawdownValue: 0, sharpeRatio: 3.5,
            numberOfTrades: 0, winningTrades: 0, losingTrades: 0,
            averageHoldingPeriodDays: 0
        )
        XCTAssertEqual(excellent.sharpeRating, "Excellent")
    }

    func testHoldingPeriodDescription() {
        let dayTrader = PerformanceMetrics(
            totalReturn: 0, totalReturnPercentage: 0, winRate: 0,
            averageWin: 0, averageLoss: 0, profitFactor: 0,
            maxDrawdown: 0, maxDrawdownValue: 0, sharpeRatio: 0,
            numberOfTrades: 0, winningTrades: 0, losingTrades: 0,
            averageHoldingPeriodDays: 3
        )
        XCTAssertEqual(dayTrader.holdingPeriodDescription, "Day Trading")

        let swingTrader = PerformanceMetrics(
            totalReturn: 0, totalReturnPercentage: 0, winRate: 0,
            averageWin: 0, averageLoss: 0, profitFactor: 0,
            maxDrawdown: 0, maxDrawdownValue: 0, sharpeRatio: 0,
            numberOfTrades: 0, winningTrades: 0, losingTrades: 0,
            averageHoldingPeriodDays: 14
        )
        XCTAssertEqual(swingTrader.holdingPeriodDescription, "Swing Trading")

        let longTerm = PerformanceMetrics(
            totalReturn: 0, totalReturnPercentage: 0, winRate: 0,
            averageWin: 0, averageLoss: 0, profitFactor: 0,
            maxDrawdown: 0, maxDrawdownValue: 0, sharpeRatio: 0,
            numberOfTrades: 0, winningTrades: 0, losingTrades: 0,
            averageHoldingPeriodDays: 120
        )
        XCTAssertEqual(longTerm.holdingPeriodDescription, "Long-term Holding")
    }

    func testRiskRewardRatio() {
        let metrics = PerformanceMetrics(
            totalReturn: 0, totalReturnPercentage: 0, winRate: 50,
            averageWin: 1000, averageLoss: 500, profitFactor: 2,
            maxDrawdown: 0, maxDrawdownValue: 0, sharpeRatio: 0,
            numberOfTrades: 2, winningTrades: 1, losingTrades: 1,
            averageHoldingPeriodDays: 0
        )
        XCTAssertEqual(metrics.riskRewardRatio, "1:2.0")
    }

    func testRiskRewardRatio_zeroLoss() {
        let metrics = PerformanceMetrics(
            totalReturn: 0, totalReturnPercentage: 0, winRate: 100,
            averageWin: 1000, averageLoss: 0, profitFactor: 0,
            maxDrawdown: 0, maxDrawdownValue: 0, sharpeRatio: 0,
            numberOfTrades: 1, winningTrades: 1, losingTrades: 0,
            averageHoldingPeriodDays: 0
        )
        XCTAssertEqual(metrics.riskRewardRatio, "N/A")
    }
}
