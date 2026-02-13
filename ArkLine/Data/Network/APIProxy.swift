import Foundation
import Supabase

// MARK: - API Proxy
/// Routes external API requests through the `api-proxy` Supabase Edge Function,
/// keeping API keys server-side. Falls back to direct HTTP with local API keys
/// from Secrets.plist when the proxy is unavailable (no auth session, Edge
/// Function down, etc.).
final class APIProxy {
    // MARK: - Singleton
    static let shared = APIProxy()

    private init() {}

    // MARK: - Service Identifiers
    enum Service: String {
        case fmp
        case coingecko
        case metals
        case taapi
        case fred
        case coinglass
        case finnhub
    }

    // MARK: - Request Types

    /// GET request payload (no body)
    private struct GetRequest: Encodable {
        let service: String
        let path: String
        let method: String
        let queryItems: [String: String]?
    }

    /// POST request payload (with body)
    private struct PostRequest<Body: Encodable>: Encodable {
        let service: String
        let path: String
        let method: String
        let queryItems: [String: String]?
        let body: Body
    }

    // MARK: - Direct Fallback Configuration

    private enum KeyInjection {
        case header(name: String)
        case queryParam(name: String)
        case dynamicCoinGeckoHeader
    }

    private struct DirectConfig {
        let baseURL: String
        let apiKey: String?
        let keyInjection: KeyInjection
    }

    private func directConfig(for service: Service) -> DirectConfig {
        switch service {
        case .coingecko:
            return DirectConfig(
                baseURL: Constants.Endpoints.coinGeckoBase,
                apiKey: Constants.API.coinGeckoAPIKey,
                keyInjection: .dynamicCoinGeckoHeader
            )
        case .fred:
            return DirectConfig(
                baseURL: Constants.Endpoints.fredBase,
                apiKey: Constants.API.fredAPIKey,
                keyInjection: .queryParam(name: "api_key")
            )
        case .metals:
            return DirectConfig(
                baseURL: Constants.Endpoints.metalsAPIBase,
                apiKey: Constants.API.metalsAPIKey,
                keyInjection: .queryParam(name: "access_key")
            )
        case .taapi:
            return DirectConfig(
                baseURL: Constants.Endpoints.taapiBase,
                apiKey: Constants.API.taapiAPIKey,
                keyInjection: .queryParam(name: "secret")
            )
        case .fmp:
            return DirectConfig(
                baseURL: Constants.Endpoints.fmpBase,
                apiKey: Constants.API.fmpAPIKey,
                keyInjection: .header(name: "apikey")
            )
        case .coinglass:
            return DirectConfig(
                baseURL: Constants.Endpoints.coinglassBase,
                apiKey: Constants.API.coinglassAPIKey,
                keyInjection: .header(name: "CG-API-KEY")
            )
        case .finnhub:
            return DirectConfig(
                baseURL: Constants.Endpoints.finnhubBase,
                apiKey: Constants.API.finnhubAPIKey,
                keyInjection: .header(name: "X-Finnhub-Token")
            )
        }
    }

    // MARK: - Public API (GET)

    /// Request data from an external API. Tries the Edge Function proxy first,
    /// falls back to a direct HTTP request with local API keys on failure.
    func request(
        service: Service,
        path: String,
        method: String = "GET",
        queryItems: [String: String]? = nil
    ) async throws -> Data {
        // Try proxy first
        if SupabaseManager.shared.isConfigured {
            do {
                return try await proxyGetRequest(service: service, path: path, method: method, queryItems: queryItems)
            } catch {
                logWarning("Proxy failed for \(service.rawValue)\(path): \(error.localizedDescription), trying direct", category: .network)
            }
        }

        // Fallback: direct HTTP with local API key
        return try await directGetRequest(service: service, path: path, method: method, queryItems: queryItems)
    }

    /// Request data with a POST body. Tries proxy first, falls back to direct.
    func request<Body: Encodable>(
        service: Service,
        path: String,
        queryItems: [String: String]? = nil,
        body: Body
    ) async throws -> Data {
        // Try proxy first
        if SupabaseManager.shared.isConfigured {
            do {
                return try await proxyPostRequest(service: service, path: path, queryItems: queryItems, body: body)
            } catch {
                logWarning("Proxy POST failed for \(service.rawValue)\(path): \(error.localizedDescription), trying direct", category: .network)
            }
        }

        // Fallback: direct HTTP with local API key
        return try await directPostRequest(service: service, path: path, queryItems: queryItems, body: body)
    }

    // MARK: - Proxy GET Request

    private func proxyGetRequest(
        service: Service,
        path: String,
        method: String,
        queryItems: [String: String]?
    ) async throws -> Data {
        let payload = GetRequest(
            service: service.rawValue,
            path: path,
            method: method,
            queryItems: queryItems
        )

        do {
            let data: Data = try await SupabaseManager.shared.functions.invoke(
                "api-proxy",
                options: FunctionInvokeOptions(body: payload),
                decode: { data, _ in data }
            )
            return data
        } catch let error as FunctionsError {
            throw mapError(error)
        }
    }

    // MARK: - Proxy POST Request

