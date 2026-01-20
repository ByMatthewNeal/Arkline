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
    case coinDetail(id: String)
    case coinMarketChart(id: String, currency: String, days: Int)
    case searchCoins(query: String)
    case globalData
    case trendingCoins
    case fearGreedIndex

    var baseURL: String { Constants.Endpoints.coinGeckoBase }

    var path: String {
        switch self {
        case .simplePrice:
            return "/simple/price"
        case .coinMarkets:
            return "/coins/markets"
        case .coinDetail(let id):
            return "/coins/\(id)"
        case .coinMarketChart(let id, _, _):
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
        case .searchCoins(let query):
            return ["query": query]
        case .globalData, .trendingCoins, .fearGreedIndex:
            return nil
        }
    }

    var headers: [String: String]? {
        if !Constants.API.coinGeckoAPIKey.isEmpty && Constants.API.coinGeckoAPIKey != "your-coingecko-api-key" {
            return ["x-cg-pro-api-key": Constants.API.coinGeckoAPIKey]
        }
        return nil
    }
}

// MARK: - Alpha Vantage Endpoints
enum AlphaVantageEndpoint: APIEndpoint {
    case globalQuote(symbol: String)
    case dailyTimeSeries(symbol: String)
    case searchSymbol(keywords: String)

    var baseURL: String { Constants.Endpoints.alphaVantageBase }

    var path: String { "/query" }

    var method: HTTPMethod { .get }

    var queryParameters: [String: String]? {
        var params: [String: String] = ["apikey": Constants.API.alphaVantageAPIKey]

        switch self {
        case .globalQuote(let symbol):
            params["function"] = "GLOBAL_QUOTE"
            params["symbol"] = symbol
        case .dailyTimeSeries(let symbol):
            params["function"] = "TIME_SERIES_DAILY"
            params["symbol"] = symbol
            params["outputsize"] = "compact"
        case .searchSymbol(let keywords):
            params["function"] = "SYMBOL_SEARCH"
            params["keywords"] = keywords
        }

        return params
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

// MARK: - Claude API Endpoints
enum ClaudeEndpoint: APIEndpoint {
    case messages(request: ClaudeMessageRequest)

    var baseURL: String { Constants.Endpoints.claudeBase }

    var path: String {
        switch self {
        case .messages:
            return "/messages"
        }
    }

    var method: HTTPMethod { .post }

    var headers: [String: String]? {
        [
            "x-api-key": Constants.API.claudeAPIKey,
            "anthropic-version": "2023-06-01"
        ]
    }

    var body: Data? {
        switch self {
        case .messages(let request):
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            return try? encoder.encode(request)
        }
    }

    var requiresAuth: Bool { true }
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
