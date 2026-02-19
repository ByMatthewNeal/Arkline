import Foundation

@Observable
class TrendChannelViewModel {

    // MARK: - State

    var selectedIndex: IndexSymbol = .sp500
    var selectedTimeRange: TrendChannelTimeRange = .daily
    var isLoading = false
    var errorMessage: String?

    // MARK: - Data

    var channelData: LogRegressionChannelData?
    var rsiSeries: [RSISeriesPoint] = []
    var divergences: [RSIDivergence] = []
    var consolidationRanges: [ConsolidationRange] = []
    var currentPrice: Double?
    var priceChange: Double?

    // MARK: - Selection

    var selectedDate: Date?

    // MARK: - Private

    private let yahooService = YahooFinanceService.shared
    private let regressionService = LogRegressionService.shared
    private var cachedBars: [String: [OHLCBar]] = [:]
    private var cachedDailyQuote: [String: (price: Double, change: Double)] = [:]

    // MARK: - Cache Key

    private func cacheKey(symbol: String, range: TrendChannelTimeRange) -> String {
        "\(symbol)_\(range.rawValue)"
    }

    // MARK: - Load Data

    func loadData() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let symbol = selectedIndex.rawValue
            let range = selectedTimeRange
            let key = cacheKey(symbol: symbol, range: range)

            // Always fetch a 1-day quote for accurate daily price change
            if cachedDailyQuote[symbol] == nil {
                let dailyResult = try await yahooService.fetchChartBars(
                    symbol: symbol,
                    interval: "1d",
                    range: "5d"
                )
                let price = dailyResult.currentPrice
                var change = 0.0
                if let prevClose = dailyResult.previousClose, prevClose > 0 {
                    change = ((price - prevClose) / prevClose) * 100
                }
                cachedDailyQuote[symbol] = (price: price, change: change)
            }

            if let quote = cachedDailyQuote[symbol] {
                await MainActor.run {
                    self.currentPrice = quote.price
                    self.priceChange = quote.change
                }
            }

            let bars: [OHLCBar]

            if let cached = cachedBars[key] {
                bars = cached
            } else {
                let result = try await yahooService.fetchChartBars(
                    symbol: symbol,
                    interval: range.yahooInterval,
                    range: range.yahooRange
                )

                let rawBars: [OHLCBar]
                if range.needsAggregation {
                    rawBars = yahooService.aggregate4HBars(from: result.bars)
                } else {
                    rawBars = result.bars
                }

                cachedBars[key] = rawBars
                bars = rawBars
            }

            // Run calculations
            let channel = regressionService.calculateLogRegressionChannel(
                bars: bars,
                barsPerYear: range.barsPerYear
            )
            let rsi = regressionService.calculateRSISeries(bars: bars)
            let divs = regressionService.detectDivergences(bars: bars, rsiSeries: rsi)
            let consol = regressionService.detectConsolidationRanges(bars: bars)

            await MainActor.run {
                self.channelData = channel
                self.rsiSeries = rsi
                self.divergences = divs
                self.consolidationRanges = consol
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func switchTimeRange(_ range: TrendChannelTimeRange) async {
        await MainActor.run {
            selectedTimeRange = range
            selectedDate = nil
        }
        await loadData()
    }

    // MARK: - Selection Helpers

    func selectedChannelPoint() -> LogRegressionPoint? {
        guard let date = selectedDate, let points = channelData?.points else { return nil }
        return nearestPoint(to: date, in: points)
    }

    func selectedRSIPoint() -> RSISeriesPoint? {
        guard let date = selectedDate else { return nil }
        return nearestRSIPoint(to: date, in: rsiSeries)
    }

    private func nearestPoint(to date: Date, in points: [LogRegressionPoint]) -> LogRegressionPoint? {
        guard !points.isEmpty else { return nil }
        var lo = 0, hi = points.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if points[mid].date < date { lo = mid + 1 } else { hi = mid }
        }
        if lo > 0 {
            let before = points[lo - 1]
            let after = points[lo]
            return abs(before.date.timeIntervalSince(date)) < abs(after.date.timeIntervalSince(date)) ? before : after
        }
        return points[lo]
    }

    private func nearestRSIPoint(to date: Date, in points: [RSISeriesPoint]) -> RSISeriesPoint? {
        guard !points.isEmpty else { return nil }
        var lo = 0, hi = points.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if points[mid].date < date { lo = mid + 1 } else { hi = mid }
        }
        if lo > 0 {
            let before = points[lo - 1]
            let after = points[lo]
            return abs(before.date.timeIntervalSince(date)) < abs(after.date.timeIntervalSince(date)) ? before : after
        }
        return points[lo]
    }
}
