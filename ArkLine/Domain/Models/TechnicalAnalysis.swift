import Foundation
import SwiftUI

// MARK: - Technical Analysis
/// Technical analysis data for an asset including trend, SMAs, and Bollinger Bands
struct TechnicalAnalysis: Equatable {
    let assetId: String
    let assetSymbol: String
    let currentPrice: Double
    let trend: TrendAnalysis
    let smaAnalysis: SMAAnalysis
    let bollingerBands: BollingerBandAnalysis
    let sentiment: MarketSentimentAnalysis
    let rsi: RSIData
    let bullMarketBands: BullMarketSupportBands
    let timestamp: Date
    /// Algorithmic support/resistance levels (crypto only; nil when unavailable).
    var keyLevels: KeyLevels? = nil

    /// Trend Score (0-100) - measures price direction and momentum
    /// Higher = more bullish trend, Lower = more bearish trend
    var trendScore: Int {
        var score = 50

        // Trend direction is the primary factor (+/- 20)
        switch trend.direction {
        case .strongUptrend: score += 20
        case .uptrend: score += 10
        case .sideways: score += 0
        case .downtrend: score -= 10
        case .strongDowntrend: score -= 20
        }

        // SMA position confirms trend (+/- 12)
        if smaAnalysis.above21SMA { score += 4 } else { score -= 4 }
        if smaAnalysis.above50SMA { score += 4 } else { score -= 4 }
        if smaAnalysis.above200SMA { score += 4 } else { score -= 4 }

        // Bull Market Support Bands (+/- 8)
        switch bullMarketBands.position {
        case .aboveBoth: score += 8
        case .inBand: score += 2
        case .belowBoth: score -= 8
        }

        return max(0, min(100, score))
    }

    /// Opportunity Score (0-100) - measures if it's a good entry point
    /// Higher = better buying opportunity (oversold), Lower = overbought/risky entry
    var opportunityScore: Int {
        var score = 50

        // RSI is primary factor (+/- 30)
        switch rsi.value {
        case 0..<20:
            score += 30  // Extremely oversold - great opportunity
        case 20..<30:
            score += 20  // Oversold - good opportunity
        case 30..<40:
            score += 10  // Approaching oversold
        case 40..<60:
            score += 0   // Neutral
        case 60..<70:
            score -= 10  // Approaching overbought
        case 70..<80:
            score -= 20  // Overbought - risky entry
        default:
            score -= 30  // Extremely overbought - avoid
        }

        // Bollinger position confirms opportunity (+/- 20)
        switch bollingerBands.daily.position {
        case .belowLower: score += 20  // Oversold - opportunity
        case .nearLower: score += 10
        case .middle: score += 0
        case .nearUpper: score -= 10
        case .aboveUpper: score -= 20  // Overbought - risky
        }

        return max(0, min(100, score))
    }
}

// MARK: - Trend Analysis
struct TrendAnalysis: Equatable {
    let direction: AssetTrendDirection
    let strength: TrendStrength
    let daysInTrend: Int
    let higherHighs: Bool
    let higherLows: Bool

    var description: String {
        switch direction {
        case .strongUptrend: return "Strong Uptrend"
        case .uptrend: return "Uptrend"
        case .sideways: return "Sideways"
        case .downtrend: return "Downtrend"
        case .strongDowntrend: return "Strong Downtrend"
        }
    }
}

enum AssetTrendDirection: String, Equatable {
    case strongUptrend = "Strong Uptrend"
    case uptrend = "Uptrend"
    case sideways = "Sideways"
    case downtrend = "Downtrend"
    case strongDowntrend = "Strong Downtrend"

    var icon: String {
        switch self {
        case .strongUptrend: return "arrow.up.circle.fill"
        case .uptrend: return "arrow.up.right.circle.fill"
        case .sideways: return "arrow.left.arrow.right.circle.fill"
        case .downtrend: return "arrow.down.right.circle.fill"
        case .strongDowntrend: return "arrow.down.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .strongUptrend: return AppColors.success
        case .uptrend: return Color(hex: "84CC16")
        case .sideways: return AppColors.warning
        case .downtrend: return AppColors.error
        case .strongDowntrend: return AppColors.error
        }
    }

