import AppKit
import CoreText
import SwiftUI

/// The "Lamplight" look: warm parchment with a terracotta accent in light
/// mode, a lamp-lit brown desk with a coral accent in dark mode. A serif
/// display voice sits against a plain sans interface voice.
///
/// Every color is a light/dark pair that follows the system appearance.
/// There are no per-discipline hues: where one item must be singled out,
/// it takes the accent and everything else stays ink. All text meets
/// 4.5:1, so accent-colored text uses `accentText`.
enum Theme {

    // MARK: - Ground

    /// The window ground.
    static let background = adaptive(0xF8F2E8, 0x1C1813)
    /// Cards, inputs, and any surface that lifts off the ground.
    static let surface = adaptive(0xF1E9DC, 0x26201A)
    /// The deepest step — search fields, disabled fills, monogram tiles.
    static let surfaceSunken = adaptive(0xEAE0CE, 0x30281F)
    /// The sidebar column, a step outside the ground.
    static let sidebar = adaptive(0xEFE6D7, 0x211C16)
    /// The sheet the sketch canvas and viewer draw on. It stays light in
    /// dark mode, so pens draw their saved colors in both appearances.
    static let sketchPaper = adaptive(0xFDF9F1, 0xE8DDC9)

    // MARK: - Ink

    static let ink = adaptive(0x2B2419, 0xEFE6D6)
    static let inkSecondary = adaptive(0x2B2419, 0xEFE6D6, lightAlpha: 0.68, darkAlpha: 0.70)
    static let inkTertiary = adaptive(0x2B2419, 0xEFE6D6, lightAlpha: 0.45, darkAlpha: 0.46)
    /// The faintest legible ink — de-emphasized chart bars, hint text.
    static let inkQuaternary = ink.opacity(0.24)

    // MARK: - Accent

    /// The app's one hue. `accentStrong` is the text step for kickers,
    /// large numbers, and text on soft washes; `accentSoft` is the wash.
    static let accent = adaptive(0xB5502E, 0xE07A52)
    static let accentStrong = adaptive(0x7A3A1F, 0xF2A585)
    static let accentSoft = adaptive(0xF0DCC9, 0x3D271B)
    /// Accent-colored text on the ground or a surface. Light `accent` is
    /// about 4.2:1 on `surface`, so light mode takes `accentStrong`.
    static let accentText = adaptive(0x7A3A1F, 0xE07A52)
    /// The selection highlight behind the dealt prompt phrase, and the text
    /// that sits on it.
    static let mark = accentSoft
    static let onMark = accentStrong
    /// The primary action: a solid terracotta fill with a white label in
    /// light mode, a coral fill with a ground-colored label in dark mode.
    static let primaryFill = accent
    static let primaryLabel = adaptive(0xFFFFFF, 0x1C1813)

    // MARK: - Strokes

    /// The standard hairline — card borders, input wells, list separators.
    static let divider = ink.opacity(0.12)
    /// A quieter rule, for dividing text from text rather than surface from
    /// surface.
    static let dividerSoft = ink.opacity(0.07)
    /// Covers a window that must not take input, such as during a restore.
    static let scrim = background.opacity(0.88)
    static let hoverFill = ink.opacity(0.05)
    static let pressedFill = ink.opacity(0.1)

    // MARK: - Radii

    /// Three steps. Inputs, rows, and icon controls take `small`, buttons,
    /// controls, and tiles take `medium`, cards and sheets take `large`.
    /// Only `Badge` is a capsule.
    static let radiusSmall: CGFloat = 6
    static let radiusMedium: CGFloat = 10
    static let radiusLarge: CGFloat = 16

    /// The default corner for anything that doesn't say otherwise.
    static let radius: CGFloat = radiusMedium

    // MARK: - Appearance

