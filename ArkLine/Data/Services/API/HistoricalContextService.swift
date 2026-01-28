import Foundation

/// Service for finding historical context around extreme macro indicator moves
final class HistoricalContextService {

    // MARK: - Dependencies

    private let marketService: MarketServiceProtocol

    // MARK: - Cache

    private let cache = APICache.shared
    private let cacheTTL: TimeInterval = 3600 // 1 hour

    // MARK: - Initialization

    init(marketService: MarketServiceProtocol? = nil) {
        self.marketService = marketService ?? ServiceContainer.shared.marketService
    }

    // MARK: - Historical Occurrence

    /// A historical occurrence of similar indicator conditions
    struct HistoricalOccurrence: Codable, Identifiable, Equatable {
        let id: UUID
        let date: Date
        let indicatorValue: Double
        let zScore: Double
        let btcPriceAtTime: Double
        let btcPerformance7d: Double?
        let btcPerformance30d: Double?
        let btcPerformance90d: Double?

        /// Formatted date string
        var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            return formatter.string(from: date)
        }

        /// Best performance available
        var bestPerformance: (days: Int, value: Double)? {
            if let p90 = btcPerformance90d {
                return (90, p90)
            } else if let p30 = btcPerformance30d {
                return (30, p30)
            } else if let p7 = btcPerformance7d {
                return (7, p7)
            }
            return nil
        }

        /// Human-readable summary
        var summary: String {
            guard let (days, value) = bestPerformance else {
                return "BTC was $\(Int(btcPriceAtTime).formatted())"
            }
            let direction = value >= 0 ? "+" : ""
            return "BTC \(direction)\(Int(value))% over \(days) days"
        }
    }

    // MARK: - Find Similar Occurrences

    /// Find historical occurrences where the indicator had a similar z-score
    /// - Parameters:
    ///   - indicator: The macro indicator type
    ///   - currentZScore: Current z-score to match
    ///   - indicatorHistory: Historical indicator values with dates
    ///   - threshold: Z-score similarity threshold (default ±0.5)
    /// - Returns: Array of historical occurrences sorted by date (newest first)
    func findSimilarOccurrences(
        for indicator: MacroIndicatorType,
        currentZScore: Double,
        indicatorHistory: [(date: Date, value: Double)],
        threshold: Double = 0.5
    ) async throws -> [HistoricalOccurrence] {
        let cacheKey = "historical_context_\(indicator.rawValue)_\(Int(currentZScore * 10))"

        // Check cache
        if let cached: [HistoricalOccurrence] = cache.get(cacheKey) {
            return cached
        }

        // Get BTC historical data
        let btcHistory = try await fetchBTCHistory()

        // Calculate z-scores for all historical points
        let historicalValues = indicatorHistory.map { $0.value }

        guard historicalValues.count >= 20 else {
            return []
        }

        var occurrences: [HistoricalOccurrence] = []

        // Find points where z-score was similar to current
        for (index, point) in indicatorHistory.enumerated() {
            // Use rolling z-score calculation
            let lookbackStart = max(0, index - 90)
            let lookbackValues = Array(historicalValues[lookbackStart..<index])

            guard lookbackValues.count >= 20,
                  let zScoreResult = StatisticsCalculator.calculateZScore(
                      currentValue: point.value,
                      history: lookbackValues
                  ) else {
                continue
            }

            // Check if z-score is similar to current
            let zScoreDiff = abs(zScoreResult.zScore - currentZScore)
            guard zScoreDiff <= threshold else {
                continue
            }

            // Only include if it was an extreme/significant move
            guard abs(zScoreResult.zScore) >= 2.0 else {
                continue
            }

            // Find BTC price at this date and calculate performance
            let btcAtTime = findBTCPrice(at: point.date, in: btcHistory)
            let performance7d = calculatePerformance(from: point.date, days: 7, btcHistory: btcHistory)
            let performance30d = calculatePerformance(from: point.date, days: 30, btcHistory: btcHistory)
            let performance90d = calculatePerformance(from: point.date, days: 90, btcHistory: btcHistory)

            guard let btcPrice = btcAtTime else { continue }

            let occurrence = HistoricalOccurrence(
                id: UUID(),
                date: point.date,
                indicatorValue: point.value,
                zScore: zScoreResult.zScore,
                btcPriceAtTime: btcPrice,
                btcPerformance7d: performance7d,
                btcPerformance30d: performance30d,
                btcPerformance90d: performance90d
            )

            occurrences.append(occurrence)
        }

        // Sort by date (newest first) and limit to 5 most relevant
        let result = Array(occurrences.sorted { $0.date > $1.date }.prefix(5))

        // Cache result
        cache.set(cacheKey, value: result, ttl: cacheTTL)

        return result
    }

    /// Find the most recent similar occurrence
    func findMostRecentSimilar(
        for indicator: MacroIndicatorType,
        currentZScore: Double,
        indicatorHistory: [(date: Date, value: Double)]
    ) async throws -> HistoricalOccurrence? {
        let occurrences = try await findSimilarOccurrences(
            for: indicator,
            currentZScore: currentZScore,
            indicatorHistory: indicatorHistory
        )
        return occurrences.first
    }

    /// Calculate average BTC performance after similar occurrences
    func averagePerformanceAfterSimilar(
        for indicator: MacroIndicatorType,
        currentZScore: Double,
        indicatorHistory: [(date: Date, value: Double)],
        days: Int = 30
    ) async throws -> Double? {
        let occurrences = try await findSimilarOccurrences(
            for: indicator,
            currentZScore: currentZScore,
            indicatorHistory: indicatorHistory
        )

        let performances: [Double]
        switch days {
        case 7:
            performances = occurrences.compactMap { $0.btcPerformance7d }
        case 30:
            performances = occurrences.compactMap { $0.btcPerformance30d }
        case 90:
            performances = occurrences.compactMap { $0.btcPerformance90d }
        default:
            performances = occurrences.compactMap { $0.btcPerformance30d }
        }

        guard !performances.isEmpty else { return nil }

        return performances.reduce(0, +) / Double(performances.count)
    }

    // MARK: - Private Helpers

    private func fetchBTCHistory() async throws -> [(date: Date, price: Double)] {
        // Fetch BTC market chart data (max available)
        let marketChart = try await marketService.fetchCoinMarketChart(id: "bitcoin", currency: "usd", days: 365)
        return marketChart.priceHistory.map { (date: $0.date, price: $0.price) }
    }

    private func findBTCPrice(at date: Date, in history: [(date: Date, price: Double)]) -> Double? {
        // Find the closest price to the given date
        let dayStart = Calendar.current.startOfDay(for: date)

        return history
            .filter { Calendar.current.isDate($0.date, inSameDayAs: dayStart) || $0.date > dayStart }
            .first?
            .price
    }

    private func calculatePerformance(
        from date: Date,
        days: Int,
        btcHistory: [(date: Date, price: Double)]
    ) -> Double? {
        guard let startPrice = findBTCPrice(at: date, in: btcHistory) else {
            return nil
        }

        let endDate = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
        guard let endPrice = findBTCPrice(at: endDate, in: btcHistory) else {
            return nil
        }

        return ((endPrice - startPrice) / startPrice) * 100
    }
}

