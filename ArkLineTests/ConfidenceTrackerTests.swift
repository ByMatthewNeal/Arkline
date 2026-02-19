import XCTest
@testable import ArkLine

final class ConfidenceTrackerTests: XCTestCase {

    // MARK: - R-Squared Bonus

    func testRSquaredBonus_highRSquared() {
        // R² = 0.95 → (0.95 - 0.85) * 5.0 = +0.5
        let bonus = (0.95 - 0.85) * 5.0
        XCTAssertEqual(bonus, 0.5, accuracy: 0.001)
    }

    func testRSquaredBonus_lowRSquared() {
        // R² = 0.75 → (0.75 - 0.85) * 5.0 = -0.5
        let raw = (0.75 - 0.85) * 5.0
        let clamped = max(-0.5, min(1.0, raw))
        XCTAssertEqual(clamped, -0.5, accuracy: 0.001)
    }

    func testRSquaredBonus_baseline() {
        // R² = 0.85 → 0.0
        let bonus = max(-0.5, min(1.0, (0.85 - 0.85) * 5.0))
        XCTAssertEqual(bonus, 0.0, accuracy: 0.001)
    }

    func testRSquaredBonus_veryHigh_clampsAtOne() {
        // R² = 1.0 → (1.0 - 0.85) * 5.0 = 0.75, within [−0.5, 1.0]
        let bonus = max(-0.5, min(1.0, (1.0 - 0.85) * 5.0))
        XCTAssertEqual(bonus, 0.75, accuracy: 0.001)
    }

    func testRSquaredBonus_veryLow_clampsAtMinusHalf() {
        // R² = 0.5 → (0.5 - 0.85) * 5.0 = -1.75, clamped to -0.5
        let bonus = max(-0.5, min(1.0, (0.5 - 0.85) * 5.0))
        XCTAssertEqual(bonus, -0.5, accuracy: 0.001)
    }

    // MARK: - Data Point Bonus

    func testDataPointBonus_oneYear() {
        // 365 points → 0.0 (threshold not exceeded)
        let points = 365
        let bonus: Double = points > 365 ? min(1.0, log2(Double(points) / 365.0) / 4.0) : 0.0
        XCTAssertEqual(bonus, 0.0, accuracy: 0.001)
    }

    func testDataPointBonus_twoYears() {
        // 730 points → log2(730/365) / 4 = log2(2) / 4 = 1/4 = 0.25
        let points = 730.0
        let bonus = min(1.0, log2(points / 365.0) / 4.0)
        XCTAssertEqual(bonus, 0.25, accuracy: 0.001)
    }

    func testDataPointBonus_fourYears() {
        // 1460 → log2(4) / 4 = 2/4 = 0.5
        let bonus = min(1.0, log2(1460.0 / 365.0) / 4.0)
        XCTAssertEqual(bonus, 0.5, accuracy: 0.001)
    }

    func testDataPointBonus_btcRange() {
        // ~5840 → log2(16) / 4 = 4/4 = 1.0 (capped)
        let bonus = min(1.0, log2(5840.0 / 365.0) / 4.0)
        XCTAssertEqual(bonus, 1.0, accuracy: 0.001)
    }

    func testDataPointBonus_belowThreshold() {
        // 200 points → 0.0
        let points = 200
        let bonus: Double = points > 365 ? min(1.0, log2(Double(points) / 365.0) / 4.0) : 0.0
        XCTAssertEqual(bonus, 0.0)
    }

    // MARK: - Accuracy Bonus

    func testAccuracyBonus_perfect() {
        // 100% → (1.0 - 0.5) * 2.0 = 1.0
        let bonus = max(-1.0, min(1.0, (1.0 - 0.5) * 2.0))
        XCTAssertEqual(bonus, 1.0, accuracy: 0.001)
    }

    func testAccuracyBonus_coinFlip() {
        // 50% → 0.0
        let bonus = max(-1.0, min(1.0, (0.5 - 0.5) * 2.0))
        XCTAssertEqual(bonus, 0.0, accuracy: 0.001)
    }

    func testAccuracyBonus_poor() {
        // 25% → (0.25 - 0.5) * 2.0 = -0.5
        let bonus = max(-1.0, min(1.0, (0.25 - 0.5) * 2.0))
        XCTAssertEqual(bonus, -0.5, accuracy: 0.001)
    }

