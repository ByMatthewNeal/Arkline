import Foundation

// MARK: - SSL Pinning Delegate
/// URLSessionDelegate that performs SPKI hash pinning for configured domains.
/// Domains not in the pin database receive standard TLS validation.
final class SSLPinningDelegate: NSObject, URLSessionDelegate {

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host

        // Unpinned domain — use standard TLS validation
        guard let expectedPins = SSLPinningConfiguration.pins(for: host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Step 1: Standard TLS validation (chain, expiry, hostname)
        let policy = SecPolicyCreateSSL(true, host as CFString)
        SecTrustSetPolicies(serverTrust, policy)

        var secError: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &secError) else {
            logError("SSL pinning: TLS validation failed for \(host): \(secError?.localizedDescription ?? "unknown")", category: .network)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Step 2: SPKI hash pinning — check every certificate in the chain
        guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            logError("SSL pinning: Could not copy certificate chain for \(host)", category: .network)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        for certificate in chain {
            if let hash = SSLPinningConfiguration.spkiHash(for: certificate),
               expectedPins.contains(hash) {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }

        // No pin matched
        let chainHashes = chain.compactMap { SSLPinningConfiguration.spkiHash(for: $0) }
        AppLogger.shared.critical(
            "SSL PINNING FAILURE for \(host). Expected: \(expectedPins). Got: \(chainHashes).",
            category: .network
        )

        #if DEBUG
        if !SSLPinningConfiguration.enforcePinningInDebug {
            logWarning("SSL pinning: DEBUG mode — allowing connection to \(host) despite pin mismatch", category: .network)
            completionHandler(.performDefaultHandling, nil)
            return
        }
        #endif

        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}
