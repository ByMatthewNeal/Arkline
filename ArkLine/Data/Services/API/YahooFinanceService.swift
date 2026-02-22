import Foundation

// MARK: - Yahoo Finance Service
/// Fetches VIX and DXY data from Yahoo Finance
/// Uses unofficial but reliable Yahoo Finance chart API
final class YahooFinanceService {
    // MARK: - Singleton
    static let shared = YahooFinanceService()

    private init() {}

    // MARK: - Symbols
    private let vixSymbol = "^VIX"
    private let dxySymbol = "DX-Y.NYB"

    // MARK: - Base URL
    private let baseURL = "https://query1.finance.yahoo.com/v8/finance/chart"

    // MARK: - Generic Chart Data

    /// Fetch OHLC chart data for any symbol with configurable interval and range
    func fetchChartBars(symbol: String, interval: String, range: String) async throws -> (bars: [OHLCBar], currentPrice: Double, previousClose: Double?) {
        let data = try await fetchQuote(symbol: symbol, range: range, interval: interval)

        guard let result = data.chart.result?.first,
              let timestamps = result.timestamp,
              let quote = result.indicators.quote.first,
              let meta = result.meta else {
            throw YahooFinanceError.noData
        }

        var bars: [OHLCBar] = []

        for (index, timestamp) in timestamps.enumerated() {
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            let close = quote.close?[safe: index] ?? nil
            let open = quote.open?[safe: index] ?? nil
            let high = quote.high?[safe: index] ?? nil
            let low = quote.low?[safe: index] ?? nil

            if let c = close, let o = open, let h = high, let l = low, c > 0 {
                bars.append(OHLCBar(date: date, open: o, high: h, low: l, close: c))
            }
        }

        return (bars, meta.regularMarketPrice, meta.previousClose ?? meta.chartPreviousClose)
    }

    /// Aggregate hourly bars into 4-hour bars
    func aggregate4HBars(from hourlyBars: [OHLCBar]) -> [OHLCBar] {
        let sorted = hourlyBars.sorted { $0.date < $1.date }
        guard !sorted.isEmpty else { return [] }

        var result: [OHLCBar] = []
        var chunk: [OHLCBar] = []

        for bar in sorted {
            chunk.append(bar)
            if chunk.count == 4 {
                if let last = chunk.last, let first = chunk.first {
                    let aggregated = OHLCBar(
                        date: last.date,
                        open: first.open,
                        high: chunk.map(\.high).max() ?? last.high,
                        low: chunk.map(\.low).min() ?? last.low,
                        close: last.close
                    )
                    result.append(aggregated)
                }
                chunk = []
            }
        }

        // Include remaining bars as a partial 4H candle
        if let last = chunk.last, let first = chunk.first {
            let aggregated = OHLCBar(
                date: last.date,
                open: first.open,
                high: chunk.map(\.high).max() ?? last.high,
                low: chunk.map(\.low).min() ?? last.low,
                close: last.close
            )
            result.append(aggregated)
        }

        return result
    }

    // MARK: - VIX / DXY Methods

