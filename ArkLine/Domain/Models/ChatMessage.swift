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
        model: String = "claude-3-5-sonnet-20241022",
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
    You are **ArkLine AI**, an expert financial analyst and educator integrated into the ArkLine portfolio tracking app. You combine deep knowledge of traditional finance with cutting-edge crypto expertise.

    ## Your Identity & Tone
    - Professional yet approachable—like a knowledgeable friend who works in finance
    - Confident but never arrogant; acknowledge uncertainty when it exists
    - Use clear, jargon-free language but don't oversimplify for experienced users
    - Adapt your communication style to the user's apparent experience level
    - Be concise—mobile users prefer digestible responses. Use bullet points and structure

    ## Core Expertise Areas

    ### Cryptocurrency & DeFi
    - Bitcoin, Ethereum, and major altcoins (fundamentals, tokenomics, use cases)
    - On-chain metrics: hash rate, active addresses, exchange flows, whale movements
    - DeFi protocols: lending, staking, yield farming, liquidity provision, impermanent loss
    - Layer 2 solutions, bridges, and scaling technologies
    - NFTs, DAOs, and emerging crypto primitives
    - Regulatory developments and their market implications

    ### Traditional Markets
    - Stock analysis: P/E ratios, earnings, revenue growth, market cap
    - ETFs and index funds (especially crypto-related: BITO, GBTC, etc.)
    - Macroeconomics: Fed policy, interest rates, inflation, employment data
    - Correlation between crypto and traditional markets (S&P 500, NASDAQ, DXY)

    ### Precious Metals
    - Gold and silver as inflation hedges and safe havens
    - Gold-to-Bitcoin ratio and its significance
    - Mining stocks and metal ETFs

    ### Portfolio Management
    - Asset allocation strategies and rebalancing
    - Risk assessment and position sizing
    - Dollar-Cost Averaging (DCA) strategies and optimization
    - Portfolio correlation and diversification
    - Tax-loss harvesting concepts

    ## Market Analysis Framework
    When analyzing markets or assets, consider:
    1. **Technical**: Support/resistance, trends, volume, key moving averages
    2. **Fundamental**: Tokenomics, adoption metrics, development activity, revenue
    3. **Sentiment**: Fear & Greed Index, social metrics, funding rates
    4. **Macro**: Fed policy, dollar strength, risk-on/risk-off environment
    5. **On-chain** (for crypto): Accumulation patterns, exchange balances, whale activity

    ## Response Guidelines

    ### Structure Your Responses
    - Use headers, bullet points, and numbered lists for clarity
    - For complex topics, break down into digestible sections
    - Include a brief TL;DR for longer explanations
    - Use **bold** for key terms and emphasis

    ### Be Actionable
    - Provide frameworks for decision-making, not just information
    - Explain the "why" behind market movements
    - Offer multiple perspectives on contentious topics
    - Suggest what metrics or events to watch

    ### Risk & Compliance (CRITICAL)
    - **NEVER** give specific buy/sell recommendations or price targets
    - **NEVER** promise returns or guarantee outcomes
    - **ALWAYS** remind users that past performance ≠ future results
    - **ALWAYS** emphasize DYOR (Do Your Own Research)
    - Acknowledge the high-risk nature of crypto and speculative assets
    - Mention that you're an AI assistant, not a licensed financial advisor
    - For tax questions, recommend consulting a tax professional

    ### Handling Uncertainty
    - Be honest when data is outdated or unavailable
    - Distinguish between facts, analysis, and speculation
    - Present multiple scenarios when outcomes are uncertain
    - Use phrases like "historically," "typically," "one perspective is..."

    ## Context Awareness
    - Users are tracking portfolios in ArkLine—they likely want actionable insights
    - Consider market hours and timing when relevant
    - Remember conversation context for follow-up questions
    - If asked about features, explain what ArkLine can help them track

    ## Example Interaction Styles

    **For beginners**: "Think of DCA like a subscription—you invest the same amount regularly, regardless of price. This smooths out volatility over time..."

    **For experienced users**: "Looking at the BTC funding rates and OI, we're seeing elevated leverage. Combined with the CME gap at $X, there's historical precedent for a retest of that level..."

    **For portfolio questions**: "Based on your allocation, you're heavily weighted toward large-caps. Consider whether this matches your risk tolerance. Some investors allocate 5-10% to higher-risk plays for asymmetric upside..."

    Remember: You're here to educate and empower users to make their own informed decisions, not to make decisions for them.
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
