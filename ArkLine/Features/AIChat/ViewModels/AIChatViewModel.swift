import SwiftUI
import Foundation

// MARK: - AI Chat View Model
@Observable
final class AIChatViewModel {
    // MARK: - State
    var sessions: [AIChatSession] = []
    var currentSession: AIChatSession?
    var messages: [AIChatMessage] = []

    var isLoading = false
    var isTyping = false
    var error: AppError?

    // MARK: - Input
    var inputText = ""

    // MARK: - Computed Properties
    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTyping
    }

    var sortedSessions: [AIChatSession] {
        sessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Initialization
    init() {
        loadMockData()
    }

    // MARK: - Data Loading
    func refresh() async {
        isLoading = true
        error = nil

        try? await Task.sleep(nanoseconds: 500_000_000)

        loadMockData()
        isLoading = false
    }

    private func loadMockData() {
        let userId = UUID()
        let sessionId = UUID()

        sessions = [
            AIChatSession(
                userId: userId,
                title: "Bitcoin Price Analysis",
                createdAt: Date().addingTimeInterval(-3600),
                updatedAt: Date().addingTimeInterval(-1800)
            ),
            AIChatSession(
                userId: userId,
                title: "DeFi Strategy Discussion",
                createdAt: Date().addingTimeInterval(-86400),
                updatedAt: Date().addingTimeInterval(-43200)
            ),
            AIChatSession(
                userId: userId,
                title: "Portfolio Rebalancing",
                createdAt: Date().addingTimeInterval(-172800),
                updatedAt: Date().addingTimeInterval(-86400)
            )
        ]

        // Load messages for mock current session
        messages = [
            AIChatMessage(
                sessionId: sessionId,
                role: .user,
                content: "What do you think about the current Bitcoin price action?",
                createdAt: Date().addingTimeInterval(-1800)
            ),
            AIChatMessage(
                sessionId: sessionId,
                role: .assistant,
                content: "Based on current market data, Bitcoin is showing strong support around the $65,000 level. The recent consolidation suggests accumulation phase, with key resistance at $70,000. Volume indicators and on-chain metrics point to healthy market conditions. However, macro factors like Fed policy decisions could impact short-term price action.",
                createdAt: Date().addingTimeInterval(-1780)
            ),
            AIChatMessage(
                sessionId: sessionId,
                role: .user,
                content: "Should I consider DCA into BTC at these levels?",
                createdAt: Date().addingTimeInterval(-900)
            ),
            AIChatMessage(
                sessionId: sessionId,
                role: .assistant,
                content: "DCA (Dollar Cost Averaging) is generally a sound strategy for long-term investors, especially when:\n\n1. You believe in Bitcoin's long-term potential\n2. You want to minimize timing risk\n3. You can commit to regular investments regardless of price\n\nAt current levels, historical data shows we're still below the previous all-time high on an inflation-adjusted basis. However, always consider your risk tolerance and never invest more than you can afford to lose.",
                createdAt: Date().addingTimeInterval(-880)
            )
        ]
    }

    // MARK: - Actions
    func createNewSession() {
        let session = AIChatSession(
            userId: UUID(),
            title: "New Chat",
            createdAt: Date(),
            updatedAt: Date()
        )
        sessions.insert(session, at: 0)
        currentSession = session
        messages = []
    }

    func selectSession(_ session: AIChatSession) {
        currentSession = session
        // In real app, load messages for this session
        loadMockData()
    }

    func deleteSession(_ session: AIChatSession) {
        sessions.removeAll { $0.id == session.id }
        if currentSession?.id == session.id {
            currentSession = sessions.first
        }
    }

    func sendMessage() async {
        guard canSend else { return }

        let userMessage = AIChatMessage(
            sessionId: currentSession?.id ?? UUID(),
            role: .user,
            content: inputText.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date()
        )

        messages.append(userMessage)
        inputText = ""
        isTyping = true

        // Simulate AI response
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        let assistantMessage = AIChatMessage(
            sessionId: currentSession?.id ?? UUID(),
            role: .assistant,
            content: generateMockResponse(for: userMessage.content),
            createdAt: Date()
        )

        messages.append(assistantMessage)
        isTyping = false

        // Update session
        if let index = sessions.firstIndex(where: { $0.id == currentSession?.id }) {
            sessions[index].updatedAt = Date()
            if sessions[index].title == "New Chat" {
                sessions[index].title = String(userMessage.content.prefix(30)) + (userMessage.content.count > 30 ? "..." : "")
            }
        }
    }

    private func generateMockResponse(for query: String) -> String {
        let responses = [
            "Based on current market analysis, I can provide some insights on this topic. The cryptocurrency market has been showing interesting patterns lately, with several key indicators pointing to potential opportunities.",
            "That's a great question! Looking at the data, there are several factors to consider. Market sentiment, on-chain metrics, and macroeconomic conditions all play a role in determining the best strategy.",
            "I'd recommend approaching this with a balanced perspective. While the short-term volatility can be concerning, the long-term fundamentals remain strong. Consider diversifying your approach and maintaining a clear investment thesis."
        ]
        return responses.randomElement() ?? responses[0]
    }

    func clearChat() {
        messages = []
    }
}