    /// Fetch latest VIX data
    func fetchVIX() async throws -> VIXData? {
        let data = try await fetchQuote(symbol: vixSymbol)
        guard let result = data.chart.result?.first,
              let quote = result.indicators.quote.first,
              let meta = result.meta else {
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        return VIXData(
            date: dateString,
            value: meta.regularMarketPrice,
            open: quote.open?.last ?? meta.regularMarketPrice,
            high: quote.high?.last ?? meta.regularMarketPrice,
            low: quote.low?.last ?? meta.regularMarketPrice,
            close: meta.regularMarketPrice
        )
    }

    /// Fetch VIX history
    func fetchVIXHistory(days: Int) async throws -> [VIXData] {
        let range = days <= 7 ? "7d" : (days <= 30 ? "1mo" : (days <= 90 ? "3mo" : "1y"))
        let data = try await fetchQuote(symbol: vixSymbol, range: range)

        guard let result = data.chart.result?.first,
              let timestamps = result.timestamp,
              let quote = result.indicators.quote.first else {
            return []
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var history: [VIXData] = []

        for (index, timestamp) in timestamps.enumerated() {
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            let dateString = dateFormatter.string(from: date)

            let close = quote.close?[safe: index] ?? 0
            let open = quote.open?[safe: index] ?? close
            let high = quote.high?[safe: index] ?? close
            let low = quote.low?[safe: index] ?? close

            if close > 0 {
                history.append(VIXData(
                    date: dateString,
                    value: close,
                    open: open,
                    high: high,
                    low: low,
                    close: close
                ))
            }
        }

        return history.suffix(days).reversed()
    }

    /// Fetch latest DXY data
    func fetchDXY() async throws -> DXYData? {
        let data = try await fetchQuote(symbol: dxySymbol)
        guard let result = data.chart.result?.first,
              let quote = result.indicators.quote.first,
              let meta = result.meta else {
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        return DXYData(
            date: dateString,
            value: meta.regularMarketPrice,
            open: quote.open?.last ?? meta.regularMarketPrice,
            high: quote.high?.last ?? meta.regularMarketPrice,
            low: quote.low?.last ?? meta.regularMarketPrice,
            close: meta.regularMarketPrice,
            previousClose: meta.chartPreviousClose ?? meta.previousClose
        )
    }

    /// Fetch DXY history
    func fetchDXYHistory(days: Int) async throws -> [DXYData] {
        let range = days <= 7 ? "7d" : (days <= 30 ? "1mo" : (days <= 90 ? "3mo" : "1y"))
        let data = try await fetchQuote(symbol: dxySymbol, range: range)

        guard let result = data.chart.result?.first,
              let timestamps = result.timestamp,
              let quote = result.indicators.quote.first else {
            return []
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var history: [DXYData] = []
        var previousClose: Double?

        for (index, timestamp) in timestamps.enumerated() {
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            let dateString = dateFormatter.string(from: date)

            let close = quote.close?[safe: index] ?? 0
            let open = quote.open?[safe: index] ?? close
            let high = quote.high?[safe: index] ?? close
            let low = quote.low?[safe: index] ?? close

            if close > 0 {
                history.append(DXYData(
                    date: dateString,
                    value: close,
                    open: open,
                    high: high,
                    low: low,
                    close: close,
                    previousClose: previousClose
                ))
                previousClose = close
            }
        }

        return history.suffix(days).reversed()
    }

    // MARK: - Private Methods

    private func fetchQuote(symbol: String, range: String = "1d", interval: String = "1d") async throws -> YahooChartResponse {
        let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        var components = URLComponents(string: "\(baseURL)/\(encodedSymbol)")
        components?.queryItems = [
            URLQueryItem(name: "interval", value: interval),
            URLQueryItem(name: "range", value: range)
        ]

        guard let url = components?.url else {
            throw YahooFinanceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let (data, response) = try await PinnedURLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw YahooFinanceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            logError("Yahoo Finance API error: \(httpResponse.statusCode)", category: .network)
            throw YahooFinanceError.httpError(httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(YahooChartResponse.self, from: data)
        } catch {
            logError("Yahoo Finance decode error: \(error)", category: .network)
            throw YahooFinanceError.decodingError(error)
        }
    }
}

// MARK: - Yahoo Finance Error
enum YahooFinanceError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Yahoo Finance URL"
        case .invalidResponse:
            return "Invalid response from Yahoo Finance"
        case .httpError(let code):
            return "Yahoo Finance HTTP error: \(code)"
        case .decodingError(let error):
            return "Failed to decode Yahoo Finance data: \(error.localizedDescription)"
        case .noData:
            return "No data available from Yahoo Finance"
        }
    }
}

// MARK: - Yahoo Finance Response Models
struct YahooChartResponse: Codable {
    let chart: YahooChart
}

struct YahooChart: Codable {
    let result: [YahooChartResult]?
    let error: YahooError?
}

struct YahooChartResult: Codable {
    let meta: YahooMeta?
    let timestamp: [Int]?
    let indicators: YahooIndicators
}

struct YahooMeta: Codable {
    let currency: String?
    let symbol: String?
    let regularMarketPrice: Double
    let previousClose: Double?
    let chartPreviousClose: Double?
}

struct YahooIndicators: Codable {
    let quote: [YahooQuote]
}

struct YahooQuote: Codable {
    let open: [Double?]?
    let high: [Double?]?
    let low: [Double?]?
    let close: [Double?]?
    let volume: [Int?]?
}

struct YahooError: Codable {
    let code: String?
    let description: String?
}

// MARK: - Safe Array Access
private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

private extension Array where Element == Double? {
    subscript(safe index: Int) -> Double? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
