import XCTest
@testable import ArkLine

final class RiskCalculatorTests: XCTestCase {

    // MARK: - LogarithmicRegression.fit

    func testLogRegressionFit_knownData() {
        // Generate power-law data: price = 10^(a + b * log10(days))
        // Using a = -2, b = 3 means price = days^3 / 100
        let origin = Calendar.current.date(from: DateComponents(year: 2009, month: 1, day: 3))!
        var prices: [(date: Date, price: Double)] = []

        for day in stride(from: 100, through: 1000, by: 50) {
            let date = origin.adding(days: day)
            let price = pow(Double(day), 3.0) / 100.0
            prices.append((date: date, price: price))
        }

        let result = LogarithmicRegression.fit(prices: prices, originDate: origin)
        XCTAssertNotNil(result)
        // R-squared should be very high for exact power-law data
        XCTAssertGreaterThan(result!.rSquared, 0.99)
    }

    func testLogRegressionFit_insufficientData() {
        let origin = Date()
        let prices = (1...5).map { day -> (date: Date, price: Double) in
            (date: origin.adding(days: day), price: Double(day) * 100)
        }
        let result = LogarithmicRegression.fit(prices: prices, originDate: origin)
        XCTAssertNil(result) // Needs >= 10 points
    }

    func testLogRegressionFit_filtersInvalidData() {
        let origin = Date()
        var prices: [(date: Date, price: Double)] = []
        // Add 15 valid points
        for day in 1...15 {
            prices.append((date: origin.adding(days: day), price: Double(day * 100)))
        }
        // Add invalid points (before origin, zero price)
        prices.append((date: origin.adding(days: -1), price: 100))
        prices.append((date: origin.adding(days: 20), price: 0))

        let result = LogarithmicRegression.fit(prices: prices, originDate: origin)
        XCTAssertNotNil(result)
    }

    // MARK: - fairValueAt

    func testFairValueAt() {
        let origin = Calendar.current.date(from: DateComponents(year: 2009, month: 1, day: 3))!
        // Create a simple regression result
        let result = LogarithmicRegression.Result(a: -2.0, b: 3.0, rSquared: 0.95, originDate: origin)

        let futureDate = origin.adding(days: 1000)
        let fairValue = result.fairValueAt(date: futureDate)

        // log(price) = -2 + 3 * log10(1000) = -2 + 9 = 7
        // price = 10^7 = 10,000,000
        XCTAssertEqual(fairValue, 10_000_000, accuracy: 5000)
    }

    func testFairValueAt_beforeOrigin() {
        let origin = Date()
        let result = LogarithmicRegression.Result(a: -2.0, b: 3.0, rSquared: 0.95, originDate: origin)
        let fairValue = result.fairValueAt(date: origin.adding(days: -1))
        XCTAssertEqual(fairValue, 0)
    }

    // MARK: - logDeviation

    func testLogDeviation_overvalued() {
        let deviation = LogarithmicRegression.logDeviation(actualPrice: 200, fairValue: 100)
        XCTAssertGreaterThan(deviation, 0) // Positive = overvalued
        XCTAssertEqual(deviation, log10(200) - log10(100), accuracy: 0.001)
    }

    func testLogDeviation_undervalued() {
        let deviation = LogarithmicRegression.logDeviation(actualPrice: 50, fairValue: 100)
        XCTAssertLessThan(deviation, 0) // Negative = undervalued
    }

    func testLogDeviation_atFairValue() {
        let deviation = LogarithmicRegression.logDeviation(actualPrice: 100, fairValue: 100)
        XCTAssertEqual(deviation, 0, accuracy: 0.001)
    }

    func testLogDeviation_invalidInputs() {
        XCTAssertEqual(LogarithmicRegression.logDeviation(actualPrice: 0, fairValue: 100), 0)
        XCTAssertEqual(LogarithmicRegression.logDeviation(actualPrice: 100, fairValue: 0), 0)
    }

    // MARK: - normalizeDeviation

    func testNormalizeDeviation_center() {
        let normalized = LogarithmicRegression.normalizeDeviation(0, bounds: (low: -1, high: 1))
        XCTAssertEqual(normalized, 0.5, accuracy: 0.001)
    }

    func testNormalizeDeviation_extremeHigh() {
        let normalized = LogarithmicRegression.normalizeDeviation(1.0, bounds: (low: -1, high: 1))
        XCTAssertEqual(normalized, 1.0, accuracy: 0.001)
    }

    func testNormalizeDeviation_extremeLow() {
        let normalized = LogarithmicRegression.normalizeDeviation(-1.0, bounds: (low: -1, high: 1))
        XCTAssertEqual(normalized, 0.0, accuracy: 0.001)
    }

    func testNormalizeDeviation_clampedAboveBounds() {
        let normalized = LogarithmicRegression.normalizeDeviation(2.0, bounds: (low: -1, high: 1))
        XCTAssertEqual(normalized, 1.0, accuracy: 0.001)
    }

