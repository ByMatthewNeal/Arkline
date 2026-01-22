import Foundation
import SwiftUI

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
    case upcomingEvents = "upcoming_events"
    case riskScore = "risk_score"
    case fearGreedIndex = "fear_greed"
    case marketMovers = "market_movers"
    case dcaReminders = "dca_reminders"
    case favorites = "favorites"
    // Market widgets (from Market tab)
    case fedWatch = "fed_watch"
    case dailyNews = "daily_news"
    case marketSentiment = "market_sentiment"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .upcomingEvents: return "Upcoming Events"
        case .riskScore: return "ArkLine Risk Score"
        case .fearGreedIndex: return "Fear & Greed Index"
        case .marketMovers: return "Market Movers"
        case .dcaReminders: return "DCA Reminders"
        case .favorites: return "Favorites"
        case .fedWatch: return "Fed Watch"
        case .dailyNews: return "Daily News"
        case .marketSentiment: return "Market Sentiment"
        }
    }

    var description: String {
        switch self {
        case .upcomingEvents: return "Economic calendar events that may impact markets"
        case .riskScore: return "Composite risk score based on multiple indicators"
        case .fearGreedIndex: return "Market sentiment gauge from 0-100"
        case .marketMovers: return "BTC and ETH price movements"
        case .dcaReminders: return "Your dollar-cost averaging reminders"
        case .favorites: return "Your favorite assets at a glance"
        case .fedWatch: return "Fed interest rate probability from CME"
        case .dailyNews: return "Latest crypto and market news"
        case .marketSentiment: return "Retail & institutional sentiment indicators"
        }
    }

    var icon: String {
        switch self {
        case .upcomingEvents: return "calendar.badge.clock"
        case .riskScore: return "gauge.with.dots.needle.33percent"
        case .fearGreedIndex: return "speedometer"
        case .marketMovers: return "chart.line.uptrend.xyaxis"
        case .dcaReminders: return "bell.badge"
        case .favorites: return "star.fill"
        case .fedWatch: return "building.columns"
        case .dailyNews: return "newspaper"
        case .marketSentiment: return "waveform.path.ecg"
        }
    }

    var accentColor: Color {
        // Simplified: All widgets use the primary accent color for consistency
        return AppColors.accent
    }

    /// Default order for widgets
    static var defaultOrder: [HomeWidgetType] {
        [.upcomingEvents, .riskScore, .fearGreedIndex, .marketMovers, .fedWatch, .dailyNews, .marketSentiment, .dcaReminders, .favorites]
    }

    /// Widgets enabled by default
    static var defaultEnabled: Set<HomeWidgetType> {
        Set([.upcomingEvents, .riskScore, .fearGreedIndex, .marketMovers, .dcaReminders])
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
         widgetSizes: [HomeWidgetType: WidgetSize] = [:]) {
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