    private func proxyPostRequest<Body: Encodable>(
        service: Service,
        path: String,
        queryItems: [String: String]?,
        body: Body
    ) async throws -> Data {
        let payload = PostRequest(
            service: service.rawValue,
            path: path,
            method: "POST",
            queryItems: queryItems,
            body: body
        )

        do {
            let data: Data = try await SupabaseManager.shared.functions.invoke(
                "api-proxy",
                options: FunctionInvokeOptions(body: payload),
                decode: { data, _ in data }
            )
            return data
        } catch let error as FunctionsError {
            throw mapError(error)
        }
    }

    // MARK: - Direct GET Fallback

    private func directGetRequest(
        service: Service,
        path: String,
        method: String,
        queryItems: [String: String]?
    ) async throws -> Data {
        let config = directConfig(for: service)
        let request = try buildDirectRequest(config: config, path: path, method: method, queryItems: queryItems)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw APIProxyError.httpError(statusCode: statusCode, data: data)
        }

        return data
    }

    // MARK: - Direct POST Fallback

    private func directPostRequest<Body: Encodable>(
        service: Service,
        path: String,
        queryItems: [String: String]?,
        body: Body
    ) async throws -> Data {
        let config = directConfig(for: service)
        var request = try buildDirectRequest(config: config, path: path, method: "POST", queryItems: queryItems)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Encode body, injecting TAAPI secret into body if needed
        var bodyData = try JSONEncoder().encode(body)
        if service == .taapi, let key = config.apiKey {
            if var bodyDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] {
                bodyDict["secret"] = key
                bodyData = try JSONSerialization.data(withJSONObject: bodyDict)
            }
        }
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw APIProxyError.httpError(statusCode: statusCode, data: data)
        }

        return data
    }

    // MARK: - Build Direct URL Request

    private func buildDirectRequest(
        config: DirectConfig,
        path: String,
        method: String,
        queryItems: [String: String]?
    ) throws -> URLRequest {
        var components = URLComponents(string: config.baseURL + path)
        var items = queryItems?.map { URLQueryItem(name: $0.key, value: $0.value) } ?? []

        // Inject API key as query param if applicable
        if case .queryParam(let name) = config.keyInjection, let key = config.apiKey {
            items.append(URLQueryItem(name: name, value: key))
        }
        if !items.isEmpty {
            components?.queryItems = items
        }

        guard let url = components?.url else {
            throw APIProxyError.notConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Inject API key as header if applicable
        switch config.keyInjection {
        case .header(let name):
            if let key = config.apiKey {
                request.setValue(key, forHTTPHeaderField: name)
            }
        case .dynamicCoinGeckoHeader:
            if let key = config.apiKey {
                let headerName = key.hasPrefix("CG-") ? "x-cg-demo-api-key" : "x-cg-pro-api-key"
                request.setValue(key, forHTTPHeaderField: headerName)
            }
        case .queryParam:
            break // already handled above
        }

        return request
    }

    // MARK: - Error Mapping

    private func mapError(_ error: FunctionsError) -> APIProxyError {
        switch error {
        case .httpError(let code, let data):
            if let body = String(data: data, encoding: .utf8),
               body.contains("Unauthorized") || body.contains("Missing authorization") {
                return .unauthorized
            }
            return .httpError(statusCode: code, data: data)
        case .relayError:
            return .relayError
        }
    }
}

// MARK: - Raw JSON Wrapper
/// Wraps pre-encoded JSON Data so it can be nested inside an Encodable struct.
/// Used by NetworkManager to forward TAAPI bulk POST bodies through the proxy.
struct RawJSON: Encodable {
    let data: Data

    func encode(to encoder: Encoder) throws {
        // Parse the raw JSON and convert to a type-safe Encodable representation
        let json = try JSONSerialization.jsonObject(with: data)
        let wrapped = Self.wrap(json)
        var container = encoder.singleValueContainer()
        try container.encode(wrapped)
    }

    /// Recursively convert a JSON object (from JSONSerialization) into a type-safe Encodable
    private static func wrap(_ value: Any) -> JSONValue {
        switch value {
        case let string as String:
            return .string(string)
        case let number as NSNumber:
            // Distinguish Bool from number (NSNumber wraps both)
            if CFBooleanGetTypeID() == CFGetTypeID(number) {
                return .bool(number.boolValue)
            } else if number.doubleValue == Double(number.intValue) && !"\(number)".contains(".") {
                return .int(number.intValue)
            } else {
                return .double(number.doubleValue)
            }
        case let dict as [String: Any]:
            return .object(dict.mapValues { wrap($0) })
        case let array as [Any]:
            return .array(array.map { wrap($0) })
        case is NSNull:
            return .null
        default:
            return .null
        }
    }
}

/// Type-safe JSON value enum for encoding arbitrary JSON through Codable
private enum JSONValue: Encodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .object(let dict): try container.encode(dict)
        case .array(let arr): try container.encode(arr)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - API Proxy Error
enum APIProxyError: Error, LocalizedError {
    case notConfigured
    case unauthorized
    case httpError(statusCode: Int, data: Data)
    case relayError

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase not configured"
        case .unauthorized:
            return "Authentication required"
        case .httpError(let code, _):
            return "API proxy HTTP error: \(code)"
        case .relayError:
            return "Edge Function relay error"
        }
    }
}
