import Foundation

/// Calculates portfolio performance metrics from transactions and history
struct PerformanceMetricsCalculator {

    /// Calculate all performance metrics
    /// - Parameters:
    ///   - transactions: All portfolio transactions
    ///   - historyPoints: Portfolio value history for drawdown/sharpe calculation
    ///   - totalReturn: Current total P/L amount
    ///   - totalReturnPercentage: Current total P/L percentage
    /// - Returns: Calculated PerformanceMetrics
    static func calculate(
        transactions: [Transaction],
        historyPoints: [PortfolioHistoryPoint],
        totalReturn: Double,
        totalReturnPercentage: Double
    ) -> PerformanceMetrics {

        // Filter to closed trades (sells only - these have realized P/L)
        let closedTrades = transactions.filter { $0.type == .sell }

        // Win/Loss calculation
        let (winningTrades, losingTrades, avgWin, avgLoss) = calculateWinLoss(closedTrades)
        let totalClosedTrades = winningTrades + losingTrades
        let winRate = totalClosedTrades > 0 ? (Double(winningTrades) / Double(totalClosedTrades)) * 100 : 0

        // Profit factor (avg win / avg loss)
        let profitFactor = avgLoss != 0 ? abs(avgWin / avgLoss) : 0

        // Maximum drawdown from portfolio history
        let (maxDrawdownPct, maxDrawdownValue) = calculateMaxDrawdown(historyPoints)

        // Sharpe ratio (using daily returns from history)
        let sharpeRatio = calculateSharpeRatio(historyPoints)

        // Average holding period
        let avgHoldingPeriod = calculateAverageHoldingPeriod(transactions)

        return PerformanceMetrics(
            totalReturn: totalReturn,
            totalReturnPercentage: totalReturnPercentage,
            winRate: winRate,
            averageWin: avgWin,
            averageLoss: avgLoss,
            profitFactor: profitFactor,
            maxDrawdown: maxDrawdownPct,
            maxDrawdownValue: maxDrawdownValue,
            sharpeRatio: sharpeRatio,
            numberOfTrades: closedTrades.count,
            winningTrades: winningTrades,
            losingTrades: losingTrades,
            averageHoldingPeriodDays: avgHoldingPeriod
        )
    }

    // MARK: - Win/Loss Calculation

    private static func calculateWinLoss(_ trades: [Transaction]) -> (wins: Int, losses: Int, avgWin: Double, avgLoss: Double) {
        var wins = 0
        var losses = 0
        var totalWinAmount = 0.0
        var totalLossAmount = 0.0

        for trade in trades {
            // Use realizedProfitLoss if available, otherwise estimate from transaction data
            if let pnl = trade.realizedProfitLoss {
                if pnl >= 0 {
                    wins += 1
                    totalWinAmount += pnl
                } else {
                    losses += 1
                    totalLossAmount += abs(pnl)
                }
            } else if let costBasis = trade.costBasisPerUnit {
                // Calculate P/L from cost basis
                let pnl = (trade.pricePerUnit - costBasis) * trade.quantity
                if pnl >= 0 {
                    wins += 1
                    totalWinAmount += pnl
                } else {
                    losses += 1
                    totalLossAmount += abs(pnl)
                }
            }
        }

        let avgWin = wins > 0 ? totalWinAmount / Double(wins) : 0
        let avgLoss = losses > 0 ? totalLossAmount / Double(losses) : 0

        return (wins, losses, avgWin, avgLoss)
    }

    // MARK: - Maximum Drawdown

    private static func calculateMaxDrawdown(_ history: [PortfolioHistoryPoint]) -> (percentage: Double, value: Double) {
        guard history.count > 1 else { return (0, 0) }

        // Sort by date to ensure chronological order
        let sortedHistory = history.sorted { $0.date < $1.date }

        var peak = sortedHistory.first?.value ?? 0
        var maxDrawdown = 0.0
        var maxDrawdownValue = 0.0

        for point in sortedHistory {
            // Update peak if we have a new high
            if point.value > peak {
                peak = point.value
            }

            // Calculate drawdown from peak
            if peak > 0 {
                let drawdown = ((peak - point.value) / peak) * 100
                let drawdownValue = peak - point.value

                if drawdown > maxDrawdown {
                    maxDrawdown = drawdown
                    maxDrawdownValue = drawdownValue
                }
            }
        }

        return (maxDrawdown, maxDrawdownValue)
    }

    // MARK: - Sharpe Ratio

    private static func calculateSharpeRatio(_ history: [PortfolioHistoryPoint], riskFreeRate: Double = 0.04) -> Double {
        guard history.count > 2 else { return 0 }

        // Sort by date
        let sortedHistory = history.sorted { $0.date < $1.date }

        // Calculate daily returns
        var dailyReturns: [Double] = []
        for i in 1..<sortedHistory.count {
            let previousValue = sortedHistory[i - 1].value
            guard previousValue > 0 else { continue }
            let dailyReturn = (sortedHistory[i].value - previousValue) / previousValue
            dailyReturns.append(dailyReturn)
        }

        guard !dailyReturns.isEmpty else { return 0 }

        // Calculate mean return
        let avgReturn = dailyReturns.reduce(0, +) / Double(dailyReturns.count)

        // Calculate standard deviation
        let variance = dailyReturns.reduce(0) { $0 + pow($1 - avgReturn, 2) } / Double(dailyReturns.count)
        let stdDev = sqrt(variance)

        guard stdDev > 0 else { return 0 }

        // Annualize (assuming 252 trading days)
        let annualizedReturn = avgReturn * 252
        let annualizedStdDev = stdDev * sqrt(252)

        // Sharpe = (return - risk-free rate) / volatility
        return (annualizedReturn - riskFreeRate) / annualizedStdDev
    }

    // MARK: - Average Holding Period

    private static func calculateAverageHoldingPeriod(_ transactions: [Transaction]) -> Double {
        // Match buys to sells for the same symbol using FIFO
        var buyDates: [String: [(date: Date, quantity: Double)]] = [:]
        var holdingPeriods: [Double] = []

        // Sort transactions chronologically
        let sortedTransactions = transactions.sorted { $0.transactionDate < $1.transactionDate }

        for tx in sortedTransactions {
            let symbol = tx.symbol.uppercased()

            switch tx.type {
            case .buy, .transferIn:
                // Add to buy queue
                buyDates[symbol, default: []].append((tx.transactionDate, tx.quantity))

            case .sell, .transferOut:
                // Match against buys FIFO
                var remainingQuantity = tx.quantity

                while remainingQuantity > 0, let firstBuy = buyDates[symbol]?.first {
                    let daysHeld = tx.transactionDate.timeIntervalSince(firstBuy.date) / 86400

                    if firstBuy.quantity <= remainingQuantity {
                        // Fully consume this buy lot
                        holdingPeriods.append(daysHeld)
                        remainingQuantity -= firstBuy.quantity
                        buyDates[symbol]?.removeFirst()
                    } else {
                        // Partially consume this buy lot
                        holdingPeriods.append(daysHeld)
                        buyDates[symbol]?[0].quantity -= remainingQuantity
                        remainingQuantity = 0
                    }
                }
            }
        }

        guard !holdingPeriods.isEmpty else { return 0 }
        return holdingPeriods.reduce(0, +) / Double(holdingPeriods.count)
    }
}
