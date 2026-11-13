import Foundation
import SwiftUI

// MARK: - Mindset Beats
/// A curated catalog of calm psychology reminders, rotated one per day. Shared by
/// the Home mindset widget and the Learn hub's "Mindset today" card so both show
/// the same beat. The live, state-matched versions live on the Cycle Scorecard
/// and Sentiment Regime screens.
enum MindsetBeats {
    static let all: [(line: String, tag: String)] = [
        ("Bottoms come wrapped in bad news. That's exactly what makes them bottoms.", "On buying fear"),
        ("Tops feel like the start of something huge, right when the smart money is quietly heading for the door.", "On selling greed"),
        ("A red day is a paper loss. It only becomes real when you sell it, or when the thing you own is actually broken.", "On loss aversion"),
        ("The loudest fear and the deepest value usually show up together. You don't have to be brave, just calm.", "On capitulation"),
        ("Comfort and opportunity rarely sit in the same seat. If a buy feels safe, the easy money is usually gone.", "On conviction"),
        ("The market doesn't know or care what you paid. Waiting to get back to even has trapped more people than any crash.", "On anchoring"),
        ("Nothing goes up forever and nothing goes down forever. The pain is loud, but it's not accurate.", "On recency bias"),
        ("The market moves money from people in a hurry to people who can wait. Most days the strongest move is to do nothing.", "On patience"),
        ("You can't dig your way out of a hole. Protect first, profit second.", "On revenge trades"),
        ("Make the plan while your head is clear. In the moment, the crowd's fear or greed will decide for you.", "On preparation"),
        ("A feed full of people who agree with you is a warning, not a green light.", "On confirmation bias"),
        ("You can't out-willpower your own brain in the moment. Decide when you're calm, then automate it so emotion gets no vote.", "On rules over willpower"),
        ("You don't need to do more. Most days you need to do less.", "On focus"),
        ("Before you ask how to win, ask how you'd blow it, then don't do that.", "On discipline"),
        ("If you can't explain why you own it, you don't.", "On conviction"),
        ("Survive first. You can't compound if you're out of the game.", "On risk"),
        ("The quiet you protect is where the real thinking happens.", "On focus"),
        ("The goal is to make money, not to be right.", "On ego"),
        ("Nobody knows the next move. Anybody who says they do is talking their own book.", "On humility"),
        ("Practice makes permanent, so repeat the right habit, not the comfortable one.", "On discipline"),
        ("Smart people lose by thinking like everybody else.", "On independence"),
        ("A loss hurts about twice as much as the same win feels good. Plan for it.", "On loss aversion"),
        ("You remember your wins bigger than they really were.", "On honesty"),
        ("Your mood is not market information.", "On awareness"),
        ("Check less. Daily noise isn't a signal.", "On focus"),
        ("Zoom out before you decide: the full cost, the long game, the other side of it.", "On clarity"),
        ("Fear and hope usually point the wrong way. You fear losing a win, and hope keeps you in a bad position.", "On awareness"),
        ("\"The chart made me do it\" is usually the ego dodging the pain of being wrong.", "On ego"),
    ]

    static var today: (line: String, tag: String) {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return all[day % all.count]
    }
}

// MARK: - Widget Size
/// Represents the display size for a widget
enum WidgetSize: String, CaseIterable, Codable, Identifiable {
    case compact = "compact"
    case standard = "standard"
    case expanded = "expanded"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compact: return "Compact"
        case .standard: return "Standard"
        case .expanded: return "Expanded"
        }
    }

    var icon: String {
        switch self {
        case .compact: return "rectangle.compress.vertical"
        case .standard: return "rectangle"
        case .expanded: return "rectangle.expand.vertical"
        }
    }
}

