import Foundation

/// Bounded undo and redo for one canvas session. Each step records an
/// operation, not a full copy of the sketch, so the history stays small.
/// Lives with the sketch's owner, so hiding the canvas keeps it.
struct SketchHistory: Equatable {
    /// A stroke removed by an erase, with its index in the sketch as it
    /// was before that erase.
    struct ErasedStroke: Equatable {
        var index: Int
        var stroke: Sketch.Stroke
    }

    enum Operation: Equatable {
        /// One finished stroke, appended to the end.
        case stroke(Sketch.Stroke)
        /// One erase drag: every stroke it removed, in ascending index order.
        case erase([ErasedStroke])
        /// Clear: every stroke the sketch held.
        case clear([Sketch.Stroke])
    }

    static let limit = 100

    private(set) var undoStack: [Operation] = []
    private(set) var redoStack: [Operation] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Records an operation already applied to the sketch. A new operation
    /// drops the redo stack, and the oldest step goes past the limit.
    mutating func record(_ operation: Operation) {
        undoStack.append(operation)
        if undoStack.count > Self.limit {
            undoStack.removeFirst(undoStack.count - Self.limit)
        }
        redoStack.removeAll()
    }

    mutating func addStroke(_ stroke: Sketch.Stroke, to sketch: inout Sketch) {
        sketch.strokes.append(stroke)
        record(.stroke(stroke))
    }

    mutating func clear(_ sketch: inout Sketch) {
        guard !sketch.strokes.isEmpty else { return }
        record(.clear(sketch.strokes))
        sketch.strokes.removeAll()
    }

    /// Records one erase drag from the strokes before and after it. An
    /// erase only removes strokes, so `after` is a subsequence of `before`.
    mutating func recordErase(before: [Sketch.Stroke], after: [Sketch.Stroke]) {
        let erased = Self.erasedStrokes(before: before, after: after)
        guard !erased.isEmpty else { return }
        record(.erase(erased))
    }

    mutating func undo(_ sketch: inout Sketch) {
        guard let operation = undoStack.popLast() else { return }
        switch operation {
        case .stroke:
            if !sketch.strokes.isEmpty { sketch.strokes.removeLast() }
        case .erase(let erased):
            for item in erased {
                sketch.strokes.insert(item.stroke, at: min(item.index, sketch.strokes.count))
            }
        case .clear(let strokes):
            sketch.strokes = strokes
        }
        redoStack.append(operation)
    }

    mutating func redo(_ sketch: inout Sketch) {
        guard let operation = redoStack.popLast() else { return }
        switch operation {
        case .stroke(let stroke):
            sketch.strokes.append(stroke)
        case .erase(let erased):
            for item in erased.reversed() where sketch.strokes.indices.contains(item.index) {
                sketch.strokes.remove(at: item.index)
            }
        case .clear:
            sketch.strokes.removeAll()
        }
        undoStack.append(operation)
    }

    mutating func reset() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    /// The strokes of `before` that are missing from `after`, with their
    /// indices in `before`.
    static func erasedStrokes(before: [Sketch.Stroke], after: [Sketch.Stroke]) -> [ErasedStroke] {
        var erased: [ErasedStroke] = []
        var remaining = after[...]
        for (index, stroke) in before.enumerated() {
            if remaining.first == stroke {
                remaining = remaining.dropFirst()
            } else {
                erased.append(ErasedStroke(index: index, stroke: stroke))
            }
        }
        return erased
    }
}