    var shortLabel: String {
        switch self {
        case .strongUptrend: return "Strong Up"
        case .uptrend: return "Up"
        case .sideways: return "Sideways"
        case .downtrend: return "Down"
        case .strongDowntrend: return "Strong Down"
        }
    }
}

enum TrendStrength: String, Equatable {
    case strong = "Strong"
    case moderate = "Moderate"
    case weak = "Weak"

    var level: Int {
        switch self {
        case .strong: return 3
        case .moderate: return 2
        case .weak: return 1
        }
    }
}

// MARK: - SMA Analysis
struct SMAAnalysis: Equatable {
    let sma21: SMAData
    let sma50: SMAData
    let sma200: SMAData

    var above21SMA: Bool { sma21.priceAbove }
    var above50SMA: Bool { sma50.priceAbove }
    var above200SMA: Bool { sma200.priceAbove }

    var goldenCross: Bool {
        // 50 SMA above 200 SMA
        sma50.value > sma200.value
    }

    var deathCross: Bool {
        // 50 SMA below 200 SMA
        sma50.value < sma200.value
    }

    var overallSignal: SMASignal {
        let aboveCount = [above21SMA, above50SMA, above200SMA].filter { $0 }.count
        switch aboveCount {
        case 3: return .strongBullish
        case 2: return .bullish
        case 1: return .mixed
        case 0: return .bearish
        default: return .mixed
        }
    }
}

struct SMAData: Equatable {
    let period: Int
    let value: Double
    let priceAbove: Bool
    let percentFromPrice: Double

    var displayValue: String {
        value.asCryptoPrice
    }

    var distanceLabel: String {
        let sign = percentFromPrice >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", percentFromPrice))%"
    }
}

enum SMASignal: String {
    case strongBullish = "Strong Bullish"
    case bullish = "Bullish"
    case mixed = "Mixed"
    case bearish = "Bearish"
    case strongBearish = "Strong Bearish"

    var color: Color {
        switch self {
        case .strongBullish: return AppColors.success
        case .bullish: return Color(hex: "84CC16")
        case .mixed: return AppColors.warning
        case .bearish: return AppColors.error
        case .strongBearish: return AppColors.error
        }
    }

    var icon: String {
        switch self {
        case .strongBullish: return "arrow.up.circle.fill"
        case .bullish: return "arrow.up.right.circle.fill"
        case .mixed: return "minus.circle.fill"
        case .bearish: return "arrow.down.right.circle.fill"
        case .strongBearish: return "arrow.down.circle.fill"
        }
    }
}

// MARK: - Bollinger Bands Analysis
struct BollingerBandAnalysis: Equatable {
    let daily: BollingerBandData
    let weekly: BollingerBandData
    let monthly: BollingerBandData
}

struct BollingerBandData: Equatable {
    let timeframe: BollingerTimeframe
    let upperBand: Double
    let middleBand: Double // 20 SMA
    let lowerBand: Double
    let currentPrice: Double
    let bandwidth: Double // Volatility measure
    let position: BollingerPosition

    var percentB: Double {
        // %B = (Price - Lower Band) / (Upper Band - Lower Band)
        guard upperBand != lowerBand else { return 0.5 }
        return (currentPrice - lowerBand) / (upperBand - lowerBand)
    }
}

enum BollingerTimeframe: String, Equatable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"

    var shortLabel: String {
        switch self {
        case .daily: return "1D"
        case .weekly: return "1W"
        case .monthly: return "1M"
        }
    }
}

enum BollingerPosition: String, Equatable {
    case aboveUpper = "Above Upper"
    case nearUpper = "Near Upper"
    case middle = "Middle"
    case nearLower = "Near Lower"
    case belowLower = "Below Lower"

