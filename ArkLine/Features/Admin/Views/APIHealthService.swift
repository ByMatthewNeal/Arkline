import Foundation

// MARK: - System Health Service
/// Checks external APIs, data freshness, and cron job status for the admin dashboard.

struct APIHealthResult: Identifiable {
    let id = UUID()
    let name: String
    let category: APICategory
    let status: APIStatus
    let latencyMs: Int?
    let detail: String?
    var explanation: String? = nil  // Why it might be degraded/down (shown only when not healthy)

    enum APICategory: String, CaseIterable {
        case pricing = "Pricing & Market Data"
        case macro = "Macro & Economics"
        case sentiment = "Sentiment & On-Chain"
        case news = "News Feeds"
        case backend = "Backend & Infrastructure"
        case dataFreshness = "Data Freshness"
        case cronJobs = "Cron Jobs"
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

    // MARK: - Freshness Check Definitions

    private struct FreshnessCheck {
        let name: String
        let table: String
        let query: FreshnessQuery
        let maxAgeMinutes: Int      // Healthy threshold
        let degradedAgeMinutes: Int // Degraded threshold (beyond = down)
        let explanation: String     // Context shown when degraded/down
    }

    private enum FreshnessQuery {
        case cacheKey(String)                    // Check market_data_cache by key
        case latestRow(dateColumn: String, orderDesc: Bool, extraFilters: [(String, String, String)])
    }

    private var apiChecks: [HealthCheck] {
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
            // NOTE: FMP is intentionally NOT checked here. In release builds
            // Constants.API.fmpAPIKey is nil by design (keys are server-side only),
            // so a direct call sent `apikey=` empty and always came back 401 —
            // a false alarm, since the app reaches FMP through the api-proxy.
            // It's checked via that real path in `runFMPCheck()` instead.

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
                url: "https://api.stlouisfed.org/fred/series?series_id=WM2NS&file_type=json",
                method: "GET",
                headers: [:],
                validateResponse: { _, response in
                    // Without api_key FRED returns 400; via api-proxy it works fine.
                    // Just check that the server responds (not a 5xx).
                    response.statusCode < 500 ? (true, nil) : (false, "HTTP \(response.statusCode)")
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
                headers: ["User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"],
                validateResponse: { data, response in
                    guard response.statusCode == 200 else { return (false, "HTTP \(response.statusCode)") }
                    let str = String(data: data, encoding: .utf8) ?? ""
                    return (str.contains("<item>") || str.contains("<entry>") || str.contains("rss")) ? (true, nil) : (false, "No items in feed")
                }
            ),
            // Bloomberg RSS check removed — Bloomberg retired its public feeds and
            // every feeds.bloomberg.com URL now returns 404, so this check was
            // permanently red for a source we no longer pull.

            // Backend & Infrastructure
            HealthCheck(
                name: "Supabase REST",
                category: .backend,
                url: "https://mprbbjgrshfbupheuscn.supabase.co/rest/v1/market_data_cache?select=key&limit=1",
                method: "GET",
                headers: [
                    "apikey": ObfuscatedSecrets.supabaseAnonKey,
                    "Authorization": "Bearer \(ObfuscatedSecrets.supabaseAnonKey)"
                ],
                validateResponse: { _, response in
                    response.statusCode == 200 ? (true, nil) : (false, "HTTP \(response.statusCode)")
                }
            ),
            HealthCheck(
                name: "Supabase Edge Functions",
                category: .backend,
                url: "https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/health-check",
                method: "POST",
                headers: [
                    "Content-Type": "application/json"
                ],
                validateResponse: { _, response in
                    // health-check expects CRON_SECRET, so 401 = function is running but auth failed (OK)
                    // 5xx or connection failure = actually down
                    response.statusCode < 500 ? (true, nil) : (false, "HTTP \(response.statusCode)")
                }
            ),
        ]
    }

    // MARK: - Freshness Checks (Supabase queries)