    /// A color that resolves to `light` or `dark` (sRGB hex) from the
    /// appearance it is drawn in, so the app follows the system setting.
    static func adaptive(
        _ light: UInt32, _ dark: UInt32,
        lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            isDark(appearance) ? srgb(dark, alpha: darkAlpha) : srgb(light, alpha: lightAlpha)
        })
    }

    static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    private static func srgb(_ hex: UInt32, alpha: CGFloat) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    // MARK: - Type

    /// Display type — Source Serif 4. Used for the wordmark, screen
    /// headlines, prompts, and entry recaps: everything that is *writing*
    /// rather than *interface*. The optical size follows the point size.
    static func display(_ size: CGFloat, weight: DisplayWeight = .semibold, italic: Bool = false) -> Font {
        cachedFont(.display(size, weight, italic)) {
            guard let font = displayFont(size, weight: weight, italic: italic) else {
                let system = Font.system(size: size, weight: weight.systemWeight, design: .serif)
                return italic ? system.italic() : system
            }
            return Font(font)
        }
    }

    /// Source Serif 4 at the given size and weight, or `nil` if the face
    /// did not load.
    static func displayFont(_ size: CGFloat, weight: DisplayWeight = .semibold, italic: Bool = false) -> CTFont? {
        Fonts.font(italic ? .sourceSerifItalic : .sourceSerif, size: size, axes: [
            .weight: weight.rawValue,
            .opticalSize: Fonts.sourceSerifOpticalSize(for: size),
        ])
    }

    /// Display weights. `.light` is for the large Insights headlines and
    /// the Today detail, prompts sit at `.regular`, and titles at `.semibold`.
    enum DisplayWeight: CGFloat {
        case light = 300
        case regular = 400
        case semibold = 600

        var systemWeight: Font.Weight {
            switch self {
            case .light: .light
            case .regular: .regular
            case .semibold: .semibold
            }
        }
    }

    /// Interface type — Work Sans. Labels, controls, body copy, everything
    /// that isn't a headline.
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        cachedFont(.ui(size, weight, italic)) {
            guard let font = uiFont(size, weight, italic: italic) else {
                let system = Font.system(size: size, weight: weight)
                return italic ? system.italic() : system
            }
            return Font(font)
        }
    }

    /// Work Sans at the given size and weight, or `nil` if the face did not
    /// load. Italic interface text uses Work Sans Italic at the same weight.
    static func uiFont(_ size: CGFloat, _ weight: Font.Weight = .regular, italic: Bool = false) -> CTFont? {
        Fonts.font(italic ? .workSansItalic : .workSans, size: size, axes: [
            .weight: uiWeight(weight),
        ])
    }

    /// Work Sans `wght` for a SwiftUI weight: 400, 500, 600, or 700.
    static func uiWeight(_ weight: Font.Weight) -> CGFloat {
        switch weight {
        case .bold, .heavy, .black: 700
        case .semibold: 600
        case .medium: 500
        default: 400
        }
    }

    /// Anything counted or compared — streaks, totals, word counts, error
    /// detail. The system monospace, so digits stay even.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Accessors run in view bodies, so each size, weight, and style builds
    /// its Core Text font once.
    private enum FontKey: Hashable {
        case display(CGFloat, DisplayWeight, Bool)
        case ui(CGFloat, Font.Weight, Bool)
    }

    private static var fontCache: [FontKey: Font] = [:]

    private static func cachedFont(_ key: FontKey, make: () -> Font) -> Font {
        if let font = fontCache[key] { return font }
        let font = make()
        fontCache[key] = font
        return font
    }
}

/// Flat ambient backdrop — no gradient, no glow. The system spends its
/// boldness on the accent alone.
struct AppBackground: View {
    var body: some View {
        Theme.background.ignoresSafeArea()
    }
}

/// Elevation steps. Light mode casts ink-colored shadows, so surfaces read
/// as paper lifting off paper. Dark mode casts neutral black: an ink-tinted
/// shadow would glow, because dark-mode ink is light.
enum Elevation {
    case none, sm, md, lg
}

extension View {
    /// Raised, borderless surface. `elevation` adds a shadow; most cards
    /// want `.sm`, hero panels want `.md`, and `.lg` is reserved for sheets and popovers floating over a scrim.
    func paperCard(cornerRadius: CGFloat = Theme.radiusMedium, elevation: Elevation = .none) -> some View {
        background(Theme.surface, in: .rect(cornerRadius: cornerRadius))
            .modifier(ElevationModifier(elevation: elevation))
    }

    /// A card that also carries a hairline — used where a surface has to
    /// hold its own edge against the ground, like the daily challenge.
    func outlinedCard(cornerRadius: CGFloat = Theme.radiusLarge, elevation: Elevation = .sm) -> some View {
        background(Theme.surface, in: .rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Theme.divider, lineWidth: 1)
            )
            .modifier(ElevationModifier(elevation: elevation))
    }

    /// Recessed input surface. Inside a card it sits on the *ground* color,
    /// a step below its container — that inversion is what makes it read as
    /// a well rather than another panel.
    func inputWell(cornerRadius: CGFloat = Theme.radiusSmall, fill: Color = Theme.background) -> some View {
        background(fill, in: .rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Theme.divider, lineWidth: 1)
            )
    }
}

