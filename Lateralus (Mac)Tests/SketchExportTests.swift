import AppKit
import XCTest
@testable import Lateralus__Mac_

final class SketchExportTests: XCTestCase {

    private func stroke(_ points: [(Double, Double)], width: Double, rgb: (Double, Double, Double) = (0.78, 0.18, 0.21)) -> Sketch.Stroke {
        Sketch.Stroke(
            points: points.map { Sketch.Point(x: $0.0, y: $0.1) },
            red: rgb.0, green: rgb.1, blue: rgb.2, width: width
        )
    }

    private func bitmap(_ data: Data) throws -> NSBitmapImageRep {
        try XCTUnwrap(NSBitmapImageRep(data: data))
    }

    /// The stored sRGB components of one pixel, with no color conversion.
    private struct Pixel {
        var redComponent: Double
        var greenComponent: Double
        var blueComponent: Double
    }

    private func pixel(in rep: NSBitmapImageRep, x: Int, y: Int) -> Pixel {
        var raw = [Int](repeating: 0, count: max(rep.samplesPerPixel, 4))
        rep.getPixel(&raw, atX: x, y: y)
        let maximum = Double((1 << rep.bitsPerSample) - 1)
        return Pixel(redComponent: Double(raw[0]) / maximum, greenComponent: Double(raw[1]) / maximum, blueComponent: Double(raw[2]) / maximum)
    }

    /// The pixel at a point in sketch coordinates.
    private func color(in rep: NSBitmapImageRep, bounds: CGRect, at point: CGPoint) -> Pixel {
        let x = Int(((point.x - bounds.minX) * SketchExport.scale).rounded(.down))
        let y = Int(((point.y - bounds.minY) * SketchExport.scale).rounded(.down))
        return pixel(in: rep, x: x, y: y)
    }

