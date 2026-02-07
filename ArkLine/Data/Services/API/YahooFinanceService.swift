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

    // MARK: - Public Methods

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
        let urlString = "\(baseURL)/\(encodedSymbol)?interval=\(interval)&range=\(range)"

        guard let url = URL(string: urlString) else {
            throw YahooFinanceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

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
