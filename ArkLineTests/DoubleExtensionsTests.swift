import XCTest
@testable import ArkLine

final class DoubleExtensionsTests: XCTestCase {

    // MARK: - formatAsCurrency

    func testFormatAsCurrency_standardValue() {
        XCTAssertTrue(1234.56.formatAsCurrency().contains("1,234.56"))
    }

    func testFormatAsCurrency_zero() {
        XCTAssertTrue((0.0).formatAsCurrency().contains("0.00"))
    }

    func testFormatAsCurrency_negativeValue() {
        let result = (-500.0).formatAsCurrency()
        XCTAssertTrue(result.contains("500.00"))
    }

    func testFormatAsCurrency_largeValue() {
        let result = 1_000_000.0.formatAsCurrency()
        XCTAssertTrue(result.contains("1,000,000.00"))
    }

    func testFormatAsCurrency_customFractionDigits() {
        let result = 99.999.formatAsCurrency(minimumFractionDigits: 0, maximumFractionDigits: 0)
        XCTAssertTrue(result.contains("100"))
    }

    // MARK: - asCurrencyCompact

    func testAsCurrencyCompact_billions() {
        let result = 5_000_000_000.0.asCurrencyCompact
        XCTAssertTrue(result.contains("B"))
    }

    func testAsCurrencyCompact_millions() {
        let result = 2_000_000.0.asCurrencyCompact
        XCTAssertTrue(result.contains("M"))
    }

    func testAsCurrencyCompact_thousands() {
        let result = 50_000.0.asCurrencyCompact
        XCTAssertTrue(result.contains("K"))
    }

    func testAsCurrencyCompact_belowThreshold() {
        let result = 500.0.asCurrencyCompact
        XCTAssertTrue(result.contains("500.00"))
    }

    // MARK: - asCryptoPrice

    func testAsCryptoPrice_aboveOne() {
        let result = 50000.0.asCryptoPrice
        // Should have 2 decimal places
        XCTAssertTrue(result.contains("50,000.00"))
    }

    func testAsCryptoPrice_belowOneAboveCent() {
        let result = 0.05.asCryptoPrice
        // Should have 4 decimal places
        XCTAssertTrue(result.contains("0.0500"))
    }

    func testAsCryptoPrice_verySmall() {
        let result = 0.0005.asCryptoPrice
        // Should have 6 decimal places
        XCTAssertTrue(result.contains("0.000500"))
    }

    func testAsCryptoPrice_extremelySmall() {
        let result = 0.00005.asCryptoPrice
        // Should have 8 decimal places
        XCTAssertTrue(result.contains("0.00005000"))
    }

    // MARK: - asPercentage

    func testAsPercentage_positive() {
        let result = 5.25.asPercentage
        XCTAssertTrue(result.contains("+"))
        XCTAssertTrue(result.contains("5.25"))
    }

    func testAsPercentage_negative() {
        let result = (-3.5).asPercentage
        // Negative values get a minus sign from the formatter
        XCTAssertTrue(result.contains("3.50") || result.contains("3.5"))
    }

    func testAsPercentage_zero() {
        let result = 0.0.asPercentage
        XCTAssertTrue(result.contains("0"))
    }

    // MARK: - formattedCompact

    func testFormattedCompact_trillions() {
        XCTAssertEqual(1_500_000_000_000.0.formattedCompact, "1.50T")
    }

    func testFormattedCompact_billions() {
        XCTAssertEqual(2_500_000_000.0.formattedCompact, "2.50B")
    }

    func testFormattedCompact_millions() {
        XCTAssertEqual(3_750_000.0.formattedCompact, "3.75M")
    }

    func testFormattedCompact_thousands() {
        XCTAssertEqual(42_500.0.formattedCompact, "42.50K")
    }

    func testFormattedCompact_small() {
        let result = 123.45.formattedCompact
        XCTAssertTrue(result.contains("123.45"))
    }

    // MARK: - rounded(toPlaces:)

    func testRoundedToPlaces_twoPlaces() {
        XCTAssertEqual(3.14159.rounded(toPlaces: 2), 3.14)
    }

    func testRoundedToPlaces_zeroPlaces() {
        XCTAssertEqual(3.7.rounded(toPlaces: 0), 4.0)
    }

    func testRoundedToPlaces_roundUp() {
        XCTAssertEqual(2.555.rounded(toPlaces: 2), 2.56)
    }

    func testRoundedToPlaces_negative() {
        XCTAssertEqual((-1.236).rounded(toPlaces: 2), -1.24)
    }

    // MARK: - clamped(to:)

    func testClamped_withinRange() {
        XCTAssertEqual(5.0.clamped(to: 0...10), 5.0)
    }

    func testClamped_belowRange() {
        XCTAssertEqual((-5.0).clamped(to: 0...10), 0.0)
    }

    func testClamped_aboveRange() {
        XCTAssertEqual(15.0.clamped(to: 0...10), 10.0)
    }

    func testClamped_atBoundary() {
        XCTAssertEqual(0.0.clamped(to: 0...10), 0.0)
        XCTAssertEqual(10.0.clamped(to: 0...10), 10.0)
    }

    // MARK: - safeDivide(by:)

    func testSafeDivide_normalDivision() {
        XCTAssertEqual(10.0.safeDivide(by: 2.0), 5.0)
    }

    func testSafeDivide_byZero() {
        XCTAssertEqual(10.0.safeDivide(by: 0.0), 0.0)
    }

    func testSafeDivide_zeroByValue() {
        XCTAssertEqual(0.0.safeDivide(by: 5.0), 0.0)
    }

    // MARK: - percentageChange(from:)

    func testPercentageChange_increase() {
        XCTAssertEqual(110.0.percentageChange(from: 100.0), 10.0, accuracy: 0.001)
    }

    func testPercentageChange_decrease() {
        XCTAssertEqual(90.0.percentageChange(from: 100.0), -10.0, accuracy: 0.001)
    }

    func testPercentageChange_noChange() {
        XCTAssertEqual(100.0.percentageChange(from: 100.0), 0.0, accuracy: 0.001)
    }

    func testPercentageChange_fromZero() {
        XCTAssertEqual(50.0.percentageChange(from: 0.0), 0.0)
    }

    func testPercentageChange_fromNegative() {
        // -50 to 50 = 200% increase
        XCTAssertEqual(50.0.percentageChange(from: -50.0), 200.0, accuracy: 0.001)
    }

    // MARK: - Boolean Checks

    func testIsPositive() {
        XCTAssertTrue(1.0.isPositive)
        XCTAssertFalse(0.0.isPositive)
        XCTAssertFalse((-1.0).isPositive)
    }

    func testIsNegative() {
        XCTAssertTrue((-1.0).isNegative)
        XCTAssertFalse(0.0.isNegative)
        XCTAssertFalse(1.0.isNegative)
    }

    func testIsZero() {
        XCTAssertTrue(0.0.isZero)
        XCTAssertFalse(0.001.isZero)
        XCTAssertFalse((-0.001).isZero)
    }

    // MARK: - asQuantity

    func testAsQuantity_zero() {
        XCTAssertEqual(0.0.asQuantity, "0")
    }

    func testAsQuantity_largeNumber() {
        let result = 2_000_000.0.asQuantity
        XCTAssertTrue(result.contains("M"))
    }

    func testAsQuantity_normalNumber() {
        XCTAssertEqual(1.5.asQuantity, "1.5000")
    }

    func testAsQuantity_smallNumber() {
        XCTAssertEqual(0.001.asQuantity, "0.001000")
    }
}
