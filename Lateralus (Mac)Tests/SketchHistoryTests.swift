import XCTest
@testable import Lateralus__Mac_

final class SketchHistoryTests: XCTestCase {

    private func stroke(_ x: Double) -> Sketch.Stroke {
        Sketch.Stroke(points: [Sketch.Point(x: x, y: x)], red: 0.1, green: 0.2, blue: 0.3, width: 3)
    }

    private func sketch(_ xs: [Double]) -> Sketch {
        Sketch(strokes: xs.map(stroke))
    }

    func testStrokeUndoAndRedo() {
        var history = SketchHistory()
        var drawing = Sketch()
        history.addStroke(stroke(1), to: &drawing)
        history.addStroke(stroke(2), to: &drawing)
        XCTAssertEqual(drawing, sketch([1, 2]))

        history.undo(&drawing)
        XCTAssertEqual(drawing, sketch([1]))
        XCTAssertTrue(history.canRedo)

        history.undo(&drawing)
        XCTAssertEqual(drawing, Sketch())
        XCTAssertFalse(history.canUndo)

        history.redo(&drawing)
        history.redo(&drawing)
        XCTAssertEqual(drawing, sketch([1, 2]))
        XCTAssertFalse(history.canRedo)
    }

    func testEraseDragIsOneStepAndRestoresOrder() {
        var history = SketchHistory()
        let before = sketch([1, 2, 3, 4, 5]).strokes
        var drawing = sketch([1, 3, 5])
        history.recordErase(before: before, after: drawing.strokes)
        XCTAssertEqual(history.undoStack.count, 1)

        history.undo(&drawing)
        XCTAssertEqual(drawing.strokes, before)

        history.redo(&drawing)
        XCTAssertEqual(drawing, sketch([1, 3, 5]))
    }

    func testEraseOfFirstAndLastStrokes() {
        var history = SketchHistory()
        let before = sketch([1, 2, 3]).strokes
        var drawing = sketch([2])
        history.recordErase(before: before, after: drawing.strokes)
        history.undo(&drawing)
        XCTAssertEqual(drawing.strokes, before)
    }

    func testEraseThatRemovesNothingRecordsNoStep() {
        var history = SketchHistory()
        let strokes = sketch([1, 2]).strokes
        history.recordErase(before: strokes, after: strokes)
        XCTAssertFalse(history.canUndo)
    }

    func testEraseOfDuplicateStrokes() {
        var history = SketchHistory()
        let before = sketch([1, 1, 2]).strokes
        var drawing = sketch([1, 2])
        history.recordErase(before: before, after: drawing.strokes)
        history.undo(&drawing)
        XCTAssertEqual(drawing.strokes, before)
        history.redo(&drawing)
        XCTAssertEqual(drawing, sketch([1, 2]))
    }

    func testClearUndoAndRedo() {
        var history = SketchHistory()
        var drawing = sketch([1, 2, 3])
        history.clear(&drawing)
        XCTAssertTrue(drawing.isEmpty)

        history.undo(&drawing)
        XCTAssertEqual(drawing, sketch([1, 2, 3]))

        history.redo(&drawing)
        XCTAssertTrue(drawing.isEmpty)
    }

    func testClearOfEmptySketchRecordsNoStep() {
        var history = SketchHistory()
        var drawing = Sketch()
        history.clear(&drawing)
        XCTAssertFalse(history.canUndo)
    }

    func testMixedOperationsUndoInReverseOrder() {
        var history = SketchHistory()
        var drawing = Sketch()
        history.addStroke(stroke(1), to: &drawing)
        history.addStroke(stroke(2), to: &drawing)
        let beforeErase = drawing.strokes
        drawing.strokes.removeFirst()
        history.recordErase(before: beforeErase, after: drawing.strokes)
        history.addStroke(stroke(3), to: &drawing)
        history.clear(&drawing)

        history.undo(&drawing)
        XCTAssertEqual(drawing, sketch([2, 3]))
        history.undo(&drawing)
        XCTAssertEqual(drawing, sketch([2]))
        history.undo(&drawing)
        XCTAssertEqual(drawing, sketch([1, 2]))

        history.redo(&drawing)
        history.redo(&drawing)
        history.redo(&drawing)
        XCTAssertTrue(drawing.isEmpty)
    }

    func testNewOperationClearsRedo() {
        var history = SketchHistory()
        var drawing = Sketch()
        history.addStroke(stroke(1), to: &drawing)
        history.addStroke(stroke(2), to: &drawing)
        history.undo(&drawing)
        XCTAssertTrue(history.canRedo)

        history.addStroke(stroke(3), to: &drawing)
        XCTAssertFalse(history.canRedo)
        history.redo(&drawing)
        XCTAssertEqual(drawing, sketch([1, 3]))
    }

    func testEraseAndClearAlsoClearRedo() {
        var history = SketchHistory()
        var drawing = Sketch()
        history.addStroke(stroke(1), to: &drawing)
        history.addStroke(stroke(2), to: &drawing)
        history.undo(&drawing)
        history.recordErase(before: drawing.strokes, after: [])
        drawing.strokes.removeAll()
        XCTAssertFalse(history.canRedo)

        history.addStroke(stroke(4), to: &drawing)
        history.addStroke(stroke(5), to: &drawing)
        history.undo(&drawing)
        XCTAssertTrue(history.canRedo)
        history.clear(&drawing)
        XCTAssertFalse(history.canRedo)
        history.undo(&drawing)
        XCTAssertEqual(drawing, sketch([4]))
    }

    func testHistoryKeepsTheLast100Steps() {
        var history = SketchHistory()
        var drawing = Sketch()
        for x in 0..<(SketchHistory.limit + 5) {
            history.addStroke(stroke(Double(x)), to: &drawing)
        }
        XCTAssertEqual(history.undoStack.count, SketchHistory.limit)
        for _ in 0..<(SketchHistory.limit + 5) {
            history.undo(&drawing)
        }
        XCTAssertEqual(drawing, sketch([0, 1, 2, 3, 4]))
        XCTAssertEqual(history.redoStack.count, SketchHistory.limit)
    }

    func testUndoAndRedoOnEmptyHistoryDoNothing() {
        var history = SketchHistory()
        var drawing = sketch([1])
        history.undo(&drawing)
        history.redo(&drawing)
        XCTAssertEqual(drawing, sketch([1]))
    }

    func testResetDropsBothStacks() {
        var history = SketchHistory()
        var drawing = Sketch()
        history.addStroke(stroke(1), to: &drawing)
        history.addStroke(stroke(2), to: &drawing)
        history.undo(&drawing)
        history.reset()
        XCTAssertFalse(history.canUndo)
        XCTAssertFalse(history.canRedo)
    }

    /// Sketch JSON saved before this change has no history fields and must
    /// still decode.
    func testSketchSavedBeforeHistoryStillDecodes() throws {
        let json = #"{"strokes":[{"points":[{"x":1,"y":2}],"red":0.1,"green":0.2,"blue":0.3,"width":3}]}"#
        let decoded = try XCTUnwrap(Sketch.decode(Data(json.utf8)))
        XCTAssertEqual(decoded.strokes.count, 1)
        XCTAssertEqual(decoded.strokes[0].points, [Sketch.Point(x: 1, y: 2)])
    }
}
