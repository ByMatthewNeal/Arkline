import Foundation
import Supabase

// MARK: - API Proxy
/// Shared proxy client that routes all external API requests through the
/// `api-proxy` Supabase Edge Function, keeping API keys server-side.
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

    // MARK: - Public API

    /// Invoke the api-proxy Edge Function for a GET request (or any request without a body).
    func request(
        service: Service,
        path: String,
        method: String = "GET",
        queryItems: [String: String]? = nil
    ) async throws -> Data {
        guard SupabaseManager.shared.isConfigured else {
            throw APIProxyError.notConfigured
        }

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

    /// Invoke the api-proxy Edge Function for a POST request with an Encodable body.
    func request<Body: Encodable>(
        service: Service,
        path: String,
        queryItems: [String: String]? = nil,
        body: Body
    ) async throws -> Data {
        guard SupabaseManager.shared.isConfigured else {
            throw APIProxyError.notConfigured
        }

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
