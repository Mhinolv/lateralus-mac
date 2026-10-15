import SwiftUI

/// The catalog of thinking disciplines. Raw values are stored in the
/// journal database and must stay stable across releases.
enum Exercise: String, CaseIterable, Codable, Identifiable, Hashable {
    case alternateUses = "alternateUses"
    case twistedUses = "twistedUses"
    case realityShift = "realityShift"
    case fusion = "fusion"
    case backstory = "backstory"
    case perspectiveFlip = "perspectiveFlip"
    case redefine = "redefine"
    case coinAWord = "coinAWord"
    case commonThread = "commonThread"
    case positiveSpin = "positiveSpin"
    case inventions = "inventions"
    case miniMythology = "miniMythology"
    /// A prompt-free journal entry. Not part of the practice rotation.
    case diary = "diary"
    /// Fallback for identifiers written by a future version of the app.
    case unknown = "unknown"

    var id: String { rawValue }

    /// The twelve disciplines in the daily and practice rotation.
    static let practice: [Exercise] = [
        .alternateUses, .twistedUses, .realityShift, .fusion,
        .backstory, .perspectiveFlip, .redefine, .coinAWord,
        .commonThread, .positiveSpin, .inventions, .miniMythology,
    ]

    /// Everything a journal filter can select, including Diary.
    static let journalFilters: [Exercise] = practice + [.diary]

    var title: String {
        switch self {
        case .alternateUses: "Alternate Uses"
        case .twistedUses: "Twisted Uses"
        case .realityShift: "Reality Shift"
        case .fusion: "Fusion"
        case .backstory: "Backstory"
        case .perspectiveFlip: "Perspective Flip"
        case .redefine: "Redefine"
        case .coinAWord: "Coin a Word"
        case .commonThread: "Common Thread"
        case .positiveSpin: "Positive Spin"
        case .inventions: "Inventions"
        case .miniMythology: "Mini Mythology"
        case .diary: "Diary"
        case .unknown: "Archived Exercise"
        }
    }

    var blurb: String {
        switch self {
        case .alternateUses: "Push a familiar object past its job description."
        case .twistedUses: "Invent uses after the rules of the object change."
        case .realityShift: "Follow the consequences of a broken law of reality."
        case .fusion: "Weld two strangers into one working idea."
        case .backstory: "Explain how a strange moment came to be."
        case .perspectiveFlip: "Answer from a point of view that isn't yours."
        case .redefine: "Give an old concept a sharper, stranger meaning."
        case .coinAWord: "Name a feeling language forgot to cover."
        case .commonThread: "Find the hidden bridge between distant ideas."
        case .positiveSpin: "Mine something difficult for honest upside."
        case .inventions: "Design a thing the world quietly needs."
        case .miniMythology: "Write the tiny myth behind an ordinary thing."
        case .diary: "Free writing, no prompt, no rules."
        case .unknown: "An entry from a newer version of Lateralus."
        }
    }

    /// The standing rule of the discipline, shown above every prompt.
    var directive: String {
        switch self {
        case .alternateUses:
            "List as many unconventional uses as you can. Quantity first — the tenth idea is usually stranger than the first."
        case .twistedUses:
            "The twist changes what the object can do. Take the constraint seriously, then find uses only this version could have."
        case .realityShift:
            "Assume the shift is simply true. Trace what breaks, what improves, and who adapts first."
        case .fusion:
            "Combine both concepts into one coherent thing. Keep something essential from each parent."
        case .backstory:
            "Explain how this situation came to be. Aim for surprising but internally consistent."
        case .perspectiveFlip:
            "Stay in the assigned point of view the whole time. Let its priorities, fears, and blind spots drive the answer."
        case .redefine:
            "Write a new definition that reveals something true the dictionary misses. Format it like a real entry if you like."
        case .coinAWord:
            "Invent a word for this experience, then define it. Say it out loud — it should feel pronounceable."
        case .commonThread:
            "Find one word or idea that genuinely connects all three prompts. Obvious links score nothing here — dig sideways."
        case .positiveSpin:
            "Find credible benefits, openings, or lessons. No toxic cheerfulness — the upside has to survive scrutiny."
        case .inventions:
            "Design something that answers the need. Describe how it works, who reaches for it, and why it beats doing nothing."
        case .miniMythology:
            "Write a compact myth — gods, spirits, bargains, or curses — that explains the phenomenon better than physics does."
        case .diary, .unknown:
            ""
        }
    }

