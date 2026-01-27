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

    // MARK: - Multi-Factor Risk Calculation

    /// Calculate multi-factor risk for a single price point.
    /// Combines logarithmic regression with 5 supplementary factors.
    /// - Parameters:
    ///   - price: Current price of the asset
    ///   - date: Date of the price point
    ///   - config: Asset-specific configuration
    ///   - factorData: Supplementary factor data (RSI, SMA, funding, etc.)
    ///   - weights: Weight configuration (defaults to standard weights)
    ///   - regression: Pre-calculated regression (optional)
    ///   - priceHistory: Historical prices for fitting regression (if regression not provided)
    /// - Returns: Multi-factor risk point with full breakdown, nil if base regression fails
    func calculateMultiFactorRisk(
        price: Double,
        date: Date,
        config: AssetRiskConfig,
        factorData: RiskFactorData,
        weights: RiskFactorWeights = .default,
        regression: LogarithmicRegression.Result? = nil,
        priceHistory: [(date: Date, price: Double)]? = nil
    ) -> MultiFactorRiskPoint? {
        // Step 1: Calculate base regression risk (required)
        guard let baseRisk = calculateRisk(
            price: price,
            date: date,
            config: config,
            regression: regression,
            priceHistory: priceHistory
        ) else {
            return nil // Base regression is critical dependency
        }

        // Step 2: Build factor array with normalized values
        var factors: [RiskFactor] = []

        // Factor 1: Log Regression (always available if we got here)
        factors.append(RiskFactor(
            type: .logRegression,
            rawValue: baseRisk.deviation,
            normalizedValue: baseRisk.riskLevel,
            weight: weights.logRegression
        ))

        // Factor 2: RSI
        if let rsi = factorData.rsi {
            factors.append(RiskFactor(
                type: .rsi,
                rawValue: rsi,
                normalizedValue: RiskFactorNormalizer.normalizeRSI(rsi),
                weight: weights.rsi
            ))
        } else {
            factors.append(.unavailable(.rsi, weight: weights.rsi))
        }

        // Factor 3: SMA Position
        if let sma200 = factorData.sma200, let currentPrice = factorData.currentPrice ?? Optional(price) {
            let normalizedSMA = RiskFactorNormalizer.normalizeSMAPosition(price: currentPrice, sma200: sma200)
            factors.append(RiskFactor(
                type: .smaPosition,
                rawValue: currentPrice > sma200 ? 0.3 : 0.7, // Store binary state as raw
                normalizedValue: normalizedSMA,
                weight: weights.smaPosition
            ))
        } else {
            factors.append(.unavailable(.smaPosition, weight: weights.smaPosition))
        }

        // Factor 4: Funding Rate
        if let fundingRate = factorData.fundingRate {
            factors.append(RiskFactor(
                type: .fundingRate,
                rawValue: fundingRate,
                normalizedValue: RiskFactorNormalizer.normalizeFundingRate(fundingRate),
                weight: weights.fundingRate
            ))
        } else {
            factors.append(.unavailable(.fundingRate, weight: weights.fundingRate))
        }

        // Factor 5: Fear & Greed
        if let fearGreed = factorData.fearGreedValue {
            factors.append(RiskFactor(
                type: .fearGreed,
                rawValue: fearGreed,
                normalizedValue: RiskFactorNormalizer.normalizeFearGreed(fearGreed),
                weight: weights.fearGreed
            ))
        } else {
            factors.append(.unavailable(.fearGreed, weight: weights.fearGreed))
        }

        // Factor 6: Macro Risk (VIX + DXY average)
        if let macroNormalized = RiskFactorNormalizer.normalizeMacroRisk(
            vix: factorData.vixValue,
            dxy: factorData.dxyValue
        ) {
            // Calculate raw value as simple average for display
            let rawMacro: Double
            switch (factorData.vixValue, factorData.dxyValue) {
            case let (.some(v), .some(d)):
                rawMacro = (v + d) / 2.0
            case let (.some(v), .none):
                rawMacro = v
            case let (.none, .some(d)):
                rawMacro = d
            default:
                rawMacro = 0
            }

            factors.append(RiskFactor(
                type: .macroRisk,
                rawValue: rawMacro,
                normalizedValue: macroNormalized,
                weight: weights.macroRisk
            ))
        } else {
            factors.append(.unavailable(.macroRisk, weight: weights.macroRisk))
        }

        // Step 3: Renormalize weights based on available factors
        let renormalizedFactors = RiskFactorNormalizer.renormalizeWeights(
            factors: factors,
            originalWeights: weights
        )

        // Step 4: Calculate composite risk level
        let compositeRisk = renormalizedFactors
            .compactMap { $0.weightedContribution }
            .reduce(0.0, +)

        // Clamp to valid range
        let finalRisk = max(0.0, min(1.0, compositeRisk))

        return MultiFactorRiskPoint(
            date: date,
            riskLevel: finalRisk,
            price: price,
            fairValue: baseRisk.fairValue,
            deviation: baseRisk.deviation,
            factors: renormalizedFactors,
            weights: weights
        )
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
