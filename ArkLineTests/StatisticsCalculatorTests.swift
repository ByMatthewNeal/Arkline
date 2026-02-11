import XCTest
@testable import ArkLine

final class StatisticsCalculatorTests: XCTestCase {

    // MARK: - Mean

    func testMean_basic() {
        XCTAssertEqual(StatisticsCalculator.mean([1, 2, 3, 4, 5]), 3.0, accuracy: 0.001)
    }

    func testMean_singleValue() {
        XCTAssertEqual(StatisticsCalculator.mean([42.0]), 42.0, accuracy: 0.001)
    }

    func testMean_empty() {
        XCTAssertEqual(StatisticsCalculator.mean([]), 0.0)
    }

    func testMean_negativeValues() {
        XCTAssertEqual(StatisticsCalculator.mean([-10, 10]), 0.0, accuracy: 0.001)
    }

    func testMean_largeDataset() {
        let data = (1...100).map { Double($0) }
        XCTAssertEqual(StatisticsCalculator.mean(data), 50.5, accuracy: 0.001)
    }

    // MARK: - Standard Deviation

    func testStandardDeviation_knownDataset() {
        // [2, 4, 4, 4, 5, 5, 7, 9] - population SD = 2.0, sample SD ≈ 2.138
        let data = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
        let sd = StatisticsCalculator.standardDeviation(data)
        XCTAssertEqual(sd, 2.138, accuracy: 0.01)
    }

    func testStandardDeviation_singleValue() {
        XCTAssertEqual(StatisticsCalculator.standardDeviation([5.0]), 0.0)
    }

    func testStandardDeviation_empty() {
        XCTAssertEqual(StatisticsCalculator.standardDeviation([]), 0.0)
    }

    func testStandardDeviation_identicalValues() {
        XCTAssertEqual(StatisticsCalculator.standardDeviation([5.0, 5.0, 5.0, 5.0]), 0.0)
    }

    func testPopulationStandardDeviation() {
        let data = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
        let sd = StatisticsCalculator.populationStandardDeviation(data)
        XCTAssertEqual(sd, 2.0, accuracy: 0.01)
    }

    // MARK: - Z-Score

    func testCalculateZScore_normalValue() {
        // Create a dataset with known mean and SD
        let history = Array(repeating: 50.0, count: 20) + [30.0, 70.0]
        // Mean ≈ 48.18, but let's just test the function works
        let result = StatisticsCalculator.calculateZScore(currentValue: 50.0, history: history)
        XCTAssertNotNil(result)
        // Value close to mean should have z-score close to 0
        XCTAssertLessThan(abs(result!.zScore), 2.0)
    }

