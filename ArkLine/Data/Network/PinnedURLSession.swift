import Foundation

// MARK: - Pinned URL Session
/// Provides a shared URLSession with SSL certificate pinning.
/// All network requests should use this instead of URLSession.shared.
/// Unpinned domains pass through with standard TLS validation.
enum PinnedURLSession {
    static let shared: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        return URLSession(
            configuration: configuration,
            delegate: SSLPinningDelegate(),
            delegateQueue: nil
        )
    }()
}
