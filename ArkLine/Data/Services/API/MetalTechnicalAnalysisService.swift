import Foundation

// MARK: - Metal Technical Analysis Service
/// Computes technical analysis for precious metals using FMP historical price data.
/// Since TAAPI.io only supports crypto pairs, all indicators (RSI, SMA, Bollinger Bands)
/// are calculated locally from daily OHLCV data.
final class MetalTechnicalAnalysisService {

    static let shared = MetalTechnicalAnalysisService()
    private init() {}

    /// Map metal XAU/XAG symbols to FMP futures symbols
    static func futuresSymbol(for metalSymbol: String) -> String {
        switch metalSymbol.uppercased() {
        case "XAU": return "GCUSD"
        case "XAG": return "SIUSD"
        case "XPT": return "PLUSD"
        case "XPD": return "PAUSD"
        default: return "GCUSD"
        }
    }

    /// Fetch complete technical analysis for a metal
    func fetchTechnicalAnalysis(
        metalSymbol: String,
        currentPrice: Double
    ) async throws -> TechnicalAnalysis {
        let fmpSymbol = Self.futuresSymbol(for: metalSymbol)

        // Fetch enough daily data for 200 SMA + buffer
        let dailyPrices = try await FMPService.shared.fetchHistoricalPrices(
            symbol: fmpSymbol,
            limit: 250
        )

        guard dailyPrices.count >= 200 else {
            throw MetalTAError.insufficientData(
                available: dailyPrices.count,
                required: 200
            )
        }

        // FMP returns newest-first; reverse to oldest-first for calculations
        let closingPrices = dailyPrices.reversed().map(\.close)

        // Compute indicators
        let sma21 = computeSMA(prices: closingPrices, period: 21)
        let sma50 = computeSMA(prices: closingPrices, period: 50)
        let sma200 = computeSMA(prices: closingPrices, period: 200)
        let rsiValue = computeRSI(prices: closingPrices, period: 14)

        let dailyBB = computeBollingerBands(
            prices: closingPrices,
            period: 20,
            stddevMultiplier: 2.0,
            timeframe: .daily,
            currentPrice: currentPrice
        )

        // Build SMA analysis
        let smaAnalysis = SMAAnalysis(
            sma21: SMAData(
                period: 21,
                value: sma21,
                priceAbove: currentPrice > sma21,
                percentFromPrice: percentDiff(price: currentPrice, sma: sma21)
            ),
            sma50: SMAData(
                period: 50,
                value: sma50,
                priceAbove: currentPrice > sma50,
                percentFromPrice: percentDiff(price: currentPrice, sma: sma50)
            ),
            sma200: SMAData(
                period: 200,
                value: sma200,
                priceAbove: currentPrice > sma200,
                percentFromPrice: percentDiff(price: currentPrice, sma: sma200)
            )
        )

        // Determine trend
        let trend = determineTrend(
            currentPrice: currentPrice,
            sma21: sma21,
            sma50: sma50,
            sma200: sma200
        )

        // Bollinger Bands (estimate weekly/monthly from daily)
        let weeklyBB = estimateBollingerData(from: dailyBB, timeframe: .weekly, currentPrice: currentPrice)
        let monthlyBB = estimateBollingerData(from: dailyBB, timeframe: .monthly, currentPrice: currentPrice)

        let bollingerBands = BollingerBandAnalysis(
            daily: dailyBB,
            weekly: weeklyBB,
            monthly: monthlyBB
        )

        // RSI and sentiment
        let rsi = RSIData(value: rsiValue, period: 14)
        let sentiment = determineSentiment(rsi: rsiValue, trend: trend, smaAnalysis: smaAnalysis)

        // Bull Market Support Bands (20-week SMA, 21-week EMA from daily data)
        let bullMarketBands = computeBullMarketBands(
            closingPrices: closingPrices,
            currentPrice: currentPrice
        )

        return TechnicalAnalysis(
            assetId: metalSymbol.lowercased(),
            assetSymbol: metalSymbol.uppercased(),
            currentPrice: currentPrice,
            trend: trend,
            smaAnalysis: smaAnalysis,
            bollingerBands: bollingerBands,
            sentiment: sentiment,
            rsi: rsi,
            bullMarketBands: bullMarketBands,
            timestamp: Date()
        )
    }

    // MARK: - Indicator Computations

