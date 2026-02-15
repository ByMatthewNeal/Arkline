import Foundation
import CryptoKit

// MARK: - SSL Pinning Configuration
/// Central pin database for SSL certificate pinning.
/// Uses SHA-256 hashes of Subject Public Key Info (SPKI) — survives cert rotation
/// as long as the same key pair is reused.
enum SSLPinningConfiguration {

    // MARK: - Debug Override

    /// When true, pinning failures block requests even in DEBUG builds.
    /// Default false so development behind proxies is not disrupted.
    static var enforcePinningInDebug: Bool = false

    // MARK: - Pin Database

    /// Maps domains to base64-encoded SHA-256 SPKI hashes.
    /// Each domain has at least two pins (leaf + intermediate backup) to survive cert rotation.
    ///
    /// To generate a pin hash:
    /// ```
    /// echo | openssl s_client -connect DOMAIN:443 2>/dev/null \
    ///   | openssl x509 -pubkey -noout \
    ///   | openssl pkey -pubin -outform DER \
    ///   | openssl dgst -sha256 -binary | base64
    /// ```
    static let pinnedDomains: [String: [String]] = [
        // Binance spot API (real-time prices, klines)
        "api.binance.com": [
            "/Y6BOeqMgXS6wjqk6emFs+Y+HWkIXO2R8Dox5VO1YT0=",  // leaf
            "SDG5orEv8iX6MNenIAxa8nQFNpROB/6+llsZdXHZNqs=",  // intermediate CA backup
        ],
        // Binance futures API (funding rates)
        "fapi.binance.com": [
            "/Y6BOeqMgXS6wjqk6emFs+Y+HWkIXO2R8Dox5VO1YT0=",  // leaf (same org)
            "SDG5orEv8iX6MNenIAxa8nQFNpROB/6+llsZdXHZNqs=",  // intermediate CA backup
        ],
    ]

    // MARK: - Domain Lookup

    /// Returns valid SPKI hashes for a domain, or nil if not pinned.
    static func pins(for host: String) -> [String]? {
        let lowered = host.lowercased()
        if let exact = pinnedDomains[lowered] {
            return exact
        }
        for (domain, pins) in pinnedDomains where lowered.hasSuffix("." + domain) {
            return pins
        }
        return nil
    }

    // MARK: - SPKI Hash Extraction

    /// Extracts SHA-256 hash of the Subject Public Key Info from a SecCertificate.
    static func spkiHash(for certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate) else { return nil }

        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return nil
        }

        let spkiData = addASN1Header(to: keyData, for: publicKey)
        let hash = SHA256.hash(data: spkiData)
        return Data(hash).base64EncodedString()
    }

    // MARK: - ASN.1 Header

    /// Prepends the ASN.1 algorithm identifier to raw key bytes to form a proper SPKI structure.
    /// SecKeyCopyExternalRepresentation returns raw key data without the wrapper that openssl includes.
    private static func addASN1Header(to keyData: Data, for key: SecKey) -> Data {
        guard let attributes = SecKeyCopyAttributes(key) as? [String: Any],
              let keyType = attributes[kSecAttrKeyType as String] as? String,
              let keySize = attributes[kSecAttrKeySizeInBits as String] as? Int else {
            return keyData
        }

        let header: [UInt8]

        if keyType == (kSecAttrKeyTypeRSA as String) && keySize == 2048 {
            // RSA 2048 SPKI header
            header = [
                0x30, 0x82, 0x01, 0x22, 0x30, 0x0D, 0x06, 0x09,
                0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01,
                0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0F, 0x00
            ]
        } else if keyType == (kSecAttrKeyTypeRSA as String) && keySize == 4096 {
            // RSA 4096 SPKI header
            header = [
                0x30, 0x82, 0x02, 0x22, 0x30, 0x0D, 0x06, 0x09,
                0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01,
                0x01, 0x05, 0x00, 0x03, 0x82, 0x02, 0x0F, 0x00
            ]
        } else if keyType == (kSecAttrKeyTypeECSECPrimeRandom as String) && keySize == 256 {
            // EC P-256 SPKI header
            header = [
                0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2A, 0x86,
                0x48, 0xCE, 0x3D, 0x02, 0x01, 0x06, 0x08, 0x2A,
                0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07, 0x03,
                0x42, 0x00
            ]
        } else if keyType == (kSecAttrKeyTypeECSECPrimeRandom as String) && keySize == 384 {
            // EC P-384 SPKI header
            header = [
                0x30, 0x76, 0x30, 0x10, 0x06, 0x07, 0x2A, 0x86,
                0x48, 0xCE, 0x3D, 0x02, 0x01, 0x06, 0x05, 0x2B,
                0x81, 0x04, 0x00, 0x22, 0x03, 0x62, 0x00
            ]
        } else {
            // Unsupported key type — hash raw key data as fallback
            return keyData
        }

        var result = Data(header)
        result.append(keyData)
        return result
    }
}