    private var freshnessChecks: [FreshnessCheck] {
        [
            // Data Freshness: Cache entries populated by edge functions
            FreshnessCheck(
                name: "Crypto Prices",
                table: "market_data_cache",
                query: .cacheKey("crypto_assets_1_100"),
                maxAgeMinutes: 15,
                degradedAgeMinutes: 30,
                explanation: "sync-crypto-prices cron runs every 5 min via CoinGecko. If stale, check CoinGecko API status or cron logs."
            ),
            FreshnessCheck(
                name: "Global Market Data",
                table: "market_data_cache",
                query: .cacheKey("global_market_data"),
                maxAgeMinutes: 15,
                degradedAgeMinutes: 30,
                explanation: "Synced alongside crypto prices. Same cron, same root cause if stale."
            ),
            FreshnessCheck(
                name: "Global Liquidity Index",
                table: "market_data_cache",
                query: .cacheKey("global_liquidity_index"),
                maxAgeMinutes: 60 * 26,
                degradedAgeMinutes: 60 * 50,
                explanation: "sync-global-liquidity runs daily at 08:00 UTC. Pulls BIS + FRED data. BIS data itself lags ~2 months."
            ),
            FreshnessCheck(
                name: "Signal Analytics",
                table: "market_data_cache",
                query: .cacheKey("signal_analytics"),
                maxAgeMinutes: 60 * 26,
                degradedAgeMinutes: 60 * 50,
                explanation: "compute-signal-analytics runs daily at 01:00 UTC. Derives adaptive pipeline params from closed signals."
            ),

            // Data Freshness: Table-based checks
            FreshnessCheck(
                name: "Positioning Signals",
                table: "positioning_signals",
                query: .latestRow(dateColumn: "created_at", orderDesc: true, extraFilters: []),
                maxAgeMinutes: 60 * 26,
                degradedAgeMinutes: 60 * 50,
                explanation: "compute-positioning-signals runs daily at 00:15 UTC. Feeds model portfolios and daily briefings."
            ),
            FreshnessCheck(
                name: "Economic Events",
                table: "economic_events",
                // Use updated_at, not created_at: the sync UPSERTS every 30 min so it
                // touches updated_at each run, but created_at only advances when a
                // brand-new event is inserted (weekly-ish batches). Watching created_at
                // made this go red during normal gaps between new events.
                query: .latestRow(dateColumn: "updated_at", orderDesc: true, extraFilters: []),
                maxAgeMinutes: 60,
                degradedAgeMinutes: 120,
                explanation: "sync-economic-events runs every 30 min via FMP. Freshness tracks the last sync (updated_at)."
            ),
            FreshnessCheck(
                name: "Model Portfolio NAV",
                table: "model_portfolio_nav",
                query: .latestRow(dateColumn: "nav_date", orderDesc: true, extraFilters: []),
                maxAgeMinutes: 60 * 26,
                degradedAgeMinutes: 60 * 50,
                explanation: "compute-model-portfolios runs daily at 00:30 UTC. Depends on positioning signals and FMP BTC history."
            ),
            FreshnessCheck(
                name: "Daily Briefing",
                table: "market_summaries",
                query: .latestRow(dateColumn: "generated_at", orderDesc: true, extraFilters: []),
                maxAgeMinutes: 60 * 26,
                degradedAgeMinutes: 60 * 30,
                explanation: "market-summary runs 2x daily Mon–Fri (10am, 5pm ET) and 1x on Sat & Sun (12pm ET). Weekend gaps up to 24h are normal."
            ),
            FreshnessCheck(
                name: "OHLC Candles",
                table: "ohlc_candles",
                query: .latestRow(dateColumn: "open_time", orderDesc: true, extraFilters: []),
                maxAgeMinutes: 120,
                degradedAgeMinutes: 240,
                explanation: "fibonacci-pipeline fetches from Coinbase every 30 min. If stale, pipeline cron may be down."
            ),
            FreshnessCheck(
                name: "Curated News",
                table: "curated_news",
                query: .latestRow(dateColumn: "created_at", orderDesc: true, extraFilters: []),
                maxAgeMinutes: 60,
                degradedAgeMinutes: 120,
                explanation: "curate-news runs every 30 min. Fetches CNBC, Reuters and MarketWatch RSS, filters with Claude Haiku, enriches with Sonnet. If stale, check Claude API credits or RSS feed availability."
            ),
            FreshnessCheck(
                name: "Trade Signals",
                table: "trade_signals",
                query: .latestRow(dateColumn: "generated_at", orderDesc: true, extraFilters: []),
                maxAgeMinutes: 60 * 24 * 7,
                degradedAgeMinutes: 60 * 24 * 14,
                explanation: "EMA regime filter blocks signals in choppy markets — days/weeks without a signal is normal. Check OHLC Candles to confirm the pipeline itself is running."
            ),
        ]
    }

    // MARK: - Run All Checks

    func runAllChecks() async -> [APIHealthResult] {
        async let apiResults = runAPIChecks()
        async let freshnessResults = runFreshnessChecks()
        let (api, freshness) = await (apiResults, freshnessResults)
        return (api + freshness).sorted { $0.category.rawValue < $1.category.rawValue }
    }

    // MARK: - API Checks

    private func runAPIChecks() async -> [APIHealthResult] {
        // FMP goes through the api-proxy (see runFMPCheck), everything else is a
        // direct keyless endpoint.
        async let fmp = runFMPCheck()

        let others = await withTaskGroup(of: APIHealthResult.self) { group -> [APIHealthResult] in
            for check in apiChecks {
                group.addTask {
                    await self.runAPICheck(check)
                }
            }

            var results: [APIHealthResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        return others + [await fmp]
    }

    /// FMP is reached through the api-proxy edge function, which holds the key
    /// server-side. Release builds have `Constants.API.fmpAPIKey == nil` on
    /// purpose, so hitting FMP directly would send an empty key and always report
    /// a bogus 401. Checking the proxy tests the path the app actually uses.
    private func runFMPCheck() async -> APIHealthResult {
        let start = Date()
        do {
            let data = try await APIProxy.shared.request(
                service: .fmp,
                path: "/quote", // api-proxy requires a leading slash (matches FMPService)
                queryItems: ["symbol": "AAPL"]
            )
            let latency = Int(Date().timeIntervalSince(start) * 1000)

            if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]], !arr.isEmpty {
                return APIHealthResult(
                    name: "FMP",
                    category: .pricing,
                    status: latency > 5000 ? .degraded : .healthy,
                    latencyMs: latency,
                    detail: nil
                )
            }
            return APIHealthResult(
                name: "FMP",
                category: .pricing,
                status: .down,
                latencyMs: latency,
                detail: "No data"
            )
        } catch {
            return APIHealthResult(
                name: "FMP",
                category: .pricing,
                status: .down,
                latencyMs: Int(Date().timeIntervalSince(start) * 1000),
                detail: error.localizedDescription
            )
        }
    }

