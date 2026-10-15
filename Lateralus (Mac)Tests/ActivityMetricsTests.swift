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

    func testDisciplinesTriedCountsPracticeOnly() {
        XCTAssertEqual(metrics([]).disciplinesTried, 0)
        let m = metrics([
            (daysAgo(0), .fusion),
            (daysAgo(0), .fusion),
            (daysAgo(1), .diary),
            (daysAgo(2), .unknown),
            (daysAgo(2), .redefine),
        ])
        XCTAssertEqual(m.disciplinesTried, 2)
        let all = metrics(Exercise.practice.map { (daysAgo(0), $0) })
        XCTAssertEqual(all.disciplinesTried, 12)
    }

    func testLeadingDisciplineIsNilWithoutPractice() {
        XCTAssertNil(metrics([]).leadingDiscipline)
        XCTAssertNil(metrics([(daysAgo(0), .diary), (daysAgo(1), .diary)]).leadingDiscipline)
    }

    func testLeadingDisciplineTakesTheHighestCount() {
        let m = metrics([
            (daysAgo(0), .miniMythology),
            (daysAgo(1), .miniMythology),
            (daysAgo(2), .fusion),
            (daysAgo(3), .diary),
            (daysAgo(3), .diary),
            (daysAgo(3), .diary),
        ])
        XCTAssertEqual(m.leadingDiscipline, .miniMythology)
    }

    func testLeadingDisciplineTieGoesToCatalogOrder() {
        // Fusion comes before Inventions in the catalog, whatever the insert order.
        let m = metrics([(daysAgo(0), .inventions), (daysAgo(1), .fusion)])
        XCTAssertEqual(m.leadingDiscipline, .fusion)
        let reversed = metrics([(daysAgo(0), .fusion), (daysAgo(1), .inventions)])
        XCTAssertEqual(reversed.leadingDiscipline, .fusion)
    }

    func testBalanceDotsScaleToTheLeader() {
        XCTAssertEqual(ActivityMetrics.balanceDots(count: 6, max: 6), 6)
        XCTAssertEqual(ActivityMetrics.balanceDots(count: 3, max: 6), 3)
        XCTAssertEqual(ActivityMetrics.balanceDots(count: 40, max: 40), 6)
        XCTAssertEqual(ActivityMetrics.balanceDots(count: 1, max: 1), 6)
        // 6 × 5 ÷ 12 = 2.5 rounds up.
        XCTAssertEqual(ActivityMetrics.balanceDots(count: 5, max: 12), 3)
        // 6 × 3 ÷ 10 = 1.8 rounds to 2.
        XCTAssertEqual(ActivityMetrics.balanceDots(count: 3, max: 10), 2)
    }

    func testBalanceDotsShowAtLeastOneForAnyEntry() {
        // 6 × 1 ÷ 100 = 0.06 would round to zero.
        XCTAssertEqual(ActivityMetrics.balanceDots(count: 1, max: 100), 1)
        XCTAssertEqual(ActivityMetrics.balanceDots(count: 0, max: 100), 0)
    }

    func testBalanceDotsWithNoLeaderOrBadInput() {
        XCTAssertEqual(ActivityMetrics.balanceDots(count: 0, max: 0), 0)
        XCTAssertEqual(ActivityMetrics.balanceDots(count: 3, max: 0), 0)
        XCTAssertEqual(ActivityMetrics.balanceDots(count: -1, max: 5), 0)
        // A count above the leader never exceeds the slots.
        XCTAssertEqual(ActivityMetrics.balanceDots(count: 9, max: 3), 6)
    }
}
