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
    let timestamp: Date

    /// Overall technical score (0-100)
    var technicalScore: Int {
        var score = 50

        // Trend contribution (+/- 15)
        switch trend.direction {
        case .strongUptrend: score += 15
        case .uptrend: score += 8
        case .sideways: score += 0
        case .downtrend: score -= 8
        case .strongDowntrend: score -= 15
        }

        // SMA contribution (+/- 20)
        if smaAnalysis.above21SMA { score += 5 }
        if smaAnalysis.above50SMA { score += 7 }
        if smaAnalysis.above200SMA { score += 8 }

        // Bollinger contribution (+/- 15)
        switch bollingerBands.daily.position {
        case .aboveUpper: score -= 5 // Overbought
        case .nearUpper: score += 0
        case .middle: score += 5
        case .nearLower: score += 8
        case .belowLower: score += 10 // Oversold (potential buy)
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
        case .downtrend: return Color(hex: "F97316")
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
        case .bearish: return Color(hex: "F97316")
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
        case .bearish: return Color(hex: "F97316")
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

        return TechnicalAnalysis(
            assetId: asset.id,
            assetSymbol: asset.symbol,
            currentPrice: asset.currentPrice,
            trend: trend,
            smaAnalysis: smaAnalysis,
            bollingerBands: bollingerBands,
            sentiment: sentiment,
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