    /// Compute Simple Moving Average (prices oldest-first, returns latest SMA value)
    func computeSMA(prices: [Double], period: Int) -> Double {
        guard prices.count >= period else { return prices.last ?? 0 }
        let slice = prices.suffix(period)
        return slice.reduce(0, +) / Double(period)
    }

    /// Compute Exponential Moving Average
    func computeEMA(prices: [Double], period: Int) -> Double {
        guard !prices.isEmpty else { return 0 }
        let multiplier = 2.0 / Double(period + 1)
        var ema = prices[0]
        for i in 1..<prices.count {
            ema = (prices[i] - ema) * multiplier + ema
        }
        return ema
    }

    /// Compute RSI using Wilder's smoothing method
    func computeRSI(prices: [Double], period: Int) -> Double {
        guard prices.count > period else { return 50.0 }

        var gains: [Double] = []
        var losses: [Double] = []
        for i in 1..<prices.count {
            let change = prices[i] - prices[i - 1]
            gains.append(max(0, change))
            losses.append(max(0, -change))
        }

        guard gains.count >= period else { return 50.0 }

        // Initial average gain/loss
        var avgGain = gains.prefix(period).reduce(0, +) / Double(period)
        var avgLoss = losses.prefix(period).reduce(0, +) / Double(period)

        // Wilder's smoothing for remaining values
        for i in period..<gains.count {
            avgGain = (avgGain * Double(period - 1) + gains[i]) / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + losses[i]) / Double(period)
        }

