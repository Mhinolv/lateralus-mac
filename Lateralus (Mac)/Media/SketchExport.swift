import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Renders a saved sketch to a PNG image: opaque paper, 2x scale, and a
/// margin wide enough that no stroke cap clips.
enum SketchExport {
    /// Pixels per sketch point.
    static let scale: CGFloat = 2
    /// The paper margin outside the outer edge of the strokes.
    static let margin: CGFloat = 16

    /// The area of the image in sketch coordinates. Each stroke grows by half
    /// its width, so round caps and dots stay inside, then the margin is added.
    static func bounds(of sketch: Sketch) -> CGRect? {
        var union: CGRect?
        for stroke in sketch.strokes where !stroke.points.isEmpty {
            let path = SketchRendering.path(for: stroke).boundingRect
                .insetBy(dx: -stroke.width / 2, dy: -stroke.width / 2)
            union = union.map { $0.union(path) } ?? path
        }
        return union?.insetBy(dx: -margin, dy: -margin)
    }

    /// The PNG data for the sketch, or nil when it has no strokes to draw.
    static func pngData(for sketch: Sketch) -> Data? {
        guard let bounds = bounds(of: sketch),
              let image = render(sketch, in: bounds) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    /// Writes the sketch as a PNG file at `url`.
    static func write(_ sketch: Sketch, to url: URL) throws {
        guard let data = pngData(for: sketch) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url, options: .atomic)
    }

    /// The Save panel's default name, from the entry's local date.
    static func defaultFileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return "Lateralus Sketch \(formatter.string(from: date)).png"
    }

    private static func render(_ sketch: Sketch, in bounds: CGRect) -> CGImage? {
        let width = Int((bounds.width * scale).rounded(.up))
        let height = Int((bounds.height * scale).rounded(.up))
        guard width > 0, height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else { return nil }

        let paper = SketchRendering.paperRGB
        context.setFillColor(CGColor(srgbRed: paper.red, green: paper.green, blue: paper.blue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Sketch points have a top-left origin; the bitmap has a bottom-left one.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for stroke in sketch.strokes where !stroke.points.isEmpty {
            context.setStrokeColor(CGColor(srgbRed: stroke.red, green: stroke.green, blue: stroke.blue, alpha: 1))
            context.setLineWidth(stroke.width)
            context.addPath(SketchRendering.path(for: stroke).cgPath)
            context.strokePath()
        }
        return context.makeImage()
    }
}
