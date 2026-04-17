import Foundation
import Supabase

// MARK: - Market Summary Service
/// Fetches AI-generated market summaries via the market-summary edge function.
/// Generated twice daily (10:00 AM EST / 4:30 PM EST) and cached server-side.
final class MarketSummaryService {
    static let shared = MarketSummaryService()

    private static let cacheKey = "market_summary_session"
    private static let cacheTTL: TimeInterval = 7200 // 2 hours
    private static let diskCacheKey = "arkline_last_briefing"

    private let yahooService = YahooFinanceService.shared

    private init() {}

    // MARK: - Disk-Persisted Briefing (survives app kill)

    /// Load last briefing from disk immediately (no network). Returns nil if never cached.
    func loadPersistedBriefing() -> MarketSummary? {
        guard let data = UserDefaults.standard.data(forKey: Self.diskCacheKey),
              let persisted = try? JSONDecoder().decode(PersistedBriefing.self, from: data) else {
            return nil
        }
        return MarketSummary(
            summary: persisted.summary,
            generatedAt: persisted.generatedAt,
            summaryDate: persisted.summaryDate,
            slot: persisted.slot,
            feedbackRating: persisted.feedbackRating,
            feedbackNote: persisted.feedbackNote
        )
    }

    /// Save briefing to disk so it's available on next cold start.
    private func persistBriefing(_ briefing: MarketSummary) {
        let persisted = PersistedBriefing(
            summary: briefing.summary,
            generatedAt: briefing.generatedAt,
            summaryDate: briefing.summaryDate,
            slot: briefing.slot,
            feedbackRating: briefing.feedbackRating,
            feedbackNote: briefing.feedbackNote
        )
        if let data = try? JSONEncoder().encode(persisted) {
            UserDefaults.standard.set(data, forKey: Self.diskCacheKey)
        }
    }

    private struct PersistedBriefing: Codable {
        let summary: String
        let generatedAt: Date
        let summaryDate: String
        let slot: String
        let feedbackRating: Bool?
        let feedbackNote: String?
    }

    // MARK: - Request / Response

    struct MarketSummaryPayload: Encodable {
        // Crypto prices
        let btcPrice: Double?
        let btcChange24h: Double?
        let ethPrice: Double?
        let ethChange24h: Double?
        let solPrice: Double?
        let solChange24h: Double?
        // Equities
        let sp500Price: Double?
        let sp500Change: Double?
        let nasdaqPrice: Double?
        let nasdaqChange: Double?
        // Sentiment & Risk
        let fearGreedValue: Int?
        let fearGreedClassification: String?
        let riskScore: Int?
        let riskTier: String?
        // Macro
        let vixValue: Double?
        let vixSignal: String?
        let dxyValue: Double?
        let dxySignal: String?
        let netLiquiditySignal: String?
        let goldSignal: String?
        // Canonical macro regime from MacroRegimeCalculator
        let macroRegime: String?
        // Crypto positioning derived from regime quadrant
        let cryptoPositioning: String?
        // App signals
        let btcRiskZone: String?
        let ethRiskZone: String?
        let altcoinSeason: String?
        let sentimentRegime: String?
        let coinbaseRank: Int?
        let btcSearchInterest: String?
        let topGainer: String?
        // Technical Analysis (BTC)
        let btcTrend: String?
        let btcRsi: String?
        let btcSmaPosition: String?
        let btcBmsbPosition: String?
        let btcBollingerPosition: String?
        // Derivatives
        let btcFundingRate: String?
        let btcLiquidations: String?
        let btcLongShortRatio: String?
        let btcOpenInterest: String?
        // Capital Flow
        let btcDominance: String?
        let capitalRotation: String?
        let etfNetFlow: String?
        // Risk Breakdown
        let riskFactors: String?
        // Macro Enrichment
        let geiScore: String?
        let supplyInProfit: String?
        let rainbowBand: String?
        // Fib Support/Resistance
        let btcKeyLevels: String?
        // Central Bank Liquidity & Cycle
        let cbLiquidity: String?
        let liquidityCyclePhase: String?
        let liquidityMomentum: String?
        let yieldCurveRegime: String?
        // US Futures
        let usFutures: String?
        // Market session
        let marketSession: String?
        // Events & News
        let economicEvents: [EventEntry]?
        let newsHeadlines: [String]?
    }

