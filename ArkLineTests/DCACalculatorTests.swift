import XCTest
@testable import ArkLine

final class DCACalculatorTests: XCTestCase {

    // MARK: - Purchase Count: Daily

    func testPurchaseCount_daily_threeMonths() {
        let count = DCACalculatorService.purchaseCount(
            frequency: .daily,
            duration: .threeMonths,
            selectedDays: []
        )
        // 3 months ≈ 91 days
        XCTAssertEqual(count, DCADuration.threeMonths.approximateDays)
        XCTAssertGreaterThan(count, 80)
    }

    func testPurchaseCount_daily_oneYear() {
        let count = DCACalculatorService.purchaseCount(
            frequency: .daily,
            duration: .oneYear,
            selectedDays: []
        )
        XCTAssertEqual(count, DCADuration.oneYear.approximateDays)
        XCTAssertGreaterThan(count, 350)
    }

    // MARK: - Purchase Count: Weekly

    func testPurchaseCount_weekly_singleDay() {
        let count = DCACalculatorService.purchaseCount(
            frequency: .weekly,
            duration: .threeMonths,
            selectedDays: [.monday]
        )
        // 3 months ≈ 13 weeks, 1 day per week
        XCTAssertEqual(count, DCADuration.threeMonths.approximateWeeks)
    }

    func testPurchaseCount_weekly_multipleDays() {
        let count = DCACalculatorService.purchaseCount(
            frequency: .weekly,
            duration: .threeMonths,
            selectedDays: [.monday, .wednesday, .friday]
        )
        // 13 weeks * 3 days = 39
        XCTAssertEqual(count, DCADuration.threeMonths.approximateWeeks * 3)
    }

    func testPurchaseCount_weekly_noDaysSelected_defaultsToOne() {
        let count = DCACalculatorService.purchaseCount(
            frequency: .weekly,
            duration: .threeMonths,
            selectedDays: []
        )
        // Should default to 1 day per week
        XCTAssertEqual(count, DCADuration.threeMonths.approximateWeeks)
    }

    // MARK: - Purchase Count: Twice Weekly

    func testPurchaseCount_twiceWeekly() {
        let count = DCACalculatorService.purchaseCount(
            frequency: .twiceWeekly,
            duration: .sixMonths,
            selectedDays: []
        )
        XCTAssertEqual(count, DCADuration.sixMonths.approximateWeeks * 2)
    }

    // MARK: - Purchase Count: Biweekly

    func testPurchaseCount_biweekly() {
        let count = DCACalculatorService.purchaseCount(
            frequency: .biweekly,
            duration: .oneYear,
            selectedDays: []
        )
        XCTAssertEqual(count, DCADuration.oneYear.approximateWeeks / 2)
    }

    // MARK: - Purchase Count: Monthly

    func testPurchaseCount_monthly() {
        XCTAssertEqual(
            DCACalculatorService.purchaseCount(frequency: .monthly, duration: .threeMonths, selectedDays: []),
            3
        )
        XCTAssertEqual(
            DCACalculatorService.purchaseCount(frequency: .monthly, duration: .sixMonths, selectedDays: []),
            6
        )
        XCTAssertEqual(
            DCACalculatorService.purchaseCount(frequency: .monthly, duration: .oneYear, selectedDays: []),
            12
        )
        XCTAssertEqual(
            DCACalculatorService.purchaseCount(frequency: .monthly, duration: .twoYears, selectedDays: []),
            24
        )
    }

    // MARK: - Generate Purchase Dates: Daily