// MARK: - Home Widget Type
/// Represents the different widgets that can be displayed on the home screen
enum HomeWidgetType: String, CaseIterable, Codable, Identifiable {
    case marketTicker = "market_ticker"
    case upcomingEvents = "upcoming_events"
    case riskScore = "risk_score"
    case fearGreedIndex = "fear_greed"
    case marketMovers = "market_movers"
    case dcaReminders = "dca_reminders"
    // Market widgets (from Market tab)
    case fedWatch = "fed_watch"
    case dailyNews = "daily_news"
    case assetRiskLevel = "asset_risk_level"
    case vixIndicator = "vix_indicator"
    case dxyIndicator = "dxy_indicator"
    case globalLiquidity = "global_liquidity"
    case macroDashboard = "macro_dashboard"
    case supplyInProfit = "supply_in_profit"
    case favorites = "favorites"
    case aiMarketSummary = "ai_market_summary"
    case flashIntel = "flash_intel"
    case usFutures = "us_futures"
    case qpsSignals = "qps_signals"
    case marketDeck = "market_deck"
    case stockRiskLevel = "stock_risk_level"
    case modelPortfolioUpdate = "model_portfolio_update"
    case perpPremium = "perp_premium"
    case rotationGauge = "rotation_gauge"
    case marketBreadth = "market_breadth"
    case learnCard = "learn_card"
    case supportResistance = "support_resistance"
    case liquidationHeatmap = "liquidation_heatmap"
    case spotDerivativesFlows = "spot_derivatives_flows"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .marketTicker: return "Market Ticker"
        case .upcomingEvents: return "Upcoming Events"
        case .riskScore: return "ArkLine Score"
        case .fearGreedIndex: return "Fear & Greed Index"
        case .marketMovers: return "Core"
        case .dcaReminders: return "DCA Reminders"
        case .fedWatch: return "Fed Watch"
        case .dailyNews: return "Daily News"
        case .assetRiskLevel: return "Crypto Risk Levels"
        case .vixIndicator: return "VIX"
        case .dxyIndicator: return "DXY"
        case .globalLiquidity: return "Global M2"
        case .macroDashboard: return "Macro Dashboard"
        case .supplyInProfit: return "BTC Supply in Profit"
        case .favorites: return "Favorites"
        case .aiMarketSummary: return "Daily Briefing"
        case .flashIntel: return "Trade Signals"
        case .usFutures: return "US Futures"
        case .qpsSignals: return "Signal Changes"
        case .marketDeck: return "Weekly Update"
        case .stockRiskLevel: return "Stock Risk Levels"
        case .modelPortfolioUpdate: return "Model Portfolio Updates"
        case .perpPremium: return "Perp Premium"
        case .rotationGauge: return "Crypto/Equities Rotation"
        case .marketBreadth: return "Market Breadth"
        case .learnCard: return "Learn"
        case .supportResistance: return "Support & Resistance"
        case .liquidationHeatmap: return "Liquidation Heatmap"
        case .spotDerivativesFlows: return "Spot vs Derivatives"
        }
    }

    var description: String {
        switch self {
        case .marketTicker: return "Scrolling strip of prices, sentiment, and top headlines"
        case .upcomingEvents: return "Economic calendar events that may impact markets"
        case .riskScore: return "Composite risk score based on multiple indicators"
        case .fearGreedIndex: return "Market sentiment gauge from 0-100"
        case .marketMovers: return "BTC, ETH, and SOL prices at a glance"
        case .dcaReminders: return "Your dollar-cost averaging reminders"
        case .fedWatch: return "Fed interest rate probability from CME"
        case .dailyNews: return "Latest crypto and market news"
        case .assetRiskLevel: return "Crypto regression risk from genesis date"
        case .vixIndicator: return "CBOE Volatility Index - Market fear gauge"
        case .dxyIndicator: return "US Dollar Index - Dollar strength"
        case .globalLiquidity: return "Global M2 money supply trends"
        case .macroDashboard: return "Combined macro indicators with market regime analysis"
        case .supplyInProfit: return "Percentage of BTC supply currently in profit"
        case .favorites: return "Your starred coins at a glance"
        case .aiMarketSummary: return "AI-generated daily market summary"
        case .flashIntel: return "Fibonacci-based trade signals across timeframes"
        case .usFutures: return "S&P 500, Dow, and NASDAQ futures with session indicator"
        case .qpsSignals: return "Daily positioning signal changes across 8 assets"
        case .marketDeck: return "Weekly market update slide deck"
        case .stockRiskLevel: return "Regression risk levels for select stocks"
        case .modelPortfolioUpdate: return "Latest rebalance from your followed strategy"
        case .perpPremium: return "Directional bias in perpetual futures markets"
        case .rotationGauge: return "Daily signal showing when to favor crypto vs equities, with sector rankings"
        case .marketBreadth: return "% of tokens in uptrend with EMA crossover signals"
        case .learnCard: return "A daily lesson or 'did you know' definition to learn from"
        case .supportResistance: return "Nearest algorithmic support and resistance levels for BTC"
        case .liquidationHeatmap: return "Estimated liquidation clusters above and below price"
        case .spotDerivativesFlows: return "Spot CVD vs open interest and funding, spot or leverage led"
        }
    }

    var icon: String {
        switch self {
        case .marketTicker: return "dot.radiowaves.left.and.right"
        case .upcomingEvents: return "calendar.badge.clock"
        case .riskScore: return "gauge.with.dots.needle.33percent"
        case .fearGreedIndex: return "speedometer"
        case .marketMovers: return "chart.line.uptrend.xyaxis"
        case .dcaReminders: return "bell.badge"
        case .fedWatch: return "building.columns"
        case .dailyNews: return "newspaper"
        case .assetRiskLevel: return "gauge.with.needle"
        case .vixIndicator: return "chart.line.uptrend.xyaxis"
        case .dxyIndicator: return "dollarsign.arrow.trianglehead.counterclockwise.rotate.90"
        case .globalLiquidity: return "chart.bar.fill"
        case .macroDashboard: return "chart.bar.xaxis"
        case .supplyInProfit: return "chart.pie"
        case .favorites: return "star.fill"
        case .aiMarketSummary: return "sparkles"
        case .flashIntel: return "scope"
        case .usFutures: return "chart.line.uptrend.xyaxis"
        case .qpsSignals: return "waveform.path.ecg"
        case .marketDeck: return "doc.richtext"
        case .stockRiskLevel: return "chart.line.uptrend.xyaxis"
        case .modelPortfolioUpdate: return "arrow.triangle.2.circlepath"
        case .perpPremium: return "gauge.with.dots.needle.33percent"
        case .rotationGauge: return "arrow.left.arrow.right.circle"
        case .marketBreadth: return "chart.bar.xaxis"
        case .learnCard: return "books.vertical"
        case .supportResistance: return "arrow.up.arrow.down"
        case .liquidationHeatmap: return "flame"
        case .spotDerivativesFlows: return "arrow.left.arrow.right"
        }
    }

    var accentColor: Color {
        // Simplified: All widgets use the primary accent color for consistency
        return AppColors.accent
    }

    /// Whether this widget mirrors content that also lives on the Market tab.
    /// Shown as a hint in Customize Home so users know where the canonical version lives.
    var isMirroredOnMarket: Bool {
        switch self {
        case .fedWatch, .dailyNews, .vixIndicator, .dxyIndicator, .globalLiquidity,
             .macroDashboard, .supplyInProfit, .flashIntel, .usFutures, .qpsSignals,
             .rotationGauge, .marketBreadth, .riskScore, .fearGreedIndex, .liquidationHeatmap,
             .spotDerivativesFlows:
            return true
        case .marketTicker, .upcomingEvents, .marketMovers, .dcaReminders, .assetRiskLevel,
             .favorites, .aiMarketSummary, .marketDeck, .stockRiskLevel, .modelPortfolioUpdate,
             .perpPremium, .learnCard, .supportResistance:
            return false
        }
    }

    /// Whether this widget requires a Pro subscription
    var isPremium: Bool {
        switch self {
        case .marketTicker, .upcomingEvents, .fearGreedIndex, .marketMovers, .dcaReminders, .dailyNews, .assetRiskLevel, .favorites, .aiMarketSummary, .usFutures, .marketDeck, .stockRiskLevel, .modelPortfolioUpdate, .marketBreadth, .learnCard, .supportResistance, .liquidationHeatmap, .spotDerivativesFlows:
            return false
        case .riskScore, .fedWatch, .vixIndicator, .dxyIndicator, .globalLiquidity, .macroDashboard, .supplyInProfit, .flashIntel, .qpsSignals, .perpPremium, .rotationGauge:
            return true
        }
    }

    /// Default order for widgets. Model Portfolio sits right under Upcoming
    /// Events — "what the strategy is doing" is front-page content.
    static var defaultOrder: [HomeWidgetType] {
        [.marketTicker, .upcomingEvents, .modelPortfolioUpdate, .marketDeck, .usFutures, .qpsSignals, .rotationGauge, .flashIntel, .perpPremium, .riskScore, .fearGreedIndex, .marketMovers, .favorites, .marketBreadth, .macroDashboard, .vixIndicator, .dxyIndicator, .globalLiquidity, .supplyInProfit, .assetRiskLevel, .stockRiskLevel, .fedWatch, .dailyNews, .learnCard, .dcaReminders, .aiMarketSummary, .supportResistance, .liquidationHeatmap, .spotDerivativesFlows]
    }

    /// Widgets enabled by default (lean set for new users — rest is discoverable via Customize).
    /// Home focuses on "my situation"; broad market content lives on the Market tab, with the
    /// Market Ticker as the always-on bridge. Fear & Greed and Macro Dashboard remain one
    /// toggle away (their headline values scroll in the ticker).
    static var defaultEnabled: Set<HomeWidgetType> {
        Set([.marketTicker, .upcomingEvents, .modelPortfolioUpdate, .aiMarketSummary, .supportResistance, .marketMovers, .marketDeck, .qpsSignals, .assetRiskLevel, .stockRiskLevel, .dailyNews, .learnCard, .liquidationHeatmap, .spotDerivativesFlows])
    }

    /// Default widget sizes (compact where appropriate to keep the home screen tight)
    static var defaultSizes: [HomeWidgetType: WidgetSize] {
        [.upcomingEvents: .compact, .dailyNews: .compact, .learnCard: .compact]
    }
}

