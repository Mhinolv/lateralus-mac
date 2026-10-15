import SwiftUI
import XCTest
@testable import Lateralus__Mac_

/// The Today hero: headline size steps, the marked phrase each discipline
/// deals, and the highlighter that draws it.
@MainActor
final class TodayHeroTests: XCTestCase {

    // MARK: - Headline scale

    func testHeadlineScaleStepsByLength() {
        let cases: [(Int, CGFloat, CGFloat)] = [
            (0, 88, -2), (1, 88, -2), (24, 88, -2),
            (25, 56, -1.2), (60, 56, -1.2),
            (61, 44, -0.8), (400, 44, -0.8),
        ]
        for (length, size, kerning) in cases {
            let scale = HeadlineScale(for: String(repeating: "a", count: length))
            XCTAssertEqual(scale, HeadlineScale(size: size, kerning: kerning), "length \(length)")
        }
    }

    /// Length counts characters, not UTF-16 units or bytes.
    func testHeadlineScaleCountsCharacters() {
        XCTAssertEqual(HeadlineScale(for: String(repeating: "é", count: 24)).size, 88)
        XCTAssertEqual(HeadlineScale(for: String(repeating: "e\u{301}", count: 24)).size, 88)
    }

    // MARK: - Marked phrase

    private static let marked: Set<Exercise> = [.inventions, .coinAWord, .positiveSpin, .perspectiveFlip, .fusion]

    /// In every combination of every discipline, the marked phrase is set
    /// only where UX asks for it and always sits inside the headline.
    func testMarkedPhraseIsTheDealtFragmentInEveryCombination() {
        for exercise in Exercise.practice {
            for index in 0..<PromptEngine.comboCount(for: exercise) {
                let prompt = PromptEngine.prompt(for: exercise, comboIndex: index)
                guard Self.marked.contains(exercise) else {
                    XCTAssertNil(prompt.markedPhrase, "\(exercise.rawValue) #\(index)")
                    continue
                }
                guard let phrase = prompt.markedPhrase else {
                    XCTFail("\(exercise.rawValue) #\(index) has no marked phrase")
                    continue
                }
                XCTAssertNotNil(Highlight.markedRange(in: prompt.headline, phrase: phrase),
                                "\(exercise.rawValue) #\(index): \(prompt.headline)")
            }
        }
    }

    func testMarkedPhrasePicksTheDealtSlot() {
        let fusion = PromptEngine.prompt(for: .fusion, comboIndex: 0)
        XCTAssertEqual(fusion.markedPhrase, ContentPools.fusionSecond[0])
        XCTAssertTrue(fusion.headline.hasSuffix("\(ContentPools.fusionSecond[0])."))

        let flip = PromptEngine.prompt(for: .perspectiveFlip, comboIndex: 0)
        XCTAssertEqual(flip.markedPhrase, ContentPools.flipScenes[0])

        let invention = PromptEngine.prompt(for: .inventions, comboIndex: 0)
        XCTAssertEqual(invention.markedPhrase, ContentPools.inventionNeeds[0])

        XCTAssertEqual(PromptEngine.prompt(for: .coinAWord, comboIndex: 0).markedPhrase,
                       ContentPools.unnamedExperiences[0])
        XCTAssertEqual(PromptEngine.prompt(for: .positiveSpin, comboIndex: 0).markedPhrase,
                       ContentPools.hardships[0])
    }

    /// The marked phrase is display data. A prompt rebuilt from a saved
    /// entry has none, and it must still equal the dealt prompt.
    func testMarkedPhraseIsNotPartOfIdentity() {
        let dealt = PromptEngine.prompt(for: .fusion, comboIndex: 3)
        let rebuilt = Prompt(exercise: dealt.exercise, headline: dealt.headline, detail: dealt.detail)
        XCTAssertNotNil(dealt.markedPhrase)
        XCTAssertEqual(dealt, rebuilt)
        XCTAssertEqual(dealt.hashValue, rebuilt.hashValue)
        XCTAssertEqual(dealt.id, rebuilt.id)
    }

    // MARK: - Highlight

    func testHighlightMarksOnlyThePhrase() throws {
        let text = "Fuse a lighthouse with a sundial."
        let attributed = Highlight.attributed(text, marking: "a sundial")
        XCTAssertEqual(String(attributed.characters), text)

        var marked = ""
        for run in attributed.runs {
            let slice = String(attributed[run.range].characters)
            if run.backgroundColor != nil {
                XCTAssertEqual(run.backgroundColor, Theme.mark)
                XCTAssertEqual(run.foregroundColor, Theme.onMark)
                marked += slice
            } else {
                XCTAssertNil(run.foregroundColor, "unmarked text keeps the view's ink: \(slice)")
            }
        }
        XCTAssertEqual(marked, "a sundial")
    }

    /// The lead "Fuse a … with a …" repeats "a". The last match is the
    /// dealt one.
    func testHighlightUsesTheLastMatch() throws {
        let text = "Fuse a bell with a bell."
        let range = try XCTUnwrap(Highlight.markedRange(in: text, phrase: "a bell"))
        XCTAssertEqual(text[range.lowerBound...], "a bell.")
    }

    func testHighlightWithoutPhraseLeavesTextPlain() {
        for phrase in [nil, "", "not here"] as [String?] {
            let attributed = Highlight.attributed("A violin bow", marking: phrase)
            XCTAssertEqual(attributed.runs.count, 1, "\(String(describing: phrase))")
            XCTAssertNil(attributed.runs.first?.backgroundColor)
        }
    }
}
