import Foundation
import Supabase

// MARK: - Broadcast Refine Service
/// Turns a raw spoken transcript (or typed draft) into a polished, first-person
/// market insight in the admin's own voice via the `refine-broadcast` edge function.
/// The Claude call and API key live server-side; this only ships the text up and
/// returns the refined draft for the admin to edit before publishing.
final class BroadcastRefineService {
    static let shared = BroadcastRefineService()
    private init() {}

    /// Refinement tone. `polished` keeps the author's voice and length; `brief`
    /// condenses hard; `takeaways` restructures into intro + bullet points.
    enum Style: String {
        case polished
        case brief
        case takeaways

        var displayName: String {
            switch self {
            case .polished: return "Polished"
            case .brief: return "Brief"
            case .takeaways: return "Takeaways"
            }
        }
    }

    private struct RefineRequest: Encodable {
        let transcript: String
        let style: String
        let title: String?
    }

    private struct RefineResponse: Decodable {
        let refined: String?
        let style: String?
        let error: String?
    }

    /// Refine `transcript` into a published-ready insight.
    /// - Parameters:
    ///   - transcript: the raw spoken/typed input.
    ///   - style: desired tone (default `.polished`).
    ///   - title: optional working title for extra context.
    func refine(transcript: String, style: Style = .polished, title: String? = nil) async throws -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RefineError.emptyInput
        }
        guard SupabaseManager.shared.isConfigured else {
            throw RefineError.notConfigured
        }

        let payload = RefineRequest(
            transcript: trimmed,
            style: style.rawValue,
            title: title?.isEmpty == false ? title : nil
        )

        let data: Data = try await SupabaseManager.shared.functions.invoke(
            "refine-broadcast",
            options: FunctionInvokeOptions(body: payload),
            decode: { data, _ in data }
        )

        let response = try JSONDecoder().decode(RefineResponse.self, from: data)

        if let error = response.error, !error.isEmpty {
            throw RefineError.server(error)
        }
        guard let refined = response.refined?.trimmingCharacters(in: .whitespacesAndNewlines),
              !refined.isEmpty else {
            throw RefineError.emptyResponse
        }
        return refined
    }
}

// MARK: - Error

enum RefineError: LocalizedError {
    case emptyInput
    case notConfigured
    case emptyResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "There's nothing to refine yet — record or type some thoughts first."
        case .notConfigured:
            return "Refinement isn't available right now."
        case .emptyResponse:
            return "The refined draft came back empty. Please try again."
        case .server(let message):
            return message
        }
    }
}