    struct EventEntry: Encodable {
        let title: String
        let time: String?
        let actual: String?
        let forecast: String?
        let previous: String?
    }

    private struct SummaryResponse: Decodable {
        let summary: String?
        let generatedAt: String?
        let error: String?
    }

    // MARK: - Index Quotes

    /// Fetch S&P 500 and NASDAQ current price + daily change %
    func fetchIndexQuotes() async -> (sp500: (price: Double, change: Double)?, nasdaq: (price: Double, change: Double)?) {
        async let sp500Task: (price: Double, change: Double)? = fetchQuote(symbol: "^GSPC")
        async let nasdaqTask: (price: Double, change: Double)? = fetchQuote(symbol: "^IXIC")
        return await (sp500Task, nasdaqTask)
    }

    private func fetchQuote(symbol: String) async -> (price: Double, change: Double)? {
        do {
            let result = try await yahooService.fetchChartBars(symbol: symbol, interval: "1d", range: "5d")
            let price = result.currentPrice
            var change = 0.0
            if let prevClose = result.previousClose, prevClose > 0 {
                change = ((price - prevClose) / prevClose) * 100
            }
            return (price, change)
        } catch {
            logError("Index quote fetch failed for \(symbol): \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    // MARK: - Feedback Types

    struct BriefingFeedback: Encodable {
        let userId: String
        let summaryDate: String
        let slot: String
        let rating: Bool
        let note: String?

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case summaryDate = "summary_date"
            case slot, rating, note
        }
    }

    private struct BriefingFeedbackRow: Decodable {
        let rating: Bool
        let note: String?
    }

    // MARK: - Public API

    /// Fetch the latest pre-generated briefing from the server.
    /// Briefings are generated by cron at 10am and 5pm ET.
    /// Returns cached result instantly. Falls back to edge function if DB read fails.
    func fetchLatestBriefing() async throws -> MarketSummary {
        // Check client cache
        if let cached: MarketSummary = APICache.shared.get(Self.cacheKey) {
            return cached
        }

        guard SupabaseManager.shared.isConfigured else {
            throw MarketSummaryError.notConfigured
        }

        let (summaryDate, slot) = currentESTSlot()

        // Read directly from market_summaries table (no edge function call needed)
        do {
            let result = try await readBriefingFromDB(preferredDate: summaryDate, preferredSlot: slot)
            APICache.shared.set(Self.cacheKey, value: result, ttl: Self.cacheTTL)
            persistBriefing(result)
            return result
        } catch {
            logWarning("DB briefing read failed, falling back to edge function: \(error)", category: .network)
            // Fallback: call edge function (will return cached or generate on demand)
            return try await fetchViaEdgeFunction(summaryDate: summaryDate, slot: slot)
        }
    }

    /// Read briefing from market_summaries table. Tries current slot first,
    /// then other slot for today, then yesterday's evening briefing.
    private func readBriefingFromDB(preferredDate: String, preferredSlot: String) async throws -> MarketSummary {
        struct BriefingRow: Decodable {
            let summary: String
            let generatedAt: String
            let summaryDate: String
            let slot: String

            enum CodingKeys: String, CodingKey {
                case summary
                case generatedAt = "generated_at"
                case summaryDate = "summary_date"
                case slot
            }
        }

        // Try current slot for today
        let rows: [BriefingRow] = try await SupabaseManager.shared.database
            .from("market_summaries")
            .select("summary, generated_at, summary_date, slot")
            .eq("summary_date", value: preferredDate)
            .eq("slot", value: preferredSlot)
            .limit(1)
            .execute()
            .value

        if let row = rows.first {
            let feedback = await fetchFeedback(summaryDate: row.summaryDate, slot: row.slot)
            return MarketSummary(
                summary: row.summary,
                generatedAt: parseDate(row.generatedAt),
                summaryDate: row.summaryDate,
                slot: row.slot,
                feedbackRating: feedback?.rating,
                feedbackNote: feedback?.note
            )
        }

        // Fall back to the most recent briefing (other slot today, or yesterday)
        let fallbackRows: [BriefingRow] = try await SupabaseManager.shared.database
            .from("market_summaries")
            .select("summary, generated_at, summary_date, slot")
            .order("summary_date", ascending: false)
            .order("generated_at", ascending: false)
            .limit(1)
            .execute()
            .value

        if let row = fallbackRows.first {
            let feedback = await fetchFeedback(summaryDate: row.summaryDate, slot: row.slot)
            return MarketSummary(
                summary: row.summary,
                generatedAt: parseDate(row.generatedAt),
                summaryDate: row.summaryDate,
                slot: row.slot,
                feedbackRating: feedback?.rating,
                feedbackNote: feedback?.note
            )
        }

        throw MarketSummaryError.emptyResponse
    }

    /// Fallback: call edge function with empty payload. It returns cached or generates server-side.
    private func fetchViaEdgeFunction(summaryDate: String, slot: String) async throws -> MarketSummary {
        struct EmptyPayload: Encodable {}

        let data: Data = try await SupabaseManager.shared.functions.invoke(
            "market-summary",
            options: FunctionInvokeOptions(body: EmptyPayload()),
            decode: { data, _ in data }
        )

        let response = try JSONDecoder().decode(SummaryResponse.self, from: data)

        guard let summary = response.summary, !summary.isEmpty else {
            throw MarketSummaryError.emptyResponse
        }

        let feedback = await fetchFeedback(summaryDate: summaryDate, slot: slot)
        let result = MarketSummary(
            summary: summary,
            generatedAt: parseDate(response.generatedAt),
            summaryDate: summaryDate,
            slot: slot,
            feedbackRating: feedback?.rating,
            feedbackNote: feedback?.note
        )
        APICache.shared.set(Self.cacheKey, value: result, ttl: Self.cacheTTL)
        persistBriefing(result)
        return result
    }

    // MARK: - Cache Management

    /// Clears the local client cache so next fetch reads fresh from DB.
    func clearLocalCache() {
        APICache.shared.remove(Self.cacheKey)
    }

    /// Clears the server-side cached summary for today (admin only) and the local client cache.
    func clearServerCache() async throws {
        guard SupabaseManager.shared.isConfigured else { return }

        struct ClearCachePayload: Encodable {
            let clearCache = true
        }

        // clearCache requires admin JWT — use the SDK's default auth (user session)
        let _: Data = try await SupabaseManager.shared.functions.invoke(
            "market-summary",
            options: FunctionInvokeOptions(body: ClearCachePayload()),
            decode: { data, _ in data }
        )

        APICache.shared.remove(Self.cacheKey)
        UserDefaults.standard.removeObject(forKey: Self.diskCacheKey)
        logDebug("Server cache cleared for today's briefing", category: .network)
    }

    // MARK: - Feedback

    func submitFeedback(userId: UUID, summaryDate: String, slot: String, rating: Bool, note: String?) async throws {
        guard SupabaseManager.shared.isConfigured else { return }

        let feedback = BriefingFeedback(
            userId: userId.uuidString,
            summaryDate: summaryDate,
            slot: slot,
            rating: rating,
            note: note
        )

        try await SupabaseManager.shared.database
            .from("briefing_feedback")
            .upsert(feedback, onConflict: "summary_date,slot")
            .execute()

        // Invalidate client cache so feedback state refreshes
        APICache.shared.remove(Self.cacheKey)

        logDebug("Briefing feedback submitted: \(rating ? "👍" : "👎") for \(summaryDate)/\(slot)", category: .data)
    }

    // MARK: - Briefing Archive

    /// Fetch past briefings for the archive view. Returns most recent first.
    func fetchBriefingArchive(limit: Int = 30) async throws -> [MarketSummary] {
        guard SupabaseManager.shared.isConfigured else { throw MarketSummaryError.notConfigured }

        struct ArchiveRow: Decodable {
            let summary: String
            let generatedAt: String
            let summaryDate: String
            let slot: String

            enum CodingKeys: String, CodingKey {
                case summary
                case generatedAt = "generated_at"
                case summaryDate = "summary_date"
                case slot
            }
        }

        let rows: [ArchiveRow] = try await SupabaseManager.shared.database
            .from("market_summaries")
            .select("summary, generated_at, summary_date, slot")
            .order("summary_date", ascending: false)
            .order("generated_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return rows.map { row in
            MarketSummary(
                summary: row.summary,
                generatedAt: parseDate(row.generatedAt),
                summaryDate: row.summaryDate,
                slot: row.slot
            )
        }
    }

    // MARK: - Private

    private func fetchFeedback(summaryDate: String, slot: String) async -> BriefingFeedbackRow? {
        guard SupabaseManager.shared.isConfigured else { return nil }
        do {
            let rows: [BriefingFeedbackRow] = try await SupabaseManager.shared.database
                .from("briefing_feedback")
                .select("rating, note")
                .eq("summary_date", value: summaryDate)
                .eq("slot", value: slot)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch {
            logError("Feedback query failed: \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    /// Returns (YYYY-MM-DD, slot) for the current EST time, mirroring edge function logic.
    /// Weekdays: "morning" (before 5pm ET) / "evening" (5pm ET+)
    /// Weekends: "weekend" (single daily briefing at 12pm ET)
    func currentESTSlot(from date: Date = Date()) -> (String, String) {
        let year = Calendar(identifier: .gregorian).component(.year, from: date)

        // DST: second Sunday of March to first Sunday of November
        let marchSecondSunday = nthSunday(year: year, month: 3, n: 2)
        let novFirstSunday = nthSunday(year: year, month: 11, n: 1)
        let isDST = date >= marchSecondSunday && date < novFirstSunday
        let offset = isDST ? 4 : 5

        let utcComponents = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "UTC") ?? .gmt, from: date)
        let utcHour = utcComponents.hour ?? 0
        let estHour = (utcHour - offset + 24) % 24

        // Check if it's a weekend in ET
        var estCal = Calendar(identifier: .gregorian)
        estCal.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
        let weekday = estCal.component(.weekday, from: date) // 1=Sun, 7=Sat

        let slot: String
        if weekday == 1 || weekday == 7 {
            slot = "weekend"
        } else {
            slot = estHour >= 17 ? "evening" : "morning"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let summaryDate = formatter.string(from: date)
        return (summaryDate, slot)
    }

    private func nthSunday(year: Int, month: Int, n: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        var components = DateComponents(year: year, month: month, day: 1, hour: 7)
        guard var date = calendar.date(from: components) else { return Date() }
        var count = 0
        while count < n {
            if calendar.component(.weekday, from: date) == 1 { count += 1 }
            if count < n { date = calendar.date(byAdding: .day, value: 1, to: date)! }
        }
        return date
    }

    private func parseDate(_ string: String?) -> Date {
        guard let string else { return Date() }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string) ?? Date()
    }
}

// MARK: - Model
struct MarketSummary {
    let summary: String
    let generatedAt: Date
    let summaryDate: String
    let slot: String
    var feedbackRating: Bool?
    var feedbackNote: String?

    /// Canonical key for read-tracking (e.g. "2026-03-03_morning")
    var briefingKey: String { "\(summaryDate)_\(slot)" }
}

// MARK: - Error
enum MarketSummaryError: Error, LocalizedError {
    case notConfigured
    case emptyResponse
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Market summary service is not available"
        case .emptyResponse:
            return "Could not generate a market summary"
        case .networkError(let error):
            return "Market summary unavailable: \(error.localizedDescription)"
        }
    }
}
