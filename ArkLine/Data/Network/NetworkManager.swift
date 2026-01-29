import Foundation

// MARK: - Network Manager
actor NetworkManager {
    // MARK: - Singleton
    static let shared = NetworkManager()

    // MARK: - Properties
    private let session: URLSession
    private var cache: [String: CachedResponse] = [:]

    // MARK: - Cache Entry
    private struct CachedResponse {
        let data: Data
        let timestamp: Date
        let ttl: TimeInterval
    }

    // MARK: - Init
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .returnCacheDataElseLoad

        self.session = URLSession(configuration: configuration)
    }

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

        let request = try endpoint.asURLRequest()
        AppLogger.shared.logRequest(request)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.invalidResponse
            }

            AppLogger.shared.logResponse(httpResponse, data: data, error: nil)

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
            AppLogger.shared.logResponse(nil, data: nil, error: error)
            throw AppError.networkError(underlying: error)
        }
    }

    // MARK: - Request with Raw Data Response
    func requestData(endpoint: APIEndpoint) async throws -> Data {
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
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            // Try with fractional seconds first
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
            print("DEBUG: Decoding error for \(type): \(error)")
            logDebug("Decoding error: \(error)", category: .network)
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
        // In a real app, use NWPathMonitor
        // For now, assume connected
        isConnected = true
        connectionType = .wifi
    }
}
