import AppKit
import SwiftUI

/// The title and progress of a running restore. Shared by the sheet in the
/// window that runs it and the scrim in every other window.
private struct ArchiveRestoreProgress: View {
    let status: ArchiveRestoreStatus

    var body: some View {
        VStack(spacing: 14) {
            Text(status.title)
                .font(Theme.display(20))
                .foregroundStyle(Theme.ink)
            if case .restoring(let completed, let total) = status.phase {
                ProgressView(value: Double(completed), total: Double(max(total, 1)))
                    .progressViewStyle(.linear)
                    .tint(Theme.accent)
                    .frame(width: 260)
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .tint(Theme.accent)
            }
            if let progressText = status.progressText {
                Text(progressText)
                    .font(Theme.ui(14))
                    .monospacedDigit()
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status.accessibilityLabel)
    }
}

/// Shown in the window that runs the restore, while it checks and while
/// it writes. It has no Cancel: a restore is one transaction.
struct ArchiveRestoreSheet: View {
    let status: ArchiveRestoreStatus

    var body: some View {
        ArchiveRestoreProgress(status: status)
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .frame(minWidth: 360)
            .background(AppBackground())
    }
}

/// Covers every other window during a restore, so no one edits the journal
/// while it is written.
struct ArchiveRestoreScrim: View {
    let status: ArchiveRestoreStatus

    var body: some View {
        ZStack {
            Theme.scrim
                .ignoresSafeArea()
                .contentShape(.rect)
                .onTapGesture {}
            ArchiveRestoreProgress(status: status)
                .padding(.horizontal, 40)
                .padding(.vertical, 32)
                .paperCard(cornerRadius: Theme.radiusLarge, elevation: .lg)
        }
        .accessibilityAddTraits(.isModal)
    }
}

/// Enables only `.lateralusarchive` packages and plain folders to move
/// through in the Restore Archive panel. The match uses the extension,
/// because the type identifier changes with the bundle ID.
final class ArchiveOpenPanelDelegate: NSObject, NSOpenSavePanelDelegate {
    func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        if url.pathExtension.lowercased() == JournalArchive.fileExtension { return true }
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        return values?.isDirectory == true && values?.isPackage != true
    }
}