private struct ElevationModifier: ViewModifier {
    let elevation: Elevation

    func body(content: Content) -> some View {
        switch elevation {
        case .none:
            content
        case .sm:
            content
                .shadow(color: Self.shadow(0.06, dark: 0.30), radius: 1, x: 0, y: 1)
                .shadow(color: Self.shadow(0.08, dark: 0.35), radius: 10, x: 0, y: 4)
        case .md:
            content
                .shadow(color: Self.shadow(0.07, dark: 0.35), radius: 2, x: 0, y: 1)
                .shadow(color: Self.shadow(0.10, dark: 0.45), radius: 18, x: 0, y: 8)
        case .lg:
            content.shadow(color: Self.shadow(0.18, dark: 0.55), radius: 28, x: 0, y: 16)
        }
    }

    /// Light-mode ink at `light` opacity, dark-mode black at `dark`. Never
    /// `Theme.ink`, which is light in dark mode.
    static func shadow(_ light: CGFloat, dark: CGFloat) -> Color {
        Theme.adaptive(0x2B2419, 0x000000, lightAlpha: light, darkAlpha: dark)
    }
}

/// A quiet uppercase kicker label, sitting above headlines, sections, and
/// day groups.
struct SectionLabel: View {
    let text: String
    var tint: Color = Theme.inkTertiary

    var body: some View {
        Text(text)
            .font(Theme.ui(11, .semibold))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(tint)
    }
}

/// The 22 pt two-letter tile that marks a discipline in the sidebar. Quiet
/// on `surfaceSunken`, or a solid `primaryFill` tile on the selected row.
struct DisciplineMonogram: View {
    let exercise: Exercise
    var selected: Bool = false

    var body: some View {
        Text(exercise.monogram)
            .font(Theme.ui(9.5, .bold))
            .foregroundStyle(selected ? Theme.primaryLabel : Theme.inkSecondary)
            .frame(width: 22, height: 22)
            .background(
                selected ? Theme.primaryFill : Theme.surfaceSunken,
                in: .rect(cornerRadius: Theme.radiusSmall)
            )
            .accessibilityHidden(true)
    }
}

/// A discipline label: the name in semibold accent text. Deliberately not
/// a chip — an outline around every row's tag turned the list into a grid
/// of boxes.
struct Tag: View {
    let text: String
    var size: CGFloat = 12

    var body: some View {
        Text(text)
            .font(Theme.ui(size, .semibold))
            .foregroundStyle(Theme.accentText)
    }
}

/// The one outlined chip in the system, reserved for status that isn't the
/// row's identity — the "Daily" mark and the answered-today flag.
struct Badge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.ui(10, .semibold))
            .foregroundStyle(Theme.inkSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .overlay(
                Capsule().strokeBorder(Theme.divider, lineWidth: 1)
            )
    }
}

/// The prompt highlight: prompt text with its dealt fragment set on the
/// `mark` selection fill in `onMark` ink. The rest of the text keeps the style of the `Text`
/// that shows it.
enum Highlight {
    static func attributed(_ text: String, marking phrase: String?) -> AttributedString {
        var result = AttributedString(text)
        guard let range = markedRange(in: text, phrase: phrase),
              let lower = AttributedString.Index(range.lowerBound, within: result),
              let upper = AttributedString.Index(range.upperBound, within: result)
        else { return result }
        result[lower..<upper].backgroundColor = Theme.mark
        result[lower..<upper].foregroundColor = Theme.onMark
        return result
    }

    /// The last occurrence of `phrase` in `text`. Every template puts the
    /// dealt fragment after its fixed lead, so the last match is the dealt
    /// one even when the lead repeats a word of it.
    static func markedRange(in text: String, phrase: String?) -> Range<String.Index>? {
        guard let phrase, !phrase.isEmpty else { return nil }
        return text.range(of: phrase, options: .backwards)
    }
}

/// Darkens custom chrome under the pointer, since plain-style buttons
/// don't get a system hover effect. Pass the control's hit shape so the
/// highlight matches its drawn corners.
private struct HoverHighlight<S: Shape>: ViewModifier {
    let shape: S
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    private var isLit: Bool { isHovered && isEnabled }

