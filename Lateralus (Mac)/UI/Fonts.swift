import CoreText
import SwiftUI

/// The app's two bundled faces, registered into the process at first use.
///
/// Lateralus ships its own typography rather than leaning on the system
/// face: a serif for anything that reads as *writing* (the wordmark,
/// headlines, prompts) and a humanist grotesque for anything that reads as
/// *interface* (labels, controls, counts). Both are OFL — licenses ship
/// alongside the faces in `Resources/Fonts`.
///
/// Registration is scoped to the process, so nothing is installed on the
/// user's Mac and nothing survives quit.
enum Fonts {
    /// Source Serif 4 — display voice.
    enum Serif {
        static let regular = "SourceSerif4-Regular"
        static let semibold = "SourceSerif4-Semibold"
        static let italic = "SourceSerif4-It"
        static let semiboldItalic = "SourceSerif4-SemiboldIt"
    }

    /// Work Sans — interface voice.
    enum Sans {
        static let regular = "WorkSans-Regular"
        static let medium = "WorkSans-Medium"
        static let semibold = "WorkSans-SemiBold"
        static let bold = "WorkSans-Bold"
        static let italic = "WorkSans-Italic"
    }

    /// `true` once Core Text can resolve the bundled faces by PostScript
    /// name. Evaluated exactly once, on first access, before any `Font` is
    /// built — every accessor in `Theme` falls back to a system face if this
    /// is `false`, so a stripped or repackaged bundle degrades quietly
    /// instead of rendering in Helvetica-by-accident.
    static let areAvailable: Bool = {
        registerBundledFaces()
        return NSFont(name: Sans.regular, size: 12) != nil
            && NSFont(name: Serif.semibold, size: 12) != nil
    }()

    private static func registerBundledFaces() {
        let bundle = Bundle.main
        let urls = ["otf", "ttf"].flatMap { bundle.urls(forResourcesWithExtension: $0, subdirectory: nil) ?? [] }
        guard !urls.isEmpty else { return }
        // Duplicate registration (a second window, a re-entrant call) is not
        // an error worth surfacing — the faces are either usable or they
        // aren't, and `areAvailable` answers that directly.
        CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
    }
}
