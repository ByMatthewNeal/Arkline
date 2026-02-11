import XCTest
@testable import ArkLine

final class DateExtensionsTests: XCTestCase {

    // MARK: - isToday / isYesterday / isTomorrow

    func testIsToday() {
        XCTAssertTrue(Date().isToday)
        XCTAssertFalse(Date().adding(days: -1).isToday)
    }

    func testIsYesterday() {
        XCTAssertTrue(Date().adding(days: -1).isYesterday)
        XCTAssertFalse(Date().isYesterday)
    }

    func testIsTomorrow() {
        XCTAssertTrue(Date().adding(days: 1).isTomorrow)
        XCTAssertFalse(Date().isTomorrow)
    }

    // MARK: - isPast / isFuture

    func testIsPast() {
        XCTAssertTrue(Date().adding(days: -1).isPast)
        XCTAssertFalse(Date().adding(days: 1).isPast)
    }

    func testIsFuture() {
        XCTAssertTrue(Date().adding(days: 1).isFuture)
        XCTAssertFalse(Date().adding(days: -1).isFuture)
    }

    // MARK: - adding(days:)

    func testAddingDays() {
        let today = Date()
        let tomorrow = today.adding(days: 1)
        let components = Calendar.current.dateComponents([.day], from: today, to: tomorrow)
        XCTAssertEqual(components.day, 1)
    }

    func testAddingNegativeDays() {
        let today = Date()
        let yesterday = today.adding(days: -1)
        let components = Calendar.current.dateComponents([.day], from: yesterday, to: today)
        XCTAssertEqual(components.day, 1)
    }

    // MARK: - adding(months:)

    func testAddingMonths() {
        let jan1 = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let apr1 = jan1.adding(months: 3)
        let components = Calendar.current.dateComponents([.month], from: apr1)
        XCTAssertEqual(components.month, 4)
    }

    // MARK: - daysBetween

    func testDaysBetween() {
        let start = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let end = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 11))!
        XCTAssertEqual(start.daysBetween(end), 10)
    }

    func testDaysBetween_sameDay() {
        let date = Date()
        XCTAssertEqual(date.daysBetween(date), 0)
    }

    func testDaysBetween_negativeDays() {
        let start = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 11))!
        let end = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        XCTAssertEqual(start.daysBetween(end), -10)
    }

    // MARK: - startOfDay

    func testStartOfDay() {
        let date = Date()
        let startOfDay = date.startOfDay
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: startOfDay)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }

    // MARK: - startOfMonth

    func testStartOfMonth() {
        let date = Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 15))!
        let startOfMonth = date.startOfMonth
        let components = Calendar.current.dateComponents([.day], from: startOfMonth)
        XCTAssertEqual(components.day, 1)
    }

    // MARK: - startOfWeek

    func testStartOfWeek() {
        let date = Date()
        let startOfWeek = date.startOfWeek
        let weekday = Calendar.current.component(.weekday, from: startOfWeek)
        // In the default calendar, week starts on Sunday (1)
        XCTAssertEqual(weekday, Calendar.current.firstWeekday)
    }

    // MARK: - isMarketOpen

    func testIsMarketOpen_weekdayDuringHours() {
        // Wednesday at 11:00 AM
        var components = DateComponents()
        components.year = 2025
        components.month = 6
        components.day = 4 // Wednesday
        components.hour = 11
        components.minute = 0
        let date = Calendar.current.date(from: components)!
        XCTAssertTrue(date.isMarketOpen)
    }

    func testIsMarketOpen_weekendIsClosed() {
        // Saturday at 11:00 AM
        var components = DateComponents()
        components.year = 2025
        components.month = 6
        components.day = 7 // Saturday
        components.hour = 11
        components.minute = 0
        let date = Calendar.current.date(from: components)!
        XCTAssertFalse(date.isMarketOpen)
    }

    func testIsMarketOpen_afterHours() {
        // Wednesday at 5:00 PM (after 4 PM close)
        var components = DateComponents()
        components.year = 2025
        components.month = 6
        components.day = 4 // Wednesday
        components.hour = 17
        components.minute = 0
        let date = Calendar.current.date(from: components)!
        XCTAssertFalse(date.isMarketOpen)
    }

    func testIsMarketOpen_beforeHours() {
        // Wednesday at 7:00 AM (before 9 AM open)
        var components = DateComponents()
        components.year = 2025
        components.month = 6
        components.day = 4 // Wednesday
        components.hour = 7
        components.minute = 0
        let date = Calendar.current.date(from: components)!
        XCTAssertFalse(date.isMarketOpen)
    }

    // MARK: - Formatting

    func testDisplayDate() {
        let date = Calendar.current.date(from: DateComponents(year: 2025, month: 3, day: 15))!
        XCTAssertEqual(date.displayDate, "Mar 15, 2025")
    }

    func testChartDate() {
        let date = Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 25))!
        XCTAssertEqual(date.chartDate, "Dec 25")
    }

    // MARK: - TimeInterval Extensions

    func testDisplayDuration_seconds() {
        XCTAssertEqual(TimeInterval(45).displayDuration, "45s")
    }

    func testDisplayDuration_minutes() {
        XCTAssertEqual(TimeInterval(120).displayDuration, "2m")
    }

    func testDisplayDuration_hours() {
        XCTAssertEqual(TimeInterval(3660).displayDuration, "1h 1m")
    }
}
