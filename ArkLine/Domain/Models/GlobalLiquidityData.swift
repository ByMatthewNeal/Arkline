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

// MARK: - Net Liquidity Changes
/// US Net Liquidity = Fed Balance Sheet (WALCL) - TGA (WTREGEN) - RRP (RRPONTSYD)
/// The #1 short-term driver of crypto and risk asset prices
struct NetLiquidityChanges: Codable {
    let current: Double                  // Current net liquidity in USD
    let weeklyChange: Double             // 7-day change %
    let monthlyChange: Double            // 30-day change %
    let yearlyChange: Double             // 365-day change %
    let history: [GlobalLiquidityData]   // Historical data points

    /// Formatted current value
    var formattedCurrent: String {
        if current >= 1_000_000_000_000 {
            return String(format: "$%.2fT", current / 1_000_000_000_000)
        }
        return String(format: "$%.0fB", current / 1_000_000_000)
    }

    /// Overall trend signal based on weekly change
    var overallSignal: MarketSignal {
        if weeklyChange > 0.5 { return .bullish }
        if weeklyChange < -0.5 { return .bearish }
        return .neutral
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

// MARK: - Global Liquidity Index (BIS + FRED Composite)
/// Server-side composite index combining 10+ central bank balance sheets (BIS)
/// with US Net Liquidity (FRED). Updated daily by sync-global-liquidity edge function.

struct GlobalLiquidityIndex: Codable {
    let period: String                       // e.g. "2025-12"
    let compositeLiquidityT: Double          // Total in trillions USD
    let usNetLiquidityT: Double              // US net liquidity in trillions
    let fedAssetsT: Double                   // Fed balance sheet in trillions
    let tgaT: Double                         // Treasury General Account in trillions
    let rrpT: Double                         // Reverse Repo in trillions
    let bisTotalB: Double                    // BIS non-US total in billions
    let signal: String                       // "expanding", "contracting", "neutral"
    let changes: LiquidityChanges
    let liquidityCycle: LiquidityCycle?      // Cycle phase, momentum, yield curve
    let history: [LiquidityPeriod]
    let countryLatest: [String: CountryData]

    enum CodingKeys: String, CodingKey {
        case period
        case compositeLiquidityT = "composite_liquidity_t"
        case usNetLiquidityT = "us_net_liquidity_t"
        case fedAssetsT = "fed_assets_t"
        case tgaT = "tga_t"
        case rrpT = "rrp_t"
        case bisTotalB = "bis_total_b"
        case signal, changes, history
        case liquidityCycle = "liquidity_cycle"
        case countryLatest = "country_latest"
    }

    struct LiquidityChanges: Codable {
        let monthly: Double?
        let quarterly: Double?
        let semiannual: Double?
        let annual: Double?
    }

    struct LiquidityPeriod: Codable {
        let period: String
        let usNetLiquidityT: Double
        let bisTotalT: Double
        let compositeT: Double
        let breakdown: [String: Double]

        enum CodingKeys: String, CodingKey {
            case period
            case usNetLiquidityT = "us_net_liquidity_t"
            case bisTotalT = "bis_total_t"
            case compositeT = "composite_t"
            case breakdown
        }
    }

    struct CountryData: Codable {
        let name: String
        let valueB: Double

        enum CodingKeys: String, CodingKey {
            case name
            case valueB = "value_b"
        }
    }

    // MARK: - Computed Helpers

    var formattedComposite: String {
        String(format: "$%.1fT", compositeLiquidityT)
    }

    var formattedUSNetLiquidity: String {
        String(format: "$%.2fT", usNetLiquidityT)
    }

    var overallSignal: MarketSignal {
        switch signal {
        case "expanding": return .bullish
        case "contracting": return .bearish
        default: return .neutral
        }
    }

    /// Monthly change percentage
    var monthlyChange: Double {
        changes.monthly ?? 0
    }

    /// Annual change percentage
    var annualChange: Double {
        changes.annual ?? 0
    }

    /// Top central banks sorted by size
    var topCentralBanks: [(code: String, name: String, valueB: Double)] {
        countryLatest
            .map { (code: $0.key, name: $0.value.name, valueB: $0.value.valueB) }
            .sorted { $0.valueB > $1.valueB }
    }
}

// MARK: - Liquidity Cycle Data
/// Computed by sync-global-liquidity edge function: momentum, phase, yield curve, 65-month wave

struct LiquidityCycle: Codable {
    let momentumIndex: Int              // 0-100 percentile rank of 3M rate of change
    let momentum3m: Double?             // 3-month rate of change %
    let momentum6m: Double?             // 6-month rate of change %
    let acceleration: Double            // Change in 3M momentum (second derivative)
    let theoreticalWave: Double         // 0-100, 65-month sine wave position
    let cyclePhase: String              // "early_expansion", "late_expansion", "early_contraction", "late_contraction"
    let cycleAngleDegrees: Double       // 0-360 degrees on the clock
    let monthsSinceTrough: Int
    let cryptoGuidance: String
    let equityGuidance: String?
    let traditionalFavored: String
    let yieldCurve: YieldCurveData

    enum CodingKeys: String, CodingKey {
        case momentumIndex = "momentum_index"
        case momentum3m = "momentum_3m"
        case momentum6m = "momentum_6m"
        case acceleration
        case theoreticalWave = "theoretical_wave"
        case cyclePhase = "cycle_phase"
        case cycleAngleDegrees = "cycle_angle_degrees"
        case monthsSinceTrough = "months_since_trough"
        case cryptoGuidance = "crypto_guidance"
        case equityGuidance = "equity_guidance"
        case traditionalFavored = "traditional_favored"
        case yieldCurve = "yield_curve"
    }

    /// Parsed cycle phase
    var phase: LiquidityCyclePhase {
        LiquidityCyclePhase(rawValue: cyclePhase) ?? .earlyExpansion
    }
}

// MARK: - Cycle Phase

enum LiquidityCyclePhase: String, CaseIterable {
    case earlyExpansion = "early_expansion"
    case lateExpansion = "late_expansion"
    case earlyContraction = "early_contraction"
    case lateContraction = "late_contraction"

    var displayName: String {
        switch self {
        case .earlyExpansion: return "Early Expansion"
        case .lateExpansion: return "Late Expansion"
        case .earlyContraction: return "Early Contraction"
        case .lateContraction: return "Late Contraction"
        }
    }

    var shortLabel: String {
        switch self {
        case .earlyExpansion: return "Recovery"
        case .lateExpansion: return "Peak"
        case .earlyContraction: return "Slowdown"
        case .lateContraction: return "Trough"
        }
    }

    var cryptoLabel: String {
        switch self {
        case .earlyExpansion: return "BTC Accumulation"
        case .lateExpansion: return "Alt Season"
        case .earlyContraction: return "Rotate to Stables"
        case .lateContraction: return "DCA Opportunity"
        }
    }

    var equityLabel: String {
        switch self {
        case .earlyExpansion: return "Cyclical Growth"
        case .lateExpansion: return "Rotate to Value"
        case .earlyContraction: return "Defensive Sectors"
        case .lateContraction: return "Quality & Dividends"
        }
    }

    var defaultEquityGuidance: String {
        switch self {
        case .earlyExpansion:
            return "Favor cyclical growth — tech, discretionary, financials. Earnings growth accelerating as liquidity expands."
        case .lateExpansion:
            return "Rotate from growth to value — energy, materials, industrials. Valuations stretched on growth names."
        case .earlyContraction:
            return "Defensive sectors — utilities, healthcare, consumer staples. Trim broad equity exposure, raise cash."
        case .lateContraction:
            return "Quality dividends and long-duration bonds. Equity valuations resetting — begin building watchlists."
        }
    }

    var traditionalLabel: String {
        switch self {
        case .earlyExpansion: return "Bonds → Equities"
        case .lateExpansion: return "Equities → Commodities"
        case .earlyContraction: return "Cash & Defensive"
        case .lateContraction: return "Long Bonds"
        }
    }

    var color: Color {
        switch self {
        case .earlyExpansion: return AppColors.success
        case .lateExpansion: return AppColors.warning
        case .earlyContraction: return AppColors.error
        case .lateContraction: return Color(hex: "3B82F6")
        }
    }

    var icon: String {
        switch self {
        case .earlyExpansion: return "arrow.up.right"
        case .lateExpansion: return "arrow.up"
        case .earlyContraction: return "arrow.down.right"
        case .lateContraction: return "arrow.down"
        }
    }

    /// Clock position in degrees (0 = bottom/trough, 90 = left/equities, 180 = top/peak, 270 = right/cash)
    var clockStartAngle: Double {
        switch self {
        case .earlyExpansion: return 0
        case .lateExpansion: return 90
        case .earlyContraction: return 180
        case .lateContraction: return 270
        }
    }
}

// MARK: - Yield Curve Data

struct YieldCurveData: Codable {
    let t10y2y: Double?
    let t10y2y1mAgo: Double?
    let t10y3m: Double?
    let regime: String

    enum CodingKeys: String, CodingKey {
        case t10y2y
        case t10y2y1mAgo = "t10y2y_1m_ago"
        case t10y3m
        case regime
    }

    var parsedRegime: YieldCurveRegime {
        YieldCurveRegime(rawValue: regime) ?? .unknown
    }
}

enum YieldCurveRegime: String, CaseIterable {
    case steepening
    case flattening
    case inverted
    case uninverting
    case deeplyInverted = "deeply_inverted"
    case stable
    case unknown

    var displayName: String {
        switch self {
        case .steepening: return "Steepening"
        case .flattening: return "Flattening"
        case .inverted: return "Inverted"
        case .uninverting: return "Un-inverting"
        case .deeplyInverted: return "Deeply Inverted"
        case .stable: return "Stable"
        case .unknown: return "—"
        }
    }

    var color: Color {
        switch self {
        case .steepening: return AppColors.success       // Early cycle, bullish
        case .stable: return AppColors.warning
        case .flattening: return AppColors.warning        // Late cycle
        case .uninverting: return AppColors.error          // Often precedes recession
        case .inverted, .deeplyInverted: return AppColors.error
        case .unknown: return AppColors.textSecondary
        }
    }

    var interpretation: String {
        switch self {
        case .steepening: return "Early cycle signal — historically bullish for risk assets"
        case .flattening: return "Late cycle signal — Fed tightening, caution warranted"
        case .inverted: return "Recession warning — historically bearish, precedes downturns by 6-18 months"
        case .uninverting: return "Curve normalizing — often the final stage before recession begins"
        case .deeplyInverted: return "Strong recession signal — defensive positioning recommended"
        case .stable: return "Neutral yield curve conditions"
        case .unknown: return "Yield curve data unavailable"
        }
    }
}

// MARK: - Fed Data Series
/// FRED API series IDs for liquidity and FX data
enum FREDSeries: String {
    // M2 Money Supply
    case m2 = "M2SL"                    // US M2 Money Stock (Billions, Monthly)
    case m2Weekly = "WM2NS"             // US M2 Weekly

    // Other Fed series
    case fedBalance = "WALCL"           // Fed Total Assets (Millions, Weekly Wed)
    case tga = "WTREGEN"               // Treasury General Account (Millions, Weekly Wed)
    case rrp = "RRPONTSYD"             // Reverse Repo (Billions, Daily)
    case federalFundsRate = "FEDFUNDS"  // Federal Funds Rate

    // FX Rates (used for Global M2 aggregation)
    case fxCNYUSD = "DEXCHUS"           // CNY per USD
    case fxEURUSD = "DEXUSEU"           // USD per EUR
    case fxJPYUSD = "DEXJPUS"           // JPY per USD
    case fxGBPUSD = "DEXUSUK"           // USD per GBP

    var name: String {
        switch self {
        case .m2: return "US M2 Money Supply"
        case .m2Weekly: return "M2 Weekly"
        case .fedBalance: return "Fed Balance Sheet"
        case .tga: return "Treasury General Account"
        case .rrp: return "Reverse Repo"
        case .federalFundsRate: return "Federal Funds Rate"
        case .fxCNYUSD: return "CNY/USD Exchange Rate"
        case .fxEURUSD: return "EUR/USD Exchange Rate"
        case .fxJPYUSD: return "JPY/USD Exchange Rate"
        case .fxGBPUSD: return "GBP/USD Exchange Rate"
        }
    }
}
