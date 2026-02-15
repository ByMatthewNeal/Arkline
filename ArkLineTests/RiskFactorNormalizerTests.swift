import XCTest
@testable import ArkLine

final class RiskFactorNormalizerTests: XCTestCase {

    // MARK: - RSI Normalization

    func testNormalizeRSI_atLowerBound() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeRSI(30), 0.0, accuracy: 0.001)
    }

    func testNormalizeRSI_atUpperBound() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeRSI(70), 1.0, accuracy: 0.001)
    }

    func testNormalizeRSI_midpoint() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeRSI(50), 0.5, accuracy: 0.001)
    }

    func testNormalizeRSI_belowRange_clampsToZero() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeRSI(0), 0.0, accuracy: 0.001)
        XCTAssertEqual(RiskFactorNormalizer.normalizeRSI(10), 0.0, accuracy: 0.001)
    }

    func testNormalizeRSI_aboveRange_clampsToOne() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeRSI(100), 1.0, accuracy: 0.001)
        XCTAssertEqual(RiskFactorNormalizer.normalizeRSI(85), 1.0, accuracy: 0.001)
    }

    func testNormalizeRSI_typicalValues() {
        // RSI 40 → (40-30)/40 = 0.25
        XCTAssertEqual(RiskFactorNormalizer.normalizeRSI(40), 0.25, accuracy: 0.001)
        // RSI 60 → (60-30)/40 = 0.75
        XCTAssertEqual(RiskFactorNormalizer.normalizeRSI(60), 0.75, accuracy: 0.001)
    }

    // MARK: - SMA Position Normalization

    func testNormalizeSMAPosition_farAbove() {
        // 25% above SMA → 0.2
        XCTAssertEqual(RiskFactorNormalizer.normalizeSMAPosition(price: 1250, sma200: 1000), 0.2)
    }

    func testNormalizeSMAPosition_slightlyAbove10Percent() {
        // 15% above → 0.3
        XCTAssertEqual(RiskFactorNormalizer.normalizeSMAPosition(price: 1150, sma200: 1000), 0.3)
    }

    func testNormalizeSMAPosition_slightlyAbove() {
        // 5% above → 0.4
        XCTAssertEqual(RiskFactorNormalizer.normalizeSMAPosition(price: 1050, sma200: 1000), 0.4)
    }

    func testNormalizeSMAPosition_slightlyBelow() {
        // 5% below → 0.6
        XCTAssertEqual(RiskFactorNormalizer.normalizeSMAPosition(price: 950, sma200: 1000), 0.6)
    }

    func testNormalizeSMAPosition_below10Percent() {
        // 15% below → 0.7
        XCTAssertEqual(RiskFactorNormalizer.normalizeSMAPosition(price: 850, sma200: 1000), 0.7)
    }

    func testNormalizeSMAPosition_farBelow() {
        // 25% below → 0.8
        XCTAssertEqual(RiskFactorNormalizer.normalizeSMAPosition(price: 750, sma200: 1000), 0.8)
    }

    func testNormalizeSMAPosition_zeroSMA_returnsHalf() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeSMAPosition(price: 100, sma200: 0), 0.5)
    }

    // MARK: - Funding Rate Normalization

    func testNormalizeFundingRate_neutral() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeFundingRate(0), 0.5, accuracy: 0.001)
    }

    func testNormalizeFundingRate_maxPositive() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeFundingRate(0.001), 1.0, accuracy: 0.001)
    }

    func testNormalizeFundingRate_maxNegative() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeFundingRate(-0.001), 0.0, accuracy: 0.001)
    }

    func testNormalizeFundingRate_clampsAbove() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeFundingRate(0.005), 1.0, accuracy: 0.001)
    }

    func testNormalizeFundingRate_typicalPositive() {
        // 0.0001 → (0.0001 + 0.001) / 0.002 = 0.55
        XCTAssertEqual(RiskFactorNormalizer.normalizeFundingRate(0.0001), 0.55, accuracy: 0.001)
    }

    // MARK: - Fear & Greed Normalization

    func testNormalizeFearGreed_zero() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeFearGreed(0), 0.0, accuracy: 0.001)
    }

    func testNormalizeFearGreed_fifty() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeFearGreed(50), 0.5, accuracy: 0.001)
    }

    func testNormalizeFearGreed_hundred() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeFearGreed(100), 1.0, accuracy: 0.001)
    }

    func testNormalizeFearGreed_clampsAbove() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeFearGreed(150), 1.0, accuracy: 0.001)
    }

    func testNormalizeFearGreed_clampsBelow() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeFearGreed(-10), 0.0, accuracy: 0.001)
    }

    // MARK: - VIX Normalization

    func testNormalizeVIX_low_complacency() {
        // VIX 10: normalized = (40-10)/30 = 1.0, adjusted = 0.3 + 1.0*0.4 = 0.7
        XCTAssertEqual(RiskFactorNormalizer.normalizeVIX(10), 0.7, accuracy: 0.001)
    }

    func testNormalizeVIX_normal() {
        // VIX 20: normalized = (40-20)/30 ≈ 0.667, adjusted = 0.3 + 0.667*0.4 ≈ 0.567
        let result = RiskFactorNormalizer.normalizeVIX(20)
        XCTAssertEqual(result, 0.567, accuracy: 0.01)
    }

    func testNormalizeVIX_high_fear() {
        // VIX 40: normalized = (40-40)/30 = 0.0, adjusted = 0.3 + 0*0.4 = 0.3
        XCTAssertEqual(RiskFactorNormalizer.normalizeVIX(40), 0.3, accuracy: 0.001)
    }

    func testNormalizeVIX_resultAlwaysInRange() {
        for vix in stride(from: 5.0, through: 80.0, by: 5.0) {
            let result = RiskFactorNormalizer.normalizeVIX(vix)
            XCTAssertGreaterThanOrEqual(result, 0.0, "VIX \(vix) produced \(result)")
            XCTAssertLessThanOrEqual(result, 1.0, "VIX \(vix) produced \(result)")
        }
    }

    // MARK: - DXY Normalization

    func testNormalizeDXY_low() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeDXY(90), 0.0, accuracy: 0.001)
    }

    func testNormalizeDXY_neutral() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeDXY(100), 0.5, accuracy: 0.001)
    }

    func testNormalizeDXY_high() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeDXY(110), 1.0, accuracy: 0.001)
    }

    func testNormalizeDXY_clampsBelow() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeDXY(80), 0.0, accuracy: 0.001)
    }

    func testNormalizeDXY_clampsAbove() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeDXY(120), 1.0, accuracy: 0.001)
    }

    // MARK: - Macro Risk (Combined VIX + DXY)

    func testNormalizeMacroRisk_bothPresent() {
        let result = RiskFactorNormalizer.normalizeMacroRisk(vix: 20, dxy: 100)
        XCTAssertNotNil(result)
        // Average of VIX(20)≈0.567 and DXY(100)=0.5
        XCTAssertEqual(result!, 0.533, accuracy: 0.01)
    }

    func testNormalizeMacroRisk_onlyVIX() {
        let result = RiskFactorNormalizer.normalizeMacroRisk(vix: 20, dxy: nil)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, RiskFactorNormalizer.normalizeVIX(20), accuracy: 0.001)
    }

    func testNormalizeMacroRisk_onlyDXY() {
        let result = RiskFactorNormalizer.normalizeMacroRisk(vix: nil, dxy: 100)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 0.5, accuracy: 0.001)
    }

    func testNormalizeMacroRisk_bothNil() {
        let result = RiskFactorNormalizer.normalizeMacroRisk(vix: nil, dxy: nil)
        XCTAssertNil(result)
    }

    // MARK: - Bull Market Support Bands

    func testNormalizeBullMarketBands_farAboveBoth() {
        // Price 25% above avg band → 0.1
        let bands = BullMarketSupportBands(sma20Week: 1000, ema21Week: 1000, currentPrice: 1250)
        XCTAssertEqual(RiskFactorNormalizer.normalizeBullMarketBands(bands), 0.1)
    }

    func testNormalizeBullMarketBands_slightlyAboveBoth() {
        // Price 15% above avg band → 0.2
        let bands = BullMarketSupportBands(sma20Week: 1000, ema21Week: 1000, currentPrice: 1150)
        XCTAssertEqual(RiskFactorNormalizer.normalizeBullMarketBands(bands), 0.2)
    }

    func testNormalizeBullMarketBands_justAboveBoth() {
        // Price 5% above avg band → 0.3
        let bands = BullMarketSupportBands(sma20Week: 1000, ema21Week: 1000, currentPrice: 1050)
        XCTAssertEqual(RiskFactorNormalizer.normalizeBullMarketBands(bands), 0.3)
    }

    func testNormalizeBullMarketBands_inBand() {
        // Price between SMA and EMA → 0.5
        let bands = BullMarketSupportBands(sma20Week: 1100, ema21Week: 900, currentPrice: 1000)
        XCTAssertEqual(RiskFactorNormalizer.normalizeBullMarketBands(bands), 0.5)
    }

    func testNormalizeBullMarketBands_justBelowBoth() {
        // Price 5% below avg band → 0.7
        let bands = BullMarketSupportBands(sma20Week: 1000, ema21Week: 1000, currentPrice: 950)
        XCTAssertEqual(RiskFactorNormalizer.normalizeBullMarketBands(bands), 0.7)
    }

    func testNormalizeBullMarketBands_farBelowBoth() {
        // Price 25% below avg band → 0.9
        let bands = BullMarketSupportBands(sma20Week: 1000, ema21Week: 1000, currentPrice: 750)
        XCTAssertEqual(RiskFactorNormalizer.normalizeBullMarketBands(bands), 0.9)
    }

    // MARK: - Weight Renormalization

    func testRenormalizeWeights_allAvailable() {
        let factors = RiskFactorType.allCases.map { type in
            RiskFactor(type: type, rawValue: 50, normalizedValue: 0.5, weight: type.defaultWeight)
        }
        let renormalized = RiskFactorNormalizer.renormalizeWeights(factors: factors, originalWeights: .default)
        let totalWeight = renormalized.filter { $0.isAvailable }.reduce(0.0) { $0 + $1.weight }
        XCTAssertEqual(totalWeight, 1.0, accuracy: 0.001)
    }

    func testRenormalizeWeights_someUnavailable() {
        var factors: [RiskFactor] = []
        // Make logRegression, RSI, SMA available (total original weight: 0.35+0.12+0.12=0.59)
        factors.append(RiskFactor(type: .logRegression, rawValue: 0.5, normalizedValue: 0.5, weight: 0.35))
        factors.append(RiskFactor(type: .rsi, rawValue: 50, normalizedValue: 0.5, weight: 0.12))
        factors.append(RiskFactor(type: .smaPosition, rawValue: 0.3, normalizedValue: 0.3, weight: 0.12))
        // Rest unavailable
        factors.append(.unavailable(.bullMarketBands, weight: 0.11))
        factors.append(.unavailable(.fundingRate, weight: 0.10))
        factors.append(.unavailable(.fearGreed, weight: 0.10))
        factors.append(.unavailable(.macroRisk, weight: 0.10))

        let renormalized = RiskFactorNormalizer.renormalizeWeights(factors: factors, originalWeights: .default)
        let totalAvailableWeight = renormalized.filter { $0.isAvailable }.reduce(0.0) { $0 + $1.weight }
        XCTAssertEqual(totalAvailableWeight, 1.0, accuracy: 0.001)

        // Unavailable factors should keep their original weight
        let unavailable = renormalized.filter { !$0.isAvailable }
        XCTAssertEqual(unavailable.count, 4)
    }

    func testRenormalizeWeights_allUnavailable() {
        let factors = RiskFactorType.allCases.map { type in
            RiskFactor.unavailable(type, weight: type.defaultWeight)
        }
        let renormalized = RiskFactorNormalizer.renormalizeWeights(factors: factors, originalWeights: .default)
        // Should return unchanged since no available factors
        for (original, renorm) in zip(factors, renormalized) {
            XCTAssertEqual(original.weight, renorm.weight, accuracy: 0.001)
        }
    }
}
