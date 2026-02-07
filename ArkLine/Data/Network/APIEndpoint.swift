import Foundation

// MARK: - HTTP Method
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - API Endpoint Protocol
protocol APIEndpoint {
    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var queryParameters: [String: String]? { get }
    var body: Data? { get }
    var requiresAuth: Bool { get }
    var cachePolicy: URLRequest.CachePolicy { get }
    var timeoutInterval: TimeInterval { get }
}

// MARK: - Default Implementation
extension APIEndpoint {
    var headers: [String: String]? { nil }
    var queryParameters: [String: String]? { nil }
    var body: Data? { nil }
    var requiresAuth: Bool { false }
    var cachePolicy: URLRequest.CachePolicy { .useProtocolCachePolicy }
    var timeoutInterval: TimeInterval { 30 }

    var url: URL? {
        var components = URLComponents(string: baseURL + path)

        if let queryParameters = queryParameters, !queryParameters.isEmpty {
            components?.queryItems = queryParameters.map {
                URLQueryItem(name: $0.key, value: $0.value)
            }
        }

        return components?.url
    }

    func asURLRequest() throws -> URLRequest {
        guard let url = url else {
            throw AppError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.cachePolicy = cachePolicy
        request.timeoutInterval = timeoutInterval

        // Default headers
        var allHeaders = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]

        // Merge custom headers
        if let customHeaders = headers {
            allHeaders.merge(customHeaders) { _, new in new }
        }

        allHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        if let body = body {
            request.httpBody = body
        }

        return request
    }
}

// MARK: - CoinGecko Endpoints
enum CoinGeckoEndpoint: APIEndpoint {
    case simplePrice(ids: [String], currencies: [String])
    case coinMarkets(currency: String, page: Int, perPage: Int, sparkline: Bool)
    case coinMarketsFiltered(currency: String, ids: [String], sparkline: Bool)
    case coinMarketsWithPriceChange(currency: String, perPage: Int, priceChangePeriods: [String])
    case coinDetail(id: String)
    case coinMarketChart(id: String, currency: String, days: Int)
    case coinMarketChartAll(id: String, currency: String)
    case searchCoins(query: String)
    case globalData
    case trendingCoins
    case fearGreedIndex

    var baseURL: String { Constants.Endpoints.coinGeckoBase }

    var path: String {
        switch self {
        case .simplePrice:
            return "/simple/price"
        case .coinMarkets, .coinMarketsFiltered, .coinMarketsWithPriceChange:
            return "/coins/markets"
        case .coinDetail(let id):
            return "/coins/\(id)"
        case .coinMarketChart(let id, _, _):
            return "/coins/\(id)/market_chart"
        case .coinMarketChartAll(let id, _):
            return "/coins/\(id)/market_chart"
        case .searchCoins:
            return "/search"
        case .globalData:
            return "/global"
        case .trendingCoins:
            return "/search/trending"
        case .fearGreedIndex:
            return "/global"
        }
    }

    var method: HTTPMethod { .get }

    var queryParameters: [String: String]? {
        switch self {
        case .simplePrice(let ids, let currencies):
            return [
                "ids": ids.joined(separator: ","),
                "vs_currencies": currencies.joined(separator: ","),
                "include_24hr_change": "true",
                "include_market_cap": "true"
            ]
        case .coinMarkets(let currency, let page, let perPage, let sparkline):
            return [
                "vs_currency": currency,
                "order": "market_cap_desc",
                "per_page": "\(perPage)",
                "page": "\(page)",
                "sparkline": "\(sparkline)"
            ]
        case .coinMarketsFiltered(let currency, let ids, let sparkline):
            return [
                "vs_currency": currency,
                "ids": ids.joined(separator: ","),
                "order": "market_cap_desc",
                "sparkline": "\(sparkline)"
            ]
        case .coinMarketsWithPriceChange(let currency, let perPage, let priceChangePeriods):
            return [
                "vs_currency": currency,
                "order": "market_cap_desc",
                "per_page": "\(perPage)",
                "page": "1",
                "sparkline": "false",
                "price_change_percentage": priceChangePeriods.joined(separator: ",")
            ]
        case .coinDetail:
            return [
                "localization": "false",
                "tickers": "false",
                "market_data": "true",
                "community_data": "false",
                "developer_data": "false"
            ]
        case .coinMarketChart(_, let currency, let days):
            return [
                "vs_currency": currency,
                "days": "\(days)"
            ]
        case .coinMarketChartAll(_, let currency):
            return [
                "vs_currency": currency,
                "days": "max"
            ]
        case .searchCoins(let query):
            return ["query": query]
        case .globalData, .trendingCoins, .fearGreedIndex:
            return nil
        }
    }

