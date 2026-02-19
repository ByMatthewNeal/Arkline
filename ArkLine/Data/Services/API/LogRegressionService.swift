import Foundation

// MARK: - Log Regression Service
/// Pure math service for log regression channel, RSI, divergence, and consolidation calculations.
/// No network calls — operates on OHLCBar arrays.
final class LogRegressionService {

    static let shared = LogRegressionService()
    private init() {}

    // MARK: - Log Regression Channel

    func calculateLogRegressionChannel(bars: [OHLCBar], barsPerYear: Double = 252) -> LogRegressionChannelData? {
        let sorted = bars.sorted { $0.date < $1.date }
        guard sorted.count >= 20 else { return nil }

        let closes = sorted.map(\.close)
        let dates = sorted.map(\.date)

        // Log transform
        let logCloses = closes.map { log($0) }
        let n = Double(logCloses.count)
        let xs = (0..<logCloses.count).map { Double($0) }

        // Least squares: y = mx + b
        let sumX = xs.reduce(0, +)
        let sumY = logCloses.reduce(0, +)
        let sumXY = zip(xs, logCloses).reduce(0.0) { $0 + $1.0 * $1.1 }
        let sumX2 = xs.reduce(0.0) { $0 + $1 * $1 }

        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return nil }

        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n

        // Residuals and standard deviation
        let fitted = xs.map { slope * $0 + intercept }
        let residuals = zip(logCloses, fitted).map { $0 - $1 }
        let meanResidual = residuals.reduce(0, +) / n
        let variance = residuals.reduce(0.0) { $0 + ($1 - meanResidual) * ($1 - meanResidual) } / n
        let sigma = sqrt(variance)

        // R-squared
        let meanY = sumY / n
        let ssTotal = logCloses.reduce(0.0) { $0 + ($1 - meanY) * ($1 - meanY) }
        let ssResidual = residuals.reduce(0.0) { $0 + $1 * $1 }
        let rSquared = ssTotal > 0 ? 1.0 - (ssResidual / ssTotal) : 0

        // Annualized growth rate from slope
        let annualizedGrowth = exp(slope * barsPerYear) - 1.0

        // Build points
        var points: [LogRegressionPoint] = []
        for i in 0..<sorted.count {
            let fittedLog = fitted[i]
            let fittedPrice = exp(fittedLog)
            let upper = exp(fittedLog + 2 * sigma)
            let lower = exp(fittedLog - 2 * sigma)
            let upperMid = exp(fittedLog + sigma)
            let lowerMid = exp(fittedLog - sigma)
            let zone = classifyZone(price: closes[i], lower: lower, lowerMid: lowerMid, upperMid: upperMid, upper: upper)

            points.append(LogRegressionPoint(
                date: dates[i],
                close: closes[i],
                fittedPrice: fittedPrice,
                upperBand: upper,
                lowerBand: lower,
                upperMid: upperMid,
                lowerMid: lowerMid,
                zone: zone
            ))
        }

        let currentZone = points.last?.zone ?? .fair

