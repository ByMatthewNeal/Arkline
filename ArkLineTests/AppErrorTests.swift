import XCTest
@testable import ArkLine

final class AppErrorTests: XCTestCase {

    // MARK: - Error Descriptions

    func testAllErrors_haveDescription() {
        let errors: [AppError] = [
            .networkError(underlying: nil),
            .invalidURL,
            .invalidResponse,
            .httpError(statusCode: 400, message: nil),
            .decodingError(underlying: nil),
            .encodingError(underlying: nil),
            .timeout,
            .noInternetConnection,
            .sslPinningFailure(domain: "example.com"),
            .authenticationRequired,
            .invalidCredentials,
            .sessionExpired,
            .accountNotFound,
            .emailNotVerified,
            .invalidVerificationCode,
            .userAlreadyExists,
            .weakPassword,
            .biometricNotAvailable,
            .biometricFailed,
            .passcodeInvalid,
            .dataNotFound,
            .invalidData,
            .cacheError,
            .syncError,
            .portfolioNotFound,
            .holdingNotFound,
            .transactionFailed,
            .insufficientFunds,
            .invalidAmount,
            .rateLimitExceeded,
            .apiKeyInvalid,
            .apiUnavailable,
            .quotaExceeded,
            .supabaseError(message: "test"),
            .unknown(message: nil),
            .custom(message: "test"),
            .notFound,
            .notImplemented,
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "\(error) should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "\(error) description should not be empty")
        }
    }

    // MARK: - HTTP Status Code Mapping

    func testFromHTTP_400_badRequest() {
        let error = AppError.from(httpStatusCode: 400)
        if case .httpError(let code, let message) = error {
            XCTAssertEqual(code, 400)
            XCTAssertEqual(message, "Bad Request")
        } else {
            XCTFail("Expected httpError")
        }
    }

    func testFromHTTP_401_authRequired() {
        let error = AppError.from(httpStatusCode: 401)
        if case .authenticationRequired = error {
            // pass
        } else {
            XCTFail("Expected authenticationRequired, got \(error)")
        }
    }

    func testFromHTTP_403_forbidden() {
        let error = AppError.from(httpStatusCode: 403)
        if case .httpError(let code, _) = error {
            XCTAssertEqual(code, 403)
        } else {
            XCTFail("Expected httpError")
        }
    }

    func testFromHTTP_404_dataNotFound() {
        let error = AppError.from(httpStatusCode: 404)
        if case .dataNotFound = error {
            // pass
        } else {
            XCTFail("Expected dataNotFound, got \(error)")
        }
    }

    func testFromHTTP_429_rateLimited() {
        let error = AppError.from(httpStatusCode: 429)
        if case .rateLimitExceeded = error {
            // pass
        } else {
            XCTFail("Expected rateLimitExceeded, got \(error)")
        }
    }

    func testFromHTTP_500_apiUnavailable() {
        let error = AppError.from(httpStatusCode: 500)
        if case .apiUnavailable = error {
            // pass
        } else {
            XCTFail("Expected apiUnavailable, got \(error)")
        }
    }

    func testFromHTTP_503_apiUnavailable() {
        let error = AppError.from(httpStatusCode: 503)
        if case .apiUnavailable = error {
            // pass
        } else {
            XCTFail("Expected apiUnavailable, got \(error)")
        }
    }

    func testFromHTTP_unknownCode() {
        let error = AppError.from(httpStatusCode: 418)
        if case .httpError(let code, _) = error {
            XCTAssertEqual(code, 418)
        } else {
            XCTFail("Expected httpError")
        }
    }

    func testFromHTTP_customMessage() {
        let error = AppError.from(httpStatusCode: 400, message: "Custom error")
        if case .httpError(_, let message) = error {
            XCTAssertEqual(message, "Custom error")
        } else {
            XCTFail("Expected httpError")
        }
    }

    // MARK: - isRecoverable

    func testIsRecoverable_trueForTransient() {
        XCTAssertTrue(AppError.timeout.isRecoverable)
        XCTAssertTrue(AppError.noInternetConnection.isRecoverable)
        XCTAssertTrue(AppError.rateLimitExceeded.isRecoverable)
        XCTAssertTrue(AppError.apiUnavailable.isRecoverable)
    }

    func testIsRecoverable_falseForPermanent() {
        XCTAssertFalse(AppError.notImplemented.isRecoverable)
        XCTAssertFalse(AppError.invalidURL.isRecoverable)
        XCTAssertFalse(AppError.invalidCredentials.isRecoverable)
        XCTAssertFalse(AppError.dataNotFound.isRecoverable)
        XCTAssertFalse(AppError.sslPinningFailure(domain: "test.com").isRecoverable)
    }

    // MARK: - Recovery Suggestions

    func testRecoverySuggestion_exists() {
        XCTAssertNotNil(AppError.noInternetConnection.recoverySuggestion)
        XCTAssertNotNil(AppError.sessionExpired.recoverySuggestion)
        XCTAssertNotNil(AppError.authenticationRequired.recoverySuggestion)
        XCTAssertNotNil(AppError.rateLimitExceeded.recoverySuggestion)
        XCTAssertNotNil(AppError.timeout.recoverySuggestion)
        XCTAssertNotNil(AppError.biometricNotAvailable.recoverySuggestion)
        XCTAssertNotNil(AppError.sslPinningFailure(domain: "test.com").recoverySuggestion)
        XCTAssertNotNil(AppError.notImplemented.recoverySuggestion)
    }

    func testRecoverySuggestion_nilForMostErrors() {
        XCTAssertNil(AppError.invalidURL.recoverySuggestion)
        XCTAssertNil(AppError.invalidCredentials.recoverySuggestion)
        XCTAssertNil(AppError.dataNotFound.recoverySuggestion)
        XCTAssertNil(AppError.invalidData.recoverySuggestion)
    }

    // MARK: - Specific Error Messages

    func testSSLPinningFailure_containsDomain() {
        let error = AppError.sslPinningFailure(domain: "api.binance.com")
        XCTAssertTrue(error.errorDescription!.contains("api.binance.com"))
    }

    func testCustomMessage_passthrough() {
        let error = AppError.custom(message: "Something went wrong")
        XCTAssertEqual(error.errorDescription, "Something went wrong")
    }

    func testSupabaseError_passthrough() {
        let error = AppError.supabaseError(message: "Row not found")
        XCTAssertEqual(error.errorDescription, "Row not found")
    }

    func testUnknown_withMessage() {
        let error = AppError.unknown(message: "Unexpected failure")
        XCTAssertEqual(error.errorDescription, "Unexpected failure")
    }

    func testUnknown_nilMessage() {
        let error = AppError.unknown(message: nil)
        XCTAssertEqual(error.errorDescription, "An unknown error occurred")
    }

    func testHTTPError_withMessage() {
        let error = AppError.httpError(statusCode: 422, message: "Unprocessable")
        XCTAssertEqual(error.errorDescription, "Unprocessable")
    }

    func testHTTPError_nilMessage() {
        let error = AppError.httpError(statusCode: 422, message: nil)
        XCTAssertTrue(error.errorDescription!.contains("422"))
    }
}
