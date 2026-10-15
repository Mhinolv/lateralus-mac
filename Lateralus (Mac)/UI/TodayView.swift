import SwiftData
import SwiftUI

/// The daily prompt as the hero of the screen, and the door into it. No
/// stats here: streak, week, and totals live in Insights.
struct TodayView: View {
    @Environment(\.appNow) private var appNow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppModel.self) private var appModel
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @State private var activeSession: Prompt?

    private var daily: Prompt { PromptEngine.daily(for: appNow) }

    private var dailyDone: Bool {
        entries.contains {
            $0.isDaily && Calendar.autoupdatingCurrent.isDate($0.date, inSameDayAs: appNow)
        }
    }

    var body: some View {
        content
            .navigationTitle(activeSession?.exercise.title ?? SidebarItem.today.title)
    }

    @ViewBuilder
    private var content: some View {
        if let prompt = activeSession {
            SessionView(
                prompt: prompt,
                isDaily: true,
                onDone: { activeSession = nil },
                onBack: { activeSession = nil }
            )
            .id(prompt.id)
        } else {
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        metaLine
                        promptBlock
                            .padding(.top, 44)
                        beginButton
                            .padding(.top, 36)
                        practiceHint
                            .padding(.top, 20)
                        Spacer(minLength: 48)
                        recentEntries
                    }
                    .padding(.horizontal, 64)
                    .padding(.top, 50)
                    .padding(.bottom, 30)
                    .frame(maxWidth: 960, alignment: .leading)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                }
            }
        }
    }

    /// The date, then the discipline — small, so the prompt below it leads.
    private var metaLine: some View {
        HStack(spacing: 14) {
            Text(appNow.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            Circle()
                .fill(Theme.inkTertiary)
                .frame(width: 4, height: 4)
            Text(daily.exercise.title)
            if dailyDone {
                Badge(text: "Done")
            }
        }
        .font(Theme.ui(13.5))
        .foregroundStyle(Theme.inkTertiary)
    }

    /// The headline and its detail. A new day's prompt arrives from the
    /// trailing edge, or fades in when Reduce Motion is on.
    private var promptBlock: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 18) {
                let scale = HeadlineScale(for: daily.headline)
                Text(Highlight.attributed(daily.headline, marking: daily.markedPhrase))
                    .font(Theme.display(scale.size, weight: .regular))
                    .kerning(scale.kerning)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail = daily.detail {
                    Text(detail)
                        .font(Theme.display(30, weight: .light, italic: true))
                        .lineSpacing(4)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 760, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(daily.id)
            .transition(promptTransition)
        }
        .animation(.easeOut(duration: 0.22), value: daily.id)
    }

    private var promptTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity)
    }

    /// Return runs it, as the hint says.
    private var beginButton: some View {
        Button {
            activeSession = daily
        } label: {
            PrimaryActionButtonLabel(title: dailyDone ? "Answer Again" : "Begin", shortcutHint: "↩")
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
        .accessibilityLabel(
            dailyDone
                ? "Answer today's challenge again: \(daily.exercise.title)"
                : "Begin today's challenge: \(daily.exercise.title)"
        )
        .accessibilityIdentifier("daily-challenge-card")
    }

    private var practiceHint: some View {
        Text("Want more? Every discipline is in the sidebar under Practice.")
            .font(Theme.ui(13))
            .foregroundStyle(Theme.inkTertiary)
    }

    /// The three latest entries in columns under a hairline. Any of them
    /// opens the Journal.
    @ViewBuilder
    private var recentEntries: some View {
        if !entries.isEmpty {
            let recent = Array(entries.prefix(3))
            HStack(alignment: .top, spacing: 28) {
                ForEach(recent) { entry in
                    Button {
                        appModel.select(.journal)
                    } label: {
                        recentColumn(entry)
                    }
                    .buttonStyle(.plain)
                }
                // Keep the columns a third wide when there are fewer than
                // three entries.
                ForEach(recent.count..<3, id: \.self) { _ in
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                }
            }
            .padding(.top, 16)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.divider).frame(height: 1)
            }
        }
    }

    private func recentColumn(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Tag(text: entry.exercise.title)
                Text(whenLabel(for: entry.date))
                    .font(Theme.ui(12))
                    .foregroundStyle(Theme.inkTertiary)
            }
            .lineLimit(1)
            Text(entry.responseText.isEmpty ? entry.promptHeadline : entry.responseText)
                .font(Theme.display(15, weight: .regular))
                .lineSpacing(3)
                .foregroundStyle(Theme.inkSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    /// The time for today's entries, the day for older ones.
    private func whenLabel(for date: Date) -> String {
        if Calendar.autoupdatingCurrent.isDate(date, inSameDayAs: appNow) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}

/// The Today headline size, stepped by length so a short prompt fills the
/// screen and a long one still fits.
struct HeadlineScale: Equatable {
    let size: CGFloat
    let kerning: CGFloat
}

extension HeadlineScale {
    init(for headline: String) {
        switch headline.count {
        case ...24: (size, kerning) = (88, -2)
        case ...60: (size, kerning) = (56, -1.2)
        default: (size, kerning) = (44, -0.8)
        }
    }
}
