import Foundation

// MARK: - Sentiment Regime Service
/// Computes sentiment regime quadrant data from Fear & Greed history
/// and BTC volume history. Pure computation — no network calls.
enum SentimentRegimeService {

    /// Computes the full regime data set from raw inputs.
    /// - Parameters:
    ///   - fearGreedHistory: Array of FearGreedIndex, newest-first from Alternative.me
    ///   - volumeData: Array of [timestamp_ms, volume_usd] from CoinGeckoMarketChart.totalVolumes
    /// - Returns: SentimentRegimeData with trajectory and milestones, or nil if insufficient data
    static func computeRegimeData(
        fearGreedHistory: [FearGreedIndex],
        volumeData: [[Double]]
    ) -> SentimentRegimeData? {
        guard !fearGreedHistory.isEmpty, !volumeData.isEmpty else { return nil }

        // 1. Parse volume data into date-keyed dictionary (using calendar day)
        let calendar = Calendar(identifier: .gregorian)
        var volumeByDay: [String: Double] = [:]
        var volumeChronological: [(date: Date, volume: Double)] = []

        for entry in volumeData {
            guard entry.count >= 2 else { continue }
            let date = Date(timeIntervalSince1970: entry[0] / 1000.0)
            let volume = entry[1]
            let dayKey = dayKey(for: date, calendar: calendar)
            volumeByDay[dayKey] = volume
            volumeChronological.append((date, volume))
        }

        // Sort chronologically (oldest first)
        volumeChronological.sort { $0.date < $1.date }

        // 2. Compute 30-day rolling SMA of volume and normalize
        var volumeNormalized: [String: Double] = [:]
        for i in 0..<volumeChronological.count {
            let windowStart = max(0, i - 29)
            let window = volumeChronological[windowStart...i]
            let sma = window.map(\.volume).reduce(0, +) / Double(window.count)
            let engagement = normalizeVolume(volume: volumeChronological[i].volume, sma30: sma)
            let key = dayKey(for: volumeChronological[i].date, calendar: calendar)
            volumeNormalized[key] = engagement
        }

        // 3. Match Fear & Greed dates with volume dates, create regime points
        var points: [SentimentRegimePoint] = []
        for fg in fearGreedHistory {
            let key = dayKey(for: fg.timestamp, calendar: calendar)
            guard let engagement = volumeNormalized[key] else { continue }
            let point = SentimentRegimePoint(
                date: fg.timestamp,
                fearGreedValue: fg.value,
                engagementScore: engagement
            )
            points.append(point)
        }

        guard !points.isEmpty else { return nil }

        // Sort oldest-first for trajectory
        points.sort { $0.date < $1.date }

        // 4. Extract milestones
        let today = points.last!
        let oneWeekAgo = findClosestPoint(to: calendar.date(byAdding: .day, value: -7, to: today.date)!, in: points, tolerance: 2)
        let oneMonthAgo = findClosestPoint(to: calendar.date(byAdding: .day, value: -30, to: today.date)!, in: points, tolerance: 3)
        let threeMonthsAgo = findClosestPoint(to: calendar.date(byAdding: .day, value: -90, to: today.date)!, in: points, tolerance: 5)

        let milestones = RegimeMilestones(
            today: today,
            oneWeekAgo: oneWeekAgo,
            oneMonthAgo: oneMonthAgo,
            threeMonthsAgo: threeMonthsAgo
        )

        return SentimentRegimeData(
            currentRegime: today.regime,
            currentPoint: today,
            milestones: milestones,
            trajectory: points
        )
    }

    /// Normalizes a volume value against its moving average to a 0-100 engagement score.
    /// Uses sigmoid mapping so the average maps to 50, 2x maps to ~95, 0.5x maps to ~18.
    static func normalizeVolume(volume: Double, sma30: Double) -> Double {
        guard sma30 > 0 else { return 50.0 }
        let ratio = volume / sma30
        let k: Double = 3.0
        let score = 100.0 / (1.0 + exp(-k * (ratio - 1.0)))
        return min(100, max(0, score))
    }

    // MARK: - Private Helpers

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
