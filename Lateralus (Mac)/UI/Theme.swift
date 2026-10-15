import SwiftUI

/// The "Paper" look: a warm unbleached ground, one terracotta accent, a
/// serif display voice against a humanist grotesque interface voice, and
/// softly rounded edges throughout.
///
/// The system reads as a notebook rather than a dashboard — which is what
/// the product is. Everything commits to a single fixed light appearance,
/// and there are no per-discipline hues: where one item must be singled
/// out, it takes the accent and everything else stays ink.
enum Theme {

    // MARK: - Ground

    /// The window ground — warm off-white, never pure paper.
    static let background = Color(red: 0.973, green: 0.949, blue: 0.910)  // #f8f2e8
    /// Cards, the sidebar, inputs, and any surface that lifts off the ground.
    static let surface = Color(red: 0.945, green: 0.914, blue: 0.863)     // #f1e9dc
    /// The deepest paper step — chart tracks, monogram tiles, disabled fills.
    static let surfaceSunken = Color(red: 0.918, green: 0.878, blue: 0.808) // #eae0ce

    // MARK: - Ink

    static let ink = Color(red: 0.169, green: 0.141, blue: 0.098)         // #2b2419
    static let inkSecondary = ink.opacity(0.68)
    static let inkTertiary = ink.opacity(0.42)
    /// The faintest legible ink — de-emphasized chart bars, hint text.
    static let inkQuaternary = ink.opacity(0.24)

    // MARK: - Accent

    /// The app's one hue. `accentStrong` is the ~700 step (kickers, large
    /// numbers, text on soft washes); `accentSoft` is the ~100 step.
    static let accent = Color(red: 0.710, green: 0.314, blue: 0.180)      // #b5502e
    static let accentStrong = Color(red: 0.478, green: 0.227, blue: 0.122) // #7a3a1f
    static let accentSoft = Color(red: 0.941, green: 0.863, blue: 0.788)  // #f0dcc9
    static let onAccent = Color.white

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

    /// Three steps, plus `Capsule` for anything fully rounded. Inputs and
    /// rows take `small`, controls and tiles take `medium`, cards and sheets
    /// take `large`.
    static let radiusSmall: CGFloat = 6
    static let radiusMedium: CGFloat = 10
    static let radiusLarge: CGFloat = 16

    /// The default corner for anything that doesn't say otherwise.
    static let radius: CGFloat = radiusMedium

    // MARK: - Type

    /// Display type — Source Serif 4. Used for the wordmark, screen
    /// headlines, prompts, and entry recaps: everything that is *writing*
    /// rather than *interface*.
    static func display(_ size: CGFloat, weight: DisplayWeight = .semibold, italic: Bool = false) -> Font {
        guard Fonts.areAvailable else {
            let system = Font.system(size: size, weight: weight == .semibold ? .semibold : .regular, design: .serif)
            return italic ? system.italic() : system
        }
        let name = switch (weight, italic) {
        case (.semibold, false): Fonts.Serif.semibold
        case (.semibold, true): Fonts.Serif.semiboldItalic
        case (.regular, false): Fonts.Serif.regular
        case (.regular, true): Fonts.Serif.italic
        }
        return .custom(name, fixedSize: size)
    }

    /// Source Serif has no static medium master; prompts sit at `.regular`
    /// and titles at `.semibold`.
    enum DisplayWeight { case regular, semibold }

    /// Interface type — Work Sans. Labels, controls, body copy, everything
    /// that isn't a headline.
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        guard Fonts.areAvailable else {
            let system = Font.system(size: size, weight: weight)
            return italic ? system.italic() : system
        }
        if italic { return .custom(Fonts.Sans.italic, fixedSize: size) }
        let name = switch weight {
        case .bold, .heavy, .black: Fonts.Sans.bold
        case .semibold: Fonts.Sans.semibold
        case .medium: Fonts.Sans.medium
        default: Fonts.Sans.regular
        }
        return .custom(name, fixedSize: size)
    }

    /// Anything counted or compared — streaks, totals, word counts, error
    /// detail. Kept on the system monospace face so digits stay even.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// Flat ambient backdrop — no gradient, no glow. The system spends its
/// boldness on the accent alone.
struct AppBackground: View {
    var body: some View {
        Theme.background.ignoresSafeArea()
    }
}

/// Elevation steps. The ramp is warm-tinted rather than neutral so shadows
/// read as paper lifting off paper, not as a grey drop.
enum Elevation {
    case none, sm, md, lg
}

extension View {
    /// Raised, borderless surface. `elevation` adds a warm ink-tinted
    /// shadow; most cards want `.sm`, hero panels want `.md`, and `.lg` is
    /// reserved for sheets and popovers floating over a scrim.
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
                .shadow(color: Theme.ink.opacity(0.06), radius: 1, x: 0, y: 1)
                .shadow(color: Theme.ink.opacity(0.08), radius: 10, x: 0, y: 4)
        case .md:
            content
                .shadow(color: Theme.ink.opacity(0.07), radius: 2, x: 0, y: 1)
                .shadow(color: Theme.ink.opacity(0.10), radius: 18, x: 0, y: 8)
        case .lg:
            content.shadow(color: Theme.ink.opacity(0.18), radius: 28, x: 0, y: 16)
        }
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

/// The system's primary action: solid accent, white text, medium corner.
struct PrimaryActionButtonLabel: View {
    let title: String
    var enabled: Bool = true
    var fullWidth: Bool = false

    var body: some View {
        Text(title)
            .font(Theme.ui(15, .semibold))
            // Disabled still has to be readable — it names the action you'd
            // get, and this is the only button on the card.
            .foregroundStyle(enabled ? Theme.onAccent : Theme.inkSecondary)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, fullWidth ? 0 : 22)
            .padding(.vertical, 12)
            .background(
                enabled ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.surfaceSunken),
                in: .rect(cornerRadius: Theme.radiusMedium)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium)
                    .strokeBorder(enabled ? .clear : Theme.divider, lineWidth: 1)
            )
            .contentShape(.rect)
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

/// The system's secondary action: ground fill, hairline, ink text.
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
        .background(Theme.background, in: .rect(cornerRadius: Theme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMedium)
                .strokeBorder(Theme.divider, lineWidth: 1)
        )
        .contentShape(.rect)
        .hoverHighlight(cornerRadius: Theme.radiusMedium)
    }
}
