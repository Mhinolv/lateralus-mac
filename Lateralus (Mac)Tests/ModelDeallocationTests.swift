import XCTest
@testable import Lateralus__Mac_

/// Regression for #17: releasing a main-actor `@Observable` model aborted the
/// process (SIGABRT in `swift_task_deinitOnExecutorImpl`) on macOS 15.
/// A crash here takes down the whole test run, not only this test.
@MainActor
final class ModelDeallocationTests: XCTestCase {

    func testAppModelDeallocates() {
        weak var released: AppModel?
        autoreleasepool {
            let model = AppModel()
            model.select(.journal)
            released = model
        }
        XCTAssertNil(released)
    }

    func testPersistenceControllerDeallocates() {
        weak var released: PersistenceController?
        autoreleasepool {
            let controller = PersistenceController(inMemory: true)
            released = controller
        }
        XCTAssertNil(released)
    }

    func testVoiceNoteRecorderDeallocates() {
        weak var released: VoiceNoteRecorder?
        autoreleasepool {
            let recorder = VoiceNoteRecorder()
            released = recorder
        }
        XCTAssertNil(released)
    }

    func testVoiceNotePlayerDeallocates() {
        weak var released: VoiceNotePlayer?
        autoreleasepool {
            let player = VoiceNotePlayer()
            released = player
        }
        XCTAssertNil(released)
    }
}
