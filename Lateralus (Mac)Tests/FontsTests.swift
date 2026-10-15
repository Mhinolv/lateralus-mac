import CoreText
import SwiftUI
import XCTest
@testable import Lateralus__Mac_

/// The Night Shift type stack: each Theme accessor resolves to its bundled
/// variable face with the axes from the design notes.
final class FontsTests: XCTestCase {

    /// The axis values Core Text applied to `font`, keyed by tag. Core Text
    /// leaves out an axis that sits at its default, so read those from the
    /// font's axis table.
    private func axes(_ font: CTFont) -> [String: Double] {
        let variation = CTFontCopyVariation(font) as? [NSNumber: NSNumber] ?? [:]
        let table = CTFontCopyVariationAxes(font) as? [[String: Any]] ?? []
        let tags: [Fonts.Axis] = [.weight, .opticalSize, .width, .soft, .wonky]
        var result: [String: Double] = [:]
        for axis in tags {
            let id = NSNumber(value: axis.identifier)
            if let value = variation[id] {
                result[axis.rawValue] = value.doubleValue
            } else if let entry = table.first(where: { $0[kCTFontVariationAxisIdentifierKey as String] as? NSNumber == id }) {
                result[axis.rawValue] = (entry[kCTFontVariationAxisDefaultValueKey as String] as? NSNumber)?.doubleValue
            }
        }
        return result
    }

    private func family(_ font: CTFont) -> String {
        CTFontCopyFamilyName(font) as String
    }

    private func isItalic(_ font: CTFont) -> Bool {
        CTFontGetSymbolicTraits(font).contains(.traitItalic)
    }

    func testEveryFamilyShipsAndLoads() throws {
        for family in Fonts.Family.allCases {
            XCTAssertTrue(Fonts.isAvailable(family), "\(family) did not load")
        }
    }

