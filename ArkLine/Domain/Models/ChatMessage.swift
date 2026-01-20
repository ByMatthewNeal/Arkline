import Foundation

// MARK: - Chat Session
struct AIChatSession: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    var title: String?
    let createdAt: Date
    var updatedAt: Date

    // Loaded separately
    var messages: [AIChatMessage]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID = UUID(),
        userId: UUID,
        title: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [AIChatMessage]? = nil
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }

    var displayTitle: String {
        title ?? "New Chat"
    }

    var lastMessagePreview: String? {
        messages?.last?.content.prefix(100).description
    }

    var formattedDate: String {
        if updatedAt.isToday {
            return updatedAt.displayTime
        } else if updatedAt.isYesterday {
            return "Yesterday"
        } else {
            return updatedAt.chartDate
        }
    }
}

// MARK: - AI Chat Message
struct AIChatMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let sessionId: UUID
    var role: MessageRole
    var content: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case role
        case content
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        role: MessageRole,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }

    var isUser: Bool {
        role == .user
    }

    var isAssistant: Bool {
        role == .assistant
    }
}

// MARK: - Message Role
enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

// MARK: - Claude API Request/Response
struct ClaudeMessageRequest: Encodable {
    let model: String
    let maxTokens: Int
    let messages: [ClaudeMessage]
    let system: String?

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
        case system
    }

    static func create(
        messages: [AIChatMessage],
        model: String = "claude-sonnet-4-20250514",
        maxTokens: Int = 4096,
        systemPrompt: String? = nil
    ) -> ClaudeMessageRequest {
        let claudeMessages = messages.filter { $0.role != .system }.map { message in
            ClaudeMessage(role: message.role.rawValue, content: message.content)
        }

        return ClaudeMessageRequest(
            model: model,
            maxTokens: maxTokens,
            messages: claudeMessages,
            system: systemPrompt ?? defaultSystemPrompt
        )
    }

    private static let defaultSystemPrompt = """
    You are ArkLine AI, a helpful financial assistant specialized in cryptocurrency, stocks, and precious metals markets.

    Your capabilities include:
    - Explaining market trends and sentiment indicators
    - Providing educational information about trading concepts
    - Analyzing portfolio allocations (when provided)
    - Discussing DCA strategies
    - Explaining economic events and their potential market impacts

    Important guidelines:
    - Never provide specific financial advice or tell users what to buy/sell
    - Always remind users to do their own research (DYOR)
    - Be clear about the speculative nature of markets
    - Stay updated on market conditions (based on data provided)
    - Be concise but thorough in explanations
    """
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeMessageResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ClaudeContentBlock]
    let model: String
    let stopReason: String?
    let usage: ClaudeUsage

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case role
        case content
        case model
        case stopReason = "stop_reason"
        case usage
    }

    var textContent: String {
        content.compactMap { block in
            if case .text(let text) = block.type {
                return text
            }
            return nil
        }.joined()
    }
}

struct ClaudeContentBlock: Codable {
    let type: ContentType

    enum ContentType {
        case text(String)
        case other
    }

    enum CodingKeys: String, CodingKey {
        case type
        case text
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)

        if typeString == "text" {
            let text = try container.decode(String.self, forKey: .text)
            self.type = .text(text)
        } else {
            self.type = .other
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch type {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .other:
            try container.encode("other", forKey: .type)
        }
    }
}

struct ClaudeUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// MARK: - Create Message Request
struct CreateChatMessageRequest: Encodable {
    let sessionId: UUID
    let role: String
    let content: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case role
        case content
    }
}
