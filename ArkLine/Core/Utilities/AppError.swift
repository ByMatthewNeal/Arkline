import Foundation

// MARK: - App Error
enum AppError: Error, LocalizedError {
    // MARK: - Network Errors
    case networkError(underlying: Error?)
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(underlying: Error?)
    case encodingError(underlying: Error?)
    case timeout
    case noInternetConnection

    // MARK: - Authentication Errors
    case authenticationRequired
    case invalidCredentials
    case sessionExpired
    case accountNotFound
    case emailNotVerified
    case invalidVerificationCode
    case userAlreadyExists
    case weakPassword
    case biometricNotAvailable
    case biometricFailed
    case passcodeInvalid

    // MARK: - Data Errors
    case dataNotFound
    case invalidData
    case cacheError
    case syncError

    // MARK: - Portfolio Errors
    case portfolioNotFound
    case holdingNotFound
    case transactionFailed
    case insufficientFunds
    case invalidAmount

    // MARK: - API Specific Errors
    case rateLimitExceeded
    case apiKeyInvalid
    case apiUnavailable
    case quotaExceeded

    // MARK: - Supabase Errors
    case supabaseError(message: String)

    // MARK: - AI Chat Errors
    case chatSessionNotFound
    case messageFailedToSend
    case aiServiceUnavailable

    // MARK: - General Errors
    case unknown(message: String?)
    case custom(message: String)
    case notFound
    case notImplemented

    // MARK: - Error Description
    var errorDescription: String? {
        switch self {
        // Network
        case .networkError(let underlying):
            return underlying?.localizedDescription ?? "A network error occurred"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, let message):
            return message ?? "HTTP Error: \(statusCode)"
        case .decodingError:
            return "Failed to decode response"
        case .encodingError:
            return "Failed to encode request"
        case .timeout:
            return "Request timed out"
        case .noInternetConnection:
            return "No internet connection"

        // Authentication
        case .authenticationRequired:
            return "Authentication required"
        case .invalidCredentials:
            return "Invalid email or password"
        case .sessionExpired:
            return "Your session has expired. Please log in again"
        case .accountNotFound:
            return "Account not found"
        case .emailNotVerified:
            return "Please verify your email address"
        case .invalidVerificationCode:
            return "Invalid verification code"
        case .userAlreadyExists:
            return "An account with this email already exists"
        case .weakPassword:
            return "Password is too weak"
        case .biometricNotAvailable:
            return "Biometric authentication is not available"
        case .biometricFailed:
            return "Biometric authentication failed"
        case .passcodeInvalid:
            return "Invalid passcode"

        // Data
        case .dataNotFound:
            return "Data not found"
        case .invalidData:
            return "Invalid data"
        case .cacheError:
            return "Cache error"
        case .syncError:
            return "Sync failed"

        // Portfolio
        case .portfolioNotFound:
            return "Portfolio not found"
        case .holdingNotFound:
            return "Holding not found"
        case .transactionFailed:
            return "Transaction failed"
        case .insufficientFunds:
            return "Insufficient funds"
        case .invalidAmount:
            return "Invalid amount"

        // API
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later"
        case .apiKeyInvalid:
            return "Invalid API key"
        case .apiUnavailable:
            return "Service temporarily unavailable"
        case .quotaExceeded:
            return "API quota exceeded"

        // Supabase
        case .supabaseError(let message):
            return message

        // AI Chat
        case .chatSessionNotFound:
            return "Chat session not found"
        case .messageFailedToSend:
            return "Failed to send message"
        case .aiServiceUnavailable:
            return "AI service is currently unavailable"

        // General
        case .unknown(let message):
            return message ?? "An unknown error occurred"
        case .custom(let message):
            return message
        case .notFound:
            return "Resource not found"
        case .notImplemented:
            return "This feature is not yet implemented"
        }
    }

    // MARK: - Recovery Suggestion
    var recoverySuggestion: String? {
        switch self {
        case .noInternetConnection:
            return "Please check your internet connection and try again"
        case .sessionExpired, .authenticationRequired:
            return "Please log in again to continue"
        case .rateLimitExceeded:
            return "Please wait a moment before trying again"
        case .timeout:
            return "Please check your connection and try again"
        case .biometricNotAvailable:
            return "Please use your passcode instead"
        case .notImplemented:
            return "This feature is coming soon"
        default:
            return nil
        }
    }

    // MARK: - Is Recoverable
    var isRecoverable: Bool {
        switch self {
        case .timeout, .noInternetConnection, .rateLimitExceeded, .apiUnavailable:
            return true
        case .notImplemented:
            return false
        default:
            return false
        }
    }
}

// MARK: - HTTP Status Code Mapping
extension AppError {
    static func from(httpStatusCode: Int, message: String? = nil) -> AppError {
        switch httpStatusCode {
        case 400:
            return .httpError(statusCode: httpStatusCode, message: message ?? "Bad Request")
        case 401:
            return .authenticationRequired
        case 403:
            return .httpError(statusCode: httpStatusCode, message: message ?? "Forbidden")
        case 404:
            return .dataNotFound
        case 429:
            return .rateLimitExceeded
        case 500...599:
            return .apiUnavailable
        default:
            return .httpError(statusCode: httpStatusCode, message: message)
        }
    }
}
