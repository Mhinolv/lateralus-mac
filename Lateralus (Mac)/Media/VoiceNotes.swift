import AVFoundation
import Foundation
import Observation

/// Records a voice note to a temporary file. The file is only moved into
/// permanent storage when the entry saves (`AttachmentStore.commit`), so an
/// abandoned recording never leaves anything behind.
@Observable
final class VoiceNoteRecorder: NSObject {
    enum Phase: Equatable {
        case idle
        case denied
        case recording
        case recorded
        case failed(String)
    }

    static let maximumDuration: TimeInterval = 5 * 60

    private(set) var phase: Phase = .idle
    private(set) var duration: TimeInterval = 0
    /// The finished temporary recording, if any.
    private(set) var fileURL: URL?

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private let store: AttachmentStore

    init(store: AttachmentStore = .live) {
        self.store = store
    }

    var isRecording: Bool { phase == .recording }

    /// Asks for microphone access if needed, then starts recording.
    func record() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            begin()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                Task { @MainActor in
                    if granted {
                        self.begin()
                    } else {
                        self.phase = .denied
                    }
                }
            }
        case .denied, .restricted:
            phase = .denied
        @unknown default:
            phase = .denied
        }
    }

    private func begin() {
        discard()
        let url = store.temporaryRecordingURL()
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            guard recorder.record(forDuration: Self.maximumDuration) else {
                phase = .failed("Recording couldn't start. Another app may be using the microphone.")
                return
            }
            self.recorder = recorder
            phase = .recording
            duration = 0
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, let recorder = self.recorder, self.phase == .recording else { return }
                    self.duration = recorder.currentTime
                }
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Stops recording, keeping the file for a later save.
    func stop() {
        guard let recorder else { return }
        if phase == .recording {
            duration = recorder.currentTime
            recorder.stop()
            fileURL = recorder.url
            phase = .recorded
        }
        clearTimer()
    }

    /// Stops and deletes the temporary file.
    func discard() {
        recorder?.stop()
        if let fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        if let recording = recorder?.url {
            try? FileManager.default.removeItem(at: recording)
        }
        recorder = nil
        fileURL = nil
        duration = 0
        if phase != .denied { phase = .idle }
        clearTimer()
    }

    /// The temporary file has been moved into the attachment store; stop
    /// tracking it so `discard` can't delete the committed copy's origin.
    func markCommitted() {
        recorder = nil
        fileURL = nil
        clearTimer()
    }

    private func clearTimer() {
        meterTimer?.invalidate()
        meterTimer = nil
    }
}

extension VoiceNoteRecorder: AVAudioRecorderDelegate {
    /// Fires when the five-minute cap lands before a manual stop.
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            guard self.phase == .recording else { return }
            if flag {
                self.fileURL = recorder.url
                self.duration = Self.maximumDuration
                self.phase = .recorded
            } else {
                self.phase = .failed("The recording stopped unexpectedly.")
            }
            self.clearTimer()
        }
    }
}

/// Plays back a saved voice note.
@Observable
final class VoiceNotePlayer: NSObject {
    private(set) var isPlaying = false
    private var player: AVAudioPlayer?

    func toggle(url: URL) {
        if isPlaying {
            stop()
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.play()
            self.player = player
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }
}

extension VoiceNotePlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.player = nil
        }
    }
}

/// mm:ss for badge and player labels.
func voiceNoteDuration(_ interval: TimeInterval) -> String {
    let total = Int(interval.rounded())
    return String(format: "%d:%02d", total / 60, total % 60)
}