    private func assertPaper(_ color: Pixel, file: StaticString = #filePath, line: UInt = #line) {
        let paper = SketchRendering.paperRGB
        XCTAssertEqual(color.redComponent, paper.red, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(color.greenComponent, paper.green, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(color.blueComponent, paper.blue, accuracy: 0.01, file: file, line: line)
    }

    func testEmptySketchHasNoImage() {
        XCTAssertNil(SketchExport.bounds(of: Sketch()))
        XCTAssertNil(SketchExport.pngData(for: Sketch()))
        XCTAssertNil(SketchExport.pngData(for: Sketch(strokes: [stroke([], width: 3)])))
        XCTAssertThrowsError(try SketchExport.write(Sketch(), to: FileManager.default.temporaryDirectory.appendingPathComponent("never.png")))
    }

    func testBoundsGrowByHalfTheStrokeWidthPlusMargin() throws {
        let line = Sketch(strokes: [stroke([(10, 20), (110, 20)], width: 40)])
        let bounds = try XCTUnwrap(SketchExport.bounds(of: line))
        XCTAssertEqual(bounds.minX, 10 - 20 - SketchExport.margin, accuracy: 0.001)
        XCTAssertEqual(bounds.maxX, 110 + 20 + SketchExport.margin, accuracy: 0.001)
        XCTAssertEqual(bounds.minY, 20 - 20 - SketchExport.margin, accuracy: 0.001)
        XCTAssertEqual(bounds.maxY, 20 + 20 + SketchExport.margin, accuracy: 0.001)
    }

    func testSinglePointDotStaysInside() throws {
        // A dot is an ellipse of the stroke width, stroked at that width,
        // so it reaches a full width from its point.
        let dot = Sketch(strokes: [stroke([(50, 50)], width: 30)])
        let bounds = try XCTUnwrap(SketchExport.bounds(of: dot))
        XCTAssertEqual(bounds.minX, 50 - 30 - SketchExport.margin, accuracy: 0.001)
        XCTAssertEqual(bounds.maxY, 50 + 30 + SketchExport.margin, accuracy: 0.001)
    }

    func testImageIsOpaquePaperAtTwiceTheScale() throws {
        let sketch = Sketch(strokes: [stroke([(0, 0), (100, 50)], width: 3)])
        let bounds = try XCTUnwrap(SketchExport.bounds(of: sketch))
        let rep = try bitmap(try XCTUnwrap(SketchExport.pngData(for: sketch)))
        XCTAssertEqual(rep.pixelsWide, Int((bounds.width * 2).rounded(.up)))
        XCTAssertEqual(rep.pixelsHigh, Int((bounds.height * 2).rounded(.up)))
        XCTAssertFalse(rep.hasAlpha)
        XCTAssertEqual(rep.colorSpace.colorSpaceModel, .rgb)
        for corner in [CGPoint(x: bounds.minX, y: bounds.minY), CGPoint(x: bounds.maxX - 0.5, y: bounds.maxY - 0.5)] {
            assertPaper(color(in: rep, bounds: bounds, at: corner))
        }
    }

    func testWideStrokeCapsAreDrawnAndNotClipped() throws {
        // A wide horizontal line: the round caps reach half the width past each end.
        let sketch = Sketch(strokes: [stroke([(0, 0), (100, 0)], width: 40, rgb: (0.16, 0.32, 0.75))])
        let bounds = try XCTUnwrap(SketchExport.bounds(of: sketch))
        let rep = try bitmap(try XCTUnwrap(SketchExport.pngData(for: sketch)))

        // Inside each cap, near its outer edge, the pixel has the pen color.
        for point in [CGPoint(x: -18, y: 0), CGPoint(x: 118, y: 0), CGPoint(x: 50, y: -18), CGPoint(x: 50, y: 18)] {
            let pixel = color(in: rep, bounds: bounds, at: point)
            XCTAssertEqual(pixel.blueComponent, 0.75, accuracy: 0.02, "\(point)")
            XCTAssertEqual(pixel.redComponent, 0.16, accuracy: 0.02, "\(point)")
        }
        // Past the cap, in the margin, the pixel is paper again.
        for point in [CGPoint(x: -22, y: 0), CGPoint(x: 122, y: 0), CGPoint(x: 50, y: -22), CGPoint(x: 50, y: 22)] {
            assertPaper(color(in: rep, bounds: bounds, at: point))
        }
        // The first and last pixel rows and columns are paper, so nothing touches an edge.
        for x in stride(from: 0, to: rep.pixelsWide, by: 4) {
            assertPaper(pixel(in: rep, x: x, y: 0))
            assertPaper(pixel(in: rep, x: x, y: rep.pixelsHigh - 1))
        }
    }

    func testImageKeepsTheSketchOrientation() throws {
        // A dot at the top-left and paper at the bottom-left, as in the app.
        let sketch = Sketch(strokes: [
            stroke([(0, 0)], width: 6, rgb: (0.13, 0.50, 0.30)),
            stroke([(200, 100)], width: 1),
        ])
        let bounds = try XCTUnwrap(SketchExport.bounds(of: sketch))
        let rep = try bitmap(try XCTUnwrap(SketchExport.pngData(for: sketch)))
        let topLeft = color(in: rep, bounds: bounds, at: CGPoint(x: 0, y: 0))
        XCTAssertEqual(topLeft.greenComponent, 0.50, accuracy: 0.02)
        assertPaper(color(in: rep, bounds: bounds, at: CGPoint(x: 0, y: 100)))
    }

    func testWriteCreatesAPNGFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SketchExportTests-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }
        try SketchExport.write(Sketch(strokes: [stroke([(0, 0), (10, 10)], width: 3)]), to: url)
        let data = try Data(contentsOf: url)
        XCTAssertEqual(Array(data.prefix(8)), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    }

    func testWriteToAMissingFolderThrows() {
        let url = URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)/sketch.png")
        XCTAssertThrowsError(try SketchExport.write(Sketch(strokes: [stroke([(0, 0)], width: 3)]), to: url))
    }

    func testDefaultFileNameUsesTheLocalEntryDate() throws {
        let date = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23, minute: 59)))
        XCTAssertEqual(SketchExport.defaultFileName(for: date), "Lateralus Sketch 2026-03-07.png")
    }

    func testSketchSavedBeforeThisChangeStillExports() throws {
        // The JSON shape that entries already hold in `sketchData`.
        let saved = Data(#"{"strokes":[{"points":[{"x":4,"y":5},{"x":40,"y":50}],"red":0.13,"green":0.12,"blue":0.11,"width":7}]}"#.utf8)
        let sketch = try XCTUnwrap(Sketch.decode(saved))
        XCTAssertNotNil(SketchExport.pngData(for: sketch))
    }
}
