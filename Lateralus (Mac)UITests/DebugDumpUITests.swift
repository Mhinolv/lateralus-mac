import XCTest

/// Development aid: captures the practice session (with the sketch canvas
/// open) so layout can be reviewed visually. Safe to delete.
final class DebugDumpUITests: XCTestCase {
    func testCaptureSessionScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-in-memory"]
        app.launch()
        let window = app.windows.firstMatch
        _ = window.waitForExistence(timeout: 10)

        let fusionItem = window.buttons["practice-item-fusion"].firstMatch
        _ = fusionItem.waitForExistence(timeout: 5)
        fusionItem.click()
        let editor = window.textViews.firstMatch
        _ = editor.waitForExistence(timeout: 5)
        editor.click()
        editor.typeText("A cable car that stamps your journey like a passport page.")
        let sketchToggle = window.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "Sketch")
        ).allElementsBoundByIndex.first { $0.elementType == .checkBox || $0.elementType == .button }
        sketchToggle?.click()
        sleep(1)

        let data = XCUIScreen.main.screenshot().pngRepresentation
        let out = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "lateralus-session.png")
        try data.write(to: out)
        print("SCREENSHOT| \(out.path)")
    }
}