    private func runAPICheck(_ check: HealthCheck) async -> APIHealthResult {
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
            let (data, response) = try await PinnedURLSession.shared.data(for: request)
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

    // MARK: - Freshness Checks (Supabase)

    private func runFreshnessChecks() async -> [APIHealthResult] {
        guard SupabaseManager.shared.isConfigured else {
            return freshnessChecks.map {
                APIHealthResult(name: $0.name, category: .dataFreshness, status: .down, latencyMs: nil, detail: "Supabase not configured")
            }
        }

        return await withTaskGroup(of: APIHealthResult.self) { group in
            for check in freshnessChecks {
                group.addTask {
                    await self.runFreshnessCheck(check)
                }
            }

            var results: [APIHealthResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }

    private func runFreshnessCheck(_ check: FreshnessCheck) async -> APIHealthResult {
        let start = Date()

        do {
            let lastUpdated: Date? = try await withThrowingTaskGroup(of: Date?.self) { group in
                group.addTask {
                    switch check.query {
                    case .cacheKey(let key):
                        return try await self.fetchCacheTimestamp(key: key)
                    case .latestRow(let dateColumn, let orderDesc, let extraFilters):
                        return try await self.fetchLatestTimestamp(
                            table: check.table,
                            dateColumn: dateColumn,
                            orderDesc: orderDesc,
                            extraFilters: extraFilters
                        )
                    }
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(10))
                    throw CancellationError()
                }
                guard let result = try await group.next() else {
                    group.cancelAll()
                    return nil
                }
                group.cancelAll()
                return result
            }

            let latency = Int(Date().timeIntervalSince(start) * 1000)

            guard let updated = lastUpdated else {
                return APIHealthResult(
                    name: check.name,
                    category: .dataFreshness,
                    status: .down,
                    latencyMs: latency,
                    detail: "No data found",
                    explanation: check.explanation
                )
            }

            let ageMinutes = Int(Date().timeIntervalSince(updated) / 60)
            let ageString = formatAge(minutes: ageMinutes)

            let status: APIHealthResult.APIStatus
            if ageMinutes <= check.maxAgeMinutes {
                status = .healthy
            } else if ageMinutes <= check.degradedAgeMinutes {
                status = .degraded
            } else {
                status = .down
            }

            return APIHealthResult(
                name: check.name,
                category: .dataFreshness,
                status: status,
                latencyMs: latency,
                detail: "Updated \(ageString) ago",
                explanation: status != .healthy ? check.explanation : nil
            )
        } catch {
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            return APIHealthResult(
                name: check.name,
                category: .dataFreshness,
                status: .down,
                latencyMs: latency,
                detail: "Query failed",
                explanation: check.explanation
            )
        }
    }

    // MARK: - Supabase Queries

    private func fetchCacheTimestamp(key: String) async throws -> Date? {
        let rows: [[String: String]] = try await SupabaseManager.shared.client
            .from("market_data_cache")
            .select("updated_at")
            .eq("key", value: key)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first, let value = row["updated_at"] else {
            return nil
        }
        return parseTimestamp(value)
    }

    private func fetchLatestTimestamp(
        table: String,
        dateColumn: String,
        orderDesc: Bool,
        extraFilters: [(String, String, String)]
    ) async throws -> Date? {
        var query = SupabaseManager.shared.client
            .from(table)
            .select(dateColumn)

        for (col, op, val) in extraFilters {
            switch op {
            case "eq": query = query.eq(col, value: val)
            default: break
            }
        }

        let rows: [[String: String]] = try await query
            .order(dateColumn, ascending: !orderDesc)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first, let value = row[dateColumn] else {
            return nil
        }
        return parseTimestamp(value)
    }

    private func parseTimestamp(_ value: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) { return date }

        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) { return date }

        // Date-only (e.g., "2026-04-29" for model_portfolio_nav)
        let dateOnly = DateFormatter()
        dateOnly.dateFormat = "yyyy-MM-dd"
        dateOnly.locale = Locale(identifier: "en_US_POSIX")
        dateOnly.timeZone = TimeZone(identifier: "UTC")
        return dateOnly.date(from: value)
    }

    // MARK: - Helpers

    private func formatAge(minutes: Int) -> String {
        if minutes < 1 { return "<1m" }
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours < 24 {
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        }
        let days = hours / 24
        let remainingHours = hours % 24
        return remainingHours > 0 ? "\(days)d \(remainingHours)h" : "\(days)d"
    }
}
