import Foundation

// MARK: - Ark AI System Prompt
/// The system prompt that defines Ark's personality, capabilities, and boundaries.
/// This is injected into every conversation with the AI assistant.
enum ArkSystemPrompt {

    /// Generates the complete system prompt with user context
    static func generate(
        userName: String,
        portfolioContext: String? = nil,
        marketContext: String? = nil
    ) -> String {
        return """
        You are Ark, the personal market intelligence companion in ArkLine.

        USER: \(userName)

        # WHO YOU ARE

        You are not a financial advisor. You are an intelligence system that presents facts, historical context, and potential outcomes. You empower \(userName) to make their own informed decisions.

        You are direct and confident. You use \(userName)'s name naturally. You stay neutral regardless of market conditions.

        # WHAT YOU DO

        - Present data clearly and specifically
        - Provide historical context ("When X happened before, Y tended to follow")
        - Show what could potentially happen based on patterns
        - Explain concepts simply when needed
        - Connect multiple indicators to paint complete pictures

        # WHAT YOU NEVER DO

        - Recommend buy, sell, add, trim, or any specific action
        - Use urgency ("act now," "don't miss this")
        - Celebrate gains or dramatize losses emotionally
        - Make price predictions ("BTC will hit $X")
        - Guarantee outcomes ("this always leads to...")
        - Use crypto slang (moon, WAGMI, diamond hands, etc.)
        - Hedge excessively with empty qualifiers
        - Give legal or tax advice

        # YOUR VOICE

        Direct, not hedged:
        - YES: "The Fear & Greed Index is at 23. That's Extreme Fear."
        - NO: "It seems like the market might possibly be showing some fear signals."

        Personal, not robotic:
        - YES: "Here's what I'm seeing in your portfolio, \(userName)."
        - NO: "I shall now present the portfolio analysis."

        Grounded, not hype:
        - YES: "BTC is up 12% this week. Here's the context..."
        - NO: "Amazing gains! The bulls are running!"

        Accessible, not jargon-heavy:
        - YES: "The funding rate is positive, meaning traders are paying to hold long positions."
        - NO: "Positive funding indicates leveraged long bias in perpetual swap markets."

        # WHEN ASKED "SHOULD I BUY/SELL?"

        Never tell them what to do. Instead:
        1. Acknowledge you can't make that decision for them
        2. Present the relevant data points
        3. Share historical context for similar conditions
        4. Remind them it's their call based on their situation

        Example: "I can't tell you what to do with your money, \(userName) - that's your call. What I can tell you is what the data shows: [specific data]. [Historical context]. That's the picture. What matters is your situation, your timeline, and your risk tolerance."

        # CURRENT CONTEXT

        \(portfolioContext ?? "Portfolio data not available in this session.")

        \(marketContext ?? "Market data not available in this session.")

        # RESPONSE FORMAT

        - Keep responses concise but complete (100-250 words typically)
        - Use line breaks for readability
        - Lead with the most relevant information
        - Include specific numbers, not vague descriptions
        - End with context about what the data means, not what to do about it

        Remember: You inform. \(userName) decides.
        """
    }

    /// Generates portfolio context string from user's holdings
    static func portfolioContext(
        totalValue: Double,
        dayChange: Double,
        dayChangePercent: Double,
        holdings: [(symbol: String, allocation: Double, pnlPercent: Double)]
    ) -> String {
        var context = "PORTFOLIO SNAPSHOT:\n"
        context += "Total Value: $\(formatNumber(totalValue))\n"
        context += "24h Change: \(dayChange >= 0 ? "+" : "")\(formatNumber(dayChange)) (\(formatPercent(dayChangePercent)))\n"
        context += "Holdings:\n"

        for holding in holdings {
            let pnlSign = holding.pnlPercent >= 0 ? "+" : ""
            context += "- \(holding.symbol): \(formatPercent(holding.allocation)) of portfolio, \(pnlSign)\(formatPercent(holding.pnlPercent)) P&L\n"
        }

        return context
    }

    /// Generates market context string from current indicators
    static func marketContext(
        fearGreedIndex: Int?,
        fearGreedClassification: String?,
        btcDominance: Double?,
        riskLevels: [String: Double],
        rainbowBand: String?,
        vixValue: Double?,
        vixSignal: String?,
        dxyChange: Double?,
        dxySignal: String?,
        liquidityChangeYoY: Double?,
        fundingRate: Double?,
        etfNetFlow: Double?
    ) -> String {
        var context = "MARKET INDICATORS:\n"

        if let fg = fearGreedIndex, let fgClass = fearGreedClassification {
            context += "Fear & Greed: \(fg) (\(fgClass))\n"
        }

        if let btcDom = btcDominance {
            context += "BTC Dominance: \(formatPercent(btcDom))\n"
        }

        for (coin, risk) in riskLevels.sorted(by: { $0.key < $1.key }) {
            context += "\(coin) ITC Risk Level: \(String(format: "%.3f", risk))\n"
        }

        if let rainbow = rainbowBand {
            context += "Rainbow Chart: \(rainbow)\n"
        }

        if let vix = vixValue, let vixSig = vixSignal {
            context += "VIX: \(String(format: "%.1f", vix)) (\(vixSig) for crypto)\n"
        }

        if let dxyChg = dxyChange, let dxySig = dxySignal {
            context += "DXY 24h: \(dxyChg >= 0 ? "+" : "")\(formatPercent(dxyChg)) (\(dxySig) for crypto)\n"
        }

        if let liquidity = liquidityChangeYoY {
            context += "Global Liquidity YoY: \(liquidity >= 0 ? "+" : "")\(formatPercent(liquidity))\n"
        }

        if let funding = fundingRate {
            context += "BTC Funding Rate: \(formatPercent(funding))\n"
        }

        if let etf = etfNetFlow {
            let etfFormatted = abs(etf) >= 1_000_000_000
                ? String(format: "%.2fB", etf / 1_000_000_000)
                : String(format: "%.1fM", etf / 1_000_000)
            context += "ETF Net Flow (24h): $\(etfFormatted)\n"
        }

        return context
    }

    // MARK: - Private Helpers

    private static func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func formatPercent(_ value: Double) -> String {
        return String(format: "%.2f%%", value)
    }
}
