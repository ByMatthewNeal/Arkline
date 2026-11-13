import Foundation

// MARK: - Market Widget Type
/// Represents the different widgets that can be displayed on the Market Overview tab
enum MarketWidgetType: String, CaseIterable, Codable, Identifiable, Hashable {
    case usFutures = "us_futures"
    case dailyNews = "daily_news"
    case fedWatch = "fed_watch"
    case allocation = "allocation"
    case traditionalMarkets = "traditional_markets"
    case topCoins = "top_coins"
    case sentiment = "sentiment"
    case altcoinScreener = "altcoin_screener"
    case swingSetups = "swing_setups"
    case globalLiquidity = "global_liquidity"
    case liquidityCycle = "liquidity_cycle"
    case cycleScorecard = "cycle_scorecard"
    case qpsGrid = "qps_grid"
    case marketBreadth = "market_breadth"
    case mindset = "mindset"
    case metalsSupportResistance = "metals_support_resistance"
    case liquidationHeatmap = "liquidation_heatmap"
    case spotDerivativesFlows = "spot_derivatives_flows"
    case derivativesPositioning = "derivatives_positioning"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .usFutures: return "US Futures"
        case .dailyNews: return "Daily News"
        case .fedWatch: return "Fed Watch"
        case .allocation: return "Crypto Positioning"
        case .traditionalMarkets: return "Traditional Markets"
        case .topCoins: return "Top Coins"
        case .sentiment: return "Market Sentiment"
        case .altcoinScreener: return "Altcoin Screener"
        case .swingSetups: return "Trade Signals"
        case .globalLiquidity: return "Global Liquidity"
        case .liquidityCycle: return "Liquidity Cycle"
        case .cycleScorecard: return "Cycle Scorecard"
        case .qpsGrid: return "Daily Positioning"
        case .marketBreadth: return "Market Breadth"
        case .mindset: return "Mindset"
        case .metalsSupportResistance: return "Metals S/R"
        case .liquidationHeatmap: return "Liquidation Heatmap"
        case .spotDerivativesFlows: return "Spot vs Derivatives"
        case .derivativesPositioning: return "Derivatives"
        }
    }

    var description: String {
        switch self {
        case .usFutures: return "S&P 500, Dow, and NASDAQ futures with session indicator"
        case .dailyNews: return "Latest crypto and market news"
        case .fedWatch: return "Fed interest rate probability from CME"
        case .allocation: return "Crypto positioning with macro context"
        case .traditionalMarkets: return "Stock indexes and precious metals"
        case .topCoins: return "Browse top cryptocurrencies by market cap"
        case .sentiment: return "Market sentiment indicators summary"
        case .altcoinScreener: return "Altcoin 30-day return screener"
        case .swingSetups: return "Multi-timeframe Fibonacci trade signals"
        case .globalLiquidity: return "Central bank liquidity across 10+ economies"
        case .liquidityCycle: return "65-month liquidity cycle with crypto positioning"
        case .cycleScorecard: return "Top vs bottom confluence read for BTC, ETH and SOL"
        case .qpsGrid: return "Daily bullish/neutral/bearish signals for 8 assets"
        case .marketBreadth: return "% of tokens in uptrend with EMA trend analysis"
        case .mindset: return "A calm daily psychology reminder and the mental-game trail"
        case .metalsSupportResistance: return "Support and resistance levels for gold and silver"
        case .liquidationHeatmap: return "Estimated liquidation clusters above and below price"
        case .spotDerivativesFlows: return "Spot CVD vs open interest and funding, so you can see if moves are spot or leverage led"
        case .derivativesPositioning: return "Perpetual premium and funding rate positioning"
        }
    }

    var icon: String {
        switch self {
        case .usFutures: return "chart.line.uptrend.xyaxis"
        case .dailyNews: return "newspaper"
        case .fedWatch: return "building.columns"
        case .allocation: return "chart.pie"
        case .traditionalMarkets: return "chart.line.uptrend.xyaxis"
        case .topCoins: return "bitcoinsign.circle"
        case .sentiment: return "gauge.with.dots.needle.33percent"
        case .altcoinScreener: return "list.bullet.rectangle"
        case .swingSetups: return "scope"
        case .globalLiquidity: return "banknote"
        case .liquidityCycle: return "clock.arrow.2.circlepath"
        case .cycleScorecard: return "checklist"
        case .qpsGrid: return "waveform.path.ecg"
        case .marketBreadth: return "chart.bar.xaxis"
        case .mindset: return "book.closed"
        case .metalsSupportResistance: return "ruler"
        case .liquidationHeatmap: return "flame"
        case .spotDerivativesFlows: return "arrow.left.arrow.right"
        case .derivativesPositioning: return "building.columns"
        }
    }

    /// Default order for Market widgets (matches original hardcoded layout)
    static var defaultOrder: [MarketWidgetType] {
        [.usFutures, .qpsGrid, .cycleScorecard, .mindset, .liquidityCycle, .globalLiquidity, .dailyNews, .fedWatch, .allocation, .traditionalMarkets, .metalsSupportResistance, .liquidationHeatmap, .spotDerivativesFlows, .derivativesPositioning, .topCoins, .sentiment, .marketBreadth, .swingSetups, .altcoinScreener]
    }

    /// Widgets enabled by default — a lean starter set covering futures, sentiment,
    /// macro (Liquidity Cycle), Fed, coins, news, and trade signals. The remaining
    /// sections stay one toggle away in Customize Market.
    /// Note: users who installed before Market customization shipped keep the
    /// all-widgets layout via a one-time migration in `AppState.loadState()`.
    static var defaultEnabled: Set<MarketWidgetType> {
        [.usFutures, .sentiment, .cycleScorecard, .mindset, .fedWatch, .topCoins, .dailyNews, .swingSetups, .metalsSupportResistance, .liquidationHeatmap, .spotDerivativesFlows, .derivativesPositioning]
    }

    /// Sections hidden app-wide regardless of a user's saved config. The enum
    /// case, section view, and detail screen all stay intact — this just stops
    /// them rendering, so reviving one is a one-line change (remove it here).
    /// `.allocation` = the retired "Crypto Positioning" screen.
    /// `.liquidityCycle` = parked; the data pipeline and views remain, just hidden.
    static let hidden: Set<MarketWidgetType> = [.allocation, .liquidityCycle]
}

// MARK: - Market Zone
/// Groups Market widgets into scannable zones for the sticky chip filter on Market Overview.
/// "All" shows every enabled widget in the user's order (and is the only mode where reordering is allowed).
enum MarketZone: String, CaseIterable, Identifiable {
    case all
    case today
    case macro
    case assets
    case signals
    case psychology

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All"
        case .today: return "Today"
        case .macro: return "Macro"
        case .assets: return "Assets"
        case .signals: return "Signals"
        case .psychology: return "Psychology"
        }
    }
}

extension MarketWidgetType {
    /// Which zone chip this widget belongs to.
    var zone: MarketZone {
        switch self {
        case .usFutures, .sentiment, .fedWatch, .dailyNews:
            return .today
        case .qpsGrid, .cycleScorecard, .liquidityCycle, .globalLiquidity, .allocation:
            return .macro
        case .topCoins, .traditionalMarkets, .marketBreadth, .altcoinScreener, .metalsSupportResistance, .liquidationHeatmap, .spotDerivativesFlows, .derivativesPositioning:
            return .assets
        case .swingSetups:
            return .signals
        case .mindset:
            return .psychology
        }
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
        widgetOrder.filter { enabledWidgets.contains($0) && !MarketWidgetType.hidden.contains($0) }
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