    func body(content: Content) -> some View {
        content
            .overlay(shape.fill(Theme.hoverFill.opacity(isLit ? 1 : 0)).allowsHitTesting(false))
            .onHover { isHovered = $0 }
            .animation(.easeInOut(duration: 0.12), value: isLit)
    }
}

extension View {
    func hoverHighlight(in shape: some Shape = RoundedRectangle(cornerRadius: Theme.radiusSmall)) -> some View {
        modifier(HoverHighlight(shape: shape))
    }

    /// Hover highlight matching a specific corner radius, for controls that
    /// don't take the default.
    func hoverHighlight(cornerRadius: CGFloat) -> some View {
        modifier(HoverHighlight(shape: RoundedRectangle(cornerRadius: cornerRadius)))
    }
}

/// The system's primary action: a solid `primaryFill` rounded rect with a
/// `primaryLabel` title. `shortcutHint` names the key that also runs the
/// action, in mono at reduced opacity after the title.
struct PrimaryActionButtonLabel: View {
    let title: String
    var enabled: Bool = true
    var fullWidth: Bool = false
    var shortcutHint: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            if let shortcutHint {
                Text(shortcutHint)
                    .font(Theme.mono(13, .regular))
                    .opacity(0.65)
            }
        }
        .font(Theme.ui(15, .semibold))
        // Disabled still has to be readable — it names the action you'd
        // get, and this is the only button on the card.
        .foregroundStyle(enabled ? Theme.primaryLabel : Theme.inkSecondary)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .padding(.horizontal, fullWidth ? 0 : 22)
        .padding(.vertical, 12)
        .background(
            enabled ? Theme.primaryFill : Theme.surfaceSunken,
            in: .rect(cornerRadius: Theme.radiusMedium)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .strokeBorder(enabled ? .clear : Theme.divider, lineWidth: 1)
        )
        .contentShape(.rect(cornerRadius: Theme.radiusMedium))
        .hoverHighlight(cornerRadius: Theme.radiusMedium)
    }
}

/// A themed stand-in for `ContentUnavailableView`. The stock control is the
/// one place the app would otherwise render in the system face on a system
/// grey — conspicuous next to everything else here.
struct EmptyStateView<Actions: View>: View {
    let title: String
    let message: String
    @ViewBuilder var actions: Actions

    init(title: String, message: String, @ViewBuilder actions: () -> Actions = { EmptyView() }) {
        self.title = title
        self.message = message
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(Theme.display(20))
                .foregroundStyle(Theme.ink)
                .padding(.bottom, 8)
            Text(message)
                .font(Theme.ui(14))
                .lineSpacing(4)
                .foregroundStyle(Theme.inkTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 340)
            actions
                .padding(.top, 24)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The system's secondary action: a surface rounded rect, hairline, ink
/// text.
/// `small` is the header-sized step, 30 pt high.
struct SecondaryActionButtonLabel: View {
    let title: String
    var systemImage: String?
    var fullWidth: Bool = false
    var small: Bool = false

    var body: some View {
        HStack(spacing: small ? 5 : 6) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: small ? 11 : 12, weight: .semibold))
            }
            Text(title)
        }
        .font(Theme.ui(small ? 12.5 : 14, .semibold))
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .frame(height: small ? 30 : nil)
        .padding(.horizontal, fullWidth ? 0 : small ? 12 : 16)
        .padding(.vertical, small ? 0 : 10)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .strokeBorder(Theme.divider, lineWidth: 1)
        )
        .contentShape(.rect(cornerRadius: Theme.radiusMedium))
        .hoverHighlight(cornerRadius: Theme.radiusMedium)
    }
}

/// A 30 pt square icon control with small corners: `surface` with a
/// hairline, or an `accentSoft` wash with an `accent` icon while the
/// control is active, such as a filter that is on.
struct IconCapsuleLabel: View {
    let systemImage: String
    var active: Bool = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(active ? Theme.accent : Theme.inkSecondary)
            .frame(width: 30, height: 30)
            .background(
                active ? Theme.accentSoft : Theme.surface,
                in: .rect(cornerRadius: Theme.radiusSmall)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .strokeBorder(active ? .clear : Theme.divider, lineWidth: 1)
            )
            .contentShape(.rect(cornerRadius: Theme.radiusSmall))
            .hoverHighlight()
    }
}