    var headers: [String: String]? {
        let apiKey = Constants.API.coinGeckoAPIKey
        if !apiKey.isEmpty && apiKey != "your-coingecko-api-key" {
            // Demo API keys start with "CG-", Pro keys don't have this prefix
            let headerKey = apiKey.hasPrefix("CG-") ? "x-cg-demo-api-key" : "x-cg-pro-api-key"
            return [headerKey: apiKey]
        }
        return nil
    }
}

// MARK: - Metals API Endpoints
enum MetalsAPIEndpoint: APIEndpoint {
    case latest(base: String, symbols: [String])
    case historical(date: String, base: String, symbols: [String])

    var baseURL: String { Constants.Endpoints.metalsAPIBase }

    var path: String {
        switch self {
        case .latest:
            return "/latest"
        case .historical(let date, _, _):
            return "/\(date)"
        }
    }

    var method: HTTPMethod { .get }

    var queryParameters: [String: String]? {
        switch self {
        case .latest(let base, let symbols), .historical(_, let base, let symbols):
            return [
                "access_key": Constants.API.metalsAPIKey,
                "base": base,
                "symbols": symbols.joined(separator: ",")
            ]
        }
    }
}

// MARK: - Fear & Greed Index Endpoint (Alternative.me)
enum FearGreedEndpoint: APIEndpoint {
    case current
    case historical(days: Int)

    var baseURL: String { "https://api.alternative.me" }

    var path: String { "/fng/" }

    var method: HTTPMethod { .get }

    var queryParameters: [String: String]? {
        switch self {
        case .current:
            return nil
        case .historical(let days):
            return ["limit": "\(days)"]
        }
    }
}

// MARK: - CryptoCompare News Endpoint
enum CryptoCompareEndpoint: APIEndpoint {
    case news(language: String, categories: [String]?)
    case newsCategories

    var baseURL: String { "https://min-api.cryptocompare.com" }

    var path: String {
        switch self {
        case .news:
            return "/data/v2/news/"
        case .newsCategories:
            return "/data/news/categories"
        }
    }

    var method: HTTPMethod { .get }

    var queryParameters: [String: String]? {
        switch self {
        case .news(let language, let categories):
            var params: [String: String] = ["lang": language]
            if let cats = categories, !cats.isEmpty {
                params["categories"] = cats.joined(separator: ",")
            }
            return params
        case .newsCategories:
            return nil
        }
    }
}

// MARK: - Taapi.io Technical Analysis Endpoints
enum TaapiEndpoint: APIEndpoint {
    /// Simple Moving Average
    case sma(exchange: String, symbol: String, interval: String, period: Int)
    /// Bollinger Bands
    case bbands(exchange: String, symbol: String, interval: String, period: Int)
    /// Relative Strength Index
    case rsi(exchange: String, symbol: String, interval: String, period: Int)
    /// MACD
    case macd(exchange: String, symbol: String, interval: String)
    /// Bulk request for multiple indicators at once
    case bulk(exchange: String, symbol: String, interval: String, indicators: [TaapiIndicator])
    /// Current price
    case price(exchange: String, symbol: String, interval: String)

    var baseURL: String { Constants.Endpoints.taapiBase }

    var path: String {
        switch self {
        case .sma:
            return "/sma"
        case .bbands:
            return "/bbands"
        case .rsi:
            return "/rsi"
        case .macd:
            return "/macd"
        case .bulk:
            return "/bulk"
        case .price:
            return "/price"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .bulk:
            return .post
        default:
            return .get
        }
    }

    var queryParameters: [String: String]? {
        switch self {
        case .sma(let exchange, let symbol, let interval, let period):
            return [
                "secret": Constants.API.taapiAPIKey,
                "exchange": exchange,
                "symbol": symbol,
                "interval": interval,
                "period": "\(period)"
            ]
        case .bbands(let exchange, let symbol, let interval, let period):
            return [
                "secret": Constants.API.taapiAPIKey,
                "exchange": exchange,
                "symbol": symbol,
                "interval": interval,
                "period": "\(period)"
            ]
        case .rsi(let exchange, let symbol, let interval, let period):
            return [
                "secret": Constants.API.taapiAPIKey,
                "exchange": exchange,
                "symbol": symbol,
                "interval": interval,
                "period": "\(period)"
            ]
        case .macd(let exchange, let symbol, let interval):
            return [
                "secret": Constants.API.taapiAPIKey,
                "exchange": exchange,
                "symbol": symbol,
                "interval": interval
            ]
        case .bulk:
            return nil // Uses body instead
        case .price(let exchange, let symbol, let interval):
            return [
                "secret": Constants.API.taapiAPIKey,
                "exchange": exchange,
                "symbol": symbol,
                "interval": interval
            ]
        }
    }

