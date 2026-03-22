import Foundation

// MARK: - CME FedWatch Scraper
/// Provides Fed rate probability data with live rate from FMP API
/// Probabilities are estimated — future integration with CME FedWatch API ($25/mo) planned
@MainActor
final class CMEFedWatchScraper {

    // Fallback rate if FMP API is unavailable
    private static let fallbackFedFundsRate: Double = 3.625 // 3.50-3.75% range midpoint as of Mar 2026

    // Cached live rate (refreshed once per session)
    private var cachedLiveRate: Double?

    nonisolated init() {}

    // MARK: - Public Methods

    func fetchFedWatchMeetings() async throws -> [FedWatchData] {
        let rate = await fetchLiveFedFundsRate()
        let meetings = generateEstimatedProbabilities(currentRate: rate)
        logDebug("FedWatch: Generated \(meetings.count) meetings (rate: \(rate)%)", category: .network)
        return meetings
    }

    func fetchFedWatchData() async throws -> FedWatchData {
        let meetings = try await fetchFedWatchMeetings()
        guard let first = meetings.first else {
            throw AppError.invalidResponse
        }
        return first
    }

    // MARK: - Live Fed Funds Rate

    /// Fetch the current Fed Funds rate from FMP, with caching and fallback
    private func fetchLiveFedFundsRate() async -> Double {
        // Return cached value if available
        if let cached = cachedLiveRate { return cached }

        do {
            let rate = try await FMPService.shared.fetchFederalFundsRate()
            cachedLiveRate = rate
            logDebug("FedWatch: Live Fed Funds rate from FMP: \(rate)%", category: .network)
            return rate
        } catch {
            logDebug("FedWatch: FMP rate fetch failed, using fallback \(Self.fallbackFedFundsRate)%: \(error)", category: .network)
            return Self.fallbackFedFundsRate
        }
    }

    // MARK: - Estimated Probabilities

    /// Generate estimated Fed rate probabilities based on upcoming FOMC meetings
    /// These are reasonable estimates - actual probabilities change based on economic data
    private func generateEstimatedProbabilities(currentRate: Double) -> [FedWatchData] {
        let calendar = Calendar.current
        let today = Date()

        logDebug("FedWatch: Today is \(today)", category: .network)
        logDebug("FedWatch: Year is \(calendar.component(.year, from: today))", category: .network)

        // 2026 FOMC Meeting Dates (decision day = second day of 2-day meeting)
        // Source: https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm
        let fomcDates: [(month: Int, day: Int)] = [
            (1, 28),   // Jan 27-28
            (3, 18),   // Mar 17-18
            (4, 29),   // Apr 28-29
            (6, 17),   // Jun 16-17
            (7, 29),   // Jul 28-29
            (9, 16),   // Sep 15-16
            (10, 28),  // Oct 27-28
            (12, 9)    // Dec 8-9
        ]

        var meetings: [FedWatchData] = []
        let year = calendar.component(.year, from: today)

        for (index, dateInfo) in fomcDates.enumerated() {
            guard let meetingDate = calendar.date(from: DateComponents(
                year: year,
                month: dateInfo.month,
                day: dateInfo.day
            )) else { continue }

            // Include today's meeting (keep visible all day) and future meetings
            guard Calendar.current.isDateInToday(meetingDate) || meetingDate > today else { continue }

            // Generate probabilities that gradually shift toward cuts as year progresses
            let probabilities = generateProbabilitiesForMeeting(index: index, totalMeetings: fomcDates.count, currentRate: currentRate)

            meetings.append(FedWatchData(
                meetingDate: meetingDate,
                currentRate: currentRate,
                probabilities: probabilities,
                lastUpdated: today
            ))

            // Show up to 6 upcoming meetings
            if meetings.count >= 6 { break }
        }

        return meetings
    }

    private func generateProbabilitiesForMeeting(index: Int, totalMeetings: Int, currentRate: Double) -> [RateProbability] {
        // Market typically prices in gradual rate cuts over time
        // Earlier meetings: higher hold probability
        // Later meetings: higher cut probability

        // Base probabilities that shift over time
        var holdProb: Double
        var cutProb: Double
        var hikeProb: Double = 0.02 // Very low hike probability in current environment

        if index == 0 {
            // Next meeting: strong hold expected (aligned with CME FedWatch Mar 2026)
            holdProb = 0.876
            cutProb = 0.0
            hikeProb = 0.124
        } else if index == 1 {
            // Second meeting: mostly hold, some cut probability
            holdProb = 0.70
            cutProb = 0.25
            hikeProb = 0.05
        } else if index == 2 {
            // Third meeting: cuts more likely
            holdProb = 0.50
            cutProb = 0.47
            hikeProb = 0.03
        } else {
            // Later meetings: cuts expected
            holdProb = 0.35
            cutProb = 0.63
        }

        // Normalize to 100%
        let total = holdProb + cutProb + hikeProb
        holdProb /= total
        cutProb /= total
        hikeProb /= total

        return [
            RateProbability(
                targetRate: currentRate - 0.25,
                change: -25,
                probability: cutProb
            ),
            RateProbability(
                targetRate: currentRate,
                change: 0,
                probability: holdProb
            ),
            RateProbability(
                targetRate: currentRate + 0.25,
                change: 25,
                probability: hikeProb
            )
        ]
    }
}
