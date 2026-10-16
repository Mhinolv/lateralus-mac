import CoreText
import SwiftUI

/// The app's bundled variable faces, registered into the process at first
/// use.
///
/// Lateralus ships its own typography rather than leaning on the system
/// face: Source Serif 4 for anything that reads as *writing* (the wordmark,
/// headlines, prompts) and Work Sans for anything that reads as *interface*
/// (labels, controls). Counts use the system monospace. Both faces are
/// OFL — licenses ship alongside the faces in `Resources/Fonts`.
///
/// Every face is a variable font. Weights and optical sizes are set on the
/// variation axes directly, never through named instances, so a font file
/// update that renames its instances changes nothing here.
///
/// Registration is scoped to the process, so nothing is installed on the
/// user's Mac and nothing survives quit.
enum Fonts {
    /// One bundled font file. Each family is checked on its own: if one
    /// file is missing or fails to load, only its accessor falls back.
    enum Family: CaseIterable {
        /// Source Serif 4 — display voice.
        case sourceSerif
        /// Source Serif 4 Italic — display italics and the wordmark.
        case sourceSerifItalic
        /// Work Sans — interface voice.
        case workSans
        /// Work Sans Italic — `Theme.ui(italic: true)`.
        case workSansItalic

        var fileName: String {
            switch self {
            case .sourceSerif: "SourceSerif4[opsz,wght]"
            case .sourceSerifItalic: "SourceSerif4-Italic[opsz,wght]"
            case .workSans: "WorkSans[wght]"
            case .workSansItalic: "WorkSans-Italic[wght]"
            }
        }
    }

    /// OpenType variation axis tags used by the bundled faces.
    enum Axis: String {
        case weight = "wght"
        case opticalSize = "opsz"

        /// The four-byte tag as Core Text's numeric axis identifier.
        var identifier: UInt32 {
            rawValue.utf8.reduce(0) { $0 << 8 | UInt32($1) }
        }
    }

    /// Source Serif 4 tracks the point size inside its 8–60 axis range, so
    /// small text gets the sturdy caption cut and headlines the fine
    /// display cut.
    static func sourceSerifOpticalSize(for size: CGFloat) -> CGFloat {
        min(max(size, 8), 60)
    }

    /// `true` if `family` loaded and can build fonts.
    static func isAvailable(_ family: Family) -> Bool {
        baseDescriptors[family] != nil
    }

    /// `family` at `size` with each axis in `axes` pinned. `nil` if the
    /// family did not load — callers fall back to a system face.
    static func font(_ family: Family, size: CGFloat, axes: [Axis: CGFloat]) -> CTFont? {
        guard let base = baseDescriptors[family] else { return nil }
        let variation = Dictionary(uniqueKeysWithValues: axes.map { (NSNumber(value: $0.key.identifier), NSNumber(value: Double($0.value))) })
        let descriptor = CTFontDescriptorCreateCopyWithAttributes(
            base,
            [kCTFontVariationAttribute: variation] as CFDictionary
        )
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }

    /// The first descriptor of each bundled file, after process
    /// registration. Evaluated exactly once, on first access, before any
    /// `Font` is built. A stripped or repackaged bundle leaves a family out
    /// of this map, and that family degrades quietly to a system face.
    private static let baseDescriptors: [Family: CTFontDescriptor] = {
        var descriptors: [Family: CTFontDescriptor] = [:]
        for family in Family.allCases {
            guard
                let url = Bundle.main.url(forResource: family.fileName, withExtension: "ttf"),
                let found = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
                let first = found.first
            else { continue }
            // Duplicate registration (a second window, a re-entrant call)
            // is not an error worth surfacing — the descriptor loaded from
            // the file is usable either way.
            CTFontManagerRegisterFontURLs([url] as CFArray, .process, true, nil)
            descriptors[family] = first
        }
        return descriptors
    }()
}
