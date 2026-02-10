import Foundation

enum PremiumFeature: String, CaseIterable {
    case allCoinRisk
    case technicalAnalysis
    case broadcasts
    case unlimitedDCA
    case riskBasedDCA
    case advancedPortfolio
    case portfolioShowcase
    case macroDetail
    case customNews
    case premiumWidgets
    case exportData
    case fedWatchDetail

    var title: String {
        switch self {
        case .allCoinRisk: return "All Coin Risk Levels"
        case .technicalAnalysis: return "Technical Analysis"
        case .broadcasts: return "Market Broadcasts"
        case .unlimitedDCA: return "Unlimited DCA Reminders"
        case .riskBasedDCA: return "Risk-Based DCA"
        case .advancedPortfolio: return "Advanced Analytics"
        case .portfolioShowcase: return "Portfolio Showcase"
        case .macroDetail: return "Macro Dashboard"
        case .customNews: return "Custom News Topics"
        case .premiumWidgets: return "Premium Widgets"
        case .exportData: return "Export Data"
        case .fedWatchDetail: return "Fed Watch Detail"
        }
    }

    var description: String {
        switch self {
        case .allCoinRisk:
            return "Track risk levels for ETH, SOL, BNB, and more — not just BTC."
        case .technicalAnalysis:
            return "RSI, Bollinger Bands, moving averages, trend scores, and multi-timeframe analysis."
        case .broadcasts:
            return "Get market updates and analysis delivered directly from ArkLine."
        case .unlimitedDCA:
            return "Create unlimited DCA reminders to stay on top of your investment schedule."
        case .riskBasedDCA:
            return "Automatically trigger DCA buys when asset risk levels drop."
        case .advancedPortfolio:
            return "Sharpe ratio, Sortino ratio, equity curves, and detailed performance metrics."
        case .portfolioShowcase:
            return "Compare portfolios side-by-side with privacy controls and exports."
        case .macroDetail:
            return "Deep dives into VIX, DXY, Global M2, and macro regime analysis."
        case .customNews:
            return "Add custom keywords and topics to personalize your news feed."
        case .premiumWidgets:
            return "Unlock all home screen widgets including risk score, macro, and more."
        case .exportData:
            return "Export your portfolio data as PDF, CSV, or JSON."
        case .fedWatchDetail:
            return "Detailed Fed interest rate probabilities and meeting schedules."
        }
    }

    var icon: String {
        switch self {
        case .allCoinRisk: return "chart.bar.fill"
        case .technicalAnalysis: return "waveform.path.ecg"
        case .broadcasts: return "megaphone.fill"
        case .unlimitedDCA: return "calendar.badge.plus"
        case .riskBasedDCA: return "gauge.with.needle.fill"
        case .advancedPortfolio: return "chart.line.uptrend.xyaxis"
        case .portfolioShowcase: return "rectangle.on.rectangle"
        case .macroDetail: return "globe.americas.fill"
        case .customNews: return "newspaper.fill"
        case .premiumWidgets: return "square.grid.2x2.fill"
        case .exportData: return "square.and.arrow.up.fill"
        case .fedWatchDetail: return "building.columns.fill"
        }
    }
}
