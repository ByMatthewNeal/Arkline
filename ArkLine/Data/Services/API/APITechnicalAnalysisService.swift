import Foundation

// MARK: - API Technical Analysis Service
/// Taapi.io implementation of TechnicalAnalysisServiceProtocol
final class APITechnicalAnalysisService: TechnicalAnalysisServiceProtocol {
    // MARK: - Dependencies
    private let networkManager: NetworkManager

    // MARK: - Configuration
    private let defaultExchange = "binance"

    // MARK: - Initialization
    init(networkManager: NetworkManager = .shared) {
        self.networkManager = networkManager
    }

    // MARK: - TechnicalAnalysisServiceProtocol

    func fetchTechnicalAnalysis(symbol: String, exchange: String, interval: AnalysisTimeframe = .daily) async throws -> TechnicalAnalysis {
        // Fetch all data concurrently using bulk endpoint for efficiency
        let indicators: [TaapiIndicator] = [
            // SMAs
            TaapiIndicator(id: "sma21", indicator: "sma", period: 21),
            TaapiIndicator(id: "sma50", indicator: "sma", period: 50),
            TaapiIndicator(id: "sma200", indicator: "sma", period: 200),
            // Bollinger Bands
            TaapiIndicator(id: "bbands", indicator: "bbands", period: 20, stddev: 2),
            // RSI
            TaapiIndicator(id: "rsi", indicator: "rsi", period: 14),
            // Price
            TaapiIndicator(id: "price", indicator: "price")
        ]

        let endpoint = TaapiEndpoint.bulk(
            exchange: exchange,
            symbol: symbol,
            interval: interval.rawValue,
            indicators: indicators
        )

        let bulkResponse: TaapiBulkResponse = try await networkManager.request(endpoint)

        // Parse results into a dictionary for easy access
        var results: [String: TaapiIndicatorValue] = [:]
        for item in bulkResponse.data {
            results[item.id] = item.result
        }

        // Get current price
        let currentPrice = results["price"]?.value ?? 0

        // Build SMA Analysis
        let sma21Value = results["sma21"]?.value ?? 0
        let sma50Value = results["sma50"]?.value ?? 0
        let sma200Value = results["sma200"]?.value ?? 0

        let smaAnalysis = SMAAnalysis(
            sma21: SMAData(
                period: 21,
                value: sma21Value,
                priceAbove: currentPrice > sma21Value,
                percentFromPrice: calculatePercentDiff(price: currentPrice, sma: sma21Value)
            ),
            sma50: SMAData(
                period: 50,
                value: sma50Value,
                priceAbove: currentPrice > sma50Value,
                percentFromPrice: calculatePercentDiff(price: currentPrice, sma: sma50Value)
            ),
            sma200: SMAData(
                period: 200,
                value: sma200Value,
                priceAbove: currentPrice > sma200Value,
                percentFromPrice: calculatePercentDiff(price: currentPrice, sma: sma200Value)
            )
        )

        // Build Bollinger Bands for the selected timeframe
        let primaryBB = buildBollingerData(
            from: results["bbands"],
            timeframe: interval.bollingerTimeframe,
            currentPrice: currentPrice
        )

        // For the BollingerBandAnalysis structure, we set the selected timeframe's data
        // and estimate the others based on the primary
        let dailyBB: BollingerBandData
        let weeklyBB: BollingerBandData
        let monthlyBB: BollingerBandData

        switch interval {
        case .daily:
            dailyBB = primaryBB
            weeklyBB = estimateBollingerData(from: primaryBB, timeframe: .weekly, currentPrice: currentPrice)
            monthlyBB = estimateBollingerData(from: primaryBB, timeframe: .monthly, currentPrice: currentPrice)
        case .weekly:
            dailyBB = estimateBollingerData(from: primaryBB, timeframe: .daily, currentPrice: currentPrice)
            weeklyBB = primaryBB
            monthlyBB = estimateBollingerData(from: primaryBB, timeframe: .monthly, currentPrice: currentPrice)
        case .monthly:
            dailyBB = estimateBollingerData(from: primaryBB, timeframe: .daily, currentPrice: currentPrice)
            weeklyBB = estimateBollingerData(from: primaryBB, timeframe: .weekly, currentPrice: currentPrice)
            monthlyBB = primaryBB
        }

        let bollingerBands = BollingerBandAnalysis(
            daily: dailyBB,
            weekly: weeklyBB,
            monthly: monthlyBB
        )

        // Determine trend from SMAs and price position
        let trend = determineTrend(
            currentPrice: currentPrice,
            sma21: sma21Value,
            sma50: sma50Value,
            sma200: sma200Value
        )

        // Determine sentiment from RSI and trend
        let rsiValue = results["rsi"]?.value ?? 50
        let sentiment = determineSentiment(
            rsi: rsiValue,
            trend: trend,
            smaAnalysis: smaAnalysis
        )

        // Create RSI data
        let rsi = RSIData(value: rsiValue, period: 14)

        // Fetch Bull Market Support Bands (weekly data)
        let bullMarketBands = await fetchBullMarketSupportBands(
            symbol: symbol,
            exchange: exchange,
            currentPrice: currentPrice
        )

        // Extract asset info from symbol
        let assetSymbol = symbol.split(separator: "/").first.map(String.init) ?? symbol

        return TechnicalAnalysis(
            assetId: assetSymbol.lowercased(),
            assetSymbol: assetSymbol,
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

    /// Fetches weekly candle data and calculates the 20-week SMA and 21-week EMA
    private func fetchBullMarketSupportBands(symbol: String, exchange: String, currentPrice: Double) async -> BullMarketSupportBands {
        do {
            // Convert symbol format: "BTC/USDT" -> "BTCUSDT" for Binance
            let binanceSymbol = symbol.replacingOccurrences(of: "/", with: "")

            // Fetch 25 weekly candles (need 21 for EMA calculation)
            let endpoint = BinanceEndpoint.klines(symbol: binanceSymbol, interval: "1w", limit: 25)

            // Binance returns array of arrays
            let data = try await networkManager.requestData(endpoint: endpoint)
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[Any]] else {
                throw AppError.invalidData
            }

            // Parse klines
            let klines = jsonArray.compactMap { BinanceKline(from: $0) }
            guard klines.count >= 21 else {
                throw AppError.invalidData
            }

            // Get closing prices (excluding the current incomplete candle)
            let closingPrices = klines.dropLast().map { $0.close }

            // Calculate 20-week SMA (average of last 20 closes)
            let sma20Week = calculateSMA(prices: Array(closingPrices.suffix(20)))

            // Calculate 21-week EMA
            let ema21Week = calculateEMA(prices: Array(closingPrices.suffix(21)), period: 21)

            return BullMarketSupportBands(
                sma20Week: sma20Week,
                ema21Week: ema21Week,
                currentPrice: currentPrice
            )
        } catch {
            // Fallback: estimate based on current price if API fails
            print("Bull Market Bands fetch error: \(error)")
            return BullMarketSupportBands(
                sma20Week: currentPrice * 0.95,
                ema21Week: currentPrice * 0.94,
                currentPrice: currentPrice
            )
        }
    }

    /// Calculate Simple Moving Average
    private func calculateSMA(prices: [Double]) -> Double {
        guard !prices.isEmpty else { return 0 }
        return prices.reduce(0, +) / Double(prices.count)
    }

    /// Calculate Exponential Moving Average
    private func calculateEMA(prices: [Double], period: Int) -> Double {
        guard !prices.isEmpty else { return 0 }
        let multiplier = 2.0 / Double(period + 1)
        var ema = prices[0] // Start with first price as initial EMA

        for i in 1..<prices.count {
            ema = (prices[i] - ema) * multiplier + ema
        }

        return ema
    }

    func fetchSMAValues(symbol: String, exchange: String, periods: [Int], interval: String) async throws -> [Int: Double] {
        var results: [Int: Double] = [:]

        // Fetch all SMAs concurrently
        try await withThrowingTaskGroup(of: (Int, Double).self) { group in
            for period in periods {
                group.addTask {
                    let endpoint = TaapiEndpoint.sma(
                        exchange: exchange,
                        symbol: symbol,
                        interval: interval,
                        period: period
                    )
                    let response: TaapiSMAResponse = try await self.networkManager.request(endpoint)
                    return (period, response.value)
                }
            }

            for try await (period, value) in group {
                results[period] = value
            }
        }

        return results
    }

    func fetchBollingerBands(symbol: String, exchange: String, interval: String) async throws -> BollingerBandData {
        let endpoint = TaapiEndpoint.bbands(
            exchange: exchange,
            symbol: symbol,
            interval: interval,
            period: 20
        )

        let response: TaapiBBandsResponse = try await networkManager.request(endpoint)

        // Get current price for position calculation
        let currentPrice = try await fetchCurrentPrice(symbol: symbol, exchange: exchange)

        let timeframe: BollingerTimeframe
        switch interval {
        case "1w":
            timeframe = .weekly
        case "1M":
            timeframe = .monthly
        default:
            timeframe = .daily
        }

        return BollingerBandData(
            timeframe: timeframe,
            upperBand: response.valueUpperBand,
            middleBand: response.valueMiddleBand,
            lowerBand: response.valueLowerBand,
            currentPrice: currentPrice,
            bandwidth: (response.valueUpperBand - response.valueLowerBand) / response.valueMiddleBand,
            position: determineBollingerPosition(
                price: currentPrice,
                upper: response.valueUpperBand,
                lower: response.valueLowerBand
            )
        )
    }

    func fetchCurrentPrice(symbol: String, exchange: String) async throws -> Double {
        let endpoint = TaapiEndpoint.price(
            exchange: exchange,
            symbol: symbol,
            interval: "1d"
        )

        let response: TaapiPriceResponse = try await networkManager.request(endpoint)
        return response.value
    }

    func fetchRSI(symbol: String, exchange: String, interval: String, period: Int) async throws -> Double {
        let endpoint = TaapiEndpoint.rsi(
            exchange: exchange,
            symbol: symbol,
            interval: interval,
            period: period
        )

        let response: TaapiRSIResponse = try await networkManager.request(endpoint)
        return response.value
    }

    // MARK: - Private Helpers

    private func calculatePercentDiff(price: Double, sma: Double) -> Double {
        guard sma != 0 else { return 0 }
        return ((price - sma) / sma) * 100
    }

    private func buildBollingerData(
        from result: TaapiIndicatorValue?,
        timeframe: BollingerTimeframe,
        currentPrice: Double
    ) -> BollingerBandData {
        guard let result = result,
              let upper = result.valueUpperBand,
              let middle = result.valueMiddleBand,
              let lower = result.valueLowerBand else {
            // Return default values if no data
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

        return BollingerBandData(
            timeframe: timeframe,
            upperBand: upper,
            middleBand: middle,
            lowerBand: lower,
            currentPrice: currentPrice,
            bandwidth: (upper - lower) / middle,
            position: determineBollingerPosition(price: currentPrice, upper: upper, lower: lower)
        )
    }

    private func estimateBollingerData(
        from daily: BollingerBandData,
        timeframe: BollingerTimeframe,
        currentPrice: Double
    ) -> BollingerBandData {
        // Estimate wider bands for longer timeframes
        let multiplier: Double
        switch timeframe {
        case .daily:
            multiplier = 1.0
        case .weekly:
            multiplier = 1.5
        case .monthly:
            multiplier = 2.0
        }

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

    private func determineBollingerPosition(price: Double, upper: Double, lower: Double) -> BollingerPosition {
        let range = upper - lower
        guard range > 0 else { return .middle }

        let percentB = (price - lower) / range

        if percentB > 1.0 {
            return .aboveUpper
        } else if percentB > 0.8 {
            return .nearUpper
        } else if percentB > 0.2 {
            return .middle
        } else if percentB > 0 {
            return .nearLower
        } else {
            return .belowLower
        }
    }

    private func determineTrend(
        currentPrice: Double,
        sma21: Double,
        sma50: Double,
        sma200: Double
    ) -> TrendAnalysis {
        // Count how many SMAs price is above
        let aboveCount = [
            currentPrice > sma21,
            currentPrice > sma50,
            currentPrice > sma200
        ].filter { $0 }.count

        // Check for higher highs/lows pattern (simplified)
        let higherHighs = currentPrice > sma21 && sma21 > sma50
        let higherLows = sma50 > sma200

        // Determine direction
        let direction: AssetTrendDirection
        let strength: TrendStrength

        if aboveCount == 3 && higherHighs && higherLows {
            direction = .strongUptrend
            strength = .strong
        } else if aboveCount >= 2 && higherHighs {
            direction = .uptrend
            strength = aboveCount == 3 ? .strong : .moderate
        } else if aboveCount == 0 && !higherHighs && !higherLows {
            direction = .strongDowntrend
            strength = .strong
        } else if aboveCount <= 1 && !higherHighs {
            direction = .downtrend
            strength = aboveCount == 0 ? .strong : .moderate
        } else {
            direction = .sideways
            strength = .weak
        }

        // Estimate days in trend (simplified - would need historical data for accuracy)
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
        // Determine overall sentiment from RSI and trend
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

        // Short term based on RSI
        let shortTerm: AssetSentiment
        if rsi > 70 {
            shortTerm = .stronglyBullish
        } else if rsi > 55 {
            shortTerm = .bullish
        } else if rsi < 30 {
            shortTerm = .stronglyBearish
        } else if rsi < 45 {
            shortTerm = .bearish
        } else {
            shortTerm = .neutral
        }

        // Long term based on SMA 200
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

        // Volume trend (would need volume data - using placeholder)
        let volumeTrend: VolumeTrend = trend.strength == .strong ? .increasing : .stable

        return MarketSentimentAnalysis(
            overall: overall,
            shortTerm: shortTerm,
            longTerm: longTerm,
            volumeTrend: volumeTrend
        )
    }
}
