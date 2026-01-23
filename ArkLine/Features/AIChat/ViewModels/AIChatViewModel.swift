import SwiftUI
import Foundation

// MARK: - AI Chat View Model
@Observable
final class AIChatViewModel {
    // MARK: - Dependencies
    private let portfolioService: PortfolioServiceProtocol
    private let marketService: MarketServiceProtocol
    private let sentimentService: SentimentServiceProtocol
    private let vixService: VIXServiceProtocol
    private let dxyService: DXYServiceProtocol
    private let rainbowChartService: RainbowChartServiceProtocol
    private let globalLiquidityService: GlobalLiquidityServiceProtocol
    private let itcRiskService: ITCRiskServiceProtocol

    // MARK: - User Context
    var userName: String = "there"

    // MARK: - State
    var sessions: [AIChatSession] = []
    var currentSession: AIChatSession?
    var messages: [AIChatMessage] = []

    // Store messages per session
    private var sessionMessages: [UUID: [AIChatMessage]] = [:]

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
    init(
        portfolioService: PortfolioServiceProtocol = ServiceContainer.shared.portfolioService,
        marketService: MarketServiceProtocol = ServiceContainer.shared.marketService,
        sentimentService: SentimentServiceProtocol = ServiceContainer.shared.sentimentService,
        vixService: VIXServiceProtocol = ServiceContainer.shared.vixService,
        dxyService: DXYServiceProtocol = ServiceContainer.shared.dxyService,
        rainbowChartService: RainbowChartServiceProtocol = ServiceContainer.shared.rainbowChartService,
        globalLiquidityService: GlobalLiquidityServiceProtocol = ServiceContainer.shared.globalLiquidityService,
        itcRiskService: ITCRiskServiceProtocol = ServiceContainer.shared.itcRiskService
    ) {
        self.portfolioService = portfolioService
        self.marketService = marketService
        self.sentimentService = sentimentService
        self.vixService = vixService
        self.dxyService = dxyService
        self.rainbowChartService = rainbowChartService
        self.globalLiquidityService = globalLiquidityService
        self.itcRiskService = itcRiskService
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

        // Create sessions with fixed IDs for demo
        let btcSession = AIChatSession(
            userId: userId,
            title: "Bitcoin Price Analysis",
            createdAt: Date().addingTimeInterval(-3600),
            updatedAt: Date().addingTimeInterval(-1800)
        )
        let defiSession = AIChatSession(
            userId: userId,
            title: "DeFi Strategy Discussion",
            createdAt: Date().addingTimeInterval(-86400),
            updatedAt: Date().addingTimeInterval(-43200)
        )
        let portfolioSession = AIChatSession(
            userId: userId,
            title: "Portfolio Rebalancing",
            createdAt: Date().addingTimeInterval(-172800),
            updatedAt: Date().addingTimeInterval(-86400)
        )

        sessions = [btcSession, defiSession, portfolioSession]

        // Store messages per session
        sessionMessages[btcSession.id] = [
            AIChatMessage(
                sessionId: btcSession.id,
                role: .user,
                content: "What do you think about the current Bitcoin price action?",
                createdAt: Date().addingTimeInterval(-1800)
            ),
            AIChatMessage(
                sessionId: btcSession.id,
                role: .assistant,
                content: "Based on current market data, Bitcoin is showing strong support around the $65,000 level. The recent consolidation suggests accumulation phase, with key resistance at $70,000. Volume indicators and on-chain metrics point to healthy market conditions. However, macro factors like Fed policy decisions could impact short-term price action.",
                createdAt: Date().addingTimeInterval(-1780)
            ),
            AIChatMessage(
                sessionId: btcSession.id,
                role: .user,
                content: "Should I consider DCA into BTC at these levels?",
                createdAt: Date().addingTimeInterval(-900)
            ),
            AIChatMessage(
                sessionId: btcSession.id,
                role: .assistant,
                content: "DCA (Dollar Cost Averaging) is generally a sound strategy for long-term investors, especially when:\n\n1. You believe in Bitcoin's long-term potential\n2. You want to minimize timing risk\n3. You can commit to regular investments regardless of price\n\nAt current levels, historical data shows we're still below the previous all-time high on an inflation-adjusted basis. However, always consider your risk tolerance and never invest more than you can afford to lose.",
                createdAt: Date().addingTimeInterval(-880)
            )
        ]

        sessionMessages[defiSession.id] = [
            AIChatMessage(
                sessionId: defiSession.id,
                role: .user,
                content: "Can you explain yield farming strategies?",
                createdAt: Date().addingTimeInterval(-43200)
            ),
            AIChatMessage(
                sessionId: defiSession.id,
                role: .assistant,
                content: "Yield farming involves providing liquidity to DeFi protocols in exchange for rewards. Key strategies include:\n\n1. **Liquidity Provision**: Add assets to DEX pools (Uniswap, Curve)\n2. **Lending**: Supply assets to protocols like Aave or Compound\n3. **Staking**: Lock tokens for protocol rewards\n\nRisks to consider: impermanent loss, smart contract vulnerabilities, and token price volatility.",
                createdAt: Date().addingTimeInterval(-43100)
            )
        ]

        sessionMessages[portfolioSession.id] = [
            AIChatMessage(
                sessionId: portfolioSession.id,
                role: .user,
                content: "How should I rebalance my crypto portfolio?",
                createdAt: Date().addingTimeInterval(-86400)
            ),
            AIChatMessage(
                sessionId: portfolioSession.id,
                role: .assistant,
                content: "Portfolio rebalancing depends on your risk tolerance and goals. Common approaches:\n\n1. **Time-based**: Rebalance quarterly or monthly\n2. **Threshold-based**: Rebalance when allocations drift >5-10%\n3. **Hybrid**: Combine both methods\n\nConsider tax implications and transaction costs when rebalancing.",
                createdAt: Date().addingTimeInterval(-86300)
            )
        ]

        // Set initial session and load its messages
        currentSession = btcSession
        messages = sessionMessages[btcSession.id] ?? []
    }

