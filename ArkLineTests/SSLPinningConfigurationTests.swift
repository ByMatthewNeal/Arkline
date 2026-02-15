import XCTest
@testable import ArkLine

final class SSLPinningConfigurationTests: XCTestCase {

    // MARK: - Domain Lookup

    func testPins_binanceSpotAPI() {
        let pins = SSLPinningConfiguration.pins(for: "api.binance.com")
        XCTAssertNotNil(pins)
        XCTAssertEqual(pins?.count, 2, "Should have leaf + intermediate backup")
    }

    func testPins_binanceFuturesAPI() {
        let pins = SSLPinningConfiguration.pins(for: "fapi.binance.com")
        XCTAssertNotNil(pins)
        XCTAssertEqual(pins?.count, 2)
    }

    func testPins_unpinnedDomain_returnsNil() {
        XCTAssertNil(SSLPinningConfiguration.pins(for: "google.com"))
        XCTAssertNil(SSLPinningConfiguration.pins(for: "api.coingecko.com"))
        XCTAssertNil(SSLPinningConfiguration.pins(for: ""))
    }

    func testPins_caseInsensitive() {
        XCTAssertNotNil(SSLPinningConfiguration.pins(for: "API.BINANCE.COM"))
        XCTAssertNotNil(SSLPinningConfiguration.pins(for: "Api.Binance.Com"))
    }

    func testPins_subdomainMatching() {
        // "sub.api.binance.com" should match because it ends with ".api.binance.com"
        let pins = SSLPinningConfiguration.pins(for: "sub.api.binance.com")
        XCTAssertNotNil(pins)
    }

    func testPins_bothBinanceDomains_shareSameHashes() {
        let spotPins = SSLPinningConfiguration.pins(for: "api.binance.com")
        let futuresPins = SSLPinningConfiguration.pins(for: "fapi.binance.com")
        XCTAssertNotNil(spotPins)
        XCTAssertNotNil(futuresPins)
        XCTAssertEqual(spotPins, futuresPins)
    }

    func testPins_partialDomainDoesNotMatch() {
        // "binance.com" alone is not pinned (only api.binance.com and fapi.binance.com)
        XCTAssertNil(SSLPinningConfiguration.pins(for: "binance.com"))
    }

    // MARK: - Pin Hashes Format

    func testPinnedDomains_hashesAreBase64() {
        for (_, hashes) in SSLPinningConfiguration.pinnedDomains {
            for hash in hashes {
                // Base64 strings use A-Z, a-z, 0-9, +, /, and = for padding
                let base64Regex = #"^[A-Za-z0-9+/]+=*$"#
                XCTAssertTrue(hash.range(of: base64Regex, options: .regularExpression) != nil,
                              "Hash '\(hash)' should be valid base64")
            }
        }
    }

    func testPinnedDomains_hashesAreNonEmpty() {
        for (domain, hashes) in SSLPinningConfiguration.pinnedDomains {
            XCTAssertFalse(hashes.isEmpty, "\(domain) should have at least one hash")
            for hash in hashes {
                XCTAssertFalse(hash.isEmpty, "Hash for \(domain) should not be empty")
            }
        }
    }

    // MARK: - Debug Override

    func testEnforcePinningInDebug_defaultsFalse() {
        XCTAssertFalse(SSLPinningConfiguration.enforcePinningInDebug)
    }

    func testEnforcePinningInDebug_toggleable() {
        let original = SSLPinningConfiguration.enforcePinningInDebug
        SSLPinningConfiguration.enforcePinningInDebug = true
        XCTAssertTrue(SSLPinningConfiguration.enforcePinningInDebug)
        // Restore
        SSLPinningConfiguration.enforcePinningInDebug = original
    }
}