        guard avgLoss > 0 else { return 100.0 }
        let rs = avgGain / avgLoss
        return 100.0 - (100.0 / (1.0 + rs))
    }

    /// Compute Bollinger Bands from closing prices
    func computeBollingerBands(
        prices: [Double],
        period: Int,
        stddevMultiplier: Double,
        timeframe: BollingerTimeframe,
        currentPrice: Double
    ) -> BollingerBandData {
        guard prices.count >= period else {
            return BollingerBandData(
                timeframe: timeframe,
                upperBand: currentPrice * 1.05,
                middleBand: currentPrice,
                lowerBand: currentPrice * 0.95,
                currentPrice: currentPrice,
                bandwidth: 0.1,
                position: .middle
            )
        }

        let recentPrices = Array(prices.suffix(period))
        let middleBand = recentPrices.reduce(0, +) / Double(period)

        let variance = recentPrices.reduce(0.0) { sum, price in
            sum + pow(price - middleBand, 2)
        } / Double(period)
        let stddev = sqrt(variance)

        let upperBand = middleBand + (stddevMultiplier * stddev)
        let lowerBand = middleBand - (stddevMultiplier * stddev)
        let bandwidth = (upperBand - lowerBand) / middleBand

        let position = determineBollingerPosition(price: currentPrice, upper: upperBand, lower: lowerBand)

        return BollingerBandData(
            timeframe: timeframe,
            upperBand: upperBand,
            middleBand: middleBand,
            lowerBand: lowerBand,
            currentPrice: currentPrice,
            bandwidth: bandwidth,
            position: position
        )
    }

    // MARK: - Private Helpers

    private func percentDiff(price: Double, sma: Double) -> Double {
        guard sma != 0 else { return 0 }
        return ((price - sma) / sma) * 100
    }

    private func determineBollingerPosition(price: Double, upper: Double, lower: Double) -> BollingerPosition {
        let range = upper - lower
        guard range > 0 else { return .middle }
        let percentB = (price - lower) / range
        if percentB > 1.0 { return .aboveUpper }
        else if percentB > 0.8 { return .nearUpper }
        else if percentB > 0.2 { return .middle }
        else if percentB > 0 { return .nearLower }
        else { return .belowLower }
    }

    private func estimateBollingerData(
        from daily: BollingerBandData,
        timeframe: BollingerTimeframe,
        currentPrice: Double
    ) -> BollingerBandData {
        // Wider bands for longer timeframes
        let multiplier: Double = timeframe == .weekly ? 1.5 : 2.0
        let bandWidth = (daily.upperBand - daily.lowerBand) * multiplier
        let middle = daily.middleBand
        let upper = middle + (bandWidth / 2)
        let lower = middle - (bandWidth / 2)
        return BollingerBandData(
            timeframe: timeframe,
            upperBand: upper,
            middleBand: middle,
            lowerBand: lower,
            currentPrice: currentPrice,
            bandwidth: bandWidth / middle,
            position: determineBollingerPosition(price: currentPrice, upper: upper, lower: lower)
        )
    }

    private func determineTrend(
        currentPrice: Double,
        sma21: Double,
        sma50: Double,
        sma200: Double
    ) -> TrendAnalysis {
        let aboveCount = [
            currentPrice > sma21,
            currentPrice > sma50,
            currentPrice > sma200
        ].filter { $0 }.count

        let higherHighs = currentPrice > sma21 && sma21 > sma50
        let higherLows = sma50 > sma200

        let direction: AssetTrendDirection
        let strength: TrendStrength

        if aboveCount == 3 && higherHighs && higherLows {
            direction = .strongUptrend; strength = .strong
        } else if aboveCount >= 2 && higherHighs {
            direction = .uptrend; strength = aboveCount == 3 ? .strong : .moderate
        } else if aboveCount == 0 && !higherHighs && !higherLows {
            direction = .strongDowntrend; strength = .strong
        } else if aboveCount <= 1 && !higherHighs {
            direction = .downtrend; strength = aboveCount == 0 ? .strong : .moderate
        } else {
            direction = .sideways; strength = .weak
        }

        let daysInTrend = strength == .strong ? 14 : (strength == .moderate ? 7 : 3)

        return TrendAnalysis(
            direction: direction,
            strength: strength,
            daysInTrend: daysInTrend,
            higherHighs: higherHighs,
            higherLows: higherLows
        )
    }

    private func determineSentiment(
        rsi: Double,
        trend: TrendAnalysis,
        smaAnalysis: SMAAnalysis
    ) -> MarketSentimentAnalysis {
        let overall: AssetSentiment
        if rsi > 70 && trend.direction == .strongUptrend {
            overall = .stronglyBullish
        } else if rsi > 60 || trend.direction == .uptrend {
            overall = .bullish
        } else if rsi < 30 && trend.direction == .strongDowntrend {
            overall = .stronglyBearish
        } else if rsi < 40 || trend.direction == .downtrend {
            overall = .bearish
        } else {
            overall = .neutral
        }

        let shortTerm: AssetSentiment
        if rsi > 70 { shortTerm = .stronglyBullish }
        else if rsi > 55 { shortTerm = .bullish }
        else if rsi < 30 { shortTerm = .stronglyBearish }
        else if rsi < 45 { shortTerm = .bearish }
        else { shortTerm = .neutral }

        let longTerm: AssetSentiment
        if smaAnalysis.above200SMA && smaAnalysis.goldenCross {
            longTerm = .stronglyBullish
        } else if smaAnalysis.above200SMA {
            longTerm = .bullish
        } else if !smaAnalysis.above200SMA && smaAnalysis.deathCross {
            longTerm = .stronglyBearish
        } else if !smaAnalysis.above200SMA {
            longTerm = .bearish
        } else {
            longTerm = .neutral
        }

        let volumeTrend: VolumeTrend = trend.strength == .strong ? .increasing : .stable

        return MarketSentimentAnalysis(
            overall: overall,
            shortTerm: shortTerm,
            longTerm: longTerm,
            volumeTrend: volumeTrend
        )
    }

    /// Compute Bull Market Support Bands from daily closing prices
    /// Approximates weekly candles by grouping every 5 trading days
    private func computeBullMarketBands(
        closingPrices: [Double],
        currentPrice: Double
    ) -> BullMarketSupportBands {
        var weeklyCloses: [Double] = []
        let step = 5
        var i = 0
        while i + step <= closingPrices.count {
            weeklyCloses.append(closingPrices[i + step - 1])
            i += step
        }

        guard weeklyCloses.count >= 21 else {
            return BullMarketSupportBands(
                sma20Week: currentPrice * 0.95,
                ema21Week: currentPrice * 0.94,
                currentPrice: currentPrice
            )
        }

        let sma20Week = computeSMA(prices: weeklyCloses, period: 20)
        let ema21Week = computeEMA(prices: Array(weeklyCloses.suffix(21)), period: 21)

        return BullMarketSupportBands(
            sma20Week: sma20Week,
            ema21Week: ema21Week,
            currentPrice: currentPrice
        )
    }
}

// MARK: - Metal TA Errors
enum MetalTAError: Error, LocalizedError {
    case insufficientData(available: Int, required: Int)

    var errorDescription: String? {
        switch self {
        case .insufficientData(let available, let required):
            return "Insufficient price data: \(available) days available, \(required) required"
        }
    }
}
