import Foundation

/// Calculates portfolio performance metrics from transactions, holdings, and history
struct PerformanceMetricsCalculator {

    /// Calculate all performance metrics
    /// - Parameters:
    ///   - transactions: All portfolio transactions
    ///   - historyPoints: Portfolio value history for drawdown/sharpe calculation
    ///   - holdings: Current portfolio holdings
    ///   - totalReturn: Current total P/L amount
    ///   - totalReturnPercentage: Current total P/L percentage
    /// - Returns: Calculated PerformanceMetrics
    static func calculate(
        transactions: [Transaction],
        historyPoints: [PortfolioHistoryPoint],
        holdings: [PortfolioHolding],
        totalReturn: Double,
        totalReturnPercentage: Double
    ) -> PerformanceMetrics {

        // Total invested (sum of all buy transaction values)
        let totalInvested = transactions
            .filter { $0.type == .buy }
            .reduce(0.0) { $0 + ($1.quantity * $1.pricePerUnit) }

        // Current value from holdings
        let currentValue = holdings.reduce(0.0) { $0 + $1.currentValue }

        // Maximum drawdown from portfolio history
        let (maxDrawdownPct, maxDrawdownValue) = calculateMaxDrawdown(historyPoints)

        // Sharpe ratio (using daily returns from history)
        let sharpeRatio = calculateSharpeRatio(historyPoints)

        // Monthly investment activity
        let monthlyInvestments = calculateMonthlyInvestments(transactions)

        return PerformanceMetrics(
            totalReturn: totalReturn,
            totalReturnPercentage: totalReturnPercentage,
            totalInvested: totalInvested,
            currentValue: currentValue,
            numberOfAssets: holdings.count,
            maxDrawdown: maxDrawdownPct,
            maxDrawdownValue: maxDrawdownValue,
            sharpeRatio: sharpeRatio,
            monthlyInvestments: monthlyInvestments
        )
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

    // MARK: - Monthly Investments

    /// Groups buy transactions by month, returns last 6 months
    static func calculateMonthlyInvestments(_ transactions: [Transaction]) -> [MonthlyInvestment] {
        let buys = transactions.filter { $0.type == .buy }
        guard !buys.isEmpty else { return [] }

        let calendar = Calendar.current
        let monthKeyFormatter = DateFormatter()
        monthKeyFormatter.dateFormat = "yyyy-MM"

        let labelFormatter = DateFormatter()
        labelFormatter.dateFormat = "MMM ''yy"

        // Group by month
        var monthlyTotals: [String: (label: String, amount: Double, date: Date)] = [:]

        for tx in buys {
            let key = monthKeyFormatter.string(from: tx.transactionDate)
            let label = labelFormatter.string(from: tx.transactionDate)
            let amount = tx.quantity * tx.pricePerUnit

            if let existing = monthlyTotals[key] {
                monthlyTotals[key] = (label: existing.label, amount: existing.amount + amount, date: existing.date)
            } else {
                // Use the first day of the month for sorting
                let components = calendar.dateComponents([.year, .month], from: tx.transactionDate)
                let monthDate = calendar.date(from: components) ?? tx.transactionDate
                monthlyTotals[key] = (label: label, amount: amount, date: monthDate)
            }
        }

        // Sort by date descending and take last 6
        let sorted = monthlyTotals
            .sorted { $0.value.date > $1.value.date }
            .prefix(6)
            .reversed() // Show oldest first (left to right)
            .map { MonthlyInvestment(monthKey: $0.key, label: $0.value.label, amount: $0.value.amount) }

        return Array(sorted)
    }
}
