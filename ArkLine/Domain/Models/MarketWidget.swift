import Foundation

// MARK: - Market Widget Type
/// Represents the different widgets that can be displayed on the Market Overview tab
enum MarketWidgetType: String, CaseIterable, Codable, Identifiable, Hashable {
    case dailyNews = "daily_news"
    case fedWatch = "fed_watch"
    case allocation = "allocation"
    case traditionalMarkets = "traditional_markets"
    case topCoins = "top_coins"
    case sentiment = "sentiment"
    case altcoinScreener = "altcoin_screener"
    case swingSetups = "swing_setups"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dailyNews: return "Daily News"
        case .fedWatch: return "Fed Watch"
        case .allocation: return "Crypto Positioning"
        case .traditionalMarkets: return "Traditional Markets"
        case .topCoins: return "Top Coins"
        case .sentiment: return "Market Sentiment"
        case .altcoinScreener: return "Altcoin Screener"
        case .swingSetups: return "Swing Setups"
        }
    }

    var description: String {
        switch self {
        case .dailyNews: return "Latest crypto and market news"
        case .fedWatch: return "Fed interest rate probability from CME"
        case .allocation: return "Crypto positioning with macro context"
        case .traditionalMarkets: return "Stock indexes and precious metals"
        case .topCoins: return "Browse top cryptocurrencies by market cap"
        case .sentiment: return "Market sentiment indicators summary"
        case .altcoinScreener: return "Altcoin 30-day return screener"
        case .swingSetups: return "Multi-timeframe Fibonacci swing trade signals"
        }
    }

    var icon: String {
        switch self {
        case .dailyNews: return "newspaper"
        case .fedWatch: return "building.columns"
        case .allocation: return "chart.pie"
        case .traditionalMarkets: return "chart.line.uptrend.xyaxis"
        case .topCoins: return "bitcoinsign.circle"
        case .sentiment: return "gauge.with.dots.needle.33percent"
        case .altcoinScreener: return "list.bullet.rectangle"
        case .swingSetups: return "scope"
        }
    }

    /// Default order for Market widgets (matches original hardcoded layout)
    static var defaultOrder: [MarketWidgetType] {
        [.dailyNews, .fedWatch, .allocation, .traditionalMarkets, .topCoins, .sentiment, .swingSetups, .altcoinScreener]
    }

    /// All widgets enabled by default
    static var defaultEnabled: Set<MarketWidgetType> {
        Set(allCases)
    }
}

// MARK: - Market Widget Configuration
/// Stores user's Market tab widget preferences
struct MarketWidgetConfiguration: Codable, Equatable {
    var enabledWidgets: Set<MarketWidgetType>
    var widgetOrder: [MarketWidgetType]

    init(enabledWidgets: Set<MarketWidgetType> = MarketWidgetType.defaultEnabled,
         widgetOrder: [MarketWidgetType] = MarketWidgetType.defaultOrder) {
        self.enabledWidgets = enabledWidgets
        self.widgetOrder = widgetOrder
    }

    /// Returns ordered list of enabled widgets
    var orderedEnabledWidgets: [MarketWidgetType] {
        widgetOrder.filter { enabledWidgets.contains($0) }
    }

    mutating func toggleWidget(_ widget: MarketWidgetType) {
        if enabledWidgets.contains(widget) {
            enabledWidgets.remove(widget)
        } else {
            enabledWidgets.insert(widget)
        }
    }

    func isEnabled(_ widget: MarketWidgetType) -> Bool {
        enabledWidgets.contains(widget)
    }
}