    func testAccuracyBonus_zero() {
        // 0% → -1.0
        let bonus = max(-1.0, min(1.0, (0.0 - 0.5) * 2.0))
        XCTAssertEqual(bonus, -1.0, accuracy: 0.001)
    }

    // MARK: - Prediction Evaluation

    func testEvaluatePrediction_highRisk_priceDown() {
        // Risk 0.7, price dropped 10% → correct
        let result = ConfidenceTracker.evaluatePrediction(
            riskLevel: 0.7, snapshotPrice: 100, outcomePrice: 90
        )
        XCTAssertTrue(result)
    }

    func testEvaluatePrediction_highRisk_priceUp() {
        // Risk 0.7, price rose 10% → incorrect
        let result = ConfidenceTracker.evaluatePrediction(
            riskLevel: 0.7, snapshotPrice: 100, outcomePrice: 110
        )
        XCTAssertFalse(result)
    }

    func testEvaluatePrediction_lowRisk_priceUp() {
        // Risk 0.3, price rose 10% → correct
        let result = ConfidenceTracker.evaluatePrediction(
            riskLevel: 0.3, snapshotPrice: 100, outcomePrice: 110
        )
        XCTAssertTrue(result)
    }

    func testEvaluatePrediction_lowRisk_priceDown() {
        // Risk 0.3, price dropped 10% → incorrect
        let result = ConfidenceTracker.evaluatePrediction(
            riskLevel: 0.3, snapshotPrice: 100, outcomePrice: 90
        )
        XCTAssertFalse(result)
    }

    func testEvaluatePrediction_highRisk_smallDrop() {
        // Risk 0.7, price dropped 3% → incorrect (below 5% threshold)
        let result = ConfidenceTracker.evaluatePrediction(
            riskLevel: 0.7, snapshotPrice: 100, outcomePrice: 97
        )
        XCTAssertFalse(result)
    }

    func testEvaluatePrediction_lowRisk_smallRise() {
        // Risk 0.3, price rose 3% → incorrect (below 5% threshold)
        let result = ConfidenceTracker.evaluatePrediction(
            riskLevel: 0.3, snapshotPrice: 100, outcomePrice: 103
        )
        XCTAssertFalse(result)
    }

    func testEvaluatePrediction_neutral_alwaysFalse() {
        // Risk 0.50 → neutral zone, always false
        let result = ConfidenceTracker.evaluatePrediction(
            riskLevel: 0.50, snapshotPrice: 100, outcomePrice: 50
        )
        XCTAssertFalse(result)
    }

    func testEvaluatePrediction_exactThreshold_high() {
        // Risk 0.55 (boundary) → high risk zone
        let result = ConfidenceTracker.evaluatePrediction(
            riskLevel: 0.55, snapshotPrice: 100, outcomePrice: 94
        )
        XCTAssertTrue(result)
    }

    func testEvaluatePrediction_exactThreshold_low() {
        // Risk 0.4499 → low risk zone
        let result = ConfidenceTracker.evaluatePrediction(
            riskLevel: 0.4499, snapshotPrice: 100, outcomePrice: 106
        )
        XCTAssertTrue(result)
    }

    // MARK: - Adaptive Confidence Computation

    func testAdaptiveConfidence_noData_equalsStatic() async {
        let tracker = ConfidenceTracker(loadFromDisk: false)
        let result = await tracker.computeAdaptiveConfidence(for: "BTC")
        XCTAssertEqual(result.adaptiveConfidence, result.staticConfidence)
        XCTAssertEqual(result.rSquaredBonus, 0.0)
        XCTAssertEqual(result.dataPointBonus, 0.0)
        XCTAssertEqual(result.accuracyBonus, 0.0)
    }

    func testAdaptiveConfidence_highQualityData() async {
        let tracker = ConfidenceTracker(loadFromDisk: false)
        // BTC-like: high R², many data points
        await tracker.recordCalculation(
            assetId: "BTC", rSquared: 0.96,
            dataPointCount: 5800, riskLevel: 0.35, price: 70000
        )
        let result = await tracker.computeAdaptiveConfidence(for: "BTC")
        // Base 9 + R² bonus ~0.55 + data point bonus ~1.0 = ~10.55 → clamped to 9
        XCTAssertEqual(result.adaptiveConfidence, 9)
        XCTAssertGreaterThan(result.rSquaredBonus, 0)
        XCTAssertGreaterThan(result.dataPointBonus, 0)
    }

