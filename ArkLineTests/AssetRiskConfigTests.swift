import XCTest
@testable import ArkLine

final class AssetRiskConfigTests: XCTestCase {

    // MARK: - All Configs

    func testAllConfigs_count() {
        XCTAssertEqual(AssetRiskConfig.allConfigs.count, 8)
    }

    func testAllConfigs_uniqueSymbols() {
        let symbols = AssetRiskConfig.allConfigs.map { $0.assetId }
        XCTAssertEqual(Set(symbols).count, symbols.count, "Duplicate symbols found")
    }

    func testAllConfigs_uniqueGeckoIds() {
        let geckoIds = AssetRiskConfig.allConfigs.map { $0.geckoId }
        XCTAssertEqual(Set(geckoIds).count, geckoIds.count, "Duplicate geckoIds found")
    }

    // MARK: - forCoin Lookup

    func testForCoin_uppercase() {
        XCTAssertNotNil(AssetRiskConfig.forCoin("BTC"))
        XCTAssertEqual(AssetRiskConfig.forCoin("BTC")?.geckoId, "bitcoin")
    }

    func testForCoin_lowercase() {
        XCTAssertNotNil(AssetRiskConfig.forCoin("btc"))
        XCTAssertEqual(AssetRiskConfig.forCoin("btc")?.geckoId, "bitcoin")
    }

    func testForCoin_mixedCase() {
        XCTAssertNotNil(AssetRiskConfig.forCoin("Btc"))
    }

    func testForCoin_unsupported_returnsNil() {
        XCTAssertNil(AssetRiskConfig.forCoin("DOGE"))
        XCTAssertNil(AssetRiskConfig.forCoin("XRP"))
        XCTAssertNil(AssetRiskConfig.forCoin(""))
    }

    func testForCoin_allSupported() {
        let symbols = ["BTC", "ETH", "SOL", "BNB", "UNI", "RENDER", "SUI", "ONDO"]
        for symbol in symbols {
            XCTAssertNotNil(AssetRiskConfig.forCoin(symbol), "\(symbol) should be supported")
        }
    }

    // MARK: - forGeckoId Lookup

    func testForGeckoId_lowercase() {
        XCTAssertNotNil(AssetRiskConfig.forGeckoId("bitcoin"))
        XCTAssertEqual(AssetRiskConfig.forGeckoId("bitcoin")?.assetId, "BTC")
    }

    func testForGeckoId_unsupported_returnsNil() {
        XCTAssertNil(AssetRiskConfig.forGeckoId("dogecoin"))
        XCTAssertNil(AssetRiskConfig.forGeckoId(""))
    }

    // MARK: - isSupported

    func testIsSupported_allAssets() {
        let symbols = ["BTC", "ETH", "SOL", "BNB", "UNI", "RENDER", "SUI", "ONDO"]
        for symbol in symbols {
            XCTAssertTrue(AssetRiskConfig.isSupported(symbol), "\(symbol) should be supported")
        }
    }

    func testIsSupported_unsupported() {
        XCTAssertFalse(AssetRiskConfig.isSupported("DOGE"))
        XCTAssertFalse(AssetRiskConfig.isSupported(""))
    }

    // MARK: - geckoId Mapping

    func testGeckoId_forSymbol() {
        XCTAssertEqual(AssetRiskConfig.geckoId(for: "BTC"), "bitcoin")
        XCTAssertEqual(AssetRiskConfig.geckoId(for: "ETH"), "ethereum")
        XCTAssertEqual(AssetRiskConfig.geckoId(for: "SOL"), "solana")
    }

    func testGeckoId_unsupported_returnsNil() {
        XCTAssertNil(AssetRiskConfig.geckoId(for: "DOGE"))
    }

    // MARK: - Dictionary Lookups

    func testBySymbol_count() {
        XCTAssertEqual(AssetRiskConfig.bySymbol.count, 8)
    }

    func testByGeckoId_count() {
        XCTAssertEqual(AssetRiskConfig.byGeckoId.count, 8)
    }

    func testCoinGeckoIds_count() {
        XCTAssertEqual(AssetRiskConfig.coinGeckoIds.count, 8)
    }

    func testCoinGeckoIds_consistency() {
        for config in AssetRiskConfig.allConfigs {
            XCTAssertEqual(AssetRiskConfig.coinGeckoIds[config.assetId], config.geckoId)
        }
    }

    // MARK: - Config Properties

    func testBTC_originDate() {
        let btc = AssetRiskConfig.btc
        let components = Calendar.current.dateComponents([.year, .month, .day], from: btc.originDate)
        XCTAssertEqual(components.year, 2009)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 3)
    }

    func testDeviationBounds_symmetric() {
        for config in AssetRiskConfig.allConfigs {
            XCTAssertEqual(abs(config.deviationBounds.low), config.deviationBounds.high, accuracy: 0.001,
                           "\(config.assetId) bounds should be symmetric")
        }
    }

    func testDeviationBounds_positive() {
        for config in AssetRiskConfig.allConfigs {
            XCTAssertGreaterThan(config.deviationBounds.high, 0, "\(config.assetId) high bound should be positive")
            XCTAssertLessThan(config.deviationBounds.low, 0, "\(config.assetId) low bound should be negative")
        }
    }

    func testConfidenceLevels_btcHighest() {
        XCTAssertEqual(AssetRiskConfig.btc.confidenceLevel, 9)
        XCTAssertGreaterThan(AssetRiskConfig.btc.confidenceLevel, AssetRiskConfig.eth.confidenceLevel)
    }

    func testConfidenceLevels_range() {
        for config in AssetRiskConfig.allConfigs {
            XCTAssertGreaterThanOrEqual(config.confidenceLevel, 1)
            XCTAssertLessThanOrEqual(config.confidenceLevel, 9)
        }
    }

    func testAllConfigs_haveBinanceSymbol() {
        for config in AssetRiskConfig.allConfigs {
            XCTAssertNotNil(config.binanceSymbol, "\(config.assetId) should have a Binance symbol")
        }
    }

    func testAllConfigs_haveDisplayName() {
        for config in AssetRiskConfig.allConfigs {
            XCTAssertFalse(config.displayName.isEmpty, "\(config.assetId) should have a display name")
        }
    }
}