    var body: Data? {
        switch self {
        case .bulk(let exchange, let symbol, let interval, let indicators):
            let request = TaapiBulkRequest(
                secret: Constants.API.taapiAPIKey,
                construct: TaapiBulkConstruct(
                    exchange: exchange,
                    symbol: symbol,
                    interval: interval,
                    indicators: indicators
                )
            )
            return try? JSONEncoder().encode(request)
        default:
            return nil
        }
    }
}

// MARK: - Taapi.io Request/Response Models
struct TaapiIndicator: Codable {
    let id: String
    let indicator: String
    var period: Int?
    var stddev: Double?

    init(id: String, indicator: String, period: Int? = nil, stddev: Double? = nil) {
        self.id = id
        self.indicator = indicator
        self.period = period
        self.stddev = stddev
    }
}

struct TaapiBulkRequest: Codable {
    let secret: String
    let construct: TaapiBulkConstruct
}

struct TaapiBulkConstruct: Codable {
    let exchange: String
    let symbol: String
    let interval: String
    let indicators: [TaapiIndicator]
}

struct TaapiBulkResponse: Codable {
    let data: [TaapiIndicatorResult]
}

struct TaapiIndicatorResult: Codable {
    let id: String
    let result: TaapiIndicatorValue
}

struct TaapiIndicatorValue: Codable {
    // SMA result
    let value: Double?
    // Bollinger Bands results
    let valueUpperBand: Double?
    let valueMiddleBand: Double?
    let valueLowerBand: Double?
    // RSI result (uses value)
    // MACD results
    let valueMACD: Double?
    let valueMACDSignal: Double?
    let valueMACDHist: Double?
}

struct TaapiSMAResponse: Codable {
    let value: Double
}

struct TaapiBBandsResponse: Codable {
    let valueUpperBand: Double
    let valueMiddleBand: Double
    let valueLowerBand: Double
}

struct TaapiRSIResponse: Codable {
    let value: Double
}

struct TaapiPriceResponse: Codable {
    let value: Double
}

// MARK: - ArkLine Backend Endpoints
enum ArklineBackendEndpoint: APIEndpoint {
    case itcRiskLevel(coin: String)

    var baseURL: String { Constants.Endpoints.arklineBackendBase }

    var path: String {
        switch self {
        case .itcRiskLevel:
            return "/widgets/btc_risk_level"
        }
    }

    var method: HTTPMethod { .get }

    var queryParameters: [String: String]? {
        switch self {
        case .itcRiskLevel(let coin):
            return ["coin": coin]
        }
    }
}

// MARK: - Binance Endpoints (Public API - no auth required)
enum BinanceEndpoint: APIEndpoint {
    case klines(symbol: String, interval: String, limit: Int)
    case klinesWithTime(symbol: String, interval: String, startTime: Int64, limit: Int)
    case tickerPrice(symbol: String)

    var baseURL: String { "https://api.binance.com" }

    var path: String {
        switch self {
        case .klines, .klinesWithTime:
            return "/api/v3/klines"
        case .tickerPrice:
            return "/api/v3/ticker/price"
        }
    }

    var method: HTTPMethod { .get }

    var queryParameters: [String: String]? {
        switch self {
        case .klines(let symbol, let interval, let limit):
            return [
                "symbol": symbol,
                "interval": interval,
                "limit": String(limit)
            ]
        case .klinesWithTime(let symbol, let interval, let startTime, let limit):
            return [
                "symbol": symbol,
                "interval": interval,
                "startTime": String(startTime),
                "limit": String(limit)
            ]
        case .tickerPrice(let symbol):
            return ["symbol": symbol]
        }
    }
}

// MARK: - Binance Kline Data
/// Binance kline/candlestick data - array of arrays
/// [openTime, open, high, low, close, volume, closeTime, quoteVolume, trades, takerBuyBase, takerBuyQuote, ignore]
struct BinanceKline {
    let openTime: Int64
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
    let closeTime: Int64

    init?(from array: [Any]) {
        guard array.count >= 7,
              let openTime = array[0] as? Int64 ?? (array[0] as? Int).map({ Int64($0) }),
              let openStr = array[1] as? String, let open = Double(openStr),
              let highStr = array[2] as? String, let high = Double(highStr),
              let lowStr = array[3] as? String, let low = Double(lowStr),
              let closeStr = array[4] as? String, let close = Double(closeStr),
              let volumeStr = array[5] as? String, let volume = Double(volumeStr),
              let closeTime = array[6] as? Int64 ?? (array[6] as? Int).map({ Int64($0) })
        else { return nil }

        self.openTime = openTime
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        self.closeTime = closeTime
    }
}
