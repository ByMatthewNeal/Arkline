import Foundation

// MARK: - Sentiment Regime Service
/// Computes sentiment regime quadrant data using composite multi-indicator scores.
///
/// **Emotion axis** (Fear → Greed) composites:
///   - Fear & Greed Index (40%) — direct market sentiment
///   - BTC Risk Level (20%) — cycle position from ITC model
///   - Funding Rates (15%) — leverage sentiment (positive = greedy longs)
///   - Altcoin Season Index (15%) — alt speculation = greed
///   - BTC Dominance (10%) — falling dominance = risk-on speculation
///
/// **Engagement axis** (Low → High) composites:
///   - BTC Volume vs 30d SMA (40%) — core trading activity
///   - Funding Rate magnitude (20%) — high absolute rate = active market
///   - App Store Rankings (20%) — retail FOMO/interest
///   - Search Interest (20%) — public attention
///
/// Historical trajectory uses Fear & Greed + Volume (both have 90-day API history).
/// The current "Now" point uses the full composite from all live indicators.
enum SentimentRegimeService {

    // MARK: - Composite Weights

    private struct EmotionWeights {
        static let fearGreed: Double = 0.40
        static let btcRisk: Double = 0.20
        static let fundingRate: Double = 0.15
        static let altcoinSeason: Double = 0.15
        static let btcDominance: Double = 0.10
    }

    private struct EngagementWeights {
        static let volume: Double = 0.40
        static let fundingMagnitude: Double = 0.20
        static let appStore: Double = 0.20
        static let searchInterest: Double = 0.20
    }

    // MARK: - Public API

    /// Computes the full regime data set with composite scoring.
    /// - Parameters:
    ///   - fearGreedHistory: Array of FearGreedIndex, newest-first from Alternative.me
    ///   - volumeData: Array of [timestamp_ms, volume_usd] from CoinGeckoMarketChart.totalVolumes
    ///   - liveIndicators: Optional snapshot of current live indicators for enhanced "Now" point
    /// - Returns: SentimentRegimeData with trajectory, milestones, and component labels
    static func computeRegimeData(
        fearGreedHistory: [FearGreedIndex],
        volumeData: [[Double]],
        liveIndicators: RegimeIndicatorSnapshot? = nil
    ) -> SentimentRegimeData? {
        guard !fearGreedHistory.isEmpty, !volumeData.isEmpty else { return nil }

        let calendar = Calendar(identifier: .gregorian)

        // 1. Parse and normalize volume data
        var volumeChronological: [(date: Date, volume: Double)] = []
        for entry in volumeData {
            guard entry.count >= 2 else { continue }
            let date = Date(timeIntervalSince1970: entry[0] / 1000.0)
            volumeChronological.append((date, entry[1]))
        }
        volumeChronological.sort { $0.date < $1.date }

        var volumeNormalized: [String: Double] = [:]
        for i in 0..<volumeChronological.count {
            let windowStart = max(0, i - 29)
            let window = volumeChronological[windowStart...i]
            let sma = window.map(\.volume).reduce(0, +) / Double(window.count)
            let engagement = sigmoidNormalize(value: volumeChronological[i].volume, average: sma)
            volumeNormalized[dayKey(for: volumeChronological[i].date, calendar: calendar)] = engagement
        }

        // 2. Build trajectory points (historical: F&G + Volume only)
        var points: [SentimentRegimePoint] = []
        for fg in fearGreedHistory {
            let key = dayKey(for: fg.timestamp, calendar: calendar)
            guard let volumeEngagement = volumeNormalized[key] else { continue }
            let point = SentimentRegimePoint(
                date: fg.timestamp,
                emotionScore: Double(fg.value),
                engagementScore: volumeEngagement
            )
            points.append(point)
        }

        guard !points.isEmpty else { return nil }
        points.sort { $0.date < $1.date }

        // 3. Compute composite "Now" point if live indicators available
        var emotionComponents = ["Fear & Greed"]
        var engagementComponents = ["BTC Volume"]

        if let live = liveIndicators, let latestFG = fearGreedHistory.first {
            let latestVolumeKey = dayKey(for: latestFG.timestamp, calendar: calendar)
            let baseVolume = volumeNormalized[latestVolumeKey] ?? 50.0

            let (compositeEmotion, emoLabels) = computeCompositeEmotion(
                fearGreed: latestFG.value,
                indicators: live
            )
            let (compositeEngagement, engLabels) = computeCompositeEngagement(
                volumeScore: baseVolume,
                indicators: live
            )

            emotionComponents = emoLabels
            engagementComponents = engLabels

            let compositePoint = SentimentRegimePoint(
                date: latestFG.timestamp,
                emotionScore: compositeEmotion,
                engagementScore: compositeEngagement
            )

            // Replace the last point with the composite version
            if !points.isEmpty {
                points[points.count - 1] = compositePoint
            }
        }

        // 4. Extract milestones
        let today = points.last!
        let oneWeekAgo = findClosestPoint(to: calendar.date(byAdding: .day, value: -7, to: today.date)!, in: points, tolerance: 2)
        let oneMonthAgo = findClosestPoint(to: calendar.date(byAdding: .day, value: -30, to: today.date)!, in: points, tolerance: 3)
        let threeMonthsAgo = findClosestPoint(to: calendar.date(byAdding: .day, value: -90, to: today.date)!, in: points, tolerance: 5)

        return SentimentRegimeData(
            currentRegime: today.regime,
            currentPoint: today,
            milestones: RegimeMilestones(
                today: today,
                oneWeekAgo: oneWeekAgo,
                oneMonthAgo: oneMonthAgo,
                threeMonthsAgo: threeMonthsAgo
            ),
            trajectory: points,
            emotionComponents: emotionComponents,
            engagementComponents: engagementComponents
        )
    }

