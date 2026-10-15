import XCTest
@testable import Lateralus__Mac_

final class ResponseEditTests: XCTestCase {

    func testNewEditHasNoChangesAndCannotSave() {
        let edit = ResponseEdit(original: "An idea.")
        XCTAssertEqual(edit.text, "An idea.")
        XCTAssertFalse(edit.hasChanges)
        XCTAssertFalse(edit.canSave)
    }

    func testWhitespaceOnlyChangeIsNoChange() {
        var edit = ResponseEdit(original: "An idea.")
        edit.text = "  An idea.\n\n"
        XCTAssertFalse(edit.hasChanges)
        XCTAssertFalse(edit.canSave)
        XCTAssertEqual(edit.trimmed, "An idea.")
    }

    func testChangedTextCanSave() {
        var edit = ResponseEdit(original: "An idae.")
        edit.text = "An idea."
        XCTAssertTrue(edit.hasChanges)
        XCTAssertTrue(edit.canSave)
    }

    func testEmptiedTextIsAChangeThatCannotSave() {
        var edit = ResponseEdit(original: "An idea.")
        edit.text = " \n "
        XCTAssertTrue(edit.hasChanges, "Cleared text is unsaved work the guards must protect")
        XCTAssertFalse(edit.canSave)
    }

    func testOriginalWithOuterWhitespaceIsNoChange() {
        let edit = ResponseEdit(original: "An idea.\n")
        XCTAssertFalse(edit.hasChanges)
        XCTAssertFalse(edit.canSave)
    }

    func testSingleCharacterText() {
        var edit = ResponseEdit(original: "a")
        edit.text = "b"
        XCTAssertTrue(edit.canSave)
    }
}