    func testGeneratePurchaseDates_daily() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let dates = DCACalculatorService.generatePurchaseDates(
            frequency: .daily,
            duration: .threeMonths,
            startDate: startDate,
            selectedDays: []
        )
        // Should have ~91 dates
        XCTAssertGreaterThan(dates.count, 80)
        // First date should be start date
        XCTAssertEqual(dates.first, startDate)
    }

    // MARK: - Generate Purchase Dates: Weekly

    func testGeneratePurchaseDates_weekly() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let dates = DCACalculatorService.generatePurchaseDates(
            frequency: .weekly,
            duration: .threeMonths,
            startDate: startDate,
            selectedDays: [.monday]
        )
        // Should be about 13 Mondays in 3 months
        XCTAssertGreaterThan(dates.count, 10)
        XCTAssertLessThan(dates.count, 16)
        // All dates should be Mondays
        for date in dates {
            let weekday = Calendar.current.component(.weekday, from: date)
            XCTAssertEqual(weekday, 2) // Monday = 2
        }
    }

    // MARK: - Generate Purchase Dates: Twice Weekly

    func testGeneratePurchaseDates_twiceWeekly() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let dates = DCACalculatorService.generatePurchaseDates(
            frequency: .twiceWeekly,
            duration: .threeMonths,
            startDate: startDate,
            selectedDays: []
        )
        // All should be Tuesday or Friday
        for date in dates {
            let weekday = Calendar.current.component(.weekday, from: date)
            XCTAssertTrue(weekday == 3 || weekday == 6, // Tue=3, Fri=6
                          "Expected Tuesday or Friday, got weekday \(weekday)")
        }
    }

    // MARK: - Generate Purchase Dates: Biweekly

    func testGeneratePurchaseDates_biweekly() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let dates = DCACalculatorService.generatePurchaseDates(
            frequency: .biweekly,
            duration: .sixMonths,
            startDate: startDate,
            selectedDays: []
        )
        // 6 months / 2 weeks ≈ 13 dates
        XCTAssertGreaterThan(dates.count, 10)
        // Each date should be ~14 days apart
        if dates.count >= 2 {
            let diff = Calendar.current.dateComponents([.day], from: dates[0], to: dates[1])
            XCTAssertEqual(diff.day, 14)
        }
    }

    // MARK: - Generate Purchase Dates: Monthly

    func testGeneratePurchaseDates_monthly() {
        let startDate = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 15))!
        let dates = DCACalculatorService.generatePurchaseDates(
            frequency: .monthly,
            duration: .sixMonths,
            startDate: startDate,
            selectedDays: []
        )
        // Should include 7 months (start + 6)
        XCTAssertEqual(dates.count, 7) // Jan, Feb, Mar, Apr, May, Jun, Jul
    }

    // MARK: - Validation

    func testValidate_allValid() {
        let errors = DCACalculatorService.validate(
            totalAmount: 1000,
            asset: .bitcoin,
            duration: .threeMonths
        )
        XCTAssertTrue(errors.isEmpty)
    }

    func testValidate_zeroAmount() {
        let errors = DCACalculatorService.validate(
            totalAmount: 0,
            asset: .bitcoin,
            duration: .threeMonths
        )
        XCTAssertTrue(errors.contains { $0.contains("valid investment") })
    }

    func testValidate_belowMinimum() {
        let errors = DCACalculatorService.validate(
            totalAmount: 50,
            asset: .bitcoin,
            duration: .threeMonths
        )
        XCTAssertTrue(errors.contains { $0.contains("Minimum") })
    }

    func testValidate_noAsset() {
        let errors = DCACalculatorService.validate(
            totalAmount: 1000,
            asset: nil,
            duration: .threeMonths
        )
        XCTAssertTrue(errors.contains { $0.contains("asset") })
    }

    func testValidate_noDuration() {
        let errors = DCACalculatorService.validate(
            totalAmount: 1000,
            asset: .bitcoin,
            duration: nil
        )
        XCTAssertTrue(errors.contains { $0.contains("duration") })
    }

    func testValidate_multipleErrors() {
        let errors = DCACalculatorService.validate(
            totalAmount: 0,
            asset: nil,
            duration: nil
        )
        XCTAssertGreaterThanOrEqual(errors.count, 3)
    }

    // MARK: - Frequency Description

    func testFrequencyDescription_daily() {
        XCTAssertEqual(
            DCACalculatorService.frequencyDescription(frequency: .daily, selectedDays: []),
            "Every day"
        )
    }

    func testFrequencyDescription_twiceWeekly() {
        XCTAssertEqual(
            DCACalculatorService.frequencyDescription(frequency: .twiceWeekly, selectedDays: []),
            "Twice a week"
        )
    }

    func testFrequencyDescription_weekly_noSelection() {
        XCTAssertEqual(
            DCACalculatorService.frequencyDescription(frequency: .weekly, selectedDays: []),
            "Every week"
        )
    }

    func testFrequencyDescription_weekly_singleDay() {
        XCTAssertEqual(
            DCACalculatorService.frequencyDescription(frequency: .weekly, selectedDays: [.monday]),
            "Every Monday"
        )
    }

    func testFrequencyDescription_weekly_multipleDays() {
        let desc = DCACalculatorService.frequencyDescription(
            frequency: .weekly,
            selectedDays: [.monday, .friday]
        )
        XCTAssertTrue(desc.contains("Mon"))
        XCTAssertTrue(desc.contains("Fri"))
    }

    func testFrequencyDescription_biweekly() {
        XCTAssertEqual(
            DCACalculatorService.frequencyDescription(frequency: .biweekly, selectedDays: []),
            "Every 2 weeks"
        )
    }

    func testFrequencyDescription_monthly() {
        XCTAssertEqual(
            DCACalculatorService.frequencyDescription(frequency: .monthly, selectedDays: []),
            "Every month"
        )
    }

    // MARK: - Format Quick Amount

    func testFormatQuickAmount_millions() {
        XCTAssertEqual(DCACalculatorService.formatQuickAmount(1_000_000), "$1M")
    }

    func testFormatQuickAmount_thousands() {
        XCTAssertEqual(DCACalculatorService.formatQuickAmount(10_000), "$10K")
        XCTAssertEqual(DCACalculatorService.formatQuickAmount(25_000), "$25K")
    }

    func testFormatQuickAmount_small() {
        XCTAssertEqual(DCACalculatorService.formatQuickAmount(500), "$500")
    }

    // MARK: - DCACalculation Model

    func testDCACalculation_numberOfPurchases() {
        let calc = DCACalculatorService.calculateTimeBased(
            totalAmount: 10000,
            asset: .bitcoin,
            frequency: .monthly,
            duration: .oneYear,
            startDate: Date(),
            selectedDays: [],
            targetPortfolioId: nil,
            targetPortfolioName: nil
        )
        XCTAssertEqual(calc.numberOfPurchases, 12)
    }

    func testDCACalculation_amountPerPurchase() {
        let calc = DCACalculatorService.calculateTimeBased(
            totalAmount: 12000,
            asset: .bitcoin,
            frequency: .monthly,
            duration: .oneYear,
            startDate: Date(),
            selectedDays: [],
            targetPortfolioId: nil,
            targetPortfolioName: nil
        )
        XCTAssertEqual(calc.amountPerPurchase, 1000, accuracy: 1)
    }

    func testDCACalculation_riskBased_noPurchaseCount() {
        let calc = DCACalculatorService.calculateRiskBased(
            totalAmount: 10000,
            asset: .bitcoin,
            riskBands: [.veryLow, .low],
            targetPortfolioId: nil,
            targetPortfolioName: nil
        )
        XCTAssertEqual(calc.numberOfPurchases, 0)
        XCTAssertEqual(calc.amountPerPurchase, 10000)
    }

    // MARK: - DCADuration

    func testDCADuration_months() {
        XCTAssertEqual(DCADuration.threeMonths.months, 3)
        XCTAssertEqual(DCADuration.sixMonths.months, 6)
        XCTAssertEqual(DCADuration.oneYear.months, 12)
        XCTAssertEqual(DCADuration.twoYears.months, 24)
        XCTAssertEqual(DCADuration.custom(months: 18).months, 18)
    }

    func testDCADuration_displayName() {
        XCTAssertEqual(DCADuration.threeMonths.displayName, "3 months")
        XCTAssertEqual(DCADuration.oneYear.displayName, "1 year")
        XCTAssertEqual(DCADuration.custom(months: 18).displayName, "18 months")
    }

    // MARK: - Weekday

    func testWeekday_weekdays() {
        XCTAssertEqual(Weekday.weekdays.count, 5)
        XCTAssertFalse(Weekday.weekdays.contains(.saturday))
        XCTAssertFalse(Weekday.weekdays.contains(.sunday))
    }

    func testWeekday_weekend() {
        XCTAssertEqual(Weekday.weekend.count, 2)
        XCTAssertTrue(Weekday.weekend.contains(.saturday))
        XCTAssertTrue(Weekday.weekend.contains(.sunday))
    }
}
