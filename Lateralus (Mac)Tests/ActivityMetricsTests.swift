import XCTest
@testable import Lateralus__Mac_

@MainActor
final class ActivityMetricsTests: XCTestCase {

    private let calendar = Calendar.current
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 16, hour: 15))!
    }

    private func daysAgo(_ days: Int, hour: Int = 10) -> Date {
        calendar.date(byAdding: .day, value: -days, to: now)!
    }

    private func metrics(_ entries: [(date: Date, exercise: Exercise)]) -> ActivityMetrics {
        ActivityMetrics(entries: entries, now: now, calendar: calendar)
    }

    func testEmptyJournal() {
        let m = metrics([])
        XCTAssertEqual(m.streak, 0)
        XCTAssertEqual(m.total, 0)
        XCTAssertEqual(m.thisWeek, 0)
        XCTAssertEqual(m.lastSevenDays.map(\.count), [0, 0, 0, 0, 0, 0, 0])
    }

    func testStreakCountsConsecutiveDaysEndingToday() {
        let m = metrics([
            (daysAgo(0), .fusion),
            (daysAgo(1), .diary),
            (daysAgo(2), .backstory),
            (daysAgo(4), .redefine), // gap at 3 breaks the run
        ])
        XCTAssertEqual(m.streak, 3)
    }

    func testStreakSurvivesUntilTodayIsMissedEntirely() {
        // No entry today, but yesterday and the day before are active:
        // the streak shows 2 rather than snapping to zero mid-day.
        let m = metrics([(daysAgo(1), .fusion), (daysAgo(2), .fusion)])
        XCTAssertEqual(m.streak, 2)
    }

    func testStreakZeroAfterAFullMissedDay() {
        let m = metrics([(daysAgo(2), .fusion), (daysAgo(3), .fusion)])
        XCTAssertEqual(m.streak, 0)
    }

    func testMultipleEntriesOnOneDayCountOnceForStreak() {
        let m = metrics([(daysAgo(0), .fusion), (daysAgo(0, hour: 20), .redefine)])
        XCTAssertEqual(m.streak, 1)
        XCTAssertEqual(m.total, 2)
    }

    func testThisWeekUsesCurrentCalendarWeek() {
        // 2026-07-16 is a Thursday; the default week starts Sunday 07-12.
        let m = metrics([
            (daysAgo(0), .fusion),      // Thursday — in week
            (daysAgo(3), .fusion),      // Monday — in week
            (daysAgo(6), .fusion),      // Friday last week — out
        ])
        XCTAssertEqual(m.thisWeek, 2)
    }

    func testLastSevenDaysHistogram() {
        let m = metrics([
            (daysAgo(0), .fusion),
            (daysAgo(0, hour: 21), .diary),
            (daysAgo(6), .redefine),
            (daysAgo(7), .redefine), // outside the trailing window
        ])
        let counts = m.lastSevenDays.map(\.count)
        XCTAssertEqual(counts, [1, 0, 0, 0, 0, 0, 2])
        XCTAssertEqual(m.lastSevenDays.count, 7)
    }

    func testDisciplineCountsExcludeDiary() {
        let m = metrics([
            (daysAgo(0), .fusion),
            (daysAgo(0), .fusion),
            (daysAgo(1), .diary),
            (daysAgo(2), .miniMythology),
        ])
        XCTAssertEqual(m.disciplineCounts[.fusion], 2)
        XCTAssertEqual(m.disciplineCounts[.miniMythology], 1)
        XCTAssertNil(m.disciplineCounts[.diary])
        // Diary still counts toward activity totals.
        XCTAssertEqual(m.total, 4)
    }
}
