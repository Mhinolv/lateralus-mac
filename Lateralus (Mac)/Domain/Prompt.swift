import Foundation

/// One concrete challenge: a discipline plus the content it was dealt.
struct Prompt: Identifiable, Equatable, Hashable {
    let exercise: Exercise
    /// The main prompt text (the object, premise, scene, or word set).
    let headline: String
    /// Secondary element — a twist, paired concept, vantage, or catch.
    let detail: String?
    /// The dealt fragment inside `headline` that the display marks with the
    /// highlighter, or `nil` for disciplines with nothing to single out.
    /// Derived from the content, so it is not part of the identity.
    var markedPhrase: String? = nil

    var id: String { "\(exercise.rawValue)|\(headline)|\(detail ?? "")" }

    var detailLabel: String? {
        detail == nil ? nil : exercise.detailLabel
    }

    static func == (lhs: Prompt, rhs: Prompt) -> Bool {
        lhs.exercise == rhs.exercise && lhs.headline == rhs.headline && lhs.detail == rhs.detail
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(exercise)
        hasher.combine(headline)
        hasher.combine(detail)
    }
}
