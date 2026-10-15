import XCTest
@testable import Lateralus__Mac_

@MainActor
final class PromptEngineTests: XCTestCase {

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    // MARK: - Determinism

    func testSameDayAlwaysDealsTheSameChallenge() {
        let calendar = Calendar.current
        let noon = date(2026, 7, 16)
        let lateNight = calendar.date(from: DateComponents(year: 2026, month: 7, day: 16, hour: 23, minute: 59))!
        XCTAssertEqual(PromptEngine.daily(for: noon, calendar: calendar),
                       PromptEngine.daily(for: noon, calendar: calendar))
        XCTAssertEqual(PromptEngine.daily(for: noon, calendar: calendar),
                       PromptEngine.daily(for: lateNight, calendar: calendar))
    }

    func testConsecutiveDaysDealDifferentDisciplines() {
        let calendar = Calendar.current
        let today = PromptEngine.daily(for: date(2026, 7, 16), calendar: calendar)
        let tomorrow = PromptEngine.daily(for: date(2026, 7, 17), calendar: calendar)
        XCTAssertNotEqual(today, tomorrow)
    }

    /// Each 12-day block deals every discipline exactly once.
    func testTwelveDayBlockCoversEveryDiscipline() {
        let calendar = Calendar.current
        var start = calendar.startOfDay(for: date(2026, 1, 1))
        // Align to a block boundary (day number 0 is 2026-01-01).
        var seen: Set<Exercise> = []
        for offset in 0..<12 {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            seen.insert(PromptEngine.daily(for: day, calendar: calendar).exercise)
        }
        XCTAssertEqual(seen.count, 12)
        // And the next block starts a fresh coverage.
        start = calendar.date(byAdding: .day, value: 12, to: start)!
        seen.removeAll()
        for offset in 0..<12 {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            seen.insert(PromptEngine.daily(for: day, calendar: calendar).exercise)
        }
        XCTAssertEqual(seen.count, 12)
    }

    // MARK: - Non-repeat window

    /// The advertised guarantee: no (discipline, content) combination
    /// repeats anywhere in the 730-day window. Deterministic, so passing
    /// once means it holds forever for this content version.
    func testNoChallengeRepeatsInsideTheWindow() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date(2026, 1, 1))
        var seen: Set<String> = []
        for offset in 0..<PromptEngine.scheduleWindowDays {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            let prompt = PromptEngine.daily(for: day, calendar: calendar)
            XCTAssertTrue(seen.insert(prompt.id).inserted,
                          "Day offset \(offset) repeated challenge: \(prompt.id)")
        }
        XCTAssertEqual(seen.count, PromptEngine.scheduleWindowDays)
    }

    /// Every pool must be deep enough for the ~61 appearances each
    /// discipline gets inside the window.
    func testComboSpacesCoverTheWindow() {
        let appearances = PromptEngine.scheduleWindowDays / Exercise.practice.count + 1
        for exercise in Exercise.practice {
            XCTAssertGreaterThanOrEqual(
                PromptEngine.comboCount(for: exercise), appearances,
                "\(exercise.title) pool is too small for the window"
            )
        }
    }

    // MARK: - Timezone behavior

    func testDayNumberFollowsLocalCalendarDay() {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        var honolulu = Calendar(identifier: .gregorian)
        honolulu.timeZone = TimeZone(identifier: "Pacific/Honolulu")!

        // One physical instant that lands on different local days.
        let instant = tokyo.date(from: DateComponents(year: 2026, month: 7, day: 17, hour: 3))!
        let tokyoDay = PromptEngine.dayNumber(for: instant, calendar: tokyo)
        let honoluluDay = PromptEngine.dayNumber(for: instant, calendar: honolulu)
        XCTAssertEqual(tokyoDay - honoluluDay, 1)
    }

    // MARK: - Content shapes

    func testEveryComboMaterializes() {
        for exercise in Exercise.practice {
            for index in 0..<PromptEngine.comboCount(for: exercise) {
                let prompt = PromptEngine.prompt(for: exercise, comboIndex: index)
                XCTAssertFalse(prompt.headline.isEmpty, "\(exercise.title) combo \(index) is empty")
                XCTAssertEqual(prompt.exercise, exercise)
            }
        }
    }

    func testCommonThreadDealsTwoDistinctWords() {
        for index in 0..<PromptEngine.comboCount(for: .commonThread) {
            let prompt = PromptEngine.prompt(for: .commonThread, comboIndex: index)
            let words = prompt.headline.components(separatedBy: "·").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            XCTAssertEqual(words.count, 2)
            XCTAssertEqual(Set(words).count, 2, "Pair \(index) repeats a word: \(words)")
        }
    }

    func testPracticePromptsAreValid() {
        for exercise in Exercise.practice {
            for _ in 0..<25 {
                let prompt = PromptEngine.practice(exercise)
                XCTAssertEqual(prompt.exercise, exercise)
                XCTAssertFalse(prompt.headline.isEmpty)
            }
        }
    }

    /// Pins the first days of the shipped schedule. If this fails, content
    /// or engine changes reshuffled the published schedule — that requires
    /// a deliberate `contentVersion` bump, not a silent change.
    func testScheduleStabilityPin() {
        let calendar = Calendar.current
        let ids = (0..<5).map { offset -> String in
            let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: date(2026, 1, 1)))!
            return PromptEngine.daily(for: day, calendar: calendar).id
        }
        // Recorded from content version 2. Update only with a version bump.
        XCTAssertEqual(ids, Self.version2FirstFiveDays)
    }

    static let version2FirstFiveDays: [String] = [
        "alternateUses|A feather duster|",
        "twistedUses|A park bench|It is completely frictionless.",
        "backstory|The city fountain ran orange juice for exactly one hour.|",
        "perspectiveFlip|Describe the vet's waiting room on a Monday.|You are the building itself.",
        "fusion|Fuse a night market with a megaphone.|One invention, both parents visible.",
    ]
}
