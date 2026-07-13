import Foundation

// MARK: - Fed Watch Data Source
/// Reads REAL Fed rate probabilities computed server-side from 30-Day Fed Funds
/// futures (the `fed_watch` key in `market_data_cache`, written by the
/// `refresh-market-extras` edge function using CME's published methodology).
///
/// This used to return hardcoded probabilities baked into the source ("Jul 29:
/// 89.3% hold, 10.7% cut, 0% hike"), which meant the app confidently showed rate
/// CUTS while the market was actually pricing HIKES. Never reintroduce estimates
/// here — if the real data is unavailable we surface an error instead of
/// inventing numbers.
///
/// Reading the same server-computed cache the web dashboard reads also guarantees
/// iOS and web can never disagree.
@MainActor
final class CMEFedWatchScraper {

    nonisolated init() {}

    // MARK: - Public

    func fetchFedWatchMeetings() async throws -> [FedWatchData] {
        guard SupabaseManager.shared.isConfigured else {
            throw AppError.custom(message: "Fed rate data is unavailable")
        }

        let rows: [CacheRow] = try await SupabaseManager.shared.database
            .from(SupabaseTable.marketDataCache.rawValue)
            .select("data")
            .eq("key", value: "fed_watch")
            .limit(1)
            .execute()
            .value

        guard let payload = rows.first?.data, !payload.meetings.isEmpty else {
            throw AppError.custom(message: "Fed rate probabilities unavailable")
        }

        let meetings = payload.meetings.compactMap { m -> FedWatchData? in
            guard let date = Self.parseDate(m.meetingDate) else { return nil }

            // Server stores cumulative probabilities as percentages (0-100).
            // The UI sums by `change` sign, so three buckets is all it needs.
            let cut = (m.cutProbability ?? 0) / 100
            let hold = (m.holdProbability ?? 0) / 100
            let hike = (m.hikeProbability ?? 0) / 100

            return FedWatchData(
                meetingDate: date,
                currentRate: payload.rate,
                probabilities: [
                    RateProbability(targetRate: payload.rate - 0.25, change: -25, probability: cut),
                    RateProbability(targetRate: payload.rate, change: 0, probability: hold),
                    RateProbability(targetRate: payload.rate + 0.25, change: 25, probability: hike)
                ],
                lastUpdated: Date()
            )
        }

        guard !meetings.isEmpty else {
            throw AppError.custom(message: "Fed rate probabilities unavailable")
        }

        logDebug("FedWatch: loaded \(meetings.count) meetings from server (rate: \(payload.rate)%)", category: .network)
        return meetings
    }

    func fetchFedWatchData() async throws -> FedWatchData {
        let meetings = try await fetchFedWatchMeetings()
        guard let first = meetings.first else { throw AppError.invalidResponse }
        return first
    }

    // MARK: - Decoding

    private struct CacheRow: Decodable {
        let data: FedWatchPayload?
    }

    private struct FedWatchPayload: Decodable {
        let rate: Double
        let meetings: [MeetingRow]
    }

    private struct MeetingRow: Decodable {
        let meetingDate: String
        let cutProbability: Double?
        let holdProbability: Double?
        let hikeProbability: Double?

        enum CodingKeys: String, CodingKey {
            case meetingDate = "meeting_date"
            case cutProbability = "cut_probability"
            case holdProbability = "hold_probability"
            case hikeProbability = "hike_probability"
        }
    }

    /// `meeting_date` is a plain "YYYY-MM-DD" string.
    private static func parseDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }
}
