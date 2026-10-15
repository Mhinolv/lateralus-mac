import XCTest
@testable import Lateralus__Mac_

final class JournalDateRangeTests: XCTestCase {

    /// New York has a 23-hour day on 2026-03-08 and a 25-hour day on 2026-11-01.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()
    private let locale = Locale(identifier: "en_US")

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    private func range(from: Date? = nil, to: Date? = nil) -> JournalDateRange {
        JournalDateRange(from: from, to: to, calendar: calendar)
    }

    // MARK: - Boundaries

    func testEmptyRangeContainsEverything() {
        let r = range()
        XCTAssertFalse(r.isActive)
        XCTAssertTrue(r.contains(.distantPast))
        XCTAssertTrue(r.contains(.distantFuture))
        XCTAssertNil(r.summary(locale: locale))
    }

    func testBothBoundaryDaysAreInclusive() {
        let r = range(from: date(2026, 10, 3, 15), to: date(2026, 10, 10, 9))
        XCTAssertTrue(r.contains(date(2026, 10, 3, 0, 0, 0)))
        XCTAssertTrue(r.contains(date(2026, 10, 10, 23, 59, 59)))
        XCTAssertFalse(r.contains(date(2026, 10, 2, 23, 59, 59)))
        XCTAssertFalse(r.contains(date(2026, 10, 11, 0, 0, 0)))
    }

    func testFromOnlyHasNoUpperLimit() {
        let r = range(from: date(2026, 10, 3))
        XCTAssertTrue(r.isActive)
        XCTAssertFalse(r.contains(date(2026, 10, 2, 23, 59)))
        XCTAssertTrue(r.contains(date(2026, 10, 3, 0, 0)))
        XCTAssertTrue(r.contains(.distantFuture))
    }

    func testToOnlyHasNoLowerLimit() {
        let r = range(to: date(2026, 10, 10))
        XCTAssertTrue(r.contains(.distantPast))
        XCTAssertTrue(r.contains(date(2026, 10, 10, 23, 59)))
        XCTAssertFalse(r.contains(date(2026, 10, 11, 0, 0)))
    }

    func testSingleDayRange() {
        let r = range(from: date(2026, 10, 3), to: date(2026, 10, 3))
        XCTAssertTrue(r.contains(date(2026, 10, 3, 0, 0)))
        XCTAssertTrue(r.contains(date(2026, 10, 3, 23, 59, 59)))
        XCTAssertFalse(r.contains(date(2026, 10, 4, 0, 0)))
        XCTAssertFalse(r.contains(date(2026, 10, 2, 23, 59, 59)))
    }

    func testRangeWithNoMatchingEntriesGivesEmptyResult() {
        let entries = [date(2026, 9, 1), date(2026, 9, 30, 23, 59), date(2026, 10, 11, 0, 0)]
        let r = range(from: date(2026, 10, 1), to: date(2026, 10, 10))
        XCTAssertTrue(entries.filter(r.contains).isEmpty)
    }

    // MARK: - DST

    func testSpringForwardDayIsWholeAndExclusiveEndIsNextMidnight() {
        // 2026-03-08 has 23 hours. A fixed 24-hour end would leak into 03-09 01:00.
        let r = range(from: date(2026, 3, 8), to: date(2026, 3, 8))
        XCTAssertTrue(r.contains(date(2026, 3, 8, 0, 0)))
        XCTAssertTrue(r.contains(date(2026, 3, 8, 23, 59, 59)))
        XCTAssertFalse(r.contains(date(2026, 3, 9, 0, 0)))
        XCTAssertFalse(r.contains(date(2026, 3, 9, 0, 30)))
    }

    func testFallBackDayIsWhole() {
        // 2026-11-01 has 25 hours. A fixed 24-hour end would drop 23:00–23:59.
        let r = range(from: date(2026, 11, 1), to: date(2026, 11, 1))
        XCTAssertTrue(r.contains(date(2026, 11, 1, 0, 0)))
        XCTAssertTrue(r.contains(date(2026, 11, 1, 23, 30)))
        XCTAssertTrue(r.contains(date(2026, 11, 1, 23, 59, 59)))
        XCTAssertFalse(r.contains(date(2026, 11, 2, 0, 0)))
        XCTAssertFalse(r.contains(date(2026, 10, 31, 23, 59, 59)))
    }

    func testRangeAcrossDSTChangeKeepsBoundaries() {
        let r = range(from: date(2026, 3, 7), to: date(2026, 3, 9))
        XCTAssertTrue(r.contains(date(2026, 3, 7, 0, 0)))
        XCTAssertTrue(r.contains(date(2026, 3, 9, 23, 59, 59)))
        XCTAssertFalse(r.contains(date(2026, 3, 10, 0, 0)))
    }

    // MARK: - Edits

    func testFromLaterThanToMovesTo() {
        var r = range(from: date(2026, 10, 3), to: date(2026, 10, 10))
        r.setFrom(date(2026, 10, 15, 18))
        XCTAssertEqual(r.from, date(2026, 10, 15, 0, 0))
        XCTAssertEqual(r.to, date(2026, 10, 15, 0, 0))
    }

    func testToEarlierThanFromMovesFrom() {
        var r = range(from: date(2026, 10, 3), to: date(2026, 10, 10))
        r.setTo(date(2026, 9, 28, 8))
        XCTAssertEqual(r.from, date(2026, 9, 28, 0, 0))
        XCTAssertEqual(r.to, date(2026, 9, 28, 0, 0))
    }

    func testSameDayEditsDoNotMoveTheOtherDate() {
        var r = range(from: date(2026, 10, 3), to: date(2026, 10, 10))
        r.setFrom(date(2026, 10, 10, 23))
        XCTAssertEqual(r.to, date(2026, 10, 10, 0, 0))
        r.setTo(date(2026, 10, 10, 1))
        XCTAssertEqual(r.from, date(2026, 10, 10, 0, 0))
    }

    func testUnsetBoundaryAndClear() {
        var r = range(from: date(2026, 10, 3), to: date(2026, 10, 10))
        r.setFrom(nil)
        XCTAssertNil(r.from)
        XCTAssertEqual(r.to, date(2026, 10, 10, 0, 0))
        r.clear()
        XCTAssertFalse(r.isActive)
        XCTAssertNil(r.to)
    }

    // MARK: - Summary

    func testSummaryText() {
        XCTAssertEqual(range(from: date(2026, 10, 3)).summary(locale: locale), "From Oct 3, 2026")
        XCTAssertEqual(range(to: date(2026, 10, 10)).summary(locale: locale), "Until Oct 10, 2026")
        XCTAssertEqual(
            range(from: date(2026, 10, 3), to: date(2026, 10, 10)).summary(locale: locale),
            "Oct 3 – Oct 10, 2026"
        )
        XCTAssertEqual(
            range(from: date(2025, 12, 30), to: date(2026, 1, 2)).summary(locale: locale),
            "Dec 30, 2025 – Jan 2, 2026"
        )
        XCTAssertEqual(
            range(from: date(2026, 10, 3), to: date(2026, 10, 3)).summary(locale: locale),
            "Oct 3, 2026"
        )
    }
}
