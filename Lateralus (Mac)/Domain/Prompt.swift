import Foundation

/// One concrete challenge: a discipline plus the content it was dealt.
struct Prompt: Identifiable, Equatable, Hashable {
    let exercise: Exercise
    /// The main prompt text (the object, premise, scene, or word set).
    let headline: String
    /// Secondary element — a twist, paired concept, vantage, or catch.
    let detail: String?

    var id: String { "\(exercise.rawValue)|\(headline)|\(detail ?? "")" }

    var detailLabel: String? {
        detail == nil ? nil : exercise.detailLabel
    }
}
