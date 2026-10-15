import XCTest

/// End-to-end walk of the core loop: answer the daily challenge, find it
/// in the journal, check insights, run a practice round, and write a diary
/// entry. Runs against an in-memory store so the user's real journal is
/// never touched.
final class CoreFlowsUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-test-in-memory"]
        app.launch()
    }

    override func tearDown() {
        app.terminate()
    }

    func testDailyChallengeJournalInsightsPracticeAndDiary() {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 30))

        // --- Daily challenge ---
        let begin = window.descendants(matching: .any)["daily-challenge-card"].firstMatch
        XCTAssertTrue(begin.waitForExistence(timeout: 5))
        begin.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()

        let editor = window.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.click()
        editor.typeText("A word for that is definitely overdue.")

        let save = window.buttons["Save to Journal"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isEnabled)
        save.click()
        XCTAssertTrue(window.staticTexts["Saved to your journal"].waitForExistence(timeout: 5))

        window.buttons["Done"].click()

        // Back on Today, the card now offers another attempt.
        let cardAgain = window.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@ AND label BEGINSWITH %@",
                        "daily-challenge-card", "Answer today's challenge again")
        ).firstMatch
        XCTAssertTrue(cardAgain.waitForExistence(timeout: 5))

        // --- Journal ---
        window.buttons["nav-journal"].firstMatch.click()
        let row = window.staticTexts["A word for that is definitely overdue."]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.click()

        // Reading pane shows the entry with its delete control.
        XCTAssertTrue(window.buttons["detail-delete"].firstMatch.waitForExistence(timeout: 5))

        // --- Insights ---
        window.buttons["nav-insights"].firstMatch.click()
        func insightsText(_ text: String) -> XCUIElement {
            window.staticTexts.matching(
                NSPredicate(format: "label ==[c] %@ OR value ==[c] %@", text, text)
            ).firstMatch
        }
        XCTAssertTrue(insightsText("Streak").waitForExistence(timeout: 5))
        XCTAssertTrue(insightsText("Entries total").exists)
        XCTAssertTrue(insightsText("Discipline balance").exists)

        // --- Practice with unsaved-work guard ---
        let fusionItem = window.buttons["practice-item-fusion"].firstMatch
        XCTAssertTrue(fusionItem.waitForExistence(timeout: 5))
        fusionItem.click()
        let practiceEditor = window.textViews.firstMatch
        XCTAssertTrue(practiceEditor.waitForExistence(timeout: 5))
        practiceEditor.click()
        practiceEditor.typeText("Half machine, half song.")

        // Navigating away with unsaved work must ask first.
        window.buttons["nav-today"].firstMatch.click()
        let keepEditing = window.sheets.buttons["Keep Editing"].firstMatch
        XCTAssertTrue(keepEditing.waitForExistence(timeout: 5), "Expected the discard confirmation dialog")
        keepEditing.click()

        // Still in the session; save it properly.
        let practiceSave = window.buttons["Save to Journal"]
        XCTAssertTrue(practiceSave.waitForExistence(timeout: 5))
        practiceSave.click()
        XCTAssertTrue(window.staticTexts["Saved to your journal"].waitForExistence(timeout: 5))

        // --- Diary (⌘N) ---
        window.typeKey("n", modifierFlags: .command)
        let diaryEditor = app.sheets.textViews.firstMatch
        XCTAssertTrue(diaryEditor.waitForExistence(timeout: 5))
        diaryEditor.click()
        diaryEditor.typeText("Private thought, no prompt.")
        app.sheets.buttons["Save to Journal"].firstMatch.click()

        // Diary entry lands in the journal.
        window.buttons["nav-journal"].firstMatch.click()
        XCTAssertTrue(window.staticTexts["Private thought, no prompt."].waitForExistence(timeout: 5))

        // --- Search filters the list ---
        let searchField = window.textFields["journal-search"].firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()
        searchField.typeText("machine, half song")
        XCTAssertTrue(window.staticTexts["Half machine, half song."].waitForExistence(timeout: 5))
        XCTAssertFalse(window.staticTexts["Private thought, no prompt."].exists)
    }
}
