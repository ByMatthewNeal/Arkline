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
    case sslPinningFailure(domain: String)

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

    // MARK: - General Errors
    case unknown(message: String?)
    case custom(message: String)
    case notFound
    case notImplemented

    // MARK: - Error Description
    var errorDescription: String? {
        switch self {
        // Network
        case .networkError:
            return "Unable to connect. Check your connection and try again."
        case .invalidURL:
            return "Something went wrong. Please try again."
        case .invalidResponse:
            return "We got an unexpected response. Pull to refresh."
        case .httpError(let statusCode, let message):
            if let message = message { return message }
            switch statusCode {
            case 400: return "Something went wrong with that request."
            case 403: return "You don't have access to this content."
            case 500...599: return "Server is having issues. Try again shortly."
            default: return "Something went wrong. Please try again."
            }
        case .decodingError:
            return "We had trouble reading the data. Pull to refresh."
        case .encodingError:
            return "Something went wrong saving your data. Please try again."
        case .timeout:
            return "The request timed out. Check your connection and try again."
        case .noInternetConnection:
            return "No internet connection. Check your Wi-Fi or cellular data."
        case .sslPinningFailure:
            return "Secure connection failed. Make sure you're on a trusted network."

        // Authentication
        case .authenticationRequired:
            return "Please sign in to continue."
        case .invalidCredentials:
            return "Incorrect email or password. Please try again."
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .accountNotFound:
            return "No account found with that email."
        case .emailNotVerified:
            return "Please check your email and verify your account."
        case .invalidVerificationCode:
            return "That code isn't right. Check your email and try again."
        case .userAlreadyExists:
            return "An account with this email already exists. Try signing in."
        case .weakPassword:
            return "Password is too weak. Use at least 8 characters with a mix of letters and numbers."
        case .biometricNotAvailable:
            return "Biometric authentication isn't available on this device."
        case .biometricFailed:
            return "Biometric authentication failed. Try again or use your passcode."
        case .passcodeInvalid:
            return "Incorrect passcode."

        // Data
        case .dataNotFound:
            return "Couldn't find the requested data. Pull to refresh."
        case .invalidData:
            return "Something went wrong with the data. Pull to refresh."
        case .cacheError:
            return "Couldn't load cached data. Pull to refresh for the latest."
        case .syncError:
            return "Sync failed. Check your connection and try again."

        // Portfolio
        case .portfolioNotFound:
            return "Portfolio not found. It may have been deleted."
        case .holdingNotFound:
            return "Holding not found. It may have been removed."
        case .transactionFailed:
            return "Transaction failed. Please check the details and try again."
        case .insufficientFunds:
            return "Insufficient funds for this transaction."
        case .invalidAmount:
            return "Please enter a valid amount."

        // API
        case .rateLimitExceeded:
            return "Too many requests. Please wait a moment and try again."
        case .apiKeyInvalid:
            return "Service configuration error. Please contact support."
        case .apiUnavailable:
            return "Service temporarily unavailable. Try again shortly."
        case .quotaExceeded:
            return "Daily data limit reached. Try again tomorrow."

        // Supabase
        case .supabaseError(let message):
            return message

        // General
        case .unknown:
            return "Something went wrong. Pull to refresh or try again."
        case .custom(let message):
            return message
        case .notFound:
            return "Couldn't find what you're looking for."
        case .notImplemented:
            return "This feature is coming soon."
        }
    }

    // MARK: - Recovery Suggestion
    var recoverySuggestion: String? {
        switch self {
        case .noInternetConnection, .timeout, .networkError:
            return "Check your connection and pull to refresh."
        case .sessionExpired, .authenticationRequired:
            return "Sign in again to continue."
        case .rateLimitExceeded, .apiUnavailable:
            return "Wait a moment, then pull to refresh."
        case .biometricNotAvailable, .biometricFailed:
            return "Use your passcode instead."
        case .sslPinningFailure:
            return "Switch to a trusted network and try again."
        case .decodingError, .invalidResponse, .dataNotFound, .invalidData, .cacheError:
            return "Pull to refresh for the latest data."
        case .syncError:
            return "Check your connection and try again."
        case .quotaExceeded:
            return "Data limits reset daily."
        default:
            return nil
        }
    }

    // MARK: - Is Recoverable
    var isRecoverable: Bool {
        switch self {
        case .timeout, .noInternetConnection, .rateLimitExceeded, .apiUnavailable,
             .networkError, .decodingError, .invalidResponse, .dataNotFound,
             .cacheError, .syncError:
            return true
        default:
            return false
        }
    }
}

// MARK: - Error Conversion
extension AppError {
    /// Convert any Error into a user-friendly AppError.
    /// Maps common system errors (URLError, etc.) to appropriate cases
    /// instead of exposing raw localizedDescription strings to users.
    static func from(_ error: Error) -> AppError {
        // Already an AppError — return as-is
        if let appError = error as? AppError { return appError }

        // Map URLError to specific cases
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return .noInternetConnection
            case .timedOut:
                return .timeout
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return .networkError(underlying: nil)
            case .serverCertificateUntrusted:
                return .sslPinningFailure(domain: urlError.failingURL?.host ?? "unknown")
            default:
                return .networkError(underlying: nil)
            }
        }

        // Map decoding errors
        if error is DecodingError {
            return .decodingError(underlying: error)
        }

        // Map encoding errors
        if error is EncodingError {
            return .encodingError(underlying: error)
        }

        // Catch-all — do NOT expose raw localizedDescription
        return .unknown(message: nil)
    }

    /// User-facing message suitable for display in alerts and error views.
    var userMessage: String {
        errorDescription ?? "Something went wrong. Please try again."
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
