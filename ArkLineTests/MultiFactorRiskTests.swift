import XCTest
@testable import ArkLine

final class MultiFactorRiskTests: XCTestCase {

    // MARK: - RiskFactorType

    func testAllCases_count() {
        XCTAssertEqual(RiskFactorType.allCases.count, 7)
    }

    func testDefaultWeights_sumToOne() {
        let total = RiskFactorType.allCases.reduce(0.0) { $0 + $1.defaultWeight }
        XCTAssertEqual(total, 1.0, accuracy: 0.001)
    }

    func testEachType_hasDescription() {
        for type in RiskFactorType.allCases {
            XCTAssertFalse(type.description.isEmpty, "\(type.rawValue) missing description")
        }
    }

    func testEachType_hasIcon() {
        for type in RiskFactorType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "\(type.rawValue) missing icon")
        }
    }

    // MARK: - RiskFactor

    func testRiskFactor_weightedContribution() {
        let factor = RiskFactor(type: .logRegression, rawValue: 0.5, normalizedValue: 0.6, weight: 0.35)
        XCTAssertEqual(factor.weightedContribution!, 0.21, accuracy: 0.001)
    }

    func testRiskFactor_weightedContribution_nilWhenUnavailable() {
        let factor = RiskFactor.unavailable(.rsi, weight: 0.12)
        XCTAssertNil(factor.weightedContribution)
    }

    func testRiskFactor_isAvailable_true() {
        let factor = RiskFactor(type: .rsi, rawValue: 50, normalizedValue: 0.5, weight: 0.12)
        XCTAssertTrue(factor.isAvailable)
    }

    func testRiskFactor_isAvailable_false() {
        let factor = RiskFactor.unavailable(.rsi, weight: 0.12)
        XCTAssertFalse(factor.isAvailable)
    }

    func testRiskFactor_id_matchesRawValue() {
        let factor = RiskFactor(type: .fearGreed, rawValue: 75, normalizedValue: 0.75, weight: 0.10)
        XCTAssertEqual(factor.id, "Fear & Greed")
    }

    func testRiskFactor_unavailableFactory() {
        let factor = RiskFactor.unavailable(.macroRisk, weight: 0.10)
        XCTAssertNil(factor.rawValue)
        XCTAssertNil(factor.normalizedValue)
        XCTAssertEqual(factor.weight, 0.10, accuracy: 0.001)
        XCTAssertEqual(factor.type, .macroRisk)
    }

    func testRiskFactor_rawValueDisplay_rsi() {
        let factor = RiskFactor(type: .rsi, rawValue: 65.3, normalizedValue: 0.88, weight: 0.12)
        XCTAssertEqual(factor.rawValueDisplay, "65.3")
    }

    func testRiskFactor_rawValueDisplay_unavailable() {
        let factor = RiskFactor.unavailable(.rsi, weight: 0.12)
        XCTAssertEqual(factor.rawValueDisplay, "N/A")
    }

    func testRiskFactor_normalizedValueDisplay() {
        let factor = RiskFactor(type: .rsi, rawValue: 65, normalizedValue: 0.875, weight: 0.12)
        XCTAssertEqual(factor.normalizedValueDisplay, "88%")
    }

    func testRiskFactor_normalizedValueDisplay_unavailable() {
        let factor = RiskFactor.unavailable(.rsi, weight: 0.12)
        XCTAssertEqual(factor.normalizedValueDisplay, "N/A")
    }

    // MARK: - RiskFactorWeights

    func testDefaultWeights_isValid() {
        XCTAssertTrue(RiskFactorWeights.default.isValid)
    }

    func testConservativeWeights_isValid() {
        XCTAssertTrue(RiskFactorWeights.conservative.isValid)
    }

    func testSentimentFocusedWeights_isValid() {
        XCTAssertTrue(RiskFactorWeights.sentimentFocused.isValid)
    }

    func testWeights_total() {
        XCTAssertEqual(RiskFactorWeights.default.total, 1.0, accuracy: 0.001)
    }

    func testWeights_weightForType() {
        let weights = RiskFactorWeights.default
        XCTAssertEqual(weights.weight(for: .logRegression), 0.35, accuracy: 0.001)
        XCTAssertEqual(weights.weight(for: .rsi), 0.12, accuracy: 0.001)
        XCTAssertEqual(weights.weight(for: .smaPosition), 0.12, accuracy: 0.001)
        XCTAssertEqual(weights.weight(for: .bullMarketBands), 0.11, accuracy: 0.001)
        XCTAssertEqual(weights.weight(for: .fundingRate), 0.10, accuracy: 0.001)
        XCTAssertEqual(weights.weight(for: .fearGreed), 0.10, accuracy: 0.001)
        XCTAssertEqual(weights.weight(for: .macroRisk), 0.10, accuracy: 0.001)
    }

    func testWeights_codableRoundtrip() throws {
        let original = RiskFactorWeights.conservative
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RiskFactorWeights.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testWeights_invalidTotal() {
        let invalid = RiskFactorWeights(
            logRegression: 0.5, rsi: 0.5, smaPosition: 0.5,
            bullMarketBands: 0.5, fundingRate: 0.5, fearGreed: 0.5, macroRisk: 0.5
        )
        XCTAssertFalse(invalid.isValid)
    }

    // MARK: - MultiFactorRiskPoint

    func testMultiFactorRiskPoint_availableFactorCount() {
        let point = makeMultiFactorPoint(availableTypes: [.logRegression, .rsi, .fearGreed])
        XCTAssertEqual(point.availableFactorCount, 3)
    }

    func testMultiFactorRiskPoint_availableWeight() {
        let point = makeMultiFactorPoint(availableTypes: [.logRegression, .rsi])
        // 0.35 + 0.12 = 0.47
        XCTAssertEqual(point.availableWeight, 0.47, accuracy: 0.001)
    }

    func testMultiFactorRiskPoint_hasSupplementaryFactors_true() {
        let point = makeMultiFactorPoint(availableTypes: [.logRegression, .rsi])
        XCTAssertTrue(point.hasSupplementaryFactors)
    }

    func testMultiFactorRiskPoint_hasSupplementaryFactors_false() {
        let point = makeMultiFactorPoint(availableTypes: [.logRegression])
        XCTAssertFalse(point.hasSupplementaryFactors)
    }

    func testMultiFactorRiskPoint_factorForType() {
        let point = makeMultiFactorPoint(availableTypes: [.logRegression, .rsi, .fearGreed])
        XCTAssertEqual(point.factor(for: .rsi)?.type, .rsi)
        XCTAssertNotNil(point.logRegressionFactor)
        XCTAssertNotNil(point.rsiFactor)
        XCTAssertNotNil(point.fearGreedFactor)
    }

    func testMultiFactorRiskPoint_riskCategory() {
        let point = makeMultiFactorPoint(riskLevel: 0.35, availableTypes: [.logRegression])
        XCTAssertEqual(point.riskCategory, "Low Risk")
    }

    func testMultiFactorRiskPoint_toRiskHistoryPoint() {
        let point = makeMultiFactorPoint(
            riskLevel: 0.6,
            price: 95000,
            fairValue: 80000,
            deviation: 0.074,
            availableTypes: [.logRegression]
        )
        let converted = point.toRiskHistoryPoint()
        XCTAssertEqual(converted.riskLevel, 0.6, accuracy: 0.001)
        XCTAssertEqual(converted.price, 95000, accuracy: 0.01)
        XCTAssertEqual(converted.fairValue, 80000, accuracy: 0.01)
        XCTAssertEqual(converted.deviation, 0.074, accuracy: 0.001)
    }

    func testMultiFactorRiskPoint_id_equalsDateString() {
        let point = makeMultiFactorPoint(availableTypes: [.logRegression])
        XCTAssertEqual(point.id, point.dateString)
    }

    // MARK: - Helpers

    private func makeMultiFactorPoint(
        riskLevel: Double = 0.5,
        price: Double = 90000,
        fairValue: Double = 80000,
        deviation: Double = 0.05,
        availableTypes: Set<RiskFactorType>
    ) -> MultiFactorRiskPoint {
        let factors = RiskFactorType.allCases.map { type -> RiskFactor in
            if availableTypes.contains(type) {
                return RiskFactor(type: type, rawValue: 50, normalizedValue: 0.5, weight: type.defaultWeight)
            } else {
                return .unavailable(type, weight: type.defaultWeight)
            }
        }

        return MultiFactorRiskPoint(
            date: Date(),
            riskLevel: riskLevel,
            price: price,
            fairValue: fairValue,
            deviation: deviation,
            factors: factors
        )
    }
}
