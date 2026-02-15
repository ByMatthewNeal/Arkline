import Foundation
import Network

// MARK: - Network Manager
actor NetworkManager {
    // MARK: - Singleton
    static let shared = NetworkManager()

    // MARK: - Properties
    private let session: URLSession
    private var cache: [String: CachedResponse] = [:]
    private let maxCacheEntries = 100

    // MARK: - Cache Entry
    private struct CachedResponse {
        let data: Data
        let timestamp: Date
        let ttl: TimeInterval
    }

    // MARK: - Init
    private init() {
        // Use the app-wide pinned URLSession for SSL certificate pinning.
        // Pinned domains get SPKI hash verification; others use standard TLS.
        self.session = PinnedURLSession.shared
    }

    // MARK: - Retry Config
    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 1.0

    // MARK: - Proxy Service Map
    /// Maps base URLs to proxy service identifiers.
    /// Endpoints with base URLs in this map are routed through the api-proxy Edge Function.
    private static let proxyServiceMap: [String: APIProxy.Service] = [
        Constants.Endpoints.coinGeckoBase: .coingecko,
        Constants.Endpoints.metalsAPIBase: .metals,
        Constants.Endpoints.taapiBase: .taapi,
    ]

    // MARK: - Generic Request
    func request<T: Decodable>(
        endpoint: APIEndpoint,
        responseType: T.Type,
        cacheTTL: TimeInterval? = nil
    ) async throws -> T {
        // Check cache first
        if let ttl = cacheTTL, let cachedData = getCachedData(for: endpoint, ttl: ttl) {
            return try decode(cachedData, as: responseType)
        }

        // Route through API proxy if this endpoint's base URL is in the proxy map
        if let proxyService = Self.proxyServiceMap[endpoint.baseURL] {
            return try await proxyRequest(
                endpoint: endpoint,
                service: proxyService,
                responseType: responseType,
                cacheTTL: cacheTTL
            )
        }

        let urlRequest = try endpoint.asURLRequest()

        var lastError: Error?
        for attempt in 0..<maxRetries {
            AppLogger.shared.logRequest(urlRequest)

            do {
                let (data, response) = try await session.data(for: urlRequest)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AppError.invalidResponse
                }

                AppLogger.shared.logResponse(httpResponse, data: data, error: nil)

                // Retry on 429 (rate limited) with exponential backoff
                if httpResponse.statusCode == 429 {
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                        .flatMap(Double.init) ?? (baseRetryDelay * pow(2, Double(attempt)))
                    logWarning("Rate limited (429), retrying in \(retryAfter)s (attempt \(attempt + 1)/\(maxRetries))", category: .network)
                    try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                    continue
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    let errorMessage = try? JSONDecoder().decode(APIErrorResponse.self, from: data).message
                    throw AppError.from(httpStatusCode: httpResponse.statusCode, message: errorMessage)
                }

                // Cache successful response
                if let ttl = cacheTTL {
                    cacheData(data, for: endpoint, ttl: ttl)
                }

                return try decode(data, as: responseType)
            } catch let error as AppError {
                throw error
            } catch let error as URLError {
                AppLogger.shared.logResponse(nil, data: nil, error: error)
                throw mapURLError(error)
            } catch {
                lastError = error
                AppLogger.shared.logResponse(nil, data: nil, error: error)
                throw AppError.networkError(underlying: error)
            }
        }

        // All retries exhausted (only reachable for 429s)
        throw lastError ?? AppError.rateLimitExceeded
    }

    // MARK: - Request with Raw Data Response
    func requestData(endpoint: APIEndpoint) async throws -> Data {
        // Route through API proxy if applicable
        if let proxyService = Self.proxyServiceMap[endpoint.baseURL] {
            return try await APIProxy.shared.request(
                service: proxyService,
                path: endpoint.path,
                method: endpoint.method.rawValue,
                queryItems: endpoint.queryParameters
            )
        }

        let request = try endpoint.asURLRequest()
        AppLogger.shared.logRequest(request)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidResponse
        }

        AppLogger.shared.logResponse(httpResponse, data: data, error: nil)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AppError.from(httpStatusCode: httpResponse.statusCode)
        }

        return data
    }

    // MARK: - Proxy Request (with caching and retry)
    private func proxyRequest<T: Decodable>(
        endpoint: APIEndpoint,
        service: APIProxy.Service,
        responseType: T.Type,
        cacheTTL: TimeInterval?
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                let data: Data
                if let body = endpoint.body {
                    // POST request with body (e.g., TAAPI bulk)
                    data = try await APIProxy.shared.request(
                        service: service,
                        path: endpoint.path,
                        queryItems: endpoint.queryParameters,
                        body: RawJSON(data: body)
                    )
                } else {
                    data = try await APIProxy.shared.request(
                        service: service,
                        path: endpoint.path,
                        method: endpoint.method.rawValue,
                        queryItems: endpoint.queryParameters
                    )
                }

                // Cache successful response
                if let ttl = cacheTTL {
                    cacheData(data, for: endpoint, ttl: ttl)
                }

                return try decode(data, as: responseType)
            } catch let error as APIProxyError {
                if case .httpError(let code, _) = error, code == 429 {
                    let delay = baseRetryDelay * pow(2, Double(attempt))
                    logWarning("Rate limited (429) via proxy, retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetries))", category: .network)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    lastError = error
                    continue
                }
                throw AppError.networkError(underlying: error)
            } catch {
                throw AppError.networkError(underlying: error)
            }
        }

        throw lastError ?? AppError.rateLimitExceeded
    }

    // MARK: - Cache Management
    private func getCachedData(for endpoint: APIEndpoint, ttl: TimeInterval) -> Data? {
        let key = cacheKey(for: endpoint)
        guard let cached = cache[key] else { return nil }

        let isValid = Date().timeIntervalSince(cached.timestamp) < ttl
        if isValid {
            return cached.data
        }

        cache.removeValue(forKey: key)
        return nil
    }

    private func cacheData(_ data: Data, for endpoint: APIEndpoint, ttl: TimeInterval) {
        // Evict expired entries before adding
        if cache.count >= maxCacheEntries {
            clearExpiredCache()
        }
        // If still over limit, remove oldest entries
        if cache.count >= maxCacheEntries {
            let sorted = cache.sorted { $0.value.timestamp < $1.value.timestamp }
            let toRemove = cache.count - maxCacheEntries + 1
            for (key, _) in sorted.prefix(toRemove) {
                cache.removeValue(forKey: key)
            }
        }
        let key = cacheKey(for: endpoint)
        cache[key] = CachedResponse(data: data, timestamp: Date(), ttl: ttl)
    }

    private func cacheKey(for endpoint: APIEndpoint) -> String {
        var key = endpoint.baseURL + endpoint.path
        if let params = endpoint.queryParameters?.sorted(by: { $0.key < $1.key }) {
            key += params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        }
        return key
    }

    func clearCache() {
        cache.removeAll()
    }

    func clearExpiredCache() {
        let now = Date()
        cache = cache.filter { _, value in
            now.timeIntervalSince(value.timestamp) < value.ttl
        }
    }

    // MARK: - Type-Inferred Request
    /// Convenience method that infers the response type from the return type
    func request<T: Decodable>(_ endpoint: APIEndpoint, cacheTTL: TimeInterval? = nil) async throws -> T {
        return try await request(endpoint: endpoint, responseType: T.self, cacheTTL: cacheTTL)
    }

    // MARK: - Helpers
    private func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        // Don't use .convertFromSnakeCase - models have explicit CodingKeys
        // Use custom ISO8601 formatter that handles fractional seconds
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            // Try with fractional seconds first
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            // Fall back to standard ISO8601
            let standardFormatter = ISO8601DateFormatter()
            if let date = standardFormatter.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }

        do {
            return try decoder.decode(type, from: data)
        } catch {
            logError("Decoding error for \(type): \(error)", category: .network)
            throw AppError.decodingError(underlying: error)
        }
    }

    private func mapURLError(_ error: URLError) -> AppError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noInternetConnection
        case .timedOut:
            return .timeout
        case .badURL:
            return .invalidURL
        case .cancelled:
            // SSLPinningDelegate cancels the auth challenge on pin mismatch,
            // which surfaces as URLError.cancelled
            if let host = error.failingURL?.host,
               SSLPinningConfiguration.pins(for: host) != nil {
                return .sslPinningFailure(domain: host)
            }
            return .networkError(underlying: error)
        case .serverCertificateUntrusted,
             .serverCertificateHasBadDate,
             .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid:
            return .sslPinningFailure(domain: error.failingURL?.host ?? "unknown")
        default:
            return .networkError(underlying: error)
        }
    }
}

// MARK: - API Error Response
struct APIErrorResponse: Decodable {
    let message: String?
    let error: String?
    let code: Int?
}

// MARK: - Network Monitor
@MainActor
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private(set) var isConnected = true
    private(set) var connectionType: ConnectionType = .unknown

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.arkline.networkMonitor")

    enum ConnectionType {
        case wifi
        case cellular
        case wired
        case unknown
    }

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateConnectionStatus(path: path)
            }
        }
        monitor.start(queue: queue)
    }

    private func updateConnectionStatus(path: NWPath) {
        isConnected = path.status == .satisfied

        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wired
        } else {
            connectionType = .unknown
        }
    }

    deinit {
        monitor.cancel()
    }
}