    /// Optional structure for moving past the first obvious answer.
    var responseGuide: [String] {
        switch self {
        case .alternateUses: [
            "Empty the obvious ideas first — get five down fast.",
            "Change the scale: what if it were tiny, or enormous?",
            "Break it: what are the parts or the material good for?",
        ]
        case .twistedUses: [
            "Restate what the twist makes newly possible or impossible.",
            "Find one use that would be pointless without the twist.",
            "Push into a setting where this version becomes essential.",
        ]
        case .realityShift: [
            "Name the first thing that visibly changes on day one.",
            "Follow one ripple three steps: who profits, who scrambles?",
            "Find the odd new job, rule, or ritual this world invents.",
        ]
        case .fusion: [
            "List what each half does best before you weld them.",
            "Decide what the hybrid is FOR — a purpose makes it real.",
            "Give it one detail that makes it feel manufactured, not imagined.",
        ]
        case .backstory: [
            "Start earlier than feels necessary — the cause behind the cause.",
            "Give someone in the story a motive that almost makes sense.",
            "Land the final beat exactly on the scene in the prompt.",
        ]
        case .perspectiveFlip: [
            "What does this viewpoint notice first that you never would?",
            "What does it want, and what is it quietly afraid of?",
            "Let its vocabulary leak in — how would it actually phrase things?",
        ]
        case .redefine: [
            "Say what the thing really does, not what it is made of.",
            "Steal the tone of a dictionary, field guide, or user manual.",
            "A little wit is allowed if the truth underneath is sharp.",
        ]
        case .coinAWord: [
            "Pin the experience down first — when exactly does it happen?",
            "Build the word from pieces that hint at the meaning.",
            "Write the dictionary line: part of speech, definition, example use.",
        ]
        case .commonThread: [
            "List two or three properties of each prompt privately first.",
            "Look for shared verbs and functions, not shared appearances.",
            "Test the winner: does it honestly fit all three, or just two?",
        ]
        case .positiveSpin: [
            "Acknowledge the genuine cost before hunting the benefit.",
            "Ask who unexpectedly gains, learns, or gets a second chance.",
            "Find the door this closes AND the odd one it opens.",
        ]
        case .inventions: [
            "Describe the moment of need — where is the user standing?",
            "Explain the mechanism in one honest sentence.",
            "Name the detail that makes people choose it twice.",
        ]
        case .miniMythology: [
            "Choose your cast: a god, a spirit, a trickster, or a bargain.",
            "Let the myth's logic mirror how the thing actually behaves.",
            "End with the trace the story leaves in the world today.",
        ]
        case .diary, .unknown: []
        }
    }

    /// An optional extra constraint for players who want more resistance.
    var stretchPrompt: String? {
        switch self {
        case .alternateUses: "Make three of your uses ones a child could actually try today."
        case .twistedUses: "Find one use that turns the twist from a flaw into the selling point."
        case .realityShift: "Write the headline a newspaper runs one year after the shift."
        case .fusion: "Write the one-line ad slogan the hybrid would ship with."
        case .backstory: "Retell it in three sentences from a bystander who got it all wrong."
        case .perspectiveFlip: "Include one complaint your narrator would never say out loud."
        case .redefine: "Add a second sense of the word, the way real dictionaries do."
        case .coinAWord: "Coin its antonym too."
        case .commonThread: "Find a second, completely different connector."
        case .positiveSpin: "Name the person for whom this is secretly a beginning."
        case .inventions: "Describe the failure mode — what breaks when it's misused?"
        case .miniMythology: "Include one 'proof' believers still point to."
        case .diary, .unknown: nil
        }
    }

    /// Label for the secondary prompt element, when the discipline has one.
    var detailLabel: String? {
        switch self {
        case .twistedUses: "The Twist"
        case .fusion: "Fuse With"
        case .perspectiveFlip: "Your Vantage"
        case .inventions: "The Catch"
        default: nil
        }
    }

    var symbol: String {
        switch self {
        case .alternateUses: "arrow.triangle.branch"
        case .twistedUses: "tornado"
        case .realityShift: "sparkles.rectangle.stack"
        case .fusion: "link"
        case .backstory: "text.book.closed"
        case .perspectiveFlip: "eye"
        case .redefine: "character.book.closed"
        case .coinAWord: "textformat.abc"
        case .commonThread: "point.3.connected.trianglepath.dotted"
        case .positiveSpin: "sun.horizon"
        case .inventions: "gearshape.2"
        case .miniMythology: "cloud.bolt"
        case .diary: "square.and.pencil"
        case .unknown: "questionmark.square.dashed"
        }
    }

    /// Discipline accent. The system spends its color on one hue only —
    /// every discipline shares the app's single accent rather than carrying
    /// a unique identity color. (Kept as a literal here, not a reference to
    /// UI/Theme.swift, so Domain stays UI-independent; keep this in sync
    /// with `Theme.accent` if the accent ever changes.)
    /// Screens that need to single out one discipline among many (e.g.
    /// Insights' balance chart) contrast accent against faint ink instead
    /// of relying on a per-item hue.
    var tint: Color { Color(red: 0.710, green: 0.314, blue: 0.180) }

    /// Two-letter mark shown in the sidebar. Twelve SF Symbols at sidebar
    /// size all resolve to "small grey shape"; initials stay legible and
    /// turn the practice list into something closer to a contents page.
    var monogram: String {
        switch self {
        case .alternateUses: "AU"
        case .twistedUses: "TU"
        case .realityShift: "RS"
        case .fusion: "FU"
        case .backstory: "BS"
        case .perspectiveFlip: "PF"
        case .redefine: "RD"
        case .coinAWord: "CW"
        case .commonThread: "CT"
        case .positiveSpin: "PS"
        case .inventions: "IN"
        case .miniMythology: "MM"
        case .diary: "DY"
        case .unknown: "—"
        }
    }
}
