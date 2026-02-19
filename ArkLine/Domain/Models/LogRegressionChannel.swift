import Foundation
import SwiftUI

// MARK: - Index Symbol

enum IndexSymbol: String, CaseIterable, Identifiable {
    case sp500 = "^GSPC"
    case nasdaq = "^IXIC"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sp500: return "S&P 500"
        case .nasdaq: return "Nasdaq"
        }
    }
}

// MARK: - Time Range

enum TrendChannelTimeRange: String, CaseIterable, Identifiable {
    case fourHour = "4H"
    case daily = "1D"
    case weekly = "1W"
    case monthly = "1M"

    var id: String { rawValue }

    /// Yahoo Finance API interval parameter
    var yahooInterval: String {
        switch self {
        case .fourHour: return "60m"
        case .daily: return "1d"
        case .weekly: return "1wk"
        case .monthly: return "1mo"
        }
    }

    /// Yahoo Finance API range parameter
    var yahooRange: String {
        switch self {
        case .fourHour: return "60d"
        case .daily: return "2y"
        case .weekly: return "10y"
        case .monthly: return "max"
        }
    }

    /// Number of bars in one year for annualized growth rate calculation
    var barsPerYear: Double {
        switch self {
        case .fourHour: return 504    // ~2 four-hour bars per trading day × 252
        case .daily: return 252
        case .weekly: return 52
        case .monthly: return 12
        }
    }

    /// Whether this timeframe needs hourly aggregation into 4H candles
    var needsAggregation: Bool {
        self == .fourHour
    }
}

// MARK: - OHLC Bar (generic price bar for chart calculations)

struct OHLCBar {
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
}

// MARK: - Trend Channel Zone

enum TrendChannelZone: String {
    case deepValue = "Deep Value"
    case value = "Value"
    case fair = "Fair Value"
    case elevated = "Elevated"
    case overextended = "Overextended"

    var color: Color {
        switch self {
        case .deepValue: return AppColors.success
        case .value: return Color(hex: "84CC16")
        case .fair: return AppColors.warning
        case .elevated: return Color(hex: "F97316")
        case .overextended: return AppColors.error
        }
    }

    var signal: String {
        switch self {
        case .deepValue: return "Strong buy zone"
        case .value: return "Accumulation zone"
        case .fair: return "Fairly valued"
        case .elevated: return "Caution zone"
        case .overextended: return "Overextended"
        }
    }
}

// MARK: - Log Regression Channel Data

struct LogRegressionChannelData {
    let points: [LogRegressionPoint]
    let slope: Double
    let intercept: Double
    let rSquared: Double
    let standardDeviation: Double
    let currentZone: TrendChannelZone
    let annualizedGrowthRate: Double
}

struct LogRegressionPoint: Identifiable {
    let id = UUID()
    let date: Date
    let close: Double
    let fittedPrice: Double
    let upperBand: Double
    let lowerBand: Double
    let upperMid: Double
    let lowerMid: Double
    let zone: TrendChannelZone
}

// MARK: - RSI Series

struct RSISeriesPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - RSI Divergence

enum DivergenceType: String {
    case bullish = "Bullish"
    case bearish = "Bearish"

    var color: Color {
        switch self {
        case .bullish: return AppColors.success
        case .bearish: return AppColors.error
        }
    }

    var icon: String {
        switch self {
        case .bullish: return "arrow.up.right"
        case .bearish: return "arrow.down.right"
        }
    }
}

struct RSIDivergence: Identifiable {
    let id = UUID()
    let type: DivergenceType
    let startDate: Date
    let endDate: Date
    let priceStart: Double
    let priceEnd: Double
    let rsiStart: Double
    let rsiEnd: Double
}

// MARK: - Consolidation Range

struct ConsolidationRange: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    let highPrice: Double
    let lowPrice: Double
}