    func testNormalizeDeviation_clampedBelowBounds() {
        let normalized = LogarithmicRegression.normalizeDeviation(-2.0, bounds: (low: -1, high: 1))
        XCTAssertEqual(normalized, 0.0, accuracy: 0.001)
    }

    // MARK: - RiskFactorNormalizer: RSI

    func testNormalizeRSI_oversold() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeRSI(30), 0.0, accuracy: 0.001)
    }

    func testNormalizeRSI_overbought() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeRSI(70), 1.0, accuracy: 0.001)
    }

    func testNormalizeRSI_neutral() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeRSI(50), 0.5, accuracy: 0.001)
    }

    func testNormalizeRSI_clampedLow() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeRSI(10), 0.0, accuracy: 0.001)
    }

    func testNormalizeRSI_clampedHigh() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeRSI(90), 1.0, accuracy: 0.001)
    }

    // MARK: - RiskFactorNormalizer: SMA Position

    func testNormalizeSMAPosition_farAbove() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeSMAPosition(price: 130, sma200: 100), 0.2)
    }

    func testNormalizeSMAPosition_slightlyAbove() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeSMAPosition(price: 115, sma200: 100), 0.3)
    }

    func testNormalizeSMAPosition_justAbove() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeSMAPosition(price: 105, sma200: 100), 0.4)
    }

    func testNormalizeSMAPosition_slightlyBelow() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeSMAPosition(price: 95, sma200: 100), 0.6)
    }

    func testNormalizeSMAPosition_farBelow() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeSMAPosition(price: 75, sma200: 100), 0.8)
    }

    func testNormalizeSMAPosition_zeroSMA() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeSMAPosition(price: 100, sma200: 0), 0.5)
    }

    // MARK: - RiskFactorNormalizer: Funding Rate

    func testNormalizeFundingRate_negative() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeFundingRate(-0.001), 0.0, accuracy: 0.001)
    }

    func testNormalizeFundingRate_neutral() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeFundingRate(0.0), 0.5, accuracy: 0.001)
    }

    func testNormalizeFundingRate_highPositive() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeFundingRate(0.001), 1.0, accuracy: 0.001)
    }

    // MARK: - RiskFactorNormalizer: Fear & Greed

    func testNormalizeFearGreed_extremeFear() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeFearGreed(0), 0.0, accuracy: 0.001)
    }

    func testNormalizeFearGreed_neutral() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeFearGreed(50), 0.5, accuracy: 0.001)
    }

    func testNormalizeFearGreed_extremeGreed() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeFearGreed(100), 1.0, accuracy: 0.001)
    }

    func testNormalizeFearGreed_clampedAbove() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeFearGreed(120), 1.0, accuracy: 0.001)
    }

    // MARK: - RiskFactorNormalizer: VIX

    func testNormalizeVIX_low() {
        // VIX 10 = 0.6 risk (complacency)
        let result = RiskFactorNormalizer.normalizeVIX(10)
        XCTAssertEqual(result, 0.7, accuracy: 0.01)
    }

    func testNormalizeVIX_normal() {
        // VIX 20 → normalized = (40-20)/30 = 0.667 → 0.3 + 0.667*0.4 = 0.567
        let result = RiskFactorNormalizer.normalizeVIX(20)
        XCTAssertEqual(result, 0.567, accuracy: 0.01)
    }

    func testNormalizeVIX_high() {
        // VIX 40 → normalized = (40-40)/30 = 0 → 0.3 + 0*0.4 = 0.3
        let result = RiskFactorNormalizer.normalizeVIX(40)
        XCTAssertEqual(result, 0.3, accuracy: 0.01)
    }

    // MARK: - RiskFactorNormalizer: DXY

    func testNormalizeDXY_low() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeDXY(90), 0.0, accuracy: 0.001)
    }

    func testNormalizeDXY_neutral() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeDXY(100), 0.5, accuracy: 0.001)
    }

    func testNormalizeDXY_high() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeDXY(110), 1.0, accuracy: 0.001)
    }

    func testNormalizeDXY_clampedLow() {
        XCTAssertEqual(RiskFactorNormalizer.normalizeDXY(80), 0.0, accuracy: 0.001)
    }

    // MARK: - RiskFactorNormalizer: Macro Risk

    func testNormalizeMacroRisk_bothAvailable() {
        let result = RiskFactorNormalizer.normalizeMacroRisk(vix: 20, dxy: 100)
        XCTAssertNotNil(result)
        // Average of VIX normalized and DXY normalized
        let expected = (RiskFactorNormalizer.normalizeVIX(20) + RiskFactorNormalizer.normalizeDXY(100)) / 2
        XCTAssertEqual(result!, expected, accuracy: 0.001)
    }

    func testNormalizeMacroRisk_onlyVIX() {
        let result = RiskFactorNormalizer.normalizeMacroRisk(vix: 20, dxy: nil)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, RiskFactorNormalizer.normalizeVIX(20), accuracy: 0.001)
    }

    func testNormalizeMacroRisk_onlyDXY() {
        let result = RiskFactorNormalizer.normalizeMacroRisk(vix: nil, dxy: 100)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, RiskFactorNormalizer.normalizeDXY(100), accuracy: 0.001)
    }

    func testNormalizeMacroRisk_neitherAvailable() {
        XCTAssertNil(RiskFactorNormalizer.normalizeMacroRisk(vix: nil, dxy: nil))
    }

    // MARK: - RiskFactorNormalizer: Bull Market Bands

    func testNormalizeBullMarketBands_aboveBoth() {
        let bands = BullMarketSupportBands(sma20Week: 50000, ema21Week: 51000, currentPrice: 65000)
        let result = RiskFactorNormalizer.normalizeBullMarketBands(bands)
        // Far above (>20%): should be 0.1
        XCTAssertLessThanOrEqual(result, 0.3)
    }

    func testNormalizeBullMarketBands_inBand() {
        let bands = BullMarketSupportBands(sma20Week: 50000, ema21Week: 52000, currentPrice: 51000)
        let result = RiskFactorNormalizer.normalizeBullMarketBands(bands)
        XCTAssertEqual(result, 0.5)
    }

    func testNormalizeBullMarketBands_belowBoth() {
        let bands = BullMarketSupportBands(sma20Week: 50000, ema21Week: 51000, currentPrice: 35000)
        let result = RiskFactorNormalizer.normalizeBullMarketBands(bands)
        XCTAssertGreaterThanOrEqual(result, 0.7)
    }

    // MARK: - renormalizeWeights

    func testRenormalizeWeights_allAvailable() {
        let factors = [
            RiskFactor(type: .rsi, rawValue: 50, normalizedValue: 0.5, weight: 0.12),
            RiskFactor(type: .fearGreed, rawValue: 50, normalizedValue: 0.5, weight: 0.10),
        ]
        let weights = RiskFactorWeights.default
        let result = RiskFactorNormalizer.renormalizeWeights(factors: factors, originalWeights: weights)

        // Weights should sum to 1.0
        let totalWeight = result.filter { $0.isAvailable }.reduce(0) { $0 + $1.weight }
        XCTAssertEqual(totalWeight, 1.0, accuracy: 0.001)
    }

    func testRenormalizeWeights_someUnavailable() {
        let factors = [
            RiskFactor(type: .rsi, rawValue: 50, normalizedValue: 0.5, weight: 0.12),
            RiskFactor(type: .fearGreed, rawValue: nil, normalizedValue: nil, weight: 0.10),
            RiskFactor(type: .macroRisk, rawValue: 0.5, normalizedValue: 0.5, weight: 0.10),
        ]
        let weights = RiskFactorWeights.default
        let result = RiskFactorNormalizer.renormalizeWeights(factors: factors, originalWeights: weights)

        let availableWeight = result.filter { $0.isAvailable }.reduce(0) { $0 + $1.weight }
        XCTAssertEqual(availableWeight, 1.0, accuracy: 0.001)

        // Unavailable factor should keep its original weight
        let unavailable = result.first { $0.type == .fearGreed }
        XCTAssertEqual(unavailable?.weight, 0.10)
    }

    // MARK: - RiskHistoryPoint

    func testRiskCategory_veryLow() {
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.1), "Very Low Risk")
    }

    func testRiskCategory_low() {
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.3), "Low Risk")
    }

    func testRiskCategory_neutral() {
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.5), "Neutral")
    }

    func testRiskCategory_elevated() {
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.6), "Elevated Risk")
    }

    func testRiskCategory_high() {
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.8), "High Risk")
    }

    func testRiskCategory_extreme() {
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.95), "Extreme Risk")
    }

    func testRiskHistoryPoint_isOvervalued() {
        let overvalued = RiskHistoryPoint(date: Date(), riskLevel: 0.8, price: 100000, fairValue: 50000, deviation: 0.3)
        XCTAssertTrue(overvalued.isOvervalued)

        let undervalued = RiskHistoryPoint(date: Date(), riskLevel: 0.2, price: 30000, fairValue: 50000, deviation: -0.2)
        XCTAssertFalse(undervalued.isOvervalued)
    }

    func testRiskHistoryPoint_deviationPercentage() {
        let point = RiskHistoryPoint(date: Date(), riskLevel: 0.5, price: 150, fairValue: 100, deviation: 0.18)
        XCTAssertEqual(point.deviationPercentage, 50.0, accuracy: 0.01)
    }

    func testRiskHistoryPoint_deviationPercentage_zeroFairValue() {
        let point = RiskHistoryPoint(date: Date(), riskLevel: 0.5, price: 100, fairValue: 0, deviation: 0)
        XCTAssertEqual(point.deviationPercentage, 0.0)
    }
}
