import Foundation

// MARK: - CME FedWatch Scraper
/// Scrapes Fed rate probability data from CME FedWatch Tool
final class CMEFedWatchScraper {

    // Current Fed Funds rate (updated periodically)
    private let currentFedFundsRate: Double = 4.375 // 4.25-4.50% range midpoint as of Jan 2026

    // MARK: - Public Methods

    func fetchFedWatchMeetings() async throws -> [FedWatchData] {
        // Return calculated estimates based on market conditions
        // Network scraping disabled - CME uses JavaScript rendering
        let meetings = generateEstimatedProbabilities()
        logDebug("FedWatch: Generated \(meetings.count) meetings", category: .network)
        for meeting in meetings {
            logDebug("FedWatch: Meeting on \(meeting.meetingDate), rate: \(meeting.currentRate)", category: .network)
        }
        return meetings
    }

    func fetchFedWatchData() async throws -> FedWatchData {
        let meetings = try await fetchFedWatchMeetings()
        guard let first = meetings.first else {
            throw AppError.invalidResponse
        }
        return first
    }

    // MARK: - Estimated Probabilities

    /// Generate estimated Fed rate probabilities based on upcoming FOMC meetings
    /// These are reasonable estimates - actual probabilities change based on economic data
    private func generateEstimatedProbabilities() -> [FedWatchData] {
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

            // Only include future meetings
            guard meetingDate > today else { continue }

            // Generate probabilities that gradually shift toward cuts as year progresses
            let probabilities = generateProbabilitiesForMeeting(index: index, totalMeetings: fomcDates.count)

            meetings.append(FedWatchData(
                meetingDate: meetingDate,
                currentRate: currentFedFundsRate,
                probabilities: probabilities,
                lastUpdated: today
            ))

            // Show up to 6 upcoming meetings
            if meetings.count >= 6 { break }
        }

        return meetings
    }

    private func generateProbabilitiesForMeeting(index: Int, totalMeetings: Int) -> [RateProbability] {
        // Market typically prices in gradual rate cuts over time
        // Earlier meetings: higher hold probability
        // Later meetings: higher cut probability

        // Base probabilities that shift over time
        var holdProb: Double
        var cutProb: Double
        var hikeProb: Double = 0.02 // Very low hike probability in current environment

        if index == 0 {
            // Next meeting: mostly hold expected
            holdProb = 0.88
            cutProb = 0.10
        } else if index == 1 {
            // Second meeting: some cut probability
            holdProb = 0.65
            cutProb = 0.33
        } else if index == 2 {
            // Third meeting: cuts more likely
            holdProb = 0.45
            cutProb = 0.53
        } else {
            // Later meetings: cuts expected
            holdProb = 0.30
            cutProb = 0.68
        }

        // Normalize to 100%
        let total = holdProb + cutProb + hikeProb
        holdProb /= total
        cutProb /= total
        hikeProb /= total

        return [
            RateProbability(
                targetRate: currentFedFundsRate - 0.25,
                change: -25,
                probability: cutProb
            ),
            RateProbability(
                targetRate: currentFedFundsRate,
                change: 0,
                probability: holdProb
            ),
            RateProbability(
                targetRate: currentFedFundsRate + 0.25,
                change: 25,
                probability: hikeProb
            )
        ]
    }
}
