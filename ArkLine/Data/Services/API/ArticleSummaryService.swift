import Foundation
import Supabase

// MARK: - Article Summary Service
/// Fetches AI-generated summaries of news articles via the article-summary edge function.
/// Keeps the Anthropic API key server-side — client only sends the article URL.
final class ArticleSummaryService {
    // MARK: - Singleton
    static let shared = ArticleSummaryService()

    private init() {}

    // MARK: - Cache
    private var cache: [String: String] = [:]

    // MARK: - Request/Response
    private struct SummaryRequest: Encodable {
        let url: String
        let title: String
    }

    private struct SummaryResponse: Decodable {
        let summary: String?
        let error: String?
    }

    // MARK: - Public API

    /// Fetch a concise AI summary of the article at the given URL.
    /// Results are cached in memory to avoid redundant calls.
    func fetchSummary(url: String, title: String) async throws -> String {
        // Check cache first
        if let cached = cache[url] {
            return cached
        }

        guard SupabaseManager.shared.isConfigured else {
            throw ArticleSummaryError.notConfigured
        }

        let request = SummaryRequest(url: url, title: title)

        do {
            // Use raw Data approach for better error visibility
            let data: Data = try await SupabaseManager.shared.functions.invoke(
                "article-summary",
                options: FunctionInvokeOptions(body: request),
                decode: { data, _ in data }
            )

            logDebug("Article summary response: \(data.count) bytes", category: .network)

            let response = try JSONDecoder().decode(SummaryResponse.self, from: data)

            if let summary = response.summary, !summary.isEmpty {
                cache[url] = summary
                return summary
            }

            let errorMsg = response.error ?? "empty"
            logWarning("Article summary returned no summary, error: \(errorMsg)", category: .network)
            throw ArticleSummaryError.emptyResponse
        } catch let error as FunctionsError {
            // Auth or relay errors from Supabase — log details
            logWarning("Article summary function error: \(error)", category: .network)
            throw ArticleSummaryError.networkError(error)
        } catch let error as ArticleSummaryError {
            throw error
        } catch {
            logWarning("Article summary failed: \(error)", category: .network)
            throw ArticleSummaryError.networkError(error)
        }
    }
}

// MARK: - Error
enum ArticleSummaryError: Error, LocalizedError {
    case notConfigured
    case emptyResponse
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Summary service is not available"
        case .emptyResponse:
            return "Could not generate a summary for this article"
        case .networkError(let error):
            return "Summary unavailable: \(error.localizedDescription)"
        }
    }
}
