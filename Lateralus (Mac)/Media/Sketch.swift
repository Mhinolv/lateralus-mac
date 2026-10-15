import AppKit
import SwiftUI

/// A vector sketch: an ordered list of strokes. Encoded as JSON into the
/// entry row, so drawings stay editable, resolution-independent, and small.
struct Sketch: Codable, Equatable {
    struct Stroke: Codable, Equatable {
        var points: [Point]
        var red: Double
        var green: Double
        var blue: Double
        var width: Double

        /// The on-screen color. A stroke of one of the pens follows the pen
        /// into dark mode, so it stays readable on dark paper. Other colors
        /// draw as saved. The saved components never change.
        var color: Color {
            SketchPen(red: red, green: green, blue: blue)?.color
                ?? Color(red: red, green: green, blue: blue)
        }
    }

    struct Point: Codable, Equatable {
        var x: Double
        var y: Double

        var cgPoint: CGPoint { CGPoint(x: x, y: y) }
    }

    var strokes: [Stroke] = []

    var isEmpty: Bool { strokes.isEmpty }

    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func decode(_ data: Data) -> Sketch? {
        try? JSONDecoder().decode(Sketch.self, from: data)
    }
}

/// The pens available in the canvas. The saved `components` are chosen to
/// read well on light paper. On dark-mode paper each pen draws in a lifted
/// color, `darkHex`. Strokes and PNG exports keep the light components.
enum SketchPen: CaseIterable, Identifiable {
    case ink, crimson, cobalt, forest, marigold, plum

    var id: Self { self }

    /// The pen that saves exactly these components, if there is one.
    init?(red: Double, green: Double, blue: Double) {
        guard let pen = Self.allCases.first(where: {
            $0.components == (red, green, blue)
        }) else { return nil }
        self = pen
    }

    /// The saved components in light mode, `darkHex` in dark mode.
    var color: Color {
        let rgb = components
        let dark = darkHex
        return Color(nsColor: NSColor(name: nil) { appearance in
            Theme.isDark(appearance)
                ? NSColor(
                    srgbRed: CGFloat((dark >> 16) & 0xFF) / 255,
                    green: CGFloat((dark >> 8) & 0xFF) / 255,
                    blue: CGFloat(dark & 0xFF) / 255,
                    alpha: 1
                )
                : NSColor(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        })
    }

    /// The sRGB color the pen draws in on dark-mode paper.
    var darkHex: UInt32 {
        switch self {
        case .ink: 0xF2EFE7
        case .crimson: 0xE5484D
        case .cobalt: 0x4C7BF0
        case .forest: 0x3BAF6A
        case .marigold: 0xF2B33D
        case .plum: 0xA86ADB
        }
    }

    var components: (red: Double, green: Double, blue: Double) {
        switch self {
        case .ink: (0.13, 0.12, 0.11)
        case .crimson: (0.78, 0.18, 0.21)
        case .cobalt: (0.16, 0.32, 0.75)
        case .forest: (0.13, 0.50, 0.30)
        case .marigold: (0.89, 0.58, 0.10)
        case .plum: (0.52, 0.25, 0.63)
        }
    }
}

/// An editable drawing surface: `Theme.sketchPaper`, pen palette, three nib sizes,
/// a stroke eraser, undo, redo, and clear. Pointer-driven — mouse or
/// trackpad. ⌘Z and ⇧⌘Z apply only while the canvas has focus.
struct SketchCanvas: View {
    @Binding var sketch: Sketch
    @Binding var history: SketchHistory
    let tint: Color
    /// If true, the canvas fills its container and the tools float over its
    /// top-left corner in a capsule. If false, the tools sit above it.
    var floatingTools = false

    @State private var pen: SketchPen = .ink
    @State private var nib: Double = 3
    @State private var erasing = false
    @State private var activeStroke: Sketch.Stroke?
    /// The strokes before the current erase drag, so one drag is one undo step.
    @State private var eraseBaseline: [Sketch.Stroke]?
    @FocusState private var canvasFocused: Bool

