import SwiftUI

// MARK: - Global Liquidity Data
/// Represents global liquidity data (primarily M2 money supply)
/// Used to track liquidity changes that affect crypto markets
struct GlobalLiquidityData: Codable, Identifiable {
    let date: Date
    let value: Double           // Current M2 value in trillions USD
    let previousValue: Double   // Previous period value

    var id: Date { date }

    /// Change in value
    var change: Double {
        value - previousValue
    }

    /// Percentage change
    var changePercent: Double {
        guard previousValue > 0 else { return 0 }
        return ((value - previousValue) / previousValue) * 100
    }

    /// Is liquidity increasing?
    var isIncreasing: Bool {
        change > 0
    }

    /// Market signal based on liquidity trend
    var signal: MarketSignal {
        if changePercent > 0.5 {
            return .bullish  // Rising liquidity is bullish for risk assets
        } else if changePercent < -0.5 {
            return .bearish  // Falling liquidity is bearish
        } else {
            return .neutral
        }
    }

    /// Formatted value in trillions
    var formattedValue: String {
        String(format: "$%.2fT", value / 1_000_000_000_000)
    }

    /// Formatted change
    var formattedChange: String {
        let prefix = change >= 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.1f", changePercent))%"
    }
}

// MARK: - Liquidity Changes
/// Container for multi-timeframe liquidity changes
struct GlobalLiquidityChanges: Codable {
    let current: Double                  // Current M2 value
    let dailyChange: Double?             // 1-day change %
    let weeklyChange: Double             // 7-day change %
    let monthlyChange: Double            // 30-day change %
    let yearlyChange: Double             // 365-day change %
    let history: [GlobalLiquidityData]   // Historical data points

    // MARK: - Dollar Change Amounts
    /// Daily change in dollars
    var dailyChangeDollars: Double? {
        guard let daily = dailyChange else { return nil }
        return current * (daily / 100)
    }

    /// Weekly change in dollars
    var weeklyChangeDollars: Double {
        current * (weeklyChange / 100)
    }

    /// Monthly change in dollars
    var monthlyChangeDollars: Double {
        current * (monthlyChange / 100)
    }

    /// Yearly change in dollars
    var yearlyChangeDollars: Double {
        current * (yearlyChange / 100)
    }

    /// Format dollar amount in billions
    func formatDollars(_ amount: Double) -> String {
        let absAmount = abs(amount)
        let prefix = amount >= 0 ? "+" : "-"
        if absAmount >= 1_000_000_000_000 {
            return "\(prefix)$\(String(format: "%.2f", absAmount / 1_000_000_000_000))T"
        } else if absAmount >= 1_000_000_000 {
            return "\(prefix)$\(String(format: "%.1f", absAmount / 1_000_000_000))B"
        } else {
            return "\(prefix)$\(String(format: "%.0f", absAmount / 1_000_000))M"
        }
    }

    /// Overall trend signal
    var overallSignal: MarketSignal {
        // Weight longer-term trends more heavily
        let weightedChange = (weeklyChange * 0.2) + (monthlyChange * 0.3) + (yearlyChange * 0.5)

        if weightedChange > 1.0 {
            return .bullish
        } else if weightedChange < -1.0 {
            return .bearish
        } else {
            return .neutral
        }
    }

    /// Trend description
    var trendDescription: String {
        switch overallSignal {
        case .bullish:
            return "Liquidity Expansion"
        case .bearish:
            return "Liquidity Contraction"
        case .neutral:
            return "Stable Liquidity"
        }
    }

    /// Color for UI
    var signalColor: Color {
        switch overallSignal {
        case .bullish:
            return Color(hex: "22C55E")
        case .bearish:
            return Color(hex: "EF4444")
        case .neutral:
            return Color(hex: "F59E0B")
        }
    }

    /// Formatted current value
    var formattedCurrent: String {
        String(format: "$%.2fT", current / 1_000_000_000_000)
    }
}

// MARK: - Liquidity Timeframe
enum LiquidityTimeframe: String, CaseIterable {
    case daily = "1D"
    case weekly = "1W"
    case monthly = "1M"
    case yearly = "1Y"

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }

    var description: String {
        switch self {
        case .daily: return "24-hour change"
        case .weekly: return "7-day change"
        case .monthly: return "30-day change"
        case .yearly: return "Year-over-year"
        }
    }
}

// MARK: - Fed Data Series
/// FRED API series IDs for liquidity data
enum FREDSeries: String {
    case m2 = "M2SL"                    // M2 Money Stock
    case m2Weekly = "WM2NS"             // M2 Weekly
    case fedBalance = "WALCL"           // Fed Total Assets
    case federalFundsRate = "FEDFUNDS"  // Federal Funds Rate

    var name: String {
        switch self {
        case .m2: return "M2 Money Supply"
        case .m2Weekly: return "M2 Weekly"
        case .fedBalance: return "Fed Balance Sheet"
        case .federalFundsRate: return "Federal Funds Rate"
        }
    }
}
