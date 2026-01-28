import Foundation

/// Utility for statistical calculations including z-scores and standard deviations
struct StatisticsCalculator {

    // MARK: - Z-Score Result

    /// Result of a z-score calculation
    struct ZScoreResult: Codable, Equatable {
        let mean: Double
        let standardDeviation: Double
        let zScore: Double

        /// Whether this is an extreme move (|z| >= 3)
        var isExtreme: Bool {
            abs(zScore) >= 3.0
        }

        /// Whether this is a significant move (|z| >= 2)
        var isSignificant: Bool {
            abs(zScore) >= 2.0
        }

        /// Human-readable description of the z-score
        var description: String {
            if isExtreme {
                return zScore > 0 ? "Extremely High" : "Extremely Low"
            } else if isSignificant {
                return zScore > 0 ? "Significantly High" : "Significantly Low"
            } else if abs(zScore) >= 1.0 {
                return zScore > 0 ? "Above Average" : "Below Average"
            } else {
                return "Normal Range"
            }
        }

        /// Percentile approximation based on z-score (assumes normal distribution)
        var percentile: Double {
            // Using cumulative distribution function approximation
            // P(Z <= z) for standard normal
            return normalCDF(zScore) * 100
        }

        /// How rare this event is (1 in X occurrences)
        var rarity: Int? {
            let p = abs(zScore) >= 0 ? (1 - normalCDF(abs(zScore))) * 2 : 1.0 // Two-tailed
            guard p > 0 else { return nil }
            return Int(1.0 / p)
        }

        /// Format z-score for display with sigma symbol
        var formatted: String {
            String(format: "%+.1fσ", zScore)
        }
    }

    // MARK: - SD Bands

    /// Standard deviation bands for visualization
    struct SDBands: Codable, Equatable {
        let mean: Double
        let plus1SD: Double
        let plus2SD: Double
        let plus3SD: Double
        let minus1SD: Double
        let minus2SD: Double
        let minus3SD: Double
    }

    // MARK: - Calculations

    /// Calculate the mean (average) of an array of values
    /// - Parameter values: Array of numeric values
    /// - Returns: The arithmetic mean
    static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Calculate the sample standard deviation
    /// - Parameter values: Array of numeric values
    /// - Returns: The sample standard deviation
    static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }

        let avg = mean(values)
        let sumOfSquaredDiffs = values.reduce(0.0) { sum, value in
            let diff = value - avg
            return sum + (diff * diff)
        }

        // Sample standard deviation (n-1)
        return sqrt(sumOfSquaredDiffs / Double(values.count - 1))
    }

    /// Calculate the population standard deviation
    /// - Parameter values: Array of numeric values
    /// - Returns: The population standard deviation
    static func populationStandardDeviation(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }

        let avg = mean(values)
        let sumOfSquaredDiffs = values.reduce(0.0) { sum, value in
            let diff = value - avg
            return sum + (diff * diff)
        }

        return sqrt(sumOfSquaredDiffs / Double(values.count))
    }

    /// Calculate the z-score for a value given a dataset
    /// - Parameters:
    ///   - currentValue: The value to calculate z-score for
    ///   - history: Historical values to calculate mean and SD from
    /// - Returns: ZScoreResult if calculation is possible, nil if insufficient data
    static func calculateZScore(currentValue: Double, history: [Double]) -> ZScoreResult? {
        // Need at least 20 data points for meaningful statistics
        guard history.count >= 20 else { return nil }

        let avg = mean(history)
        let sd = standardDeviation(history)

        // Prevent division by zero
        guard sd > 0 else { return nil }

        let zScore = (currentValue - avg) / sd

        return ZScoreResult(
            mean: avg,
            standardDeviation: sd,
            zScore: zScore
        )
    }

    /// Calculate SD bands for visualization
    /// - Parameters:
    ///   - mean: The mean value
    ///   - sd: The standard deviation
    /// - Returns: SDBands with ±1, ±2, ±3 SD levels
    static func sdBands(mean: Double, sd: Double) -> SDBands {
        SDBands(
            mean: mean,
            plus1SD: mean + sd,
            plus2SD: mean + (2 * sd),
            plus3SD: mean + (3 * sd),
            minus1SD: mean - sd,
            minus2SD: mean - (2 * sd),
            minus3SD: mean - (3 * sd)
        )
    }

    /// Calculate SD bands from a dataset
    /// - Parameter values: Array of numeric values
    /// - Returns: SDBands if calculation is possible
    static func sdBands(from values: [Double]) -> SDBands? {
        guard values.count >= 2 else { return nil }

        let avg = mean(values)
        let sd = standardDeviation(values)

        guard sd > 0 else { return nil }

        return sdBands(mean: avg, sd: sd)
    }

    // MARK: - Rolling Statistics

    /// Calculate rolling z-score using a window of recent values
    /// - Parameters:
    ///   - currentValue: The value to calculate z-score for
    ///   - history: Historical values (newest first or oldest first - will be handled)
    ///   - windowSize: Number of periods to use for calculation (default 90)
    /// - Returns: ZScoreResult if calculation is possible
    static func rollingZScore(
        currentValue: Double,
        history: [Double],
        windowSize: Int = 90
    ) -> ZScoreResult? {
        // Use only the most recent windowSize values
        let windowData = Array(history.suffix(windowSize))
        return calculateZScore(currentValue: currentValue, history: windowData)
    }

    // MARK: - Private Helpers

    /// Cumulative distribution function for standard normal distribution
    /// Approximation using error function
    private static func normalCDF(_ x: Double) -> Double {
        // Using approximation: CDF(x) = 0.5 * (1 + erf(x / sqrt(2)))
        return 0.5 * (1.0 + erf(x / sqrt(2.0)))
    }

    /// Error function approximation
    private static func erf(_ x: Double) -> Double {
        // Horner form approximation
        let a1 =  0.254829592
        let a2 = -0.284496736
        let a3 =  1.421413741
        let a4 = -1.453152027
        let a5 =  1.061405429
        let p  =  0.3275911

        let sign = x < 0 ? -1.0 : 1.0
        let absX = abs(x)

        let t = 1.0 / (1.0 + p * absX)
        let y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-absX * absX)

        return sign * y
    }
}

// MARK: - Array Extension for Statistics

extension Array where Element == Double {
    /// Calculate the mean of the array
    var mean: Double {
        StatisticsCalculator.mean(self)
    }

    /// Calculate the standard deviation of the array
    var standardDeviation: Double {
        StatisticsCalculator.standardDeviation(self)
    }

    /// Calculate SD bands for the array
    var sdBands: StatisticsCalculator.SDBands? {
        StatisticsCalculator.sdBands(from: self)
    }
}
