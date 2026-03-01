import Foundation
import Supabase

// MARK: - Market Summary Service
/// Fetches AI-generated daily market summaries via the market-summary edge function.
/// Summaries are cached server-side (one per day) so all users share the same result.
final class MarketSummaryService {
    static let shared = MarketSummaryService()

    private static let cacheKey = "market_summary_daily"
    private static let cacheTTL: TimeInterval = 14400 // 4 hours

    private init() {}

    // MARK: - Request / Response

    struct MarketSummaryPayload: Encodable {
        let btcPrice: Double?
        let btcChange24h: Double?
        let ethPrice: Double?
        let ethChange24h: Double?
        let solPrice: Double?
        let solChange24h: Double?
        let fearGreedValue: Int?
        let fearGreedClassification: String?
        let riskScore: Int?
        let riskTier: String?
        let vixValue: Double?
        let vixSignal: String?
        let dxyValue: Double?
        let dxySignal: String?
        let m2Signal: String?
        let topGainers: [MoverEntry]?
        let topLosers: [MoverEntry]?
        let economicEvents: [EventEntry]?
        let newsHeadlines: [String]?
    }

    struct MoverEntry: Encodable {
        let symbol: String
        let change: Double
    }

    struct EventEntry: Encodable {
        let title: String
    }

    private struct SummaryResponse: Decodable {
        let summary: String?
        let generatedAt: String?
        let error: String?
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
            logError("Market summary FunctionsError: \(error)", category: .network)
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
