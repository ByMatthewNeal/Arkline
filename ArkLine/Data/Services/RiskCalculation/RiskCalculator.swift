import Foundation

// MARK: - Risk Calculator
/// Core service for calculating asset risk levels using logarithmic regression.
/// Replicates ITC (Into The Cryptoverse) methodology.
final class RiskCalculator {

    // MARK: - Singleton
    static let shared = RiskCalculator()

    // MARK: - Cache
    private var regressionCache: [String: LogarithmicRegression.Result] = [:]

    // MARK: - Calculate Risk for Single Price Point

    /// Calculate risk level for a single price point.
    /// - Parameters:
    ///   - price: Current price of the asset
    ///   - date: Date of the price point
    ///   - config: Asset-specific configuration
    ///   - regression: Pre-calculated regression (optional, will fit if not provided)
    ///   - priceHistory: Historical prices for fitting regression (if regression not provided)
    /// - Returns: Calculated risk history point
    func calculateRisk(
        price: Double,
        date: Date,
        config: AssetRiskConfig,
        regression: LogarithmicRegression.Result? = nil,
        priceHistory: [(date: Date, price: Double)]? = nil
    ) -> RiskHistoryPoint? {
        // Get or calculate regression
        let reg: LogarithmicRegression.Result?

        if let regression = regression {
            reg = regression
        } else if let history = priceHistory {
            reg = LogarithmicRegression.fit(prices: history, originDate: config.originDate)
        } else if let cached = regressionCache[config.assetId] {
            reg = cached
        } else {
            return nil
        }

        guard let regression = reg else { return nil }

        // Calculate fair value
        let fairValue = regression.fairValueAt(date: date)
        guard fairValue > 0 else { return nil }

        // Calculate deviation
        let deviation = LogarithmicRegression.logDeviation(actualPrice: price, fairValue: fairValue)

        // Normalize to risk level
        let riskLevel = LogarithmicRegression.normalizeDeviation(deviation, bounds: config.deviationBounds)

        return RiskHistoryPoint(
            date: date,
            riskLevel: riskLevel,
            price: price,
            fairValue: fairValue,
            deviation: deviation
        )
    }

    // MARK: - Calculate Risk History

    /// Calculate risk levels for an array of price points.
    /// - Parameters:
    ///   - prices: Array of price points (date, price)
    ///   - config: Asset-specific configuration
    /// - Returns: Array of risk history points sorted by date
    func calculateRiskHistory(
        prices: [(date: Date, price: Double)],
        config: AssetRiskConfig
    ) -> [RiskHistoryPoint] {
        // Fit regression to all price data
        guard let regression = LogarithmicRegression.fit(prices: prices, originDate: config.originDate) else {
            return []
        }

        // Cache the regression for future single-point calculations
        regressionCache[config.assetId] = regression

        // Calculate risk for each price point
        return prices.compactMap { point -> RiskHistoryPoint? in
            calculateRisk(
                price: point.price,
                date: point.date,
                config: config,
                regression: regression
            )
        }.sorted { $0.date < $1.date }
    }

    // MARK: - Calculate from CoinGecko Data

    /// Calculate risk history from CoinGecko market chart data.
    /// - Parameters:
    ///   - marketChart: CoinGecko market chart response
    ///   - config: Asset-specific configuration
    /// - Returns: Array of risk history points
    func calculateRiskHistory(
        from marketChart: CoinGeckoMarketChart,
        config: AssetRiskConfig
    ) -> [RiskHistoryPoint] {
        let pricePoints = marketChart.priceHistory.map { ($0.date, $0.price) }
        return calculateRiskHistory(prices: pricePoints, config: config)
    }

    // MARK: - Sample Data for Specific Time Ranges

    /// Samples risk history data to reduce points for chart display.
    /// - Parameters:
    ///   - history: Full risk history
    ///   - days: Number of days to display (nil for all)
    ///   - maxPoints: Maximum number of points to return
    /// - Returns: Sampled risk history
    func sampleHistory(_ history: [RiskHistoryPoint], days: Int?, maxPoints: Int = 100) -> [RiskHistoryPoint] {
        // Filter by days if specified
        let filtered: [RiskHistoryPoint]
        if let days = days {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            filtered = history.filter { $0.date >= cutoffDate }
        } else {
            filtered = history
        }

        // Sample if too many points
        guard filtered.count > maxPoints else { return filtered }

        let step = filtered.count / maxPoints
        var sampled: [RiskHistoryPoint] = []

        for i in stride(from: 0, to: filtered.count, by: step) {
            sampled.append(filtered[i])
        }

        // Always include the last point
        if let last = filtered.last, sampled.last?.date != last.date {
            sampled.append(last)
        }

        return sampled
    }

    // MARK: - Clear Cache

    /// Clear the regression cache
    func clearCache() {
        regressionCache.removeAll()
    }

    /// Clear cache for a specific asset
    func clearCache(for assetId: String) {
        regressionCache.removeValue(forKey: assetId)
    }

    // MARK: - Private Init
    private init() {}
}
