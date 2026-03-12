import Foundation
import Supabase

// MARK: - Market Summary Service
/// Fetches AI-generated market summaries via the market-summary edge function.
/// Generated twice daily (10:00 AM EST / 4:30 PM EST) and cached server-side.
final class MarketSummaryService {
    static let shared = MarketSummaryService()

    private static let cacheKey = "market_summary_session"
    private static let cacheTTL: TimeInterval = 7200 // 2 hours

    private let yahooService = YahooFinanceService.shared

    private init() {}

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

    /// Maximum age of a briefing before we consider it stale and force regeneration (4 hours).
    /// This ensures a morning request never returns the previous evening's briefing.
    private static let maxBriefingAge: TimeInterval = 3600 * 4

    func fetchSummary(payload: MarketSummaryPayload, allowServerCacheClear: Bool = true) async throws -> MarketSummary {
        // Check client cache
        if let cached: MarketSummary = APICache.shared.get(Self.cacheKey) {
            #if DEBUG
            print("🟢 BRIEFING: returning cached summary")
            #endif
            return cached
        }

        guard SupabaseManager.shared.isConfigured else {
            #if DEBUG
            print("🔴 BRIEFING: Supabase not configured!")
            #endif
            throw MarketSummaryError.notConfigured
        }
        #if DEBUG
        print("🟡 BRIEFING: calling edge function market-summary...")
        #endif

        let (summaryDate, slot) = currentESTSlot()

        do {
            let data: Data = try await SupabaseManager.shared.functions.invoke(
                "market-summary",
                options: FunctionInvokeOptions(body: payload),
                decode: { data, _ in data }
            )

            logDebug("Market summary response: \(data.count) bytes", category: .network)
            #if DEBUG
            print("🟡 BRIEFING: got \(data.count) bytes, decoding...")
            if let raw = String(data: data, encoding: .utf8) {
                print("🟡 BRIEFING raw (first 300): \(String(raw.prefix(300)))")
            }
            #endif

            let response = try JSONDecoder().decode(SummaryResponse.self, from: data)

            if let summary = response.summary, !summary.isEmpty {
                let generatedAt = parseDate(response.generatedAt)

                // If the server returned a stale briefing (from a previous slot),
                // clear the server cache and retry once to force fresh generation.
                let age = Date().timeIntervalSince(generatedAt)
                if age > Self.maxBriefingAge && allowServerCacheClear {
                    logInfo("Server returned stale briefing (\(Int(age / 3600))h old), clearing cache and regenerating", category: .network)
                    try? await clearServerCache()
                    return try await fetchSummary(payload: payload, allowServerCacheClear: false)
                }

                // Hydrate feedback state for this briefing
                let feedback = await fetchFeedback(summaryDate: summaryDate, slot: slot)

                let result = MarketSummary(
                    summary: summary,
                    generatedAt: generatedAt,
                    summaryDate: summaryDate,
                    slot: slot,
                    feedbackRating: feedback?.rating,
                    feedbackNote: feedback?.note
                )
                APICache.shared.set(Self.cacheKey, value: result, ttl: Self.cacheTTL)
                return result
            }

            let errorMsg = response.error ?? "empty"
            logWarning("Market summary returned no summary, error: \(errorMsg)", category: .network)
            throw MarketSummaryError.emptyResponse
        } catch let error as FunctionsError {
            switch error {
            case .httpError(let code, let data):
                let body = String(data: data, encoding: .utf8) ?? "nil"
                logError("Market summary HTTP \(code): \(body)", category: .network)
                #if DEBUG
                print("🔴 BRIEFING HTTP \(code): \(body)")
                #endif
            case .relayError:
                logError("Market summary relay error", category: .network)
                #if DEBUG
                print("🔴 BRIEFING relay error")
                #endif
            }
            throw MarketSummaryError.networkError(error)
        } catch let error as MarketSummaryError {
            #if DEBUG
            print("🔴 BRIEFING MarketSummaryError: \(error)")
            #endif
            throw error
        } catch {
            logError("Market summary failed: \(error)", category: .network)
            #if DEBUG
            print("🔴 BRIEFING unknown error: \(error)")
            #endif
            throw MarketSummaryError.networkError(error)
        }
    }

    // MARK: - Cache Management

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
    func currentESTSlot(from date: Date = Date()) -> (String, String) {
        let year = Calendar(identifier: .gregorian).component(.year, from: date)

        // DST: second Sunday of March to first Sunday of November
        let marchSecondSunday = nthSunday(year: year, month: 3, n: 2)
        let novFirstSunday = nthSunday(year: year, month: 11, n: 1)
        let isDST = date >= marchSecondSunday && date < novFirstSunday
        let offset = isDST ? 4 : 5

        let utcHour = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "UTC") ?? .gmt, from: date).hour ?? 0
        let estHour = (utcHour - offset + 24) % 24

        let slot = estHour >= 16 ? "evening" : "morning"
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
