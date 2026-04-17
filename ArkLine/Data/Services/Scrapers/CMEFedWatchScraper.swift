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

        var futureIndex = 0
        for (_, dateInfo) in fomcDates.enumerated() {
            guard let meetingDate = calendar.date(from: DateComponents(
                year: year,
                month: dateInfo.month,
                day: dateInfo.day
            )) else { continue }

            // Include today's meeting (keep visible all day) and future meetings
            guard Calendar.current.isDateInToday(meetingDate) || meetingDate > today else { continue }

            // Generate probabilities based on position among remaining meetings
            let probabilities = generateProbabilitiesForMeeting(index: futureIndex, totalMeetings: fomcDates.count, currentRate: currentRate)
            futureIndex += 1

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
        // Probabilities based on CME FedWatch data as of 2026-03-30
        // Current target rate: 350-375 bps (3.50-3.75%)
        var holdProb: Double
        var cutProb: Double
        var hikeProb: Double

        if index == 0 {
            // Apr 29: 97.4% hold, 0% cut, 2.6% hike
            holdProb = 0.974
            cutProb = 0.0
            hikeProb = 0.026
        } else if index == 1 {
            // Jun 17: 94.8% hold, 2.7% cut, 2.5% hike
            holdProb = 0.948
            cutProb = 0.027
            hikeProb = 0.025
        } else if index == 2 {
            // Jul 29: 91.8% hold, 5.8% cut, 2.4% hike
            holdProb = 0.918
            cutProb = 0.058
            hikeProb = 0.024
        } else if index == 3 {
            // Sep 16: 90.0% hold, 5.7% cut, 4.4% hike
            holdProb = 0.900
            cutProb = 0.057
            hikeProb = 0.044
        } else {
            // Oct 28, Dec 9: estimate similar to Sep
            holdProb = 0.88
            cutProb = 0.07
            hikeProb = 0.05
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
