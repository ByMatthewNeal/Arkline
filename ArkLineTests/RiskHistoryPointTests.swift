import XCTest
@testable import ArkLine

final class RiskHistoryPointTests: XCTestCase {

    // MARK: - Risk Category

    func testCategory_veryLowRisk() {
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.0), "Very Low Risk")
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.10), "Very Low Risk")
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.19), "Very Low Risk")
    }

    func testCategory_lowRisk() {
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.20), "Low Risk")
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.30), "Low Risk")
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.39), "Low Risk")
    }

    func testCategory_neutral() {
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.40), "Neutral")
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.45), "Neutral")
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.54), "Neutral")
    }

    func testCategory_elevatedRisk() {
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.55), "Elevated Risk")
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.60), "Elevated Risk")
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.69), "Elevated Risk")
    }

    func testCategory_highRisk() {
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.70), "High Risk")
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.80), "High Risk")
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.89), "High Risk")
    }

    func testCategory_extremeRisk() {
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.90), "Extreme Risk")
        XCTAssertEqual(RiskHistoryPoint.category(for: 0.95), "Extreme Risk")
        XCTAssertEqual(RiskHistoryPoint.category(for: 1.0), "Extreme Risk")
    }

    // MARK: - Computed Properties

    func testIsOvervalued_positiveDeviation() {
        let point = makePoint(deviation: 0.5)
        XCTAssertTrue(point.isOvervalued)
    }

    func testIsOvervalued_negativeDeviation() {
        let point = makePoint(deviation: -0.3)
        XCTAssertFalse(point.isOvervalued)
    }

    func testIsOvervalued_zeroDeviation() {
        let point = makePoint(deviation: 0.0)
        XCTAssertFalse(point.isOvervalued)
    }

    func testDeviationPercentage_positive() {
        let point = makePoint(price: 110, fairValue: 100)
        XCTAssertEqual(point.deviationPercentage, 10.0, accuracy: 0.001)
    }

    func testDeviationPercentage_negative() {
        let point = makePoint(price: 90, fairValue: 100)
        XCTAssertEqual(point.deviationPercentage, -10.0, accuracy: 0.001)
    }

    func testDeviationPercentage_zeroFairValue() {
        let point = makePoint(price: 100, fairValue: 0)
        XCTAssertEqual(point.deviationPercentage, 0.0)
    }

    func testRiskCategory_computedProperty() {
        let point = makePoint(riskLevel: 0.35)
        XCTAssertEqual(point.riskCategory, "Low Risk")
    }

    // MARK: - Identifiable

    func testId_equalsDateString() {
        let point = makePoint(dateString: "2025-01-15")
        XCTAssertEqual(point.id, "2025-01-15")
    }

    // MARK: - Initializers

    func testInit_withDate_generatesDateString() {
        let date = Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 15))!
        let point = RiskHistoryPoint(date: date, riskLevel: 0.5, price: 100, fairValue: 100, deviation: 0)
        XCTAssertEqual(point.dateString, "2025-06-15")
    }

    func testInit_fromITCRiskLevel() {
        let itc = ITCRiskLevel(date: "2025-03-01", riskLevel: 0.45, price: 50000, fairValue: 48000)
        let point = RiskHistoryPoint(from: itc, price: 50000, fairValue: 48000)
        XCTAssertEqual(point.dateString, "2025-03-01")
        XCTAssertEqual(point.riskLevel, 0.45, accuracy: 0.001)
        XCTAssertEqual(point.price, 50000, accuracy: 0.01)
        XCTAssertEqual(point.fairValue, 48000, accuracy: 0.01)
    }

    // MARK: - Codable

    func testCodable_roundtrip() throws {
        let original = makePoint(dateString: "2025-01-15", riskLevel: 0.65, price: 95000, fairValue: 80000, deviation: 0.074)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RiskHistoryPoint.self, from: data)

        XCTAssertEqual(decoded.dateString, original.dateString)
        XCTAssertEqual(decoded.riskLevel, original.riskLevel, accuracy: 0.001)
        XCTAssertEqual(decoded.price, original.price, accuracy: 0.01)
        XCTAssertEqual(decoded.fairValue, original.fairValue, accuracy: 0.01)
        XCTAssertEqual(decoded.deviation, original.deviation, accuracy: 0.001)
    }

    func testCodable_keysAreMapped() throws {
        let point = makePoint(dateString: "2025-01-15", riskLevel: 0.5, price: 100, fairValue: 90, deviation: 0.1)
        let data = try JSONEncoder().encode(point)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Check snake_case keys
        XCTAssertNotNil(json["date"])
        XCTAssertNotNil(json["risk_level"])
        XCTAssertNotNil(json["fair_value"])
        XCTAssertNotNil(json["price"])
        XCTAssertNotNil(json["deviation"])
        // camelCase should NOT be present
        XCTAssertNil(json["dateString"])
        XCTAssertNil(json["riskLevel"])
        XCTAssertNil(json["fairValue"])
    }

    // MARK: - Helpers

    private func makePoint(
        dateString: String = "2025-01-01",
        date: Date? = nil,
        riskLevel: Double = 0.5,
        price: Double = 100,
        fairValue: Double = 90,
        deviation: Double = 0.046
    ) -> RiskHistoryPoint {
        let pointDate = date ?? {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: dateString) ?? Date()
        }()
        return RiskHistoryPoint(
            dateString: dateString,
            date: pointDate,
            riskLevel: riskLevel,
            price: price,
            fairValue: fairValue,
            deviation: deviation
        )
    }
}
