import AppKit
import SwiftUI
import XCTest
@testable import Lateralus__Mac_

/// The Lamplight tokens resolve to the hex pairs in the redesign mockup,
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

    /// The pairs match `.dir-a.mode-light` and `.dir-a.mode-dark` in the
    /// Lamplight mockup.
    func testTokenPairsMatchLamplightMockup() throws {
        try assertPair(Theme.background, light: 0xF8F2E8, dark: 0x1C1813, "background")
        try assertPair(Theme.surface, light: 0xF1E9DC, dark: 0x26201A, "surface")
        try assertPair(Theme.surfaceSunken, light: 0xEAE0CE, dark: 0x30281F, "surfaceSunken")
        try assertPair(Theme.sidebar, light: 0xEFE6D7, dark: 0x211C16, "sidebar")
        try assertPair(Theme.ink, light: 0x2B2419, dark: 0xEFE6D6, "ink")
        try assertPair(Theme.accent, light: 0xB5502E, dark: 0xE07A52, "accent")
        try assertPair(Theme.accentStrong, light: 0x7A3A1F, dark: 0xF2A585, "accentStrong")
        try assertPair(Theme.accentSoft, light: 0xF0DCC9, dark: 0x3D271B, "accentSoft")
        try assertPair(Theme.accentText, light: 0x7A3A1F, dark: 0xE07A52, "accentText")
        try assertPair(Theme.mark, light: 0xF0DCC9, dark: 0x3D271B, "mark")
        try assertPair(Theme.onMark, light: 0x7A3A1F, dark: 0xF2A585, "onMark")
        try assertPair(Theme.primaryFill, light: 0xB5502E, dark: 0xE07A52, "primaryFill")
        try assertPair(Theme.primaryLabel, light: 0xFFFFFF, dark: 0x1C1813, "primaryLabel")
        try assertPair(Theme.sketchPaper, light: 0xFDF9F1, dark: 0xE8DDC9, "sketchPaper")
    }

    func testInkStepsAndDividersFollowInk() throws {
        try assertPair(Theme.inkSecondary, light: 0x2B2419, dark: 0xEFE6D6, lightAlpha: 68, darkAlpha: 70, "inkSecondary")
        try assertPair(Theme.inkTertiary, light: 0x2B2419, dark: 0xEFE6D6, lightAlpha: 45, darkAlpha: 46, "inkTertiary")
        try assertPair(Theme.inkQuaternary, light: 0x2B2419, dark: 0xEFE6D6, lightAlpha: 24, darkAlpha: 24, "inkQuaternary")
        try assertPair(Theme.divider, light: 0x2B2419, dark: 0xEFE6D6, lightAlpha: 12, darkAlpha: 12, "divider")
        try assertPair(Theme.dividerSoft, light: 0x2B2419, dark: 0xEFE6D6, lightAlpha: 7, darkAlpha: 7, "dividerSoft")
        try assertPair(Theme.hoverFill, light: 0x2B2419, dark: 0xEFE6D6, lightAlpha: 5, darkAlpha: 5, "hoverFill")
        try assertPair(Theme.pressedFill, light: 0x2B2419, dark: 0xEFE6D6, lightAlpha: 10, darkAlpha: 10, "pressedFill")
    }

    /// WCAG relative luminance of an opaque sRGB color.
    private func luminance(_ hex: UInt32) -> Double {
        func channel(_ byte: UInt32) -> Double {
            let c = Double(byte) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(hex >> 16 & 0xFF) + 0.7152 * channel(hex >> 8 & 0xFF) + 0.0722 * channel(hex & 0xFF)
    }

    private func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Owner decision: text meets 4.5:1. Accent text, primary labels, and
    /// the prompt highlight pass on every ground they sit on.
    func testTextPairsMeetFourPointFiveToOne() throws {
        let grounds: [(Color, String)] = [(Theme.background, "background"), (Theme.surface, "surface")]
        for dark in [false, true] {
            for (ground, name) in grounds {
                let text = try resolve(Theme.accentText, dark: dark).hex
                let fill = try resolve(ground, dark: dark).hex
                XCTAssertGreaterThanOrEqual(contrast(text, fill), 4.5, "accentText on \(name), dark: \(dark)")
            }
            let pairs: [(Color, Color, String)] = [
                (Theme.primaryLabel, Theme.primaryFill, "primaryLabel on primaryFill"),
                (Theme.onMark, Theme.mark, "onMark on mark"),
                (Theme.accentStrong, Theme.accentSoft, "accentStrong on accentSoft"),
            ]
            for (text, fill, name) in pairs {
                let ratio = contrast(try resolve(text, dark: dark).hex, try resolve(fill, dark: dark).hex)
                XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(name), dark: \(dark)")
            }
        }
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
        XCTAssertEqual(Theme.radiusSmall, 6)
        XCTAssertEqual(Theme.radiusMedium, 10)
        XCTAssertEqual(Theme.radiusLarge, 16)
    }

    func testMonogramsAreTheDesignCodes() {
        let codes = Exercise.practice.map(\.monogram)
        XCTAssertEqual(codes, ["AU", "TU", "RS", "FU", "BS", "PF", "RD", "CW", "CT", "PS", "IN", "MM"])
        XCTAssertEqual(Set(codes).count, codes.count, "Every tile is distinct")
    }

    /// The ink pen keeps its saved color on the light paper in dark mode.
    func testInkPenStrokeDrawsSavedColorInBothModes() throws {
        let ink = SketchPen.ink.components
        let stroke = Sketch.Stroke(points: [], red: ink.red, green: ink.green, blue: ink.blue, width: 3)
        XCTAssertEqual(try resolve(stroke.color, dark: false), RGBA(hex: 0x211F1C, alpha: 100))
        XCTAssertEqual(try resolve(stroke.color, dark: true), RGBA(hex: 0x211F1C, alpha: 100))
    }
}