    var description: String {
        switch self {
        case .aboveUpper: return "Overbought"
        case .nearUpper: return "Upper Band"
        case .middle: return "Mid Band"
        case .nearLower: return "Lower Band"
        case .belowLower: return "Oversold"
        }
    }

    var signal: String {
        switch self {
        case .aboveUpper: return "Potential reversal down"
        case .nearUpper: return "Resistance area"
        case .middle: return "Fair value zone"
        case .nearLower: return "Support area"
        case .belowLower: return "Potential reversal up"
        }
    }

    var color: Color {
        switch self {
        case .aboveUpper: return AppColors.error
        case .nearUpper: return Color(hex: "F97316")
        case .middle: return AppColors.warning
        case .nearLower: return Color(hex: "84CC16")
        case .belowLower: return AppColors.success
        }
    }

    var icon: String {
        switch self {
        case .aboveUpper: return "exclamationmark.triangle.fill"
        case .nearUpper: return "arrow.up.to.line"
        case .middle: return "equal.circle.fill"
        case .nearLower: return "arrow.down.to.line"
        case .belowLower: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Market Sentiment Analysis
struct MarketSentimentAnalysis: Equatable {
    let overall: AssetSentiment
    let shortTerm: AssetSentiment
    let longTerm: AssetSentiment
    let volumeTrend: VolumeTrend
}

enum AssetSentiment: String, Equatable {
    case stronglyBullish = "Strongly Bullish"
    case bullish = "Bullish"
    case neutral = "Neutral"
    case bearish = "Bearish"
    case stronglyBearish = "Strongly Bearish"

    var color: Color {
        switch self {
        case .stronglyBullish: return AppColors.success
        case .bullish: return Color(hex: "84CC16")
        case .neutral: return AppColors.warning
        case .bearish: return AppColors.error
        case .stronglyBearish: return AppColors.error
        }
    }

    var icon: String {
        switch self {
        case .stronglyBullish: return "flame.fill"
        case .bullish: return "arrow.up.right"
        case .neutral: return "minus"
        case .bearish: return "arrow.down.right"
        case .stronglyBearish: return "snow"
        }
    }
}

enum VolumeTrend: String, Equatable {
    case increasing = "Increasing"
    case stable = "Stable"
    case decreasing = "Decreasing"

    var icon: String {
        switch self {
        case .increasing: return "chart.bar.fill"
        case .stable: return "chart.bar"
        case .decreasing: return "chart.bar"
        }
    }
}

// MARK: - RSI Data
struct RSIData: Equatable {
    let value: Double // 0-100
    let period: Int   // typically 14

    var zone: RSIZone {
        switch value {
        case 0..<30: return .oversold
        case 30..<45: return .weak
        case 45..<55: return .neutral
        case 55..<70: return .strong
        default: return .overbought
        }
    }

    var displayValue: String {
        String(format: "%.1f", value)
    }
}

enum RSIZone: String {
    case oversold = "Oversold"
    case weak = "Weak"
    case neutral = "Neutral"
    case strong = "Strong"
    case overbought = "Overbought"

    var color: Color {
        switch self {
        case .oversold: return AppColors.success
        case .weak: return Color(hex: "84CC16")
        case .neutral: return AppColors.warning
        case .strong: return Color(hex: "F97316")
        case .overbought: return AppColors.error
        }
    }

    var description: String {
        switch self {
        case .oversold: return "Potential buy signal"
        case .weak: return "Momentum weakening"
        case .neutral: return "No clear signal"
        case .strong: return "Momentum building"
        case .overbought: return "Potential sell signal"
        }
    }
}

// MARK: - Bull Market Support Bands
/// 20-week SMA and 21-week EMA used as support during bull markets
struct BullMarketSupportBands: Equatable {
    let sma20Week: Double   // 20-week SMA
    let ema21Week: Double   // 21-week EMA
    let currentPrice: Double

    var aboveSMA: Bool { currentPrice > sma20Week }
    var aboveEMA: Bool { currentPrice > ema21Week }

    var position: BMSBPosition {
        if aboveSMA && aboveEMA {
            return .aboveBoth
        } else if !aboveSMA && !aboveEMA {
            return .belowBoth
        } else {
            return .inBand
        }
    }

    var percentFromSMA: Double {
        guard sma20Week != 0 else { return 0 }
        return ((currentPrice - sma20Week) / sma20Week) * 100
    }

    var percentFromEMA: Double {
        guard ema21Week != 0 else { return 0 }
        return ((currentPrice - ema21Week) / ema21Week) * 100
    }
}

enum BMSBPosition: String {
    case aboveBoth = "Above Support"
    case inBand = "Testing Support"
    case belowBoth = "Below Support"

    var color: Color {
        switch self {
        case .aboveBoth: return AppColors.success
        case .inBand: return AppColors.warning
        case .belowBoth: return AppColors.error
        }
    }

    var icon: String {
        switch self {
        case .aboveBoth: return "checkmark.circle.fill"
        case .inBand: return "minus.circle.fill"
        case .belowBoth: return "xmark.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .aboveBoth: return "Healthy bull market structure"
        case .inBand: return "Testing key support levels"
        case .belowBoth: return "Bull market support lost"
        }
    }
}

// MARK: - Mock Technical Analysis Generator
enum TechnicalAnalysisGenerator {
    /// Generates mock technical analysis for an asset based on its price change
    static func generate(for asset: CryptoAsset) -> TechnicalAnalysis {
        let isPositive = asset.priceChangePercentage24h >= 0
        let changeStrength = abs(asset.priceChangePercentage24h)

        // Determine trend based on price change
        let trendDirection: AssetTrendDirection
        if changeStrength > 5 {
            trendDirection = isPositive ? .strongUptrend : .strongDowntrend
        } else if changeStrength > 2 {
            trendDirection = isPositive ? .uptrend : .downtrend
        } else {
            trendDirection = .sideways
        }

        let trend = TrendAnalysis(
            direction: trendDirection,
            strength: changeStrength > 3 ? .strong : (changeStrength > 1 ? .moderate : .weak),
            daysInTrend: Int.random(in: 3...21),
            higherHighs: isPositive,
            higherLows: isPositive
        )

        // Generate SMA data
        let sma21Value = asset.currentPrice * (isPositive ? 0.97 : 1.03)
        let sma50Value = asset.currentPrice * (isPositive ? 0.92 : 1.08)
        let sma200Value = asset.currentPrice * (isPositive ? 0.85 : 1.15)

        let smaAnalysis = SMAAnalysis(
            sma21: SMAData(
                period: 21,
                value: sma21Value,
                priceAbove: asset.currentPrice > sma21Value,
                percentFromPrice: ((asset.currentPrice - sma21Value) / sma21Value) * 100
            ),
            sma50: SMAData(
                period: 50,
                value: sma50Value,
                priceAbove: asset.currentPrice > sma50Value,
                percentFromPrice: ((asset.currentPrice - sma50Value) / sma50Value) * 100
            ),
            sma200: SMAData(
                period: 200,
                value: sma200Value,
                priceAbove: asset.currentPrice > sma200Value,
                percentFromPrice: ((asset.currentPrice - sma200Value) / sma200Value) * 100
            )
        )

        // Generate Bollinger Bands
        let bollingerBands = BollingerBandAnalysis(
            daily: generateBollingerData(price: asset.currentPrice, timeframe: .daily, isPositive: isPositive),
            weekly: generateBollingerData(price: asset.currentPrice, timeframe: .weekly, isPositive: isPositive),
            monthly: generateBollingerData(price: asset.currentPrice, timeframe: .monthly, isPositive: isPositive)
        )

        // Generate sentiment
        let sentiment = MarketSentimentAnalysis(
            overall: isPositive ? (changeStrength > 3 ? .stronglyBullish : .bullish) : (changeStrength > 3 ? .stronglyBearish : .bearish),
            shortTerm: isPositive ? .bullish : .bearish,
            longTerm: .neutral,
            volumeTrend: changeStrength > 2 ? .increasing : .stable
        )

        // Generate RSI based on price change
        let rsiValue: Double
        if isPositive {
            rsiValue = 50 + (changeStrength * 4) // Higher RSI for positive change
        } else {
            rsiValue = 50 - (changeStrength * 4) // Lower RSI for negative change
        }
        let rsi = RSIData(value: min(100, max(0, rsiValue)), period: 14)

        // Generate Bull Market Support Bands
        let sma20Week = asset.currentPrice * (isPositive ? 0.90 : 1.10)
        let ema21Week = asset.currentPrice * (isPositive ? 0.88 : 1.12)
        let bullMarketBands = BullMarketSupportBands(
            sma20Week: sma20Week,
            ema21Week: ema21Week,
            currentPrice: asset.currentPrice
        )

        return TechnicalAnalysis(
            assetId: asset.id,
            assetSymbol: asset.symbol,
            currentPrice: asset.currentPrice,
            trend: trend,
            smaAnalysis: smaAnalysis,
            bollingerBands: bollingerBands,
            sentiment: sentiment,
            rsi: rsi,
            bullMarketBands: bullMarketBands,
            timestamp: Date()
        )
    }

    private static func generateBollingerData(price: Double, timeframe: BollingerTimeframe, isPositive: Bool) -> BollingerBandData {
        let volatility: Double
        switch timeframe {
        case .daily: volatility = 0.05
        case .weekly: volatility = 0.08
        case .monthly: volatility = 0.12
        }

        let middleBand = price * (isPositive ? 0.98 : 1.02)
        let upperBand = middleBand * (1 + volatility)
        let lowerBand = middleBand * (1 - volatility)

        let position: BollingerPosition
        let percentB = (price - lowerBand) / (upperBand - lowerBand)
        if percentB > 1.0 {
            position = .aboveUpper
        } else if percentB > 0.8 {
            position = .nearUpper
        } else if percentB > 0.2 {
            position = .middle
        } else if percentB > 0 {
            position = .nearLower
        } else {
            position = .belowLower
        }

        return BollingerBandData(
            timeframe: timeframe,
            upperBand: upperBand,
            middleBand: middleBand,
            lowerBand: lowerBand,
            currentPrice: price,
            bandwidth: (upperBand - lowerBand) / middleBand,
            position: position
        )
    }
}

// MARK: - Support & Resistance (Key Levels)

/// Whether a level sits below (support) or above (resistance) the current price.
enum LevelKind: Equatable { case support, resistance }

/// How much weight a level carries, from how often price reacted there and how
/// many methods flagged it. Presented as a plain word, never false precision.
enum LevelStrength: Int, Equatable, Comparable {
    case weak = 1, moderate = 2, strong = 3
    static func < (lhs: LevelStrength, rhs: LevelStrength) -> Bool { lhs.rawValue < rhs.rawValue }
    var label: String {
        switch self {
        case .weak: return "Weak"
        case .moderate: return "Moderate"
        case .strong: return "Strong"
        }
    }
}

/// A single algorithmic support or resistance level.
struct KeyLevel: Identifiable, Equatable {
    var id: Double { price }
    let price: Double
    let kind: LevelKind
    let strength: LevelStrength
    let touches: Int
}

/// A price point for the Key Levels mini chart.
struct SRPricePoint: Identifiable, Equatable {
    var id: TimeInterval { date.timeIntervalSince1970 }
    let date: Date
    let close: Double
}

/// The computed levels for an asset, nearest first, plus a recent price series
/// so the card can draw the levels on a small chart.
struct KeyLevels: Equatable {
    let currentPrice: Double
    let supports: [KeyLevel]     // closest below price first
    let resistances: [KeyLevel]  // closest above price first
    let series: [SRPricePoint]
    var hasLevels: Bool { !supports.isEmpty || !resistances.isEmpty }
}

/// Lightweight candle input for the calculator (keeps it free of any networking).
struct SRBar: Equatable {
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
}

/// Pure support/resistance calculator. Gathers candidate levels from swing
/// pivots, volume-profile nodes, range extremes and the 200-SMA, merges nearby
/// candidates into zones, scores each by touches + confluence, then returns the
/// nearest few supports and resistances relative to the current price.
enum SupportResistance {
    static func compute(
        bars: [SRBar],
        currentPrice: Double,
        sma200: Double?,
        maxPerSide: Int = 3
    ) -> (supports: [KeyLevel], resistances: [KeyLevel])? {
        guard bars.count >= 30, currentPrice > 0 else { return nil }
        let tol = currentPrice * 0.01        // 1% cluster / touch tolerance
        let atPrice = currentPrice * 0.003   // ignore anything basically at price

        var candidates: [Double] = []

        // 1. Swing pivots (a high with `w` lower highs on each side, and vice versa).
        let w = 4
        if bars.count > 2 * w {
            for i in w..<(bars.count - w) {
                let hi = bars[i].high
                let lo = bars[i].low
                var isPivotHigh = true
                var isPivotLow = true
                for j in (i - w)...(i + w) where j != i {
                    if bars[j].high > hi { isPivotHigh = false }
                    if bars[j].low < lo { isPivotLow = false }
                }
                if isPivotHigh { candidates.append(hi) }
                if isPivotLow { candidates.append(lo) }
            }
        }

        // Range extremes over the window.
        if let maxH = bars.map(\.high).max() { candidates.append(maxH) }
        if let minL = bars.map(\.low).min() { candidates.append(minL) }

        // 2. Volume-profile nodes: bucket closes, weight by volume, take the top shelves.
        let closes = bars.map(\.close)
        if let lo = closes.min(), let hi = closes.max(), hi > lo {
            let binCount = 40
            let binSize = (hi - lo) / Double(binCount)
            var bins = [Double](repeating: 0, count: binCount)
            for b in bars {
                let idx = min(binCount - 1, max(0, Int((b.close - lo) / binSize)))
                bins[idx] += b.volume
            }
            let topIdx = bins.enumerated().sorted { $0.element > $1.element }.prefix(3).map(\.offset)
            for idx in topIdx { candidates.append(lo + (Double(idx) + 0.5) * binSize) }
        }

        // 3. 200-SMA as a dynamic level.
        if let s = sma200, s > 0 { candidates.append(s) }

        guard !candidates.isEmpty else { return nil }

        // 4. Merge candidates within tolerance into zones.
        let sorted = candidates.sorted()
        var zones: [[Double]] = []
        for price in sorted {
            if let anchor = zones.last?.first, price - anchor <= tol {
                zones[zones.count - 1].append(price)
            } else {
                zones.append([price])
            }
        }

        // 5. Score each zone: touches (candles that reacted near it) + confluence.
        func touchCount(_ level: Double) -> Int {
            bars.reduce(0) { acc, b in
                acc + ((abs(b.high - level) <= tol || abs(b.low - level) <= tol) ? 1 : 0)
            }
        }
        func strength(touches: Int, members: Int) -> LevelStrength {
            let score = Double(touches) + Double(max(0, members - 1)) * 1.5
            if score >= 8 { return .strong }
            if score >= 4 { return .moderate }
            return .weak
        }

        var supports: [KeyLevel] = []
        var resistances: [KeyLevel] = []
        for grp in zones {
            let price = grp.reduce(0, +) / Double(grp.count)
            if abs(price - currentPrice) <= atPrice { continue }
            let level = KeyLevel(
                price: price,
                kind: price < currentPrice ? .support : .resistance,
                strength: strength(touches: touchCount(price), members: grp.count),
                touches: touchCount(price)
            )
            if level.kind == .support { supports.append(level) } else { resistances.append(level) }
        }

        supports.sort { $0.price > $1.price }      // closest below price first
        resistances.sort { $0.price < $1.price }   // closest above price first
        guard !supports.isEmpty || !resistances.isEmpty else { return nil }
        return (Array(supports.prefix(maxPerSide)), Array(resistances.prefix(maxPerSide)))
    }
}
