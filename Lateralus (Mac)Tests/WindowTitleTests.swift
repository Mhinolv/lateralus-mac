import XCTest
@testable import Lateralus__Mac_

/// The unified toolbar shows the destination as the window title (#23).
final class WindowTitleTests: XCTestCase {

    func testMainDestinationTitles() {
        XCTAssertEqual(SidebarItem.today.title, "Today")
        XCTAssertEqual(SidebarItem.journal.title, "Journal")
        XCTAssertEqual(SidebarItem.insights.title, "Insights")
    }

    func testEveryPracticeDisciplineUsesItsExerciseTitle() {
        for exercise in Exercise.practice {
            XCTAssertEqual(SidebarItem.practice(exercise).title, exercise.title)
            XCTAssertFalse(exercise.title.isEmpty, "\(exercise.rawValue) has no title")
        }
    }
}