    func testLicensesShipBesideTheFaces() throws {
        for name in ["OFL-Fraunces", "OFL-BricolageGrotesque", "OFL-JetBrainsMono"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "txt"), name)
            let text = try String(contentsOf: url, encoding: .utf8)
            XCTAssertTrue(text.contains("SIL Open Font License"), name)
        }
    }

    func testOldFacesAreGone() {
        for name in ["SourceSerif4-Regular", "WorkSans-Regular"] {
            XCTAssertNil(Bundle.main.url(forResource: name, withExtension: "otf"), name)
            XCTAssertNil(Bundle.main.url(forResource: name, withExtension: "ttf"), name)
        }
    }

    func testFrauncesOpticalSizeSwitchesAbove28() {
        XCTAssertEqual(Fonts.frauncesOpticalSize(for: 6), 9)
        XCTAssertEqual(Fonts.frauncesOpticalSize(for: 9), 9)
        XCTAssertEqual(Fonts.frauncesOpticalSize(for: 22), 22)
        XCTAssertEqual(Fonts.frauncesOpticalSize(for: 28), 28)
        XCTAssertEqual(Fonts.frauncesOpticalSize(for: 28.5), 144)
        XCTAssertEqual(Fonts.frauncesOpticalSize(for: 36), 144)
        XCTAssertEqual(Fonts.frauncesOpticalSize(for: 200), 144)
    }

    func testBricolageOpticalSizeClampsTo12Through96() {
        XCTAssertEqual(Fonts.bricolageOpticalSize(for: 10), 12)
        XCTAssertEqual(Fonts.bricolageOpticalSize(for: 12), 12)
        XCTAssertEqual(Fonts.bricolageOpticalSize(for: 13.5), 13.5)
        XCTAssertEqual(Fonts.bricolageOpticalSize(for: 96), 96)
        XCTAssertEqual(Fonts.bricolageOpticalSize(for: 120), 96)
    }

    func testDisplayIsFrauncesWithPinnedAxes() throws {
        let cases: [(CGFloat, Theme.DisplayWeight, Bool, Double, Double)] = [
            (22, .semibold, true, 600, 22),   // wordmark
            (36, .semibold, false, 600, 144),
            (32, .light, false, 300, 144),
            (28, .regular, false, 400, 28),
            (19, .regular, true, 400, 19),
        ]
        for (size, weight, italic, wght, opsz) in cases {
            let font = try XCTUnwrap(Theme.displayFont(size, weight: weight, italic: italic))
            let label = "display(\(size), \(weight), italic: \(italic))"
            XCTAssertEqual(family(font), "Fraunces", label)
            XCTAssertEqual(isItalic(font), italic, label)
            XCTAssertEqual(CTFontGetSize(font), size, label)
            let applied = axes(font)
            XCTAssertEqual(applied["wght"], wght, label)
            XCTAssertEqual(applied["opsz"], opsz, label)
            XCTAssertEqual(applied["SOFT"], 0, label)
            XCTAssertEqual(applied["WONK"], 0, label)
        }
    }

    func testUIIsBricolageAtEveryWeight() throws {
        let cases: [(Font.Weight, Double)] = [
            (.ultraLight, 400), (.light, 400), (.regular, 400), (.medium, 500),
            (.semibold, 600), (.bold, 700), (.heavy, 700), (.black, 700),
        ]
        for (weight, wght) in cases {
            let font = try XCTUnwrap(Theme.uiFont(13.5, weight))
            XCTAssertEqual(family(font), "Bricolage Grotesque", "\(weight)")
            let applied = axes(font)
            XCTAssertEqual(applied["wght"], wght, "\(weight)")
            XCTAssertEqual(applied["opsz"], 13.5, "\(weight)")
            XCTAssertEqual(applied["wdth"], 100, "\(weight)")
        }
        XCTAssertEqual(axes(try XCTUnwrap(Theme.uiFont(10)))["opsz"], 12)
    }

    func testUIItalicUsesFrauncesItalicRegular() throws {
        let font = try XCTUnwrap(Theme.uiFont(13, .semibold, italic: true))
        XCTAssertEqual(family(font), "Fraunces")
        XCTAssertTrue(isItalic(font))
        XCTAssertEqual(CTFontGetSize(font), 13)
        XCTAssertEqual(axes(font)["wght"], 400)
        XCTAssertEqual(axes(font)["opsz"], 13)
    }

    func testMonoIsJetBrainsMonoAt400Or600() throws {
        let cases: [(Font.Weight, Double)] = [
            (.light, 400), (.regular, 400), (.medium, 400),
            (.semibold, 600), (.bold, 600), (.black, 600),
        ]
        for (weight, wght) in cases {
            let font = try XCTUnwrap(Theme.monoFont(26, weight))
            XCTAssertEqual(family(font), "JetBrains Mono", "\(weight)")
            XCTAssertEqual(axes(font)["wght"], wght, "\(weight)")
        }
        XCTAssertTrue(CTFontGetSymbolicTraits(try XCTUnwrap(Theme.monoFont(12))).contains(.traitMonoSpace))
    }

    /// The axes change the outlines, not only the reported values: a
    /// heavier weight draws wider glyphs.
    func testWeightAxisChangesGlyphs() throws {
        func width(_ font: CTFont) -> Double {
            let string = NSAttributedString(string: "Lateralus", attributes: [.font: font])
            let line = CTLineCreateWithAttributedString(string)
            return CTLineGetTypographicBounds(line, nil, nil, nil)
        }
        let light = try XCTUnwrap(Theme.displayFont(32, weight: .light))
        let bold = try XCTUnwrap(Theme.displayFont(32, weight: .semibold))
        XCTAssertGreaterThan(width(bold), width(light))
        let regular = try XCTUnwrap(Theme.uiFont(14, .regular))
        let heavy = try XCTUnwrap(Theme.uiFont(14, .bold))
        XCTAssertGreaterThan(width(heavy), width(regular))
    }

    /// SwiftUI keeps the pinned axes when it lays out a `Theme` font.
    @MainActor
    func testSwiftUITextKeepsTheAxes() throws {
        func width(_ font: Font) throws -> CGFloat {
            let renderer = ImageRenderer(content: Text("Lateralus Lateralus").font(font).fixedSize())
            return try XCTUnwrap(renderer.nsImage).size.width
        }
        XCTAssertGreaterThan(try width(Theme.display(32)), try width(Theme.display(32, weight: .light)))
        XCTAssertGreaterThan(try width(Theme.ui(14, .bold)), try width(Theme.ui(14)))
        XCTAssertGreaterThan(try width(Theme.mono(14, .semibold)), 0)
    }
}