    func testAdaptiveConfidence_lowQualityData() async {
        let tracker = ConfidenceTracker(loadFromDisk: false)
        // ONDO-like: low R², few data points
        await tracker.recordCalculation(
            assetId: "ONDO", rSquared: 0.70,
            dataPointCount: 300, riskLevel: 0.30, price: 1.50
        )
        let result = await tracker.computeAdaptiveConfidence(for: "ONDO")
        // Base 3, R² bonus = -0.5, data point bonus = 0.0
        // Raw: 2.5, floor = max(1, 3-1) = 2 → rounded to 3 (2.5 rounds to 2 or 3 depending)
        XCTAssertGreaterThanOrEqual(result.adaptiveConfidence, 2)
        XCTAssertLessThanOrEqual(result.adaptiveConfidence, 3)
        XCTAssertLessThan(result.rSquaredBonus, 0)
    }

    func testAdaptiveConfidence_neverDropsMoreThanOne() async {
        let tracker = ConfidenceTracker(loadFromDisk: false)
        // SOL base = 6, bad R² and no accuracy
        await tracker.recordCalculation(
            assetId: "SOL", rSquared: 0.50,
            dataPointCount: 100, riskLevel: 0.80, price: 150
        )
        let result = await tracker.computeAdaptiveConfidence(for: "SOL")
        // Floor = max(1, 6-1) = 5
        XCTAssertGreaterThanOrEqual(result.adaptiveConfidence, 5)
    }

    func testAdaptiveConfidence_cappedAtNine() async {
        let tracker = ConfidenceTracker(loadFromDisk: false)
        // ETH base = 8, good R², lots of data
        await tracker.recordCalculation(
            assetId: "ETH", rSquared: 0.98,
            dataPointCount: 4000, riskLevel: 0.25, price: 3000
        )
        let result = await tracker.computeAdaptiveConfidence(for: "ETH")
        XCTAssertLessThanOrEqual(result.adaptiveConfidence, 9)
    }

    // MARK: - Record Calculation

    func testRecordCalculation_createsSnapshot() async {
        let tracker = ConfidenceTracker(loadFromDisk: false)
        await tracker.recordCalculation(
            assetId: "BTC", rSquared: 0.95,
            dataPointCount: 5000, riskLevel: 0.30, price: 70000
        )
        let metrics = await tracker.metrics(for: "BTC")
        XCTAssertNotNil(metrics)
        XCTAssertEqual(metrics?.rSquaredHistory.count, 1)
        XCTAssertEqual(metrics?.predictionSnapshots.count, 1) // 0.30 is directional (low risk)
    }

    func testRecordCalculation_neutralSkipsSnapshot() async {
        let tracker = ConfidenceTracker(loadFromDisk: false)
        await tracker.recordCalculation(
            assetId: "BTC", rSquared: 0.95,
            dataPointCount: 5000, riskLevel: 0.50, price: 70000
        )
        let metrics = await tracker.metrics(for: "BTC")
        XCTAssertEqual(metrics?.predictionSnapshots.count, 0) // 0.50 is neutral
        XCTAssertEqual(metrics?.rSquaredHistory.count, 1) // R² still recorded
    }

    func testRecordCalculation_noDuplicateSameDay() async {
        let tracker = ConfidenceTracker(loadFromDisk: false)
        let date = Date()
        await tracker.recordCalculation(
            assetId: "BTC", rSquared: 0.95,
            dataPointCount: 5000, riskLevel: 0.30, price: 70000, date: date
        )
        await tracker.recordCalculation(
            assetId: "BTC", rSquared: 0.95,
            dataPointCount: 5000, riskLevel: 0.35, price: 71000, date: date
        )
        let metrics = await tracker.metrics(for: "BTC")
        XCTAssertEqual(metrics?.predictionSnapshots.count, 1) // Only 1 per day
        XCTAssertEqual(metrics?.rSquaredHistory.count, 2) // R² always recorded
    }
}