        return LogRegressionChannelData(
            points: points,
            slope: slope,
            intercept: intercept,
            rSquared: rSquared,
            standardDeviation: sigma,
            currentZone: currentZone,
            annualizedGrowthRate: annualizedGrowth
        )
    }

    private func classifyZone(price: Double, lower: Double, lowerMid: Double, upperMid: Double, upper: Double) -> TrendChannelZone {
        if price <= lower { return .deepValue }
        if price <= lowerMid { return .value }
        if price <= upperMid { return .fair }
        if price <= upper { return .elevated }
        return .overextended
    }

    // MARK: - RSI Calculation (Wilder's Smoothed)

    func calculateRSISeries(bars: [OHLCBar], period: Int = 14) -> [RSISeriesPoint] {
        let sorted = bars.sorted { $0.date < $1.date }
        guard sorted.count > period else { return [] }

        let closes = sorted.map(\.close)
        let dates = sorted.map(\.date)

        var gains: [Double] = []
        var losses: [Double] = []

        for i in 1..<closes.count {
            let change = closes[i] - closes[i - 1]
            gains.append(max(change, 0))
            losses.append(max(-change, 0))
        }

        guard gains.count >= period else { return [] }

        var avgGain = gains[0..<period].reduce(0, +) / Double(period)
        var avgLoss = losses[0..<period].reduce(0, +) / Double(period)

        var rsiPoints: [RSISeriesPoint] = []

        for i in period..<gains.count {
            avgGain = (avgGain * Double(period - 1) + gains[i]) / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + losses[i]) / Double(period)

            let rsi: Double
            if avgLoss == 0 {
                rsi = 100
            } else {
                let rs = avgGain / avgLoss
                rsi = 100 - (100 / (1 + rs))
            }

            // gains[i] corresponds to dates[i+1]
            let dateIndex = i + 1
            if dateIndex < dates.count {
                rsiPoints.append(RSISeriesPoint(date: dates[dateIndex], value: rsi))
            }
        }

        return rsiPoints
    }

    // MARK: - Divergence Detection

    func detectDivergences(bars: [OHLCBar], rsiSeries: [RSISeriesPoint], lookback: Int = 5) -> [RSIDivergence] {
        let sorted = bars.sorted { $0.date < $1.date }
        guard sorted.count > lookback * 2, rsiSeries.count > lookback * 2 else { return [] }

        // Build RSI lookup by date string
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        var rsiByDate: [String: Double] = [:]
        for point in rsiSeries {
            rsiByDate[dateFormatter.string(from: point.date)] = point.value
        }
        // Also index by date-only for daily+ timeframes
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        for point in rsiSeries {
            rsiByDate[dayFormatter.string(from: point.date)] = point.value
        }

        let swingHighs = findSwingHighs(bars: sorted, lookback: lookback)
        let swingLows = findSwingLows(bars: sorted, lookback: lookback)

        var divergences: [RSIDivergence] = []

        // Bearish divergence: price higher high, RSI lower high
        for i in 1..<swingHighs.count {
            let prev = swingHighs[i - 1]
            let curr = swingHighs[i]
            let prevKey1 = dateFormatter.string(from: prev.date)
            let prevKey2 = dayFormatter.string(from: prev.date)
            let currKey1 = dateFormatter.string(from: curr.date)
            let currKey2 = dayFormatter.string(from: curr.date)
            let prevRSI = rsiByDate[prevKey1] ?? rsiByDate[prevKey2]
            let currRSI = rsiByDate[currKey1] ?? rsiByDate[currKey2]

            if let pRSI = prevRSI, let cRSI = currRSI,
               curr.price > prev.price, cRSI < pRSI, cRSI > 55 {
                let daysBetween = Calendar.current.dateComponents([.day], from: prev.date, to: curr.date).day ?? 0
                if daysBetween >= 3, daysBetween <= 365 {
                    divergences.append(RSIDivergence(
                        type: .bearish,
                        startDate: prev.date, endDate: curr.date,
                        priceStart: prev.price, priceEnd: curr.price,
                        rsiStart: pRSI, rsiEnd: cRSI
                    ))
                }
            }
        }

        // Bullish divergence: price lower low, RSI higher low
        for i in 1..<swingLows.count {
            let prev = swingLows[i - 1]
            let curr = swingLows[i]
            let prevKey1 = dateFormatter.string(from: prev.date)
            let prevKey2 = dayFormatter.string(from: prev.date)
            let currKey1 = dateFormatter.string(from: curr.date)
            let currKey2 = dayFormatter.string(from: curr.date)
            let prevRSI = rsiByDate[prevKey1] ?? rsiByDate[prevKey2]
            let currRSI = rsiByDate[currKey1] ?? rsiByDate[currKey2]

            if let pRSI = prevRSI, let cRSI = currRSI,
               curr.price < prev.price, cRSI > pRSI, cRSI < 45 {
                let daysBetween = Calendar.current.dateComponents([.day], from: prev.date, to: curr.date).day ?? 0
                if daysBetween >= 3, daysBetween <= 365 {
                    divergences.append(RSIDivergence(
                        type: .bullish,
                        startDate: prev.date, endDate: curr.date,
                        priceStart: prev.price, priceEnd: curr.price,
                        rsiStart: pRSI, rsiEnd: cRSI
                    ))
                }
            }
        }

        return Array(divergences.suffix(5))
    }

    private struct SwingPoint {
        let date: Date
        let price: Double
    }

    private func findSwingHighs(bars: [OHLCBar], lookback: Int) -> [SwingPoint] {
        var swings: [SwingPoint] = []
        guard bars.count > lookback * 2 else { return swings }

        for i in lookback..<(bars.count - lookback) {
            let current = bars[i].high
            var isSwing = true
            for j in (i - lookback)..<i {
                if bars[j].high >= current { isSwing = false; break }
            }
            if isSwing {
                for j in (i + 1)...(i + lookback) {
                    if bars[j].high >= current { isSwing = false; break }
                }
            }
            if isSwing {
                swings.append(SwingPoint(date: bars[i].date, price: current))
            }
        }
        return swings
    }

    private func findSwingLows(bars: [OHLCBar], lookback: Int) -> [SwingPoint] {
        var swings: [SwingPoint] = []
        guard bars.count > lookback * 2 else { return swings }

        for i in lookback..<(bars.count - lookback) {
            let current = bars[i].low
            var isSwing = true
            for j in (i - lookback)..<i {
                if bars[j].low <= current { isSwing = false; break }
            }
            if isSwing {
                for j in (i + 1)...(i + lookback) {
                    if bars[j].low <= current { isSwing = false; break }
                }
            }
            if isSwing {
                swings.append(SwingPoint(date: bars[i].date, price: current))
            }
        }
        return swings
    }

    // MARK: - Consolidation Range Detection

    func detectConsolidationRanges(bars: [OHLCBar], minBars: Int = 10, atrMultiplier: Double = 1.5) -> [ConsolidationRange] {
        let sorted = bars.sorted { $0.date < $1.date }
        guard sorted.count > 20 else { return [] }

        var trueRanges: [Double] = []
        for i in 1..<sorted.count {
            let tr = max(
                sorted[i].high - sorted[i].low,
                max(abs(sorted[i].high - sorted[i - 1].close), abs(sorted[i].low - sorted[i - 1].close))
            )
            trueRanges.append(tr)
        }

        guard trueRanges.count >= 20 else { return [] }

        var ranges: [ConsolidationRange] = []
        var i = 20

        while i < sorted.count {
            let startIdx = max(0, i - 21)
            let endIdx = i - 1
            let atr = trueRanges[startIdx..<endIdx].reduce(0, +) / Double(endIdx - startIdx)
            let threshold = atr * atrMultiplier

            let rangeStart = i
            var rangeHigh = sorted[i].high
            var rangeLow = sorted[i].low

            var j = i + 1
            while j < sorted.count {
                let newHigh = max(rangeHigh, sorted[j].high)
                let newLow = min(rangeLow, sorted[j].low)
                if newHigh - newLow <= threshold {
                    rangeHigh = newHigh
                    rangeLow = newLow
                    j += 1
                } else {
                    break
                }
            }

            if j - rangeStart >= minBars {
                ranges.append(ConsolidationRange(
                    startDate: sorted[rangeStart].date,
                    endDate: sorted[j - 1].date,
                    highPrice: rangeHigh,
                    lowPrice: rangeLow
                ))
                i = j
            } else {
                i += 1
            }
        }

        return ranges
    }
}
