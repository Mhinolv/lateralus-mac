import AppKit
import CoreText
import SwiftUI

/// The "Night Shift" look: a blue-black night desk and a lime highlighter
/// in dark mode, warm paper with an olive accent in light mode. A serif
/// display voice sits against a grotesque interface voice.
///
/// Every color is a light/dark pair that follows the system appearance.
/// There are no per-discipline hues: where one item must be singled out,
/// it takes the accent and everything else stays ink. Lime is only a fill
/// in light mode, never text — light accent text is olive.
enum Theme {

    // MARK: - Ground

    /// The window ground.
    static let background = adaptive(0xF5F3EC, 0x111318)
    /// Cards, inputs, and any surface that lifts off the ground.
    static let surface = adaptive(0xFFFFFF, 0x191C23)
    /// The deepest step — chart tracks, monogram tiles, disabled fills.
    static let surfaceSunken = adaptive(0xECE9DF, 0x222630)
    /// The sidebar column, a step outside the ground.
    static let sidebar = adaptive(0xEDEAE1, 0x0C0E12)
    /// The sheet the sketch canvas and viewer draw on.
    static let sketchPaper = adaptive(0xFFFFFF, 0x1B1F27)

    // MARK: - Ink

    static let ink = adaptive(0x111318, 0xF2EFE7)
    static let inkSecondary = ink.opacity(0.68)
    static let inkTertiary = ink.opacity(0.42)
    /// The faintest legible ink — de-emphasized chart bars, hint text.
    static let inkQuaternary = ink.opacity(0.24)

    // MARK: - Accent

    /// The app's one hue. `accentStrong` is the text step for kickers,
    /// large numbers, and text on soft washes; `accentSoft` is the wash.
    static let accent = adaptive(0x4A6300, 0xD4F25A)
    static let accentStrong = adaptive(0x3F5600, 0xD4F25A)
    static let accentSoft = adaptive(0xE9F7B0, 0xD4F25A, darkAlpha: 0.14)
    /// The highlighter fill, and the text that sits on it.
    static let mark = adaptive(0xDDF57A, 0xD4F25A)
    static let onMark = adaptive(0x111318, 0x111318)
    /// The primary action: an ink pill with a lime label in light mode, a
    /// lime pill with an ink label in dark mode.
    static let primaryFill = adaptive(0x111318, 0xD4F25A)
    static let primaryLabel = adaptive(0xDDF57A, 0x111318)

    // MARK: - Strokes

    /// The standard hairline — card borders, input wells, list separators.
    static let divider = ink.opacity(0.11)
    /// A quieter rule, for dividing text from text rather than surface from
    /// surface.
    static let dividerSoft = ink.opacity(0.06)
    /// Covers a window that must not take input, such as during a restore.
    static let scrim = background.opacity(0.88)
    static let hoverFill = ink.opacity(0.05)
    static let pressedFill = ink.opacity(0.1)

    // MARK: - Radii

    /// Three steps, plus `Capsule` for anything fully rounded. Inputs and
    /// rows take `small`, controls and tiles take `medium`, cards and sheets
    /// take `large`. Buttons are capsules.
    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 14
    static let radiusLarge: CGFloat = 22

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

    /// Display type — Fraunces. Used for the wordmark, screen headlines,
    /// prompts, and entry recaps: everything that is *writing* rather than
    /// *interface*. Above 28 pt it takes the 144 pt optical cut.
    static func display(_ size: CGFloat, weight: DisplayWeight = .semibold, italic: Bool = false) -> Font {
        cachedFont(.display(size, weight, italic)) {
            guard let font = displayFont(size, weight: weight, italic: italic) else {
                let system = Font.system(size: size, weight: weight.systemWeight, design: .serif)
                return italic ? system.italic() : system
            }
            return Font(font)
        }
    }

    /// Fraunces at the given size and weight, or `nil` if the face did not
    /// load. `SOFT` and `WONK` stay at 0 for a crisp, regular cut.
    static func displayFont(_ size: CGFloat, weight: DisplayWeight = .semibold, italic: Bool = false) -> CTFont? {
        Fonts.font(italic ? .frauncesItalic : .fraunces, size: size, axes: [
            .weight: weight.rawValue,
            .opticalSize: Fonts.frauncesOpticalSize(for: size),
            .soft: 0,
            .wonky: 0,
        ])
    }

    /// Display weights. `.light` is for the large Today and Insights
    /// headlines, prompts sit at `.regular`, and titles at `.semibold`.
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

