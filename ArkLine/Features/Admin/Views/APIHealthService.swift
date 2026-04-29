import Foundation

// MARK: - API Health Service
/// Pings all external APIs and reports their status for the admin dashboard.

struct APIHealthResult: Identifiable {
    let id = UUID()
    let name: String
    let category: APICategory
    let status: APIStatus
    let latencyMs: Int?
    let detail: String?

    enum APICategory: String, CaseIterable {
        case pricing = "Pricing & Market Data"
        case macro = "Macro & Economics"
        case sentiment = "Sentiment & On-Chain"
        case news = "News Feeds"
        case backend = "Backend & Infrastructure"
    }

    enum APIStatus: String {
        case healthy = "Healthy"
        case degraded = "Degraded"
        case down = "Down"
        case checking = "Checking"

        var icon: String {
            switch self {
            case .healthy: return "checkmark.circle.fill"
            case .degraded: return "exclamationmark.triangle.fill"
            case .down: return "xmark.circle.fill"
            case .checking: return "arrow.clockwise"
            }
        }

        var color: String {
            switch self {
            case .healthy: return "success"
            case .degraded: return "warning"
            case .down: return "error"
            case .checking: return "textSecondary"
            }
        }
    }
}

actor APIHealthService {

    static let shared = APIHealthService()

    // MARK: - Health Check Definitions

    private struct HealthCheck {
        let name: String
        let category: APIHealthResult.APICategory
        let url: String
        let method: String
        let headers: [String: String]
        let validateResponse: (Data, HTTPURLResponse) -> (Bool, String?)
    }

    private var checks: [HealthCheck] {
        [
            // Pricing & Market Data
            HealthCheck(
                name: "Coinbase",
                category: .pricing,
                url: "https://api.coinbase.com/api/v3/brokerage/market/products/BTC-USD/candles?granularity=ONE_HOUR&limit=1&start=\(Int(Date().timeIntervalSince1970) - 7200)&end=\(Int(Date().timeIntervalSince1970))",
                method: "GET",
                headers: [:],
                validateResponse: { data, response in
                    guard response.statusCode == 200 else { return (false, "HTTP \(response.statusCode)") }
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let candles = json["candles"] as? [[String: Any]], !candles.isEmpty {
                        return (true, nil)
                    }
                    return (false, "No candle data")
                }
            ),
            HealthCheck(
                name: "CoinGecko",
                category: .pricing,
                url: "https://api.coingecko.com/api/v3/ping",
                method: "GET",
                headers: [:],
                validateResponse: { _, response in
                    response.statusCode == 200 ? (true, nil) : (false, "HTTP \(response.statusCode)")
                }
            ),
            HealthCheck(
                name: "Binance",
                category: .pricing,
                url: "https://data-api.binance.vision/api/v3/ticker/price?symbol=BTCUSDT",
                method: "GET",
                headers: [:],
                validateResponse: { data, response in
                    guard response.statusCode == 200 else { return (false, "HTTP \(response.statusCode)") }
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       json["price"] != nil {
                        return (true, nil)
                    }
                    return (false, "No price data")
                }
            ),
            HealthCheck(
                name: "FMP",
                category: .pricing,
                url: "https://financialmodelingprep.com/stable/quote?symbol=AAPL&apikey=\(Constants.API.fmpAPIKey ?? "")",
                method: "GET",
                headers: [:],
                validateResponse: { data, response in
                    guard response.statusCode == 200 else { return (false, "HTTP \(response.statusCode)") }
                    if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]], !arr.isEmpty {
                        return (true, nil)
                    }
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       json["Error Message"] != nil {
                        return (false, "Invalid API key")
                    }
                    return (false, "No data")
                }
            ),

            // Macro & Economics
            HealthCheck(
                name: "Yahoo Finance",
                category: .macro,
                url: "https://query1.finance.yahoo.com/v8/finance/chart/%5EVIX?interval=1d&range=1d",
                method: "GET",
                headers: ["User-Agent": "Mozilla/5.0"],
                validateResponse: { _, response in
                    response.statusCode == 200 ? (true, nil) : (false, "HTTP \(response.statusCode)")
                }
            ),
            HealthCheck(
                name: "FRED",
                category: .macro,
                url: "https://api.stlouisfed.org/fred/series?series_id=WM2NS&api_key=demo&file_type=json",
                method: "GET",
                headers: [:],
                validateResponse: { _, response in
                    response.statusCode == 200 ? (true, nil) : (false, "HTTP \(response.statusCode)")
                }
            ),

            // Sentiment & On-Chain
            HealthCheck(
                name: "Fear & Greed",
                category: .sentiment,
                url: "https://api.alternative.me/fng/?limit=1",
                method: "GET",
                headers: [:],
                validateResponse: { data, response in
                    guard response.statusCode == 200 else { return (false, "HTTP \(response.statusCode)") }
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let dataArr = json["data"] as? [[String: Any]], !dataArr.isEmpty {
                        return (true, nil)
                    }
                    return (false, "No data")
                }
            ),

            // News Feeds
            HealthCheck(
                name: "Google News RSS",
                category: .news,
                url: "https://news.google.com/rss/search?q=bitcoin&hl=en-US&gl=US&ceid=US:en",
                method: "GET",
                headers: ["User-Agent": "Mozilla/5.0"],
                validateResponse: { data, response in
                    guard response.statusCode == 200 else { return (false, "HTTP \(response.statusCode)") }
                    let str = String(data: data.prefix(500), encoding: .utf8) ?? ""
                    return str.contains("<item>") ? (true, nil) : (false, "No items in feed")
                }
            ),
            HealthCheck(
                name: "Bloomberg RSS",
                category: .news,
                url: "https://feeds.bloomberg.com/markets/news.rss",
                method: "GET",
                headers: ["User-Agent": "Mozilla/5.0"],
                validateResponse: { data, response in
                    guard response.statusCode == 200 else { return (false, "HTTP \(response.statusCode)") }
                    let str = String(data: data.prefix(500), encoding: .utf8) ?? ""
                    return str.contains("<item>") || str.contains("<entry>") ? (true, nil) : (false, "No items in feed")
                }
            ),

            // Backend & Infrastructure
            HealthCheck(
                name: "Supabase",
                category: .backend,
                url: "https://mprbbjgrshfbupheuscn.supabase.co/rest/v1/",
                method: "GET",
                headers: [
                    "apikey": ObfuscatedSecrets.supabaseAnonKey
                ],
                validateResponse: { _, response in
                    // Supabase returns 200 on the REST root
                    (response.statusCode == 200 || response.statusCode == 404) ? (true, nil) : (false, "HTTP \(response.statusCode)")
                }
            ),
            HealthCheck(
                name: "Supabase Edge Functions",
                category: .backend,
                url: "https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/health-check",
                method: "GET",
                headers: [:],
                validateResponse: { _, response in
                    response.statusCode == 200 ? (true, nil) : (false, "HTTP \(response.statusCode)")
                }
            ),
        ]
    }

    // MARK: - Run All Checks

    func runAllChecks() async -> [APIHealthResult] {
        await withTaskGroup(of: APIHealthResult.self) { group in
            for check in checks {
                group.addTask {
                    await self.runCheck(check)
                }
            }

            var results: [APIHealthResult] = []
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.category.rawValue < $1.category.rawValue }
        }
    }

    // MARK: - Single Check

    private func runCheck(_ check: HealthCheck) async -> APIHealthResult {
        guard let url = URL(string: check.url) else {
            return APIHealthResult(name: check.name, category: check.category, status: .down, latencyMs: nil, detail: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = check.method
        request.timeoutInterval = 10
        for (key, value) in check.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let start = Date()

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let latency = Int(Date().timeIntervalSince(start) * 1000)

            guard let httpResponse = response as? HTTPURLResponse else {
                return APIHealthResult(name: check.name, category: check.category, status: .down, latencyMs: latency, detail: "No HTTP response")
            }

            let (isHealthy, detail) = check.validateResponse(data, httpResponse)

            let status: APIHealthResult.APIStatus
            if isHealthy {
                status = latency > 5000 ? .degraded : .healthy
            } else {
                status = .down
            }

            return APIHealthResult(
                name: check.name,
                category: check.category,
                status: status,
                latencyMs: latency,
                detail: isHealthy && latency > 5000 ? "Slow response (\(latency)ms)" : detail
            )
        } catch {
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            let detail: String
            if (error as NSError).code == NSURLErrorTimedOut {
                detail = "Timed out (10s)"
            } else {
                detail = error.localizedDescription
            }
            return APIHealthResult(name: check.name, category: check.category, status: .down, latencyMs: latency, detail: detail)
        }
    }
}
