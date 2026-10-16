import XCTest
@testable import Lateralus__Mac_

/// The text and step rules behind the Journal and Insights
/// screens (#26).
@MainActor
final class JournalInsightsStyleTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func header(_ day: Date, now: Date) -> String {
        JournalDayHeader.title(for: day, now: now, calendar: calendar, locale: locale)
    }

    // MARK: - Day headers

    func testDayHeaderToday() {
        let now = date(2026, 10, 15, hour: 9)
        XCTAssertEqual(header(date(2026, 10, 15, hour: 0), now: now), "Today")
        XCTAssertEqual(header(date(2026, 10, 15, hour: 23), now: now), "Today")
    }

    func testDayHeaderYesterday() {
        let now = date(2026, 10, 15, hour: 0)
        XCTAssertEqual(header(date(2026, 10, 14, hour: 23), now: now), "Yesterday")
        XCTAssertEqual(header(date(2026, 10, 14, hour: 0), now: now), "Yesterday")
    }

    func testDayHeaderOlderDayShowsWeekdayAndDate() {
        let now = date(2026, 10, 15)
        XCTAssertEqual(header(date(2026, 10, 13), now: now), "Tuesday, October 13")
    }

    func testDayHeaderYesterdayAcrossMonthAndYear() {
        XCTAssertEqual(header(date(2026, 9, 30), now: date(2026, 10, 1, hour: 8)), "Yesterday")
        XCTAssertEqual(header(date(2025, 12, 31), now: date(2026, 1, 1, hour: 8)), "Yesterday")
    }

    func testDayHeaderOtherYearShowsTheYear() {
        let now = date(2026, 1, 5)
        XCTAssertEqual(header(date(2025, 12, 30), now: now), "Tuesday, December 30, 2025")
    }

    func testDayHeaderFutureDayIsNotToday() {
        // A clock moved backwards can leave an entry dated tomorrow.
        let now = date(2026, 10, 15)
        XCTAssertEqual(header(date(2026, 10, 16), now: now), "Friday, October 16")
    }

    // MARK: - Insights week dots

    func testDayDotOpacitySteps() {
        XCTAssertEqual(InsightsView.dayDotOpacity(count: 0), 0)
        XCTAssertEqual(InsightsView.dayDotOpacity(count: -1), 0)
        XCTAssertEqual(InsightsView.dayDotOpacity(count: 1), 0.55)
        XCTAssertEqual(InsightsView.dayDotOpacity(count: 2), 0.78)
        XCTAssertEqual(InsightsView.dayDotOpacity(count: 3), 1)
        XCTAssertEqual(InsightsView.dayDotOpacity(count: 40), 1)
    }

    // MARK: - Entry detail

    func testDetailLineJoinsLabelAndDetail() {
        XCTAssertEqual(
            EntryDetailView.detailLine(label: "The Catch", detail: "It must make no sound."),
            "The Catch · It must make no sound."
        )
    }

    func testDetailLineWithoutLabelShowsDetailOnly() {
        XCTAssertEqual(EntryDetailView.detailLine(label: nil, detail: "A lamp"), "A lamp")
        XCTAssertEqual(EntryDetailView.detailLine(label: "", detail: "A lamp"), "A lamp")
    }
}