    /// Interface type — Bricolage Grotesque. Labels, controls, body copy,
    /// everything that isn't a headline.
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        cachedFont(.ui(size, weight, italic)) {
            guard let font = uiFont(size, weight, italic: italic) else {
                let system = Font.system(size: size, weight: weight)
                return italic ? system.italic() : system
            }
            return Font(font)
        }
    }

    /// Bricolage at the given size and weight, or `nil` if the face did not
    /// load. Bricolage has no italic, so italic interface text is Fraunces
    /// Italic at the regular weight.
    static func uiFont(_ size: CGFloat, _ weight: Font.Weight = .regular, italic: Bool = false) -> CTFont? {
        if italic {
            return Fonts.font(.frauncesItalic, size: size, axes: [
                .weight: DisplayWeight.regular.rawValue,
                .opticalSize: Fonts.frauncesOpticalSize(for: size),
                .soft: 0,
                .wonky: 0,
            ])
        }
        return Fonts.font(.bricolage, size: size, axes: [
            .weight: uiWeight(weight),
            .opticalSize: Fonts.bricolageOpticalSize(for: size),
            .width: 100,
        ])
    }

    /// Bricolage `wght` for a SwiftUI weight: 400, 500, 600, or 700.
    static func uiWeight(_ weight: Font.Weight) -> CGFloat {
        switch weight {
        case .bold, .heavy, .black: 700
        case .semibold: 600
        case .medium: 500
        default: 400
        }
    }

    /// Anything counted or compared — streaks, totals, word counts, error
    /// detail. JetBrains Mono, so digits stay even.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        cachedFont(.mono(size, weight)) {
            guard let font = monoFont(size, weight) else {
                return .system(size: size, weight: weight, design: .monospaced)
            }
            return Font(font)
        }
    }

    /// JetBrains Mono at the given size and weight, or `nil` if the face
    /// did not load.
    static func monoFont(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> CTFont? {
        Fonts.font(.jetBrainsMono, size: size, axes: [.weight: monoWeight(weight)])
    }

    /// JetBrains Mono `wght` for a SwiftUI weight: 400, or 600 for
    /// semibold and heavier.
    static func monoWeight(_ weight: Font.Weight) -> CGFloat {
        switch weight {
        case .semibold, .bold, .heavy, .black: 600
        default: 400
        }
    }

    /// Accessors run in view bodies, so each size, weight, and style builds
    /// its Core Text font once.
    private enum FontKey: Hashable {
        case display(CGFloat, DisplayWeight, Bool)
        case ui(CGFloat, Font.Weight, Bool)
        case mono(CGFloat, Font.Weight)
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
        Theme.adaptive(0x111318, 0x000000, lightAlpha: light, darkAlpha: dark)
    }
}

/// Uppercase kicker label — the system's one recurring structural motif,
/// sitting above headlines and cards.
struct SectionLabel: View {
    let text: String
    var tint: Color = Theme.accent

    var body: some View {
        Text(text)
            .font(Theme.ui(11, .semibold))
            .textCase(.uppercase)
            .kerning(0.9)
            .foregroundStyle(tint)
    }
}

/// A discipline label. Deliberately not a chip: at the sizes it appears
/// (journal rows, recent entries, entry headers) an outline around every
/// row's tag turned the list into a grid of boxes. Accent-colored text
/// carries the same information and lets the row breathe.
struct Tag: View {
    let text: String
    var size: CGFloat = 11

    var body: some View {
        Text(text)
            .font(Theme.ui(size, .semibold))
            .foregroundStyle(Theme.accent)
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

/// The streak indicator shown on Today. A filled accent wash rather than an
/// outline: it's the one number the product wants you to notice, and the
/// only place a soft fill appears outside of selection.
struct StreakPill: View {
    let days: Int

    var body: some View {
        Text("\(days) day\(days == 1 ? "" : "s") streak")
            .font(Theme.ui(14, .semibold))
            .monospacedDigit()
            .foregroundStyle(Theme.accentStrong)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.accentSoft, in: .capsule)
            .opacity(days > 0 ? 1 : 0.5)
            .help("Consecutive days with at least one journal entry")
    }
}

/// The two-letter mark that stands in for each discipline in the sidebar.
/// Twelve glyph-based icons at 13 pt all read as "small grey shape"; two
/// letters are legible, and the list scans as a contents page.
struct DisciplineMonogram: View {
    let letters: String
    var selected: Bool = false

    var body: some View {
        Text(letters)
            .font(Theme.ui(10, .bold))
            .kerning(0.2)
            .foregroundStyle(selected ? Theme.accentStrong : Theme.inkSecondary)
            .frame(width: 24, height: 24)
            .background(
                selected ? Theme.accentSoft : Theme.surfaceSunken,
                in: .rect(cornerRadius: Theme.radiusSmall)
            )
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

/// The system's primary action: a `primaryFill` capsule with a
/// `primaryLabel` title.
struct PrimaryActionButtonLabel: View {
    let title: String
    var enabled: Bool = true
    var fullWidth: Bool = false

    var body: some View {
        Text(title)
            .font(Theme.ui(15, .semibold))
            // Disabled still has to be readable — it names the action you'd
            // get, and this is the only button on the card.
            .foregroundStyle(enabled ? Theme.primaryLabel : Theme.inkSecondary)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, fullWidth ? 0 : 22)
            .padding(.vertical, 12)
            .background(enabled ? Theme.primaryFill : Theme.surfaceSunken, in: .capsule)
            .overlay(
                Capsule().strokeBorder(enabled ? .clear : Theme.divider, lineWidth: 1)
            )
            .contentShape(.capsule)
            .hoverHighlight(in: Capsule())
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

/// The system's secondary action: a surface capsule, hairline, ink text.
struct SecondaryActionButtonLabel: View {
    let title: String
    var systemImage: String?
    var fullWidth: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 12, weight: .semibold))
            }
            Text(title)
        }
        .font(Theme.ui(14, .semibold))
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .padding(.horizontal, fullWidth ? 0 : 16)
        .padding(.vertical, 10)
        .background(Theme.surface, in: .capsule)
        .overlay(
            Capsule().strokeBorder(Theme.divider, lineWidth: 1)
        )
        .contentShape(.capsule)
        .hoverHighlight(in: Capsule())
    }
}
