import Foundation
import Supabase

// MARK: - Content Studio Service
/// The voice engine client. Sends a transcript + target format to the
/// `generate-content` edge function and returns platform-ready content written
/// in the founder's own voice (learned from their library + published posts).
final class ContentStudioService {
    static let shared = ContentStudioService()
    private init() {}

    /// Target platform/format for generated content.
    enum Format: String, CaseIterable, Identifiable {
        case broadcast
        case instagram
        case twitterPost = "twitter_post"
        case twitterThread = "twitter_thread"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .broadcast: return "Broadcast"
            case .instagram: return "Instagram"
            case .twitterPost: return "X Post"
            case .twitterThread: return "X Thread"
            }
        }

        var iconName: String {
            switch self {
            case .broadcast: return "megaphone.fill"
            case .instagram: return "camera.fill"
            case .twitterPost: return "bubble.left.fill"
            case .twitterThread: return "text.line.first.and.arrowtriangle.forward"
            }
        }

        var subtitle: String {
            switch self {
            case .broadcast: return "Polished insight for your members"
            case .instagram: return "Caption with a hook + hashtags"
            case .twitterPost: return "One sharp post under 280 chars"
            case .twitterThread: return "Numbered multi-tweet thread"
            }
        }
    }

    private struct GenerateRequest: Encodable {
        let transcript: String
        let format: String
        let title: String?
    }

    private struct GenerateResponse: Decodable {
        let content: String?
        let format: String?
        let error: String?
    }

    /// Generate content for `format` from `transcript`.
    func generate(transcript: String, format: Format, title: String? = nil) async throws -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw RefineError.emptyInput }
        guard SupabaseManager.shared.isConfigured else { throw RefineError.notConfigured }

        let payload = GenerateRequest(
            transcript: trimmed,
            format: format.rawValue,
            title: title?.isEmpty == false ? title : nil
        )

        let data: Data = try await SupabaseManager.shared.functions.invoke(
            "generate-content",
            options: FunctionInvokeOptions(body: payload),
            decode: { data, _ in data }
        )

        let response = try JSONDecoder().decode(GenerateResponse.self, from: data)
        if let error = response.error, !error.isEmpty {
            throw RefineError.server(error)
        }
        guard let content = response.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw RefineError.emptyResponse
        }
        return content
    }
}