    // MARK: - Actions
    func createNewSession() {
        // Save current messages before switching
        saveCurrentSessionMessages()

        let session = AIChatSession(
            userId: UUID(),
            title: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        sessions.insert(session, at: 0)
        currentSession = session
        messages = []
    }

    func selectSession(_ session: AIChatSession) {
        // Save current messages before switching
        saveCurrentSessionMessages()

        // Switch to new session and load its messages
        currentSession = session
        messages = sessionMessages[session.id] ?? []
    }

    func deleteSession(_ session: AIChatSession) {
        sessions.removeAll { $0.id == session.id }
        sessionMessages.removeValue(forKey: session.id)

        if currentSession?.id == session.id {
            currentSession = sessions.first
            if let firstSession = currentSession {
                messages = sessionMessages[firstSession.id] ?? []
            } else {
                messages = []
            }
        }
    }

    private func saveCurrentSessionMessages() {
        guard let sessionId = currentSession?.id, !messages.isEmpty else { return }
        sessionMessages[sessionId] = messages
    }

    func sendMessage() async {
        guard canSend else { return }

        let sessionId = currentSession?.id ?? UUID()
        let userMessage = AIChatMessage(
            sessionId: sessionId,
            role: .user,
            content: inputText.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date()
        )

        messages.append(userMessage)
        inputText = ""
        isTyping = true
        error = nil

        do {
            // Call Claude API
            let responseContent = try await sendToClaudeAPI()

            let assistantMessage = AIChatMessage(
                sessionId: sessionId,
                role: .assistant,
                content: responseContent,
                createdAt: Date()
            )

            messages.append(assistantMessage)
        } catch {
            // On error, show error message and use fallback
            self.error = error as? AppError ?? .networkError(underlying: error)

            let errorMessage = AIChatMessage(
                sessionId: sessionId,
                role: .assistant,
                content: "I'm sorry, I couldn't connect to the AI service. Please check your internet connection and try again.\n\nError: \(error.localizedDescription)",
                createdAt: Date()
            )
            messages.append(errorMessage)
        }

        isTyping = false

        // Update session
        if let index = sessions.firstIndex(where: { $0.id == currentSession?.id }) {
            sessions[index].updatedAt = Date()
            if sessions[index].title == nil || sessions[index].title == "New Chat" {
                sessions[index].title = String(userMessage.content.prefix(30)) + (userMessage.content.count > 30 ? "..." : "")
            }
        }

        // Save messages to session storage
        saveCurrentSessionMessages()
    }

    private func sendToClaudeAPI() async throws -> String {
        // Build personalized system prompt with current context
        let systemPrompt = await buildSystemPrompt()

        // Build the request with conversation history and Ark personality
        let request = ClaudeMessageRequest.create(
            messages: messages,
            systemPrompt: systemPrompt
        )
        let endpoint = ClaudeEndpoint.messages(request: request)

        let response: ClaudeMessageResponse = try await NetworkManager.shared.request(
            endpoint: endpoint,
            responseType: ClaudeMessageResponse.self
        )

        return response.textContent
    }

    // MARK: - Context Building

    private func buildSystemPrompt() async -> String {
        // Gather context in parallel
        async let portfolioContext = gatherPortfolioContext()
        async let marketContext = gatherMarketContext()

        let (portfolio, market) = await (portfolioContext, marketContext)

        return ArkSystemPrompt.generate(
            userName: userName,
            portfolioContext: portfolio,
            marketContext: market
        )
    }

    private func gatherPortfolioContext() async -> String? {
        do {
            let portfolios = try await portfolioService.fetchPortfolios(userId: UUID())
            guard let mainPortfolio = portfolios.first,
                  let holdings = mainPortfolio.holdings,
                  !holdings.isEmpty else {
                return nil
            }

            let totalValue = holdings.reduce(0.0) { $0 + $1.currentValue }
            let totalCost = holdings.reduce(0.0) { $0 + $1.totalCost }
            let dayChange = totalValue - totalCost
            let dayChangePercent = totalCost > 0 ? (dayChange / totalCost) * 100 : 0

            let holdingsData: [(symbol: String, allocation: Double, pnlPercent: Double)] = holdings.map { holding in
                let allocation = totalValue > 0 ? (holding.currentValue / totalValue) * 100 : 0
                let pnl = holding.totalCost > 0 ? ((holding.currentValue - holding.totalCost) / holding.totalCost) * 100 : 0
                return (symbol: holding.symbol, allocation: allocation, pnlPercent: pnl)
            }

            return ArkSystemPrompt.portfolioContext(
                totalValue: totalValue,
                dayChange: dayChange,
                dayChangePercent: dayChangePercent,
                holdings: holdingsData
            )
        } catch {
            return nil
        }
    }

    private func gatherMarketContext() async -> String? {
        // Fetch all indicators in parallel
        async let fearGreedTask = fetchFearGreedSafe()
        async let btcDominanceTask = fetchBTCDominanceSafe()
        async let btcRiskTask = fetchITCRiskSafe(coin: "BTC")
        async let ethRiskTask = fetchITCRiskSafe(coin: "ETH")
        async let vixTask = fetchVIXSafe()
        async let dxyTask = fetchDXYSafe()
        async let liquidityTask = fetchLiquiditySafe()
        async let fundingTask = fetchFundingRateSafe()
        async let etfTask = fetchETFFlowSafe()
        async let rainbowTask = fetchRainbowBandSafe()

        let (fearGreed, btcDominance, btcRisk, ethRisk, vix, dxy, liquidity, funding, etf, rainbow) = await (
            fearGreedTask, btcDominanceTask, btcRiskTask, ethRiskTask,
            vixTask, dxyTask, liquidityTask, fundingTask, etfTask, rainbowTask
        )

        return ArkSystemPrompt.marketContext(
            fearGreedIndex: fearGreed?.value,
            fearGreedClassification: fearGreed?.classification,
            btcDominance: btcDominance?.value,
            btcRiskLevel: btcRisk?.riskLevel,
            ethRiskLevel: ethRisk?.riskLevel,
            rainbowBand: rainbow,
            vixValue: vix?.value,
            vixSignal: vix?.signal.rawValue,
            dxyChange: dxy?.changePercent,
            dxySignal: dxy?.signal.rawValue,
            liquidityChangeYoY: liquidity?.yearlyChange,
            fundingRate: funding?.averageRate,
            etfNetFlow: etf?.dailyNetFlow
        )
    }

    // MARK: - Safe Fetch Helpers

    private func fetchFearGreedSafe() async -> FearGreedIndex? {
        try? await sentimentService.fetchFearGreedIndex()
    }

    private func fetchBTCDominanceSafe() async -> BTCDominance? {
        try? await sentimentService.fetchBTCDominance()
    }

    private func fetchITCRiskSafe(coin: String) async -> ITCRiskLevel? {
        try? await itcRiskService.fetchLatestRiskLevel(coin: coin)
    }

    private func fetchVIXSafe() async -> VIXData? {
        try? await vixService.fetchLatestVIX()
    }

    private func fetchDXYSafe() async -> DXYData? {
        try? await dxyService.fetchLatestDXY()
    }

    private func fetchLiquiditySafe() async -> GlobalLiquidityChanges? {
        try? await globalLiquidityService.fetchLiquidityChanges()
    }

    private func fetchFundingRateSafe() async -> FundingRate? {
        try? await sentimentService.fetchFundingRate()
    }

    private func fetchETFFlowSafe() async -> ETFNetFlow? {
        try? await sentimentService.fetchETFNetFlow()
    }

    private func fetchRainbowBandSafe() async -> String? {
        // Get current BTC price first
        guard let btcPrice = try? await marketService.fetchCryptoAssets(page: 1, perPage: 1).first?.currentPrice,
              let rainbowData = try? await rainbowChartService.fetchCurrentRainbowData(btcPrice: btcPrice) else {
            return nil
        }
        return rainbowData.currentBand.rawValue
    }

    func clearChat() {
        messages = []
    }
}