    func testCalculateZScore_extremeHigh() {
        // History centered around 100 with small variance
        var history = (0..<25).map { _ in Double.random(in: 95...105) }
        history.append(contentsOf: [100.0, 100.0, 100.0, 100.0, 100.0])
        let result = StatisticsCalculator.calculateZScore(currentValue: 200.0, history: history)
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result!.zScore, 2.0)
    }

    func testCalculateZScore_insufficientData() {
        let result = StatisticsCalculator.calculateZScore(currentValue: 50.0, history: [1, 2, 3])
        XCTAssertNil(result)
    }

    func testCalculateZScore_minimumDataPoints() {
        // Exactly 20 data points
        let history = (1...20).map { Double($0) }
        let result = StatisticsCalculator.calculateZScore(currentValue: 10.5, history: history)
        XCTAssertNotNil(result)
    }

    func testCalculateZScore_zeroVariance() {
        let history = Array(repeating: 50.0, count: 25)
        let result = StatisticsCalculator.calculateZScore(currentValue: 51.0, history: history)
        XCTAssertNil(result) // SD = 0 should return nil
    }

    // MARK: - ZScoreResult Properties

    func testZScoreResult_isExtreme() {
        let extreme = StatisticsCalculator.ZScoreResult(mean: 50, standardDeviation: 10, zScore: 3.5)
        XCTAssertTrue(extreme.isExtreme)
        XCTAssertTrue(extreme.isSignificant)

        let normal = StatisticsCalculator.ZScoreResult(mean: 50, standardDeviation: 10, zScore: 0.5)
        XCTAssertFalse(normal.isExtreme)
        XCTAssertFalse(normal.isSignificant)
    }

    func testZScoreResult_isSignificant() {
        let significant = StatisticsCalculator.ZScoreResult(mean: 50, standardDeviation: 10, zScore: 2.5)
        XCTAssertTrue(significant.isSignificant)
        XCTAssertFalse(significant.isExtreme)
    }

    func testZScoreResult_description() {
        let extreme = StatisticsCalculator.ZScoreResult(mean: 0, standardDeviation: 1, zScore: 3.5)
        XCTAssertEqual(extreme.description, "Extremely High")

        let extremeNeg = StatisticsCalculator.ZScoreResult(mean: 0, standardDeviation: 1, zScore: -3.5)
        XCTAssertEqual(extremeNeg.description, "Extremely Low")

        let significant = StatisticsCalculator.ZScoreResult(mean: 0, standardDeviation: 1, zScore: 2.5)
        XCTAssertEqual(significant.description, "Significantly High")

        let above = StatisticsCalculator.ZScoreResult(mean: 0, standardDeviation: 1, zScore: 1.5)
        XCTAssertEqual(above.description, "Above Average")

        let normal = StatisticsCalculator.ZScoreResult(mean: 0, standardDeviation: 1, zScore: 0.3)
        XCTAssertEqual(normal.description, "Normal Range")
    }

    func testZScoreResult_formatted() {
        let result = StatisticsCalculator.ZScoreResult(mean: 0, standardDeviation: 1, zScore: 1.5)
        XCTAssertEqual(result.formatted, "+1.5σ")

        let negative = StatisticsCalculator.ZScoreResult(mean: 0, standardDeviation: 1, zScore: -2.3)
        XCTAssertEqual(negative.formatted, "-2.3σ")
    }

    // MARK: - SD Bands

    func testSDBands_fromMeanAndSD() {
        let bands = StatisticsCalculator.sdBands(mean: 100, sd: 10)
        XCTAssertEqual(bands.mean, 100)
        XCTAssertEqual(bands.plus1SD, 110)
        XCTAssertEqual(bands.plus2SD, 120)
        XCTAssertEqual(bands.plus3SD, 130)
        XCTAssertEqual(bands.minus1SD, 90)
        XCTAssertEqual(bands.minus2SD, 80)
        XCTAssertEqual(bands.minus3SD, 70)
    }

    func testSDBands_fromValues() {
        let values = [10.0, 20.0, 30.0, 40.0, 50.0]
        let bands = StatisticsCalculator.sdBands(from: values)
        XCTAssertNotNil(bands)
        XCTAssertEqual(bands!.mean, 30.0, accuracy: 0.001)
    }

    func testSDBands_fromValues_insufficientData() {
        XCTAssertNil(StatisticsCalculator.sdBands(from: [5.0]))
    }

    func testSDBands_fromValues_zeroVariance() {
        XCTAssertNil(StatisticsCalculator.sdBands(from: [5.0, 5.0, 5.0]))
    }

    // MARK: - Rolling Z-Score

    func testRollingZScore_usesWindow() {
        // Large dataset
        let history = (1...200).map { Double($0) }
        let result = StatisticsCalculator.rollingZScore(
            currentValue: 195.0,
            history: history,
            windowSize: 50
        )
        XCTAssertNotNil(result)
        // With window of last 50 values (151-200), mean ≈ 175.5
        // 195 should be above average
        XCTAssertGreaterThan(result!.zScore, 0)
    }

    func testRollingZScore_defaultWindowSize() {
        let history = (1...100).map { Double($0) }
        let result = StatisticsCalculator.rollingZScore(currentValue: 95.0, history: history)
        XCTAssertNotNil(result)
    }

    func testRollingZScore_smallDataset() {
        // Fewer than 20 points
        let history = [1.0, 2.0, 3.0]
        let result = StatisticsCalculator.rollingZScore(currentValue: 2.0, history: history)
        XCTAssertNil(result)
    }

    // MARK: - Array Extension

    func testArrayExtension_mean() {
        XCTAssertEqual([1.0, 2.0, 3.0].mean, 2.0, accuracy: 0.001)
    }

    func testArrayExtension_standardDeviation() {
        let sd = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0].standardDeviation
        XCTAssertEqual(sd, 2.138, accuracy: 0.01)
    }

    func testArrayExtension_sdBands() {
        let bands = [10.0, 20.0, 30.0, 40.0, 50.0].sdBands
        XCTAssertNotNil(bands)
    }
}
