import Foundation

// MARK: - Risk Calculator
/// Core service for calculating asset risk levels using logarithmic regression.
/// Replicates ITC (Into The Cryptoverse) methodology.
final class RiskCalculator {

    // MARK: - Singleton
    static let shared = RiskCalculator()

    // MARK: - Cache
    private var regressionCache: [String: LogarithmicRegression.Result] = [:]
    private let cacheLock = NSLock()

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
        } else if let cached = cacheLock.withLock({ regressionCache[config.assetId] }) {
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

    // MARK: - Calculate Risk with Regression Result

    /// Calculate risk and return both the risk point and the regression result.
    /// This exposes R-squared for adaptive confidence tracking.
    func calculateRiskWithRegression(
        price: Double,
        date: Date,
        config: AssetRiskConfig,
        priceHistory: [(date: Date, price: Double)]
    ) -> (risk: RiskHistoryPoint, regression: LogarithmicRegression.Result)? {
        guard let regression = LogarithmicRegression.fit(
            prices: priceHistory, originDate: config.originDate
        ) else { return nil }

        cacheLock.withLock { regressionCache[config.assetId] = regression; return }

        guard let risk = calculateRisk(
            price: price, date: date, config: config, regression: regression
        ) else { return nil }

        return (risk, regression)
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
        cacheLock.withLock { regressionCache[config.assetId] = regression; return }

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

    // MARK: - Stock Risk Calculation (Multi-Factor, No Regression)

    /// Calculate stock risk using price-derived factors instead of log regression.
    /// Factors: 200-SMA deviation (40%), RSI (25%), relative 52-week position (20%), 50-SMA trend (15%)
    /// All computed from price history alone — no external API needed.
    func calculateStockRisk(
        priceHistory: [(date: Date, price: Double)],
        config: AssetRiskConfig
    ) -> RiskHistoryPoint? {
        guard priceHistory.count >= 200 else {
            // Need at least 200 days for SMA200
            guard priceHistory.count >= 50 else { return nil }
            // Fallback: use what we have
            return calculateStockRiskPartial(priceHistory: priceHistory, config: config)
        }

        let closes = priceHistory.map(\.price)
        let currentPrice = closes.last ?? 0
        guard currentPrice > 0 else { return nil }

        // Factor 1: Price vs 200-SMA deviation (40%)
        // >20% above = high risk, at SMA = neutral, >20% below = low risk
        let sma200 = closes.suffix(200).reduce(0, +) / 200.0
        let smaDeviation = (currentPrice - sma200) / sma200  // e.g., 0.15 = 15% above
        let smaRisk = min(1.0, max(0.0, (smaDeviation + 0.20) / 0.40))  // -20% → 0, +20% → 1

        // Factor 2: RSI(14) (25%)
        let rsiRisk: Double
        if closes.count >= 15 {
            let rsi = computeRSI(closes: closes)
            rsiRisk = min(1.0, max(0.0, rsi / 100.0))  // 0-100 → 0-1
        } else {
            rsiRisk = 0.5  // neutral fallback
        }

        // Factor 3: 52-week range position (20%)
        // Near yearly high = high risk, near yearly low = low risk
        let yearSlice = closes.suffix(252)  // ~252 trading days in a year
        let yearHigh = yearSlice.max() ?? currentPrice
        let yearLow = yearSlice.min() ?? currentPrice
        let yearRange = yearHigh - yearLow
        let yearRisk = yearRange > 0 ? (currentPrice - yearLow) / yearRange : 0.5

        // Factor 4: 50-SMA trend direction (15%)
        // SMA slope: rising = higher risk (extended), falling = lower risk (discounted)
        let sma50 = closes.suffix(50).reduce(0, +) / 50.0
        let sma50_10dAgo: Double = {
            let offset = min(closes.count, 60)
            let slice = closes.suffix(offset).prefix(50)
            return slice.isEmpty ? sma50 : slice.reduce(0, +) / Double(slice.count)
        }()
        let smaSlope = sma50 > 0 ? (sma50 - sma50_10dAgo) / sma50 : 0
        // Map slope: -2% → 0, +2% → 1
        let trendRisk = min(1.0, max(0.0, (smaSlope + 0.02) / 0.04))

        // Weighted composite
        let riskLevel = smaRisk * 0.40 + rsiRisk * 0.25 + yearRisk * 0.20 + trendRisk * 0.15

        return RiskHistoryPoint(
            date: Date(),
            riskLevel: min(1.0, max(0.0, riskLevel)),
            price: currentPrice,
            fairValue: sma200,  // Use 200-SMA as "fair value" proxy
            deviation: smaDeviation
        )
    }

    /// Partial calculation when <200 days of data available
    private func calculateStockRiskPartial(
        priceHistory: [(date: Date, price: Double)],
        config: AssetRiskConfig
    ) -> RiskHistoryPoint? {
        let closes = priceHistory.map(\.price)
        let currentPrice = closes.last ?? 0
        guard currentPrice > 0 else { return nil }

        let sma50 = closes.suffix(50).reduce(0, +) / Double(min(closes.count, 50))
        let deviation = sma50 > 0 ? (currentPrice - sma50) / sma50 : 0

        let rsiRisk: Double = closes.count >= 15 ? computeRSI(closes: closes) / 100.0 : 0.5
        let smaRisk = min(1.0, max(0.0, (deviation + 0.15) / 0.30))

        let riskLevel = smaRisk * 0.55 + rsiRisk * 0.45

        return RiskHistoryPoint(
            date: Date(),
            riskLevel: min(1.0, max(0.0, riskLevel)),
            price: currentPrice,
            fairValue: sma50,
            deviation: deviation
        )
    }

    /// Compute RSI(14) from an array of closing prices
    private func computeRSI(closes: [Double], period: Int = 14) -> Double {
        guard closes.count > period else { return 50 }

        var gains: [Double] = []
        var losses: [Double] = []
        for i in (closes.count - period - 1)..<(closes.count - 1) {
            let change = closes[i + 1] - closes[i]
            gains.append(max(0, change))
            losses.append(max(0, -change))
        }

        let avgGain = gains.reduce(0, +) / Double(period)
        let avgLoss = losses.reduce(0, +) / Double(period)

        guard avgLoss > 0 else { return 100 }
        let rs = avgGain / avgLoss
        return 100 - (100 / (1 + rs))
    }

    /// Calculate stock risk history for charting
    func calculateStockRiskHistory(
        priceHistory: [(date: Date, price: Double)]
    ) -> [RiskHistoryPoint] {
        guard priceHistory.count >= 200 else { return [] }

        let closes = priceHistory.map(\.price)
        var results: [RiskHistoryPoint] = []

        // Calculate for each day starting from day 200
        for i in 200..<closes.count {
            let slice = Array(closes[0...i])
            let currentPrice = slice.last ?? 0
            guard currentPrice > 0 else { continue }

            let sma200 = slice.suffix(200).reduce(0, +) / 200.0
            let smaDeviation = (currentPrice - sma200) / sma200
            let smaRisk = min(1.0, max(0.0, (smaDeviation + 0.20) / 0.40))

            let rsi = computeRSI(closes: Array(slice))
            let rsiRisk = min(1.0, max(0.0, rsi / 100.0))

            let yearSlice = slice.suffix(252)
            let yearHigh = yearSlice.max() ?? currentPrice
            let yearLow = yearSlice.min() ?? currentPrice
            let yearRange = yearHigh - yearLow
            let yearRisk = yearRange > 0 ? (currentPrice - yearLow) / yearRange : 0.5

            let sma50 = slice.suffix(50).reduce(0, +) / 50.0
            let offset = min(slice.count, 60)
            let sma50_prev = Array(slice.suffix(offset).prefix(50))
            let sma50_10dAgo = sma50_prev.isEmpty ? sma50 : sma50_prev.reduce(0, +) / Double(sma50_prev.count)
            let smaSlope = sma50 > 0 ? (sma50 - sma50_10dAgo) / sma50 : 0
            let trendRisk = min(1.0, max(0.0, (smaSlope + 0.02) / 0.04))

            let riskLevel = smaRisk * 0.40 + rsiRisk * 0.25 + yearRisk * 0.20 + trendRisk * 0.15

            results.append(RiskHistoryPoint(
                date: priceHistory[i].date,
                riskLevel: min(1.0, max(0.0, riskLevel)),
                price: currentPrice,
                fairValue: sma200,
                deviation: smaDeviation
            ))
        }

        return results
    }

    // MARK: - Multi-Factor Risk Calculation

    /// Calculate multi-factor risk for a single price point.
    /// Combines logarithmic regression with 7 supplementary factors.
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

        // Factor 4: Bull Market Support Bands
        if let bands = factorData.bullMarketBands {
            let normalizedBMSB = RiskFactorNormalizer.normalizeBullMarketBands(bands)
            factors.append(RiskFactor(
                type: .bullMarketBands,
                rawValue: bands.percentFromSMA, // Store % from 20W SMA as raw
                normalizedValue: normalizedBMSB,
                weight: weights.bullMarketBands
            ))
        } else {
            factors.append(.unavailable(.bullMarketBands, weight: weights.bullMarketBands))
        }

        // Factor 5: Funding Rate
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

        // Factor 6: Fear & Greed
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

        // Factor 7: Macro Risk (VIX + DXY average)
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

        // Factor 8: Oil Risk (WTI Crude Oil)
        if let oil = factorData.oilValue {
            factors.append(RiskFactor(
                type: .oilRisk,
                rawValue: oil,
                normalizedValue: RiskFactorNormalizer.normalizeOilRisk(oil),
                weight: weights.oilRisk
            ))
        } else {
            factors.append(.unavailable(.oilRisk, weight: weights.oilRisk))
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
        cacheLock.withLock { regressionCache.removeAll(); return }
    }

    /// Clear cache for a specific asset
    func clearCache(for assetId: String) {
        cacheLock.withLock { regressionCache.removeValue(forKey: assetId); return }
    }

    // MARK: - Private Init
    private init() {}
}
