import Foundation

// MARK: - Logarithmic Regression
/// Math utilities for fitting logarithmic regression to price data.
/// Used to calculate "fair value" based on the formula: log(price) = a + b * log(days_since_origin)
struct LogarithmicRegression {

    // MARK: - Regression Result
    struct Result {
        /// Y-intercept coefficient
        let a: Double
        /// Slope coefficient
        let b: Double
        /// Coefficient of determination (R-squared)
        let rSquared: Double
        /// Origin date used for regression
        let originDate: Date

        /// Calculate fair value price at a given date
        func fairValueAt(date: Date) -> Double {
            let daysSinceOrigin = date.timeIntervalSince(originDate) / 86400.0
            guard daysSinceOrigin > 0 else { return 0 }

            // log(price) = a + b * log(days)
            // price = 10^(a + b * log10(days))
            let logPrice = a + b * log10(daysSinceOrigin)
            return pow(10, logPrice)
        }
    }

    // MARK: - Fit Regression
    /// Fits a logarithmic regression to price data.
    /// Formula: log10(price) = a + b * log10(days_since_origin)
    /// - Parameters:
    ///   - prices: Array of (date, price) tuples
    ///   - originDate: The origin date for calculating days since genesis
    /// - Returns: Regression result with coefficients and R-squared
    static func fit(prices: [(date: Date, price: Double)], originDate: Date) -> Result? {
        // Filter out invalid data points
        let validPrices = prices.filter { point in
            let days = point.date.timeIntervalSince(originDate) / 86400.0
            return days > 0 && point.price > 0
        }

        guard validPrices.count >= 10 else { return nil }

        // Transform to log-log space
        var sumX: Double = 0
        var sumY: Double = 0
        var sumXX: Double = 0
        var sumXY: Double = 0
        let n = Double(validPrices.count)

        for point in validPrices {
            let days = point.date.timeIntervalSince(originDate) / 86400.0
            let x = log10(days)
            let y = log10(point.price)

            sumX += x
            sumY += y
            sumXX += x * x
            sumXY += x * y
        }

        // Calculate slope (b) and intercept (a) using least squares
        let denominator = n * sumXX - sumX * sumX
        guard abs(denominator) > 1e-10 else { return nil }

        let b = (n * sumXY - sumX * sumY) / denominator
        let a = (sumY - b * sumX) / n

        // Calculate R-squared
        let meanY = sumY / n
        var ssTotal: Double = 0
        var ssResidual: Double = 0

        for point in validPrices {
            let days = point.date.timeIntervalSince(originDate) / 86400.0
            let x = log10(days)
            let y = log10(point.price)
            let predicted = a + b * x

            ssTotal += (y - meanY) * (y - meanY)
            ssResidual += (y - predicted) * (y - predicted)
        }

        let rSquared = ssTotal > 0 ? 1 - (ssResidual / ssTotal) : 0

        return Result(a: a, b: b, rSquared: rSquared, originDate: originDate)
    }

    // MARK: - Calculate Log Deviation
    /// Calculates the logarithmic deviation of actual price from fair value.
    /// Deviation = log10(actualPrice) - log10(fairValue)
    /// - Parameters:
    ///   - actualPrice: Current market price
    ///   - fairValue: Calculated fair value from regression
    /// - Returns: Log deviation (positive = overvalued, negative = undervalued)
    static func logDeviation(actualPrice: Double, fairValue: Double) -> Double {
        guard actualPrice > 0 && fairValue > 0 else { return 0 }
        return log10(actualPrice) - log10(fairValue)
    }

    // MARK: - Normalize Deviation to Risk
    /// Normalizes a log deviation to a 0.0-1.0 risk scale.
    /// - Parameters:
    ///   - deviation: Log deviation from fair value
    ///   - bounds: Min and max bounds for normalization (e.g., -0.8 to 0.8)
    /// - Returns: Risk level from 0.0 (extremely undervalued) to 1.0 (extremely overvalued)
    static func normalizeDeviation(_ deviation: Double, bounds: (low: Double, high: Double)) -> Double {
        // Clamp deviation to bounds
        let clampedDeviation = max(bounds.low, min(bounds.high, deviation))

        // Map from [low, high] to [0, 1]
        let range = bounds.high - bounds.low
        guard range > 0 else { return 0.5 }

        return (clampedDeviation - bounds.low) / range
    }
}
