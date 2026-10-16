import CoreText
import SwiftUI
import XCTest
@testable import Lateralus__Mac_

/// The Lamplight type stack: each Theme accessor resolves to its bundled
/// variable face with the axes from the design notes.
final class FontsTests: XCTestCase {

    /// The axis values Core Text applied to `font`, keyed by tag. Core Text
    /// leaves out an axis that sits at its default, so read those from the
    /// font's axis table.
    private func axes(_ font: CTFont) -> [String: Double] {
        let variation = CTFontCopyVariation(font) as? [NSNumber: NSNumber] ?? [:]
        let table = CTFontCopyVariationAxes(font) as? [[String: Any]] ?? []
        let tags: [Fonts.Axis] = [.weight, .opticalSize]
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
        for name in ["OFL-SourceSerif4", "OFL-WorkSans"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "txt"), name)
            let text = try String(contentsOf: url, encoding: .utf8)
            XCTAssertTrue(text.contains("SIL Open Font License"), name)
        }
    }

    /// Owner decision: Fraunces, Bricolage Grotesque, JetBrains Mono, and
    /// their licenses no longer ship.
    func testNightShiftFacesAreGone() {
        let faces = [
            "Fraunces[SOFT,WONK,opsz,wght]", "Fraunces-Italic[SOFT,WONK,opsz,wght]",
            "BricolageGrotesque[opsz,wdth,wght]", "JetBrainsMono[wght]",
        ]
        for name in faces {
            XCTAssertNil(Bundle.main.url(forResource: name, withExtension: "ttf"), name)
        }
        for name in ["OFL-Fraunces", "OFL-BricolageGrotesque", "OFL-JetBrainsMono"] {
            XCTAssertNil(Bundle.main.url(forResource: name, withExtension: "txt"), name)
        }
    }

    func testSourceSerifOpticalSizeClampsTo8Through60() {
        XCTAssertEqual(Fonts.sourceSerifOpticalSize(for: 6), 8)
        XCTAssertEqual(Fonts.sourceSerifOpticalSize(for: 8), 8)
        XCTAssertEqual(Fonts.sourceSerifOpticalSize(for: 13.5), 13.5)
        XCTAssertEqual(Fonts.sourceSerifOpticalSize(for: 22), 22)
        XCTAssertEqual(Fonts.sourceSerifOpticalSize(for: 60), 60)
        XCTAssertEqual(Fonts.sourceSerifOpticalSize(for: 200), 60)
    }

    func testDisplayIsSourceSerifWithPinnedAxes() throws {
        let cases: [(CGFloat, Theme.DisplayWeight, Bool, Double, Double)] = [
            (22, .semibold, true, 600, 22),   // wordmark
            (36, .semibold, false, 600, 36),
            (32, .light, false, 300, 32),
            (72, .light, false, 300, 60),
            (13, .regular, true, 400, 13),
            (7, .regular, false, 400, 8),
        ]
        for (size, weight, italic, wght, opsz) in cases {
            let font = try XCTUnwrap(Theme.displayFont(size, weight: weight, italic: italic))
            let label = "display(\(size), \(weight), italic: \(italic))"
            XCTAssertEqual(family(font), "Source Serif 4", label)
            XCTAssertEqual(isItalic(font), italic, label)
            XCTAssertEqual(CTFontGetSize(font), size, label)
            let applied = axes(font)
            XCTAssertEqual(applied["wght"], wght, label)
            XCTAssertEqual(applied["opsz"], opsz, label)
        }
    }

    func testUIIsWorkSansAtEveryWeight() throws {
        let cases: [(Font.Weight, Double)] = [
            (.ultraLight, 400), (.light, 400), (.regular, 400), (.medium, 500),
            (.semibold, 600), (.bold, 700), (.heavy, 700), (.black, 700),
        ]
        for (weight, wght) in cases {
            for italic in [false, true] {
                let font = try XCTUnwrap(Theme.uiFont(13.5, weight, italic: italic))
                let label = "\(weight), italic: \(italic)"
                XCTAssertEqual(family(font), "Work Sans", label)
                XCTAssertEqual(isItalic(font), italic, label)
                XCTAssertEqual(CTFontGetSize(font), 13.5, label)
                XCTAssertEqual(axes(font)["wght"], wght, label)
            }
        }
    }

    /// Counts use the system monospace. No bundled mono face ships.
    @MainActor
    func testMonoIsSystemMonospace() throws {
        XCTAssertEqual(Theme.mono(12), Font.system(size: 12, weight: .semibold, design: .monospaced))
        XCTAssertEqual(Theme.mono(26, .regular), Font.system(size: 26, weight: .regular, design: .monospaced))
        func width(_ text: String) throws -> CGFloat {
            let renderer = ImageRenderer(content: Text(text).font(Theme.mono(14)).fixedSize())
            return try XCTUnwrap(renderer.nsImage).size.width
        }
        XCTAssertEqual(try width("1111"), try width("8888"), accuracy: 0.5, "Digits stay even")
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
    }
}