// MARK: - Widget Configuration
/// Stores user's widget preferences
struct WidgetConfiguration: Codable, Equatable {
    var enabledWidgets: Set<HomeWidgetType>
    var widgetOrder: [HomeWidgetType]
    var widgetSizes: [HomeWidgetType: WidgetSize]

    init(enabledWidgets: Set<HomeWidgetType> = HomeWidgetType.defaultEnabled,
         widgetOrder: [HomeWidgetType] = HomeWidgetType.defaultOrder,
         widgetSizes: [HomeWidgetType: WidgetSize] = HomeWidgetType.defaultSizes) {
        self.enabledWidgets = enabledWidgets
        self.widgetOrder = widgetOrder
        self.widgetSizes = widgetSizes
    }

    /// Returns ordered list of enabled widgets
    var orderedEnabledWidgets: [HomeWidgetType] {
        widgetOrder.filter { enabledWidgets.contains($0) }
    }

    mutating func toggleWidget(_ widget: HomeWidgetType) {
        if enabledWidgets.contains(widget) {
            enabledWidgets.remove(widget)
        } else {
            enabledWidgets.insert(widget)
        }
    }

    mutating func setWidgetEnabled(_ widget: HomeWidgetType, enabled: Bool) {
        if enabled {
            enabledWidgets.insert(widget)
        } else {
            enabledWidgets.remove(widget)
        }
    }

    func isEnabled(_ widget: HomeWidgetType) -> Bool {
        enabledWidgets.contains(widget)
    }

    func sizeFor(_ widget: HomeWidgetType) -> WidgetSize {
        widgetSizes[widget] ?? .standard
    }

    mutating func setSize(_ size: WidgetSize, for widget: HomeWidgetType) {
        widgetSizes[widget] = size
    }
}