    private let nibSizes: [Double] = [1.5, 3, 7]

    /// A floating-tools canvas is a pane, so it takes the pane corner.
    private var cornerRadius: CGFloat {
        floatingTools ? Theme.radiusMedium : Theme.radiusSmall
    }

    var body: some View {
        if floatingTools {
            canvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topLeading) {
                    toolbar
                        .labelStyle(.iconOnly)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.surface, in: .capsule)
                        .overlay(Capsule().strokeBorder(Theme.divider, lineWidth: 1))
                        .padding(12)
                }
        } else {
            VStack(spacing: 10) {
                toolbar
                canvas
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(SketchPen.allCases) { candidate in
                    Button {
                        pen = candidate
                        erasing = false
                    } label: {
                        Circle()
                            .fill(candidate.color)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle().strokeBorder(
                                    Theme.ink.opacity(pen == candidate && !erasing ? 0.85 : 0.15),
                                    lineWidth: 2
                                )
                            )
                            .padding(2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Pen \(String(describing: candidate))")
                }
            }

            Divider().frame(height: 18)

            HStack(spacing: 8) {
                ForEach(nibSizes, id: \.self) { size in
                    Button {
                        nib = size
                        erasing = false
                    } label: {
                        Circle()
                            .fill(Theme.ink.opacity(nib == size && !erasing ? 0.85 : 0.3))
                            .frame(width: size + 5, height: size + 5)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Nib \(Int(size)) points")
                }
            }

            Divider().frame(height: 18)

            Toggle(isOn: $erasing) {
                Image(systemName: "eraser")
            }
            .toggleStyle(.button)
            .buttonStyle(.borderless)
            .tint(tint)
            .accessibilityLabel("Eraser")
            .help("Eraser — click or drag across a stroke to remove it")

            if floatingTools {
                Divider().frame(height: 18)
            } else {
                Spacer()
            }

            Button {
                history.undo(&sketch)
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.borderless)
            .disabled(!history.canUndo)
            .keyboardShortcut(canvasFocused ? KeyboardShortcut("z", modifiers: .command) : nil)
            .help("Undo (⌘Z)")

            Button {
                history.redo(&sketch)
            } label: {
                Label("Redo", systemImage: "arrow.uturn.forward")
            }
            .buttonStyle(.borderless)
            .disabled(!history.canRedo)
            .keyboardShortcut(canvasFocused ? KeyboardShortcut("z", modifiers: [.command, .shift]) : nil)
            .help("Redo (⇧⌘Z)")

            Button("Clear") {
                history.clear(&sketch)
            }
            .buttonStyle(.borderless)
            .disabled(sketch.strokes.isEmpty)
        }
        .font(.callout)
    }

    private var canvas: some View {
        Canvas { context, _ in
            for stroke in sketch.strokes {
                context.stroke(
                    SketchRendering.path(for: stroke),
                    with: .color(stroke.color),
                    style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round)
                )
            }
            if let activeStroke {
                context.stroke(
                    SketchRendering.path(for: activeStroke),
                    with: .color(activeStroke.color),
                    style: StrokeStyle(lineWidth: activeStroke.width, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .background(Theme.sketchPaper)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    canvasFocused ? Theme.accent : Theme.divider,
                    lineWidth: canvasFocused ? 1.5 : 1
                )
        )
        .frame(minHeight: 260)
        .focusable()
        .focused($canvasFocused)
        .focusEffectDisabled()
        .gesture(drawGesture)
        .accessibilityLabel("Drawing canvas")
    }

    private var drawGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !canvasFocused {
                    canvasFocused = true
                }
                let point = Sketch.Point(x: value.location.x, y: value.location.y)
                if erasing {
                    if eraseBaseline == nil {
                        eraseBaseline = sketch.strokes
                    }
                    erase(at: value.location)
                } else if activeStroke == nil {
                    let rgb = pen.components
                    activeStroke = Sketch.Stroke(
                        points: [point], red: rgb.red, green: rgb.green, blue: rgb.blue, width: nib
                    )
                } else {
                    activeStroke?.points.append(point)
                }
            }
            .onEnded { _ in
                if let finished = activeStroke {
                    history.addStroke(finished, to: &sketch)
                    activeStroke = nil
                }
                if let baseline = eraseBaseline {
                    history.recordErase(before: baseline, after: sketch.strokes)
                    eraseBaseline = nil
                }
            }
    }

