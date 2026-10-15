import XCTest
@testable import Lateralus__Mac_

/// The Session mode rail: three equal modes, ⌥⌘1–3, and a status line for
/// each mode's content.
final class ResponseModeTests: XCTestCase {

    func testModesAreTextSketchVoiceInRailOrder() {
        XCTAssertEqual(ResponseMode.allCases, [.text, .sketch, .voice])
        XCTAssertEqual(ResponseMode.allCases.map(\.title), ["Text", "Sketch", "Voice"])
        XCTAssertEqual(ResponseMode.allCases.map(\.shortcutKey), ["1", "2", "3"])
        XCTAssertEqual(
            ResponseMode.allCases.map(\.symbol),
            ["character.cursor.ibeam", "scribble.variable", "mic"]
        )
    }

    func testTextStatusCountsWords() {
        XCTAssertEqual(ResponseMode.textStatus(""), "Empty")
        XCTAssertEqual(ResponseMode.textStatus("  \n\t "), "Empty")
        XCTAssertEqual(ResponseMode.textStatus("idea"), "1 word")
        XCTAssertEqual(ResponseMode.textStatus("a  cable\ncar\tthat"), "4 words")
    }

    func testTextStatusCountsALongResponse() {
        let text = Array(repeating: "word", count: 48).joined(separator: " ")
        XCTAssertEqual(ResponseMode.textStatus(text), "48 words")
    }

    func testSketchStatusCountsStrokes() {
        let stroke = Sketch.Stroke(points: [.init(x: 1, y: 1)], red: 0, green: 0, blue: 0, width: 3)
        XCTAssertEqual(ResponseMode.sketchStatus(Sketch()), "Empty")
        XCTAssertEqual(ResponseMode.sketchStatus(Sketch(strokes: [stroke])), "1 stroke")
        XCTAssertEqual(ResponseMode.sketchStatus(Sketch(strokes: Array(repeating: stroke, count: 14))), "14 strokes")
    }

    func testVoiceStatusShowsTheDurationOnlyWithARecording() {
        XCTAssertEqual(ResponseMode.voiceStatus(duration: 0, hasRecording: false), "Empty")
        XCTAssertEqual(ResponseMode.voiceStatus(duration: 42, hasRecording: false), "Empty")
        XCTAssertEqual(ResponseMode.voiceStatus(duration: 0, hasRecording: true), "0:00")
        XCTAssertEqual(ResponseMode.voiceStatus(duration: 42, hasRecording: true), "0:42")
        XCTAssertEqual(ResponseMode.voiceStatus(duration: VoiceNoteRecorder.maximumDuration, hasRecording: true), "5:00")
    }

    func testNewPromptIsOnlyOfferedOnPracticeScreens() {
        let model = AppModel()
        XCTAssertFalse(model.canDealNewPrompt, "Today")
        model.select(.practice(.inventions))
        XCTAssertTrue(model.canDealNewPrompt)
        model.select(.journal)
        XCTAssertFalse(model.canDealNewPrompt)
        model.select(.insights)
        XCTAssertFalse(model.canDealNewPrompt)
    }
}
