import Foundation

/// Deterministic prompt generation.
///
/// The daily challenge is a pure function of (local calendar day,
/// `contentVersion`): the same day always deals the same challenge, the
/// schedule never repeats a (discipline, content) combination inside the
/// advertised 730-day window, and intentional content changes ship behind a
/// version bump so past days stay honest.
enum PromptEngine {

    /// Bump whenever `ContentPools` changes in a way that should reshuffle
    /// the published schedule.
    static let contentVersion: UInt64 = 2

    /// The advertised non-repeat window, in days.
    static let scheduleWindowDays = 730

    // MARK: - Daily

    /// The featured challenge for the calendar day containing `date`,
    /// evaluated in the user's current calendar and timezone.
    static func daily(for date: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> Prompt {
        let day = dayNumber(for: date, calendar: calendar)
        let block = day.flooredDivision(by: Exercise.practice.count)
        let slot = day.flooredModulo(Exercise.practice.count)

        // Each 12-day block deals every discipline exactly once, in an
        // order shuffled per block. `block` is therefore also how many
        // times this discipline has already been featured.
        var blockRNG = SplitMix64(seed: mix(contentVersion, 0x64AB, UInt64(bitPattern: Int64(block))))
        let order = fisherYates(Array(Exercise.practice.indices), using: &blockRNG)
        let exercise = Exercise.practice[order[slot]]

        return content(for: exercise, occurrence: block)
    }

    /// Days elapsed since the schedule epoch, in local calendar days.
    /// Negative-safe: days before the epoch continue the sequence backward.
    static func dayNumber(for date: Date, calendar: Calendar) -> Int {
        var epochComponents = DateComponents()
        epochComponents.year = 2026
        epochComponents.month = 1
        epochComponents.day = 1
        let epoch = calendar.date(from: epochComponents) ?? Date(timeIntervalSinceReferenceDate: 0)
        let start = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: epoch), to: start).day ?? 0
    }

    // MARK: - Practice

    /// A fresh, non-deterministic prompt for one discipline.
    static func practice(_ exercise: Exercise) -> Prompt {
        var rng = SplitMix64(seed: UInt64.random(in: .min ... .max))
        let space = comboCount(for: exercise)
        return prompt(for: exercise, comboIndex: Int(rng.next() % UInt64(space)))
    }

    // MARK: - Content dealing

    /// The `occurrence`-th featured prompt for a discipline: a seeded
    /// permutation of the discipline's whole combination space, walked in
    /// order, so combinations can't repeat until the space is exhausted.
    static func content(for exercise: Exercise, occurrence: Int) -> Prompt {
        let space = comboCount(for: exercise)
        let epoch = occurrence.flooredDivision(by: space)
        let position = occurrence.flooredModulo(space)
        var rng = SplitMix64(seed: mix(contentVersion, seedTag(for: exercise), UInt64(bitPattern: Int64(epoch))))
        let permutation = fisherYates(Array(0..<space), using: &rng)
        return prompt(for: exercise, comboIndex: permutation[position])
    }

    /// Size of each discipline's combination space.
    static func comboCount(for exercise: Exercise) -> Int {
        switch exercise {
        case .alternateUses: ContentPools.objects.count
        case .twistedUses: ContentPools.objects.count * ContentPools.twists.count
        case .realityShift: ContentPools.shiftPremises.count
        case .fusion: ContentPools.fusionFirst.count * ContentPools.fusionSecond.count
        case .backstory: ContentPools.backstoryScenes.count
        case .perspectiveFlip: ContentPools.flipScenes.count * ContentPools.flipVantages.count
        case .redefine: ContentPools.redefineConcepts.count
        case .coinAWord: ContentPools.unnamedExperiences.count
        // Every unordered pair of distinct words: C(60,2) = 1770
        // combinations, comfortably beyond the ~61 appearances one
        // discipline gets in the window.
        case .commonThread: commonThreadPairs.count
        case .positiveSpin: ContentPools.hardships.count
        case .inventions: ContentPools.inventionNeeds.count * ContentPools.inventionCatches.count
        case .miniMythology: ContentPools.mythPhenomena.count
        case .diary, .unknown: 1
        }
    }

    /// Materializes combination `index` of a discipline's space.
    static func prompt(for exercise: Exercise, comboIndex index: Int) -> Prompt {
        switch exercise {
        case .alternateUses:
            return Prompt(
                exercise: exercise,
                headline: capitalizedFirstLetter(ContentPools.objects[index]),
                detail: nil
            )
        case .twistedUses:
            let object = ContentPools.objects[index / ContentPools.twists.count]
            let twist = ContentPools.twists[index % ContentPools.twists.count]
            return Prompt(
                exercise: exercise,
                headline: capitalizedFirstLetter(object),
                detail: capitalizedFirstLetter(twist) + "."
            )
        case .realityShift:
            return Prompt(exercise: exercise, headline: ContentPools.shiftPremises[index], detail: nil)
        case .fusion:
            let first = ContentPools.fusionFirst[index / ContentPools.fusionSecond.count]
            let second = ContentPools.fusionSecond[index % ContentPools.fusionSecond.count]
            return Prompt(
                exercise: exercise,
                headline: "Fuse \(first) with \(second).",
                detail: "One invention, both parents visible.",
                markedPhrase: second
            )
        case .backstory:
            return Prompt(exercise: exercise, headline: ContentPools.backstoryScenes[index], detail: nil)
        case .perspectiveFlip:
            let scene = ContentPools.flipScenes[index / ContentPools.flipVantages.count]
            let vantage = ContentPools.flipVantages[index % ContentPools.flipVantages.count]
            return Prompt(
                exercise: exercise,
                headline: "Describe \(scene).",
                detail: "You are \(vantage).",
                markedPhrase: scene
            )
        case .redefine:
            return Prompt(
                exercise: exercise,
                headline: capitalizedFirstLetter(ContentPools.redefineConcepts[index]),
                detail: nil
            )
        case .coinAWord:
            return Prompt(
                exercise: exercise,
                headline: "Invent a word for: \(ContentPools.unnamedExperiences[index]).",
                detail: nil,
                markedPhrase: ContentPools.unnamedExperiences[index]
            )
        case .commonThread:
            let pair = commonThreadPairs[index]
            return Prompt(
                exercise: exercise,
                headline: "\(pair.0.capitalized)  ·  \(pair.1.capitalized)",
                detail: nil
            )
        case .positiveSpin:
            return Prompt(
                exercise: exercise,
                headline: "Find the honest upside: \(ContentPools.hardships[index]).",
                detail: nil,
                markedPhrase: ContentPools.hardships[index]
            )
        case .inventions:
            let need = ContentPools.inventionNeeds[index / ContentPools.inventionCatches.count]
            let catchRule = ContentPools.inventionCatches[index % ContentPools.inventionCatches.count]
            return Prompt(
                exercise: exercise,
                headline: "Design something for \(need).",
                detail: catchRule.prefix(1).capitalized + String(catchRule.dropFirst()) + ".",
                markedPhrase: need
            )
        case .miniMythology:
            return Prompt(
                exercise: exercise,
                headline: "Write the myth that explains \(ContentPools.mythPhenomena[index]).",
                detail: nil
            )
        case .diary, .unknown:
            return Prompt(exercise: exercise, headline: exercise.title, detail: nil)
        }
    }

    /// Capitalizes just the leading character, leaving the rest of the
    /// (already lowercase-authored) pool text untouched.
    static func capitalizedFirstLetter(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// Every unordered pair of distinct Common Thread words, enumerated
    /// once. Indexing directly into this flat list (rather than reshuffling
    /// the word pool per occurrence) is what makes the outer permutation in
    /// `content(for:occurrence:)` a genuine non-repeat guarantee: two
    /// independent word-list shuffles can coincidentally land the same pair
    /// adjacent to each other, but two distinct indices into this list can
    /// never name the same pair.
    static let commonThreadPairs: [(String, String)] = {
        let words = ContentPools.threadWords
        var pairs: [(String, String)] = []
        for i in 0..<words.count {
            for j in (i + 1)..<words.count {
                pairs.append((words[i], words[j]))
            }
        }
        return pairs
    }()

    // MARK: - Deterministic randomness

    /// Common Thread's combination space is per-epoch; the daily scheduler
    /// only guarantees non-repetition when triples differ across the epochs
    /// reachable inside the window. That property is pinned by a unit test
    /// rather than by construction.
    static func seedTag(for exercise: Exercise) -> UInt64 {
        UInt64(truncatingIfNeeded: exercise.rawValue.utf8.reduce(into: UInt64(0xCBF2_9CE4_8422_2325)) { hash, byte in
            hash = (hash ^ UInt64(byte)) &* 0x100_0000_01B3
        })
    }

    static func mix(_ a: UInt64, _ b: UInt64, _ c: UInt64) -> UInt64 {
        var state = SplitMix64(seed: a &+ (b &* 0x9E37_79B9_7F4A_7C15) &+ (c &* 0xBF58_476D_1CE4_E5B9))
        return state.next()
    }

    /// Our own Fisher–Yates so the permutation is stable across OS releases
    /// (the standard library's `shuffled(using:)` algorithm is unspecified).
    static func fisherYates<T>(_ items: [T], using rng: inout SplitMix64) -> [T] {
        var result = items
        guard result.count > 1 else { return result }
        for i in stride(from: result.count - 1, through: 1, by: -1) {
            let j = Int(rng.next() % UInt64(i + 1))
            result.swapAt(i, j)
        }
        return result
    }
}

/// A tiny, well-known deterministic PRNG. Stable output is part of the
/// product contract (the published daily schedule), so this must never be
/// replaced by a platform RNG.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

extension Int {
    /// Division that rounds toward negative infinity (Swift's `/` truncates
    /// toward zero, which would mirror the schedule around the epoch).
    func flooredDivision(by divisor: Int) -> Int {
        let q = self / divisor
        return (self % divisor < 0) ? q - 1 : q
    }

    /// Modulo with a result that is always in `0..<divisor`.
    func flooredModulo(_ divisor: Int) -> Int {
        let r = self % divisor
        return r < 0 ? r + divisor : r
    }
}