    /// Removes any stroke passing near the pointer.
    private func erase(at location: CGPoint) {
        sketch.strokes.removeAll { stroke in
            stroke.points.contains { point in
                hypot(point.x - location.x, point.y - location.y) < max(10, stroke.width * 2)
            }
        }
    }
}

/// Read-only display of a saved sketch, scaled to fit its container.
struct SketchImage: View {
    let data: Data

    var body: some View {
        if let sketch = Sketch.decode(data), !sketch.isEmpty {
            let bounds = SketchRendering.bounds(of: sketch)
            Canvas { context, size in
                let scale = min(size.width / bounds.width, size.height / bounds.height, 1)
                context.translateBy(
                    x: (size.width - bounds.width * scale) / 2 - bounds.minX * scale,
                    y: (size.height - bounds.height * scale) / 2 - bounds.minY * scale
                )
                context.scaleBy(x: scale, y: scale)
                for stroke in sketch.strokes {
                    context.stroke(
                        SketchRendering.path(for: stroke),
                        with: .color(stroke.color),
                        style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round)
                    )
                }
            }
            .background(Theme.sketchPaper)
            .clipShape(.rect(cornerRadius: Theme.radiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .strokeBorder(Theme.divider, lineWidth: 1)
            )
            .aspectRatio(max(bounds.width / max(bounds.height, 1), 0.5), contentMode: .fit)
            .frame(maxHeight: 320)
        }
    }
}

enum SketchRendering {
    /// The sRGB paper of an exported PNG. An export is always light, so
    /// saved colors keep their contrast whatever the app appearance is.
    /// On screen, the editor and viewer draw on `Theme.sketchPaper`.
    static let paperRGB = (red: 0.992, green: 0.976, blue: 0.945)

    /// Midpoint-smoothed path through a stroke's sampled points.
    static func path(for stroke: Sketch.Stroke) -> Path {
        var path = Path()
        let points = stroke.points.map(\.cgPoint)
        guard let first = points.first else { return path }
        guard points.count > 1 else {
            // A click without movement still leaves a dot.
            path.addEllipse(in: CGRect(
                x: first.x - stroke.width / 2, y: first.y - stroke.width / 2,
                width: stroke.width, height: stroke.width
            ))
            return path
        }
        path.move(to: first)
        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midpoint = CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2)
            path.addQuadCurve(to: midpoint, control: previous)
        }
        if let last = points.last {
            path.addLine(to: last)
        }
        return path
    }

    /// The padded bounding box of every stroke point.
    static func bounds(of sketch: Sketch) -> CGRect {
        var minX = Double.greatestFiniteMagnitude, minY = Double.greatestFiniteMagnitude
        var maxX = -Double.greatestFiniteMagnitude, maxY = -Double.greatestFiniteMagnitude
        for stroke in sketch.strokes {
            for point in stroke.points {
                minX = min(minX, point.x); minY = min(minY, point.y)
                maxX = max(maxX, point.x); maxY = max(maxY, point.y)
            }
        }
        guard minX <= maxX else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        return CGRect(x: minX, y: minY, width: max(maxX - minX, 1), height: max(maxY - minY, 1))
            .insetBy(dx: -16, dy: -16)
    }
}