    // MARK: - Composite Emotion Score

    /// Computes a weighted composite emotion score (0-100) from multiple indicators.
    /// Missing indicators have their weight redistributed to available ones.
    static func computeCompositeEmotion(
        fearGreed: Int,
        indicators: RegimeIndicatorSnapshot
    ) -> (score: Double, components: [String]) {
        var components: [(score: Double, weight: Double, label: String)] = []

        // Fear & Greed (always available) — 0-100 direct
        components.append((Double(fearGreed), EmotionWeights.fearGreed, "Fear & Greed"))

        // BTC Risk Level — 0.0-1.0 mapped to 0-100 (higher risk = more greed)
        if let risk = indicators.btcRiskLevel {
            components.append((risk * 100.0, EmotionWeights.btcRisk, "BTC Risk"))
        }

        // Funding Rate — typically -0.01 to +0.01, normalize to 0-100
        // Positive = longs paying shorts = bullish/greedy
        if let rate = indicators.fundingRate {
            let normalized = sigmoidNormalize(value: rate, average: 0, k: 300)
            components.append((normalized, EmotionWeights.fundingRate, "Funding Rate"))
        }

        // Altcoin Season — 0-100 direct (higher = more alt speculation = greed)
        if let alt = indicators.altcoinSeason {
            components.append((Double(alt), EmotionWeights.altcoinSeason, "Altcoin Season"))
        }

        // BTC Dominance — inverted: lower dominance = more speculation = greed
        // Typical range: 40-70%, map to 0-100 inverted
        if let dom = indicators.btcDominance {
            let inverted = max(0, min(100, (70.0 - dom) / 30.0 * 100.0))
            components.append((inverted, EmotionWeights.btcDominance, "BTC Dominance"))
        }

        return weightedAverage(components)
    }

    // MARK: - Composite Engagement Score

    /// Computes a weighted composite engagement score (0-100) from multiple indicators.
    /// Missing indicators have their weight redistributed to available ones.
    static func computeCompositeEngagement(
        volumeScore: Double,
        indicators: RegimeIndicatorSnapshot
    ) -> (score: Double, components: [String]) {
        var components: [(score: Double, weight: Double, label: String)] = []

        // Volume vs SMA (always available) — already 0-100 sigmoid
        components.append((volumeScore, EngagementWeights.volume, "BTC Volume"))

        // Funding Rate magnitude — high absolute rate = active market
        if let rate = indicators.fundingRate {
            let magnitude = abs(rate)
            // abs rate typically 0-0.005, map via sigmoid: 0.001 avg
            let normalized = sigmoidNormalize(value: magnitude, average: 0.001, k: 1500)
            components.append((normalized, EngagementWeights.fundingMagnitude, "Funding Activity"))
        }

        // App Store Rankings — higher score = more retail interest/engagement
        if let score = indicators.appStoreScore {
            components.append((score, EngagementWeights.appStore, "App Store"))
        }

        // Search Interest — 0-100 direct
        if let search = indicators.searchInterest {
            components.append((Double(search), EngagementWeights.searchInterest, "Search Trends"))
        }

        return weightedAverage(components)
    }

    // MARK: - Helpers

    /// Sigmoid normalization: maps a value relative to its average to 0-100.
    /// When value == average, returns 50. Higher k = steeper curve.
    static func sigmoidNormalize(value: Double, average: Double, k: Double = 3.0) -> Double {
        guard average != 0 || k > 100 else {
            // For zero-centered data (like funding rates), use value directly
            let score = 100.0 / (1.0 + exp(-k * value))
            return min(100, max(0, score))
        }
        let ratio = value / average
        let score = 100.0 / (1.0 + exp(-k * (ratio - 1.0)))
        return min(100, max(0, score))
    }

    /// Computes weighted average, redistributing weight from missing components.
    private static func weightedAverage(
        _ components: [(score: Double, weight: Double, label: String)]
    ) -> (score: Double, components: [String]) {
        let totalWeight = components.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return (50.0, []) }

        let score = components.reduce(0.0) { sum, c in
            sum + c.score * (c.weight / totalWeight)
        }
        return (min(100, max(0, score)), components.map(\.label))
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year!)-\(components.month!)-\(components.day!)"
    }

    private static func findClosestPoint(
        to targetDate: Date,
        in points: [SentimentRegimePoint],
        tolerance: Int
    ) -> SentimentRegimePoint? {
        let toleranceSeconds = TimeInterval(tolerance * 86400)
        return points.min(by: { point1, point2 in
            abs(point1.date.timeIntervalSince(targetDate)) < abs(point2.date.timeIntervalSince(targetDate))
        }).flatMap { closest in
            abs(closest.date.timeIntervalSince(targetDate)) <= toleranceSeconds ? closest : nil
        }
    }
}
