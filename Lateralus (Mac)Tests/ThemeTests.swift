import AppKit
import SwiftUI
import XCTest
@testable import Lateralus__Mac_

/// The Night Shift tokens resolve to the hex pairs in the redesign summary,
/// in both system appearances.
final class ThemeTests: XCTestCase {

    private struct RGBA: Equatable, CustomStringConvertible {
        let hex: UInt32
        let alpha: Int

        var description: String { String(format: "#%06X @%d%%", hex, alpha) }
    }

    /// Resolves `color` as AppKit draws it in the light or dark appearance.
    private func resolve(_ color: Color, dark: Bool) throws -> RGBA {
        let appearance = try XCTUnwrap(NSAppearance(named: dark ? .darkAqua : .aqua))
        var resolved: NSColor?
        appearance.performAsCurrentDrawingAppearance {
            resolved = NSColor(color).usingColorSpace(.sRGB)
        }
        let rgb = try XCTUnwrap(resolved)
        func byte(_ value: CGFloat) -> UInt32 { UInt32((value * 255).rounded()) }
        return RGBA(
            hex: byte(rgb.redComponent) << 16 | byte(rgb.greenComponent) << 8 | byte(rgb.blueComponent),
            alpha: Int((rgb.alphaComponent * 100).rounded())
        )
    }

    private func assertPair(
        _ color: Color, light: UInt32, dark: UInt32,
        lightAlpha: Int = 100, darkAlpha: Int = 100,
        _ name: String, line: UInt = #line
    ) throws {
        XCTAssertEqual(try resolve(color, dark: false), RGBA(hex: light, alpha: lightAlpha), "\(name) light", line: line)
        XCTAssertEqual(try resolve(color, dark: true), RGBA(hex: dark, alpha: darkAlpha), "\(name) dark", line: line)
    }

    func testTokenPairsMatchSummary() throws {
        try assertPair(Theme.background, light: 0xF5F3EC, dark: 0x111318, "background")
        try assertPair(Theme.surface, light: 0xFFFFFF, dark: 0x191C23, "surface")
        try assertPair(Theme.surfaceSunken, light: 0xECE9DF, dark: 0x222630, "surfaceSunken")
        try assertPair(Theme.sidebar, light: 0xEDEAE1, dark: 0x0C0E12, "sidebar")
        try assertPair(Theme.ink, light: 0x111318, dark: 0xF2EFE7, "ink")
        try assertPair(Theme.accent, light: 0x4A6300, dark: 0xD4F25A, "accent")
        try assertPair(Theme.accentStrong, light: 0x3F5600, dark: 0xD4F25A, "accentStrong")
        try assertPair(Theme.accentSoft, light: 0xE9F7B0, dark: 0xD4F25A, darkAlpha: 14, "accentSoft")
        try assertPair(Theme.mark, light: 0xDDF57A, dark: 0xD4F25A, "mark")
        try assertPair(Theme.onMark, light: 0x111318, dark: 0x111318, "onMark")
        try assertPair(Theme.primaryFill, light: 0x111318, dark: 0xD4F25A, "primaryFill")
        try assertPair(Theme.primaryLabel, light: 0xDDF57A, dark: 0x111318, "primaryLabel")
        try assertPair(Theme.sketchPaper, light: 0xFFFFFF, dark: 0x1B1F27, "sketchPaper")
    }

    func testInkStepsAndDividersFollowInk() throws {
        try assertPair(Theme.inkSecondary, light: 0x111318, dark: 0xF2EFE7, lightAlpha: 68, darkAlpha: 68, "inkSecondary")
        try assertPair(Theme.inkTertiary, light: 0x111318, dark: 0xF2EFE7, lightAlpha: 42, darkAlpha: 42, "inkTertiary")
        try assertPair(Theme.inkQuaternary, light: 0x111318, dark: 0xF2EFE7, lightAlpha: 24, darkAlpha: 24, "inkQuaternary")
        try assertPair(Theme.divider, light: 0x111318, dark: 0xF2EFE7, lightAlpha: 11, darkAlpha: 11, "divider")
        try assertPair(Theme.dividerSoft, light: 0x111318, dark: 0xF2EFE7, lightAlpha: 6, darkAlpha: 6, "dividerSoft")
        try assertPair(Theme.hoverFill, light: 0x111318, dark: 0xF2EFE7, lightAlpha: 5, darkAlpha: 5, "hoverFill")
        try assertPair(Theme.pressedFill, light: 0x111318, dark: 0xF2EFE7, lightAlpha: 10, darkAlpha: 10, "pressedFill")
    }

    func testExerciseTintMatchesAccentInBothModes() throws {
        for exercise in Exercise.allCases {
            for dark in [false, true] {
                XCTAssertEqual(
                    try resolve(exercise.tint, dark: dark), try resolve(Theme.accent, dark: dark),
                    "\(exercise.rawValue) tint, dark: \(dark)"
                )
            }
        }
    }

    func testRadii() {
        XCTAssertEqual(Theme.radiusSmall, 8)
        XCTAssertEqual(Theme.radiusMedium, 14)
        XCTAssertEqual(Theme.radiusLarge, 22)
    }

    /// The near-black ink pen must stay visible on dark sketch paper, and
    /// a saved ink stroke keeps its stored components.
    func testInkPenStrokeFollowsAppearance() throws {
        let ink = SketchPen.ink.components
        let stroke = Sketch.Stroke(points: [], red: ink.red, green: ink.green, blue: ink.blue, width: 3)
        XCTAssertEqual(try resolve(stroke.color, dark: false), RGBA(hex: 0x211F1C, alpha: 100))
        XCTAssertEqual(try resolve(stroke.color, dark: true), RGBA(hex: 0xF2EFE7, alpha: 100))

        let crimson = SketchPen.crimson.components
        let other = Sketch.Stroke(points: [], red: crimson.red, green: crimson.green, blue: crimson.blue, width: 3)
        XCTAssertEqual(try resolve(other.color, dark: false), try resolve(other.color, dark: true))
    }
}