// MARK: - Summary Generation

extension HistoricalContextService {

    /// Generate a summary of historical context for display
    struct HistoricalContextSummary {
        let indicator: MacroIndicatorType
        let currentZScore: Double
        let occurrenceCount: Int
        let mostRecent: HistoricalOccurrence?
        let avgPerformance30d: Double?
        let avgPerformance90d: Double?

        var summaryText: String {
            guard occurrenceCount > 0 else {
                return "No similar historical occurrences found"
            }

            var text = "Found \(occurrenceCount) similar occurrence(s)"

            if let recent = mostRecent {
                text += ". Last: \(recent.formattedDate)"
            }

            if let avg = avgPerformance30d {
                let sign = avg >= 0 ? "+" : ""
                text += ". Avg 30d BTC: \(sign)\(Int(avg))%"
            }

            return text
        }
    }

    /// Generate a comprehensive summary of historical context
    func generateSummary(
        for indicator: MacroIndicatorType,
        currentZScore: Double,
        indicatorHistory: [(date: Date, value: Double)]
    ) async throws -> HistoricalContextSummary {
        let occurrences = try await findSimilarOccurrences(
            for: indicator,
            currentZScore: currentZScore,
            indicatorHistory: indicatorHistory
        )

        let avg30d = occurrences.compactMap { $0.btcPerformance30d }.isEmpty ? nil :
            occurrences.compactMap { $0.btcPerformance30d }.reduce(0, +) / Double(occurrences.compactMap { $0.btcPerformance30d }.count)

        let avg90d = occurrences.compactMap { $0.btcPerformance90d }.isEmpty ? nil :
            occurrences.compactMap { $0.btcPerformance90d }.reduce(0, +) / Double(occurrences.compactMap { $0.btcPerformance90d }.count)

        return HistoricalContextSummary(
            indicator: indicator,
            currentZScore: currentZScore,
            occurrenceCount: occurrences.count,
            mostRecent: occurrences.first,
            avgPerformance30d: avg30d,
            avgPerformance90d: avg90d
        )
    }
}
