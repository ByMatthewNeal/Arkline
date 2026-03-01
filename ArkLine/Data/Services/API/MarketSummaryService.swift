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
        let btcPrice: Double?
        let btcChange24h: Double?
        let ethPrice: Double?
        let ethChange24h: Double?
        let solPrice: Double?
        let solChange24h: Double?
        let sp500Price: Double?
        let sp500Change: Double?
        let nasdaqPrice: Double?
        let nasdaqChange: Double?
        let fearGreedValue: Int?
        let fearGreedClassification: String?
        let riskScore: Int?
        let riskTier: String?
        let vixValue: Double?
        let vixSignal: String?
        let dxyValue: Double?
        let dxySignal: String?
        let netLiquiditySignal: String?
        let economicEvents: [EventEntry]?
        let newsHeadlines: [String]?
    }

    struct EventEntry: Encodable {
        let title: String
        let time: String?
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

    // MARK: - Public API

    func fetchSummary(payload: MarketSummaryPayload) async throws -> MarketSummary {
        // Check client cache
        if let cached: MarketSummary = APICache.shared.get(Self.cacheKey) {
            return cached
        }

        guard SupabaseManager.shared.isConfigured else {
            throw MarketSummaryError.notConfigured
        }

        do {
            let data: Data = try await SupabaseManager.shared.functions.invoke(
                "market-summary",
                options: FunctionInvokeOptions(body: payload),
                decode: { data, _ in data }
            )

            logDebug("Market summary response: \(data.count) bytes", category: .network)

            let response = try JSONDecoder().decode(SummaryResponse.self, from: data)

            if let summary = response.summary, !summary.isEmpty {
                let generatedAt = parseDate(response.generatedAt)
                let result = MarketSummary(summary: summary, generatedAt: generatedAt)
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
            case .relayError:
                logError("Market summary relay error", category: .network)
            }
            throw MarketSummaryError.networkError(error)
        } catch let error as MarketSummaryError {
            throw error
        } catch {
            logError("Market summary failed: \(error)", category: .network)
            throw MarketSummaryError.networkError(error)
        }
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
